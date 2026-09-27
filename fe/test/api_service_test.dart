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

  test('PIN lifecycle: set, verify, reject wrong PIN', () async {
    final api = ApiService();
    expect(api.hasPin, isFalse);
    expect(api.isPinLocked, isFalse); // Not authenticated yet.

    // Not authenticated -> PIN is stored locally only.
    expect(await api.setPin('123456'), isTrue);
    expect(api.hasPin, isTrue);

    expect(api.verifyAndUnlockPin('000000'), isFalse);
    expect(api.verifyAndUnlockPin('123456'), isTrue);
  });

  test('logout clears session and PIN state', () async {
    final api = ApiService();
    await api.setPin('654321');
    expect(api.hasPin, isTrue);

    await api.logout();
    expect(api.hasPin, isFalse);
    expect(api.isAuthenticated, isFalse);
  });
}
