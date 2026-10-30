import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/flat.dart';

void main() {
  runApp(const VaultlyApp());
}

class VaultlyApp extends StatefulWidget {
  const VaultlyApp({super.key});

  @override
  State<VaultlyApp> createState() => _VaultlyAppState();
}

class _VaultlyAppState extends State<VaultlyApp> {
  // The design ships light first: opening in light regardless of the phone's
  // system theme is what the reference screens specify.
  ThemeMode _themeMode = ThemeMode.light;

  /// null while the stored onboarding flag is being read.
  bool? _showOnboarding;

  @override
  void initState() {
    super.initState();
    _loadFirstRunState();
  }

  Future<void> _loadFirstRunState() async {
    final api = ApiService();
    await api.init();
    final seen = await api.hasSeenOnboarding();
    if (!mounted) return;
    setState(() => _showOnboarding = !seen);
  }

  Future<void> _finishOnboarding() async {
    await ApiService().completeOnboarding();
    if (!mounted) return;
    setState(() => _showOnboarding = false);
  }

  void _toggleTheme() {
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
      } else {
        _themeMode = ThemeMode.dark;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VAULTLY - Secure Photos Vault',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (_showOnboarding) {
      case null:
        return const _LaunchScreen();
      case true:
        return OnboardingScreen(onDone: _finishOnboarding);
      case false:
        return HomeScreen(
          currentThemeMode: _themeMode,
          onToggleTheme: _toggleTheme,
        );
    }
  }
}

/// Blank branded frame for the frame or two before the stored flag is read, so
/// the shell never flashes before the introduction.
class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: const Center(child: VaultMark(size: 64)),
    );
  }
}
