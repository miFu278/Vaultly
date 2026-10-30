import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';

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
              horizontal: AppSpacing.margin,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppSpacing.formMax),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: colors.border),
                        ),
                        child: const VaultMark(size: 64),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Vaultly',
                      textAlign: TextAlign.center,
                      style: AppTypography.titleLg.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Kho ảnh riêng tư, mã hóa đầu cuối',
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SegmentedPills<int>(
                      selected: _activeTab,
                      onChanged: _onTabChanged,
                      activeFilled: false,
                      segments: const [
                        PillSegment(value: 0, label: 'Đăng nhập'),
                        PillSegment(value: 1, label: 'Đăng ký mới'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (_errorMessage != null) ...[
                      InfoBanner(
                        icon: Icons.error_outline_rounded,
                        title: _errorMessage!,
                        tone: BadgeTone.danger,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.body.copyWith(color: colors.foreground),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
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
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                        suffixIcon: IconButton(
                          tooltip:
                              _obscurePassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
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
                          prefixIcon:
                              const Icon(Icons.lock_reset_outlined, size: 18),
                          suffixIcon: IconButton(
                            tooltip: _obscureConfirmPassword
                                ? 'Ẩn mật khẩu'
                                : 'Hiện mật khẩu',
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
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
                    PillButton(
                      label: _activeTab == 0 ? 'Đăng nhập' : 'Tạo tài khoản',
                      icon: _isLoading ? null : Icons.arrow_forward_rounded,
                      variant: PillVariant.primary,
                      height: 52,
                      onPressed: _isLoading ? null : _submit,
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: AppSpacing.md),
                      LinearProgressIndicator(
                        minHeight: 3,
                        color: colors.primary,
                        backgroundColor: colors.surfaceMuted,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PillButton(
                      label: 'Dùng thử tài khoản Demo',
                      icon: Icons.bolt_outlined,
                      onPressed: _isLoading ? null : _fillDemoAccount,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: TextButton(
                        onPressed: () =>
                            setState(() => _showUrlConfig = !_showUrlConfig),
                        child: Text(
                          _showUrlConfig
                              ? 'Ẩn cấu hình máy chủ'
                              : 'Tuỳ chỉnh API Server',
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
                        style: AppTypography.body.copyWith(
                          color: colors.foreground,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'API Base URL',
                          hintText: 'https://api-vaultly.mpdev.tech',
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
