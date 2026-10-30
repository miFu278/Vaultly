import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vaultly/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Reset the singleton session/PIN state between tests.
    await ApiService().logout();
  });

  test('ApiException marks 401/403 as unauthorized', () {
    expect(const ApiException(401, 'expired').isUnauthorized, isTrue);
    expect(const ApiException(403, 'forbidden').isUnauthorized, isTrue);
    expect(const ApiException(500, 'oops').isUnauthorized, isFalse);
    expect(const ApiException(400, 'bad').toString(), 'bad');
  });

  test('default API host is the VPS, and only overrides are persisted', () {
    expect(ApiService.defaultBaseUrl, 'https://api-vaultly.mpdev.tech');
    expect(ApiService().baseUrl, ApiService.defaultBaseUrl);

    // The shipped default is not an override, with or without a trailing slash.
    expect(ApiService.isCustomBaseUrl(ApiService.defaultBaseUrl), isFalse);
    expect(
      ApiService.isCustomBaseUrl('https://api-vaultly.mpdev.tech/'),
      isFalse,
    );
    expect(ApiService.isCustomBaseUrl('https://staging.example.com'), isTrue);
  });

  test('PIN lifecycle: set, verify, reject wrong PIN', () async {
    final api = ApiService();
    expect(api.hasPin, isFalse);
    expect(api.isPinLocked, isFalse); // Not authenticated yet.

    // Not authenticated -> PIN is stored locally only.
    expect(await api.setPin('123456'), isTrue);
    expect(api.hasPin, isTrue);

    expect(api.verifyAndUnlockPin('000000'), isFalse);
    expect(api.verifyAndUnlockPin('123456'), isTrue);

    // The PIN must not be readable as plain text on the device.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vaultly_vault_pin'), isNull);
  });
  test('logout clears session and PIN state', () async {
    final api = ApiService();
    await api.setPin('654321');
    expect(api.hasPin, isTrue);

    await api.logout();
    expect(api.hasPin, isFalse);
    expect(api.isAuthenticated, isFalse);
  });

  test('custom folder cover persistence', () async {
    final api = ApiService();
    var covers = await api.loadFolderCustomCovers();
    expect(covers.isEmpty, isTrue);

    await api.setFolderCustomCover('folder_vacation', 'photo_123');
    covers = await api.loadFolderCustomCovers();
    expect(covers['folder_vacation'], 'photo_123');

    // Resetting clears the custom cover
    await api.setFolderCustomCover('folder_vacation', null);
    covers = await api.loadFolderCustomCovers();
    expect(covers.containsKey('folder_vacation'), isFalse);
  });
}
