import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/segmented_control.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const AuthScreen({super.key, required this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final ApiService _api = ApiService();
  int _activeTab = 0; // 0: Login, 1: Register

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _urlController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  bool _showUrlConfig = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = _api.baseUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _activeTab = index;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isRegister = _activeTab == 1;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (isRegister && password != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Mật khẩu xác nhận không khớp!';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_urlController.text.trim().isNotEmpty) {
      _api.baseUrl = _urlController.text.trim();
    }

    final res = isRegister
        ? await _api.register(email, password)
        : await _api.login(email, password);

    if (!mounted) return;

    if (res['success'] == true) {
      widget.onSuccess();
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = res['error']?.toString() ?? 'Đã có lỗi xảy ra';
      });
    }
  }

  void _fillDemoAccount() {
    _emailController.text = 'demo@vaultly.com';
    _passwordController.text = 'Password123!';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.formMax),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Icon ({rounded.xl} hero icon tile)
                    Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: AppRadii.xl,
                          border: Border.all(color: colors.border, width: 1),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 28,
                          color: colors.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Auth Hero Title (title-lg: 26px, w700, -0.5px)
                    Text(
                      'Vaultly Secure Vault',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLg.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Bảo mật ảnh cá nhân chuẩn E2EE',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Segmented Control for Auth Tabs (DESIGN.md)
                    VaultlySegmentedControl<int>(
                      selectedValue: _activeTab,
                      expand: true,
                      segments: const [
                        VaultlySegment(value: 0, label: 'Đăng nhập'),
                        VaultlySegment(value: 1, label: 'Đăng ký mới'),
                      ],
                      onValueChanged: _onTabChanged,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Error Banner in danger color if any
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm + 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceMuted,
                          borderRadius: AppRadii.sm,
                          border: Border.all(color: colors.danger, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, size: 16, color: colors.danger),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTypography.body.copyWith(
                                  color: colors.danger,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Email Field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.body.copyWith(color: colors.foreground),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined, size: 18),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập email';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Email không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: _activeTab == 1
                          ? TextInputAction.next
                          : TextInputAction.done,
                      style: AppTypography.body.copyWith(color: colors.foreground),
                      onFieldSubmitted: (_) {
                        if (_activeTab == 0) _submit();
                      },
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng nhập mật khẩu';
                        }
                        if (_activeTab == 1 && value.length < 8) {
                          return 'Mật khẩu cần tối thiểu 8 ký tự';
                        }
                        return null;
                      },
                    ),

                    // Confirm Password Field (Only on Register tab)
                    if (_activeTab == 1) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        style: AppTypography.body.copyWith(color: colors.foreground),
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Xác nhận mật khẩu',
                          prefixIcon: const Icon(Icons.lock_reset_outlined, size: 18),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(() =>
                                _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (value) {
                          if (_activeTab == 1) {
                            if (value == null || value.isEmpty) {
                              return 'Vui lòng xác nhận mật khẩu';
                            }
                            if (value != _passwordController.text) {
                              return 'Mật khẩu xác nhận không khớp';
                            }
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // Primary Action Button ({colors.primary} filled, single primary action)
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.surface,
                                ),
                              )
                            : Text(
                                _activeTab == 0 ? 'Đăng nhập' : 'Tạo tài khoản',
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm + 2),

                    // 1-Click Demo Account Login (OutlinedButton secondary)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _fillDemoAccount,
                      icon: const Icon(Icons.bolt_outlined, size: 16),
                      label: const Text('Dùng thử tài khoản Demo'),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Collapsible Backend URL Setting
                    Center(
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _showUrlConfig = !_showUrlConfig),
                        icon: Icon(
                          _showUrlConfig
                              ? Icons.keyboard_arrow_up
                              : Icons.settings_outlined,
                          size: 14,
                        ),
                        label: Text(
                          _showUrlConfig
                              ? 'Ẩn cấu hình máy chủ'
                              : 'Tùy chỉnh API Server',
                          style: AppTypography.label.copyWith(
                            color: colors.foregroundMuted,
                          ),
                        ),
                      ),
                    ),

                    if (_showUrlConfig) ...[
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _urlController,
                        style: AppTypography.label.copyWith(color: colors.foreground),
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'https://vaultly-ghqy.onrender.com',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
