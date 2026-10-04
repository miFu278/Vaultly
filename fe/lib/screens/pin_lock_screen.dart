import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/neumorphic.dart';

enum PinLockMode { unlock, setup }

class PinLockScreen extends StatefulWidget {
  final PinLockMode mode;
  final VoidCallback onSuccess;
  final VoidCallback? onLogout;

  const PinLockScreen({
    super.key,
    required this.mode,
    required this.onSuccess,
    this.onLogout,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final int _pinLength = 6;
  String _enteredPin = '';
  String? _firstEnteredPin;
  bool _isConfirming = false;
  bool _isVerifying = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberPressed(int number) {
    if (_isVerifying) return;
    if (_enteredPin.length < _pinLength) {
      HapticFeedback.lightImpact();
      setState(() {
        _errorMessage = null;
        _enteredPin += number.toString();
      });

      if (_enteredPin.length == _pinLength) {
        _handlePinComplete();
      }
    }
  }

  void _onBackspacePressed() {
    if (_isVerifying) return;
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() {
        _errorMessage = null;
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _triggerErrorShake(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _errorMessage = message;
      _enteredPin = '';
    });
    _shakeController.forward(from: 0.0);
  }

  Future<void> _handlePinComplete() async {
    if (widget.mode == PinLockMode.unlock) {
      setState(() => _isVerifying = true);
      final isValid = await _api.unlockWithPin(_enteredPin);
      if (!mounted) return;
      setState(() => _isVerifying = false);

      if (isValid) {
        HapticFeedback.mediumImpact();
        widget.onSuccess();
      } else {
        _triggerErrorShake('Mã PIN không đúng. Vui lòng thử lại!');
      }
    } else {
      // Setup mode
      if (!_isConfirming) {
        setState(() {
          _firstEnteredPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
          _errorMessage = null;
        });
      } else {
        if (_enteredPin == _firstEnteredPin) {
          setState(() => _isVerifying = true);
          final synced = await _api.setPin(_enteredPin);
          if (!mounted) return;
          setState(() => _isVerifying = false);

          if (!synced && _api.isAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Đã lưu PIN trên thiết bị này nhưng chưa đồng bộ được lên máy chủ.',
                ),
              ),
            );
          }
          HapticFeedback.mediumImpact();
          widget.onSuccess();
        } else {
          _triggerErrorShake('Mã PIN xác nhận không khớp. Hãy thử lại từ đầu!');
          setState(() {
            _firstEnteredPin = null;
            _isConfirming = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final String title;
    final String subtitle;

    if (widget.mode == PinLockMode.unlock) {
      title = 'Bảo mật Vaultly';
      subtitle = 'Nhập mã PIN 6 số để mở khóa thư viện ảnh';
    } else {
      if (!_isConfirming) {
        title = 'Thiết lập mã PIN';
        subtitle = 'Tạo mã PIN 6 số để bảo vệ ảnh riêng tư của bạn';
      } else {
        title = 'Xác nhận mã PIN';
        subtitle = 'Nhập lại mã PIN 6 số bạn vừa tạo';
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        // Scroll-safe: on short screens the keypad scrolls instead of clipping.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - AppSpacing.xl * 2,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: AppSpacing.formMax),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: AppSpacing.xl),

                      // Shield mark in an extruded disc
                      Neumorphic(
                  width: 72,
                  height: 72,
                  radius: AppRadii.rPill,
                  depth: 1.2,
                  color: colors.surface,
                  child: Icon(
                    Icons.shield_outlined,
                    size: 30,
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title (title-lg)
                Text(
                  title,
                  style: AppTypography.titleLg.copyWith(
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs + 2),

                // Subtitle (body)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // PIN dots inside a debossed well; filled = extruded disc
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    final offset = _shakeAnimation.value == 0
                        ? Offset.zero
                        : Offset(_shakeAnimation.value * (_enteredPin.isEmpty ? 1 : -1), 0);
                    return Transform.translate(
                      offset: offset,
                      child: child,
                    );
                  },
                  child: Neumorphic(
                    inset: true,
                    radius: AppRadii.rPill,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pinLength, (index) {
                        final isFilled = index < _enteredPin.length;
                        final dotColor = _errorMessage != null
                            ? colors.danger
                            : colors.foreground;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs + 1,
                          ),
                          child: Neumorphic(
                            width: isFilled ? 16 : 14,
                            height: isFilled ? 16 : 14,
                            radius: AppRadii.rPill,
                            depth: 0.6,
                            inset: !isFilled,
                            color: isFilled ? dotColor : colors.surfaceMuted,
                            child: const SizedBox.shrink(),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Error Message / verifying indicator
                SizedBox(
                  height: 24,
                  child: _isVerifying
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.foregroundMuted,
                          ),
                        )
                      : (_errorMessage != null
                          ? Text(
                              _errorMessage!,
                              style: AppTypography.body.copyWith(
                                color: colors.danger,
                              ),
                            )
                          : null),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // Numeric Keypad (rounded.md, NOT circles)
                _buildKeypad(colors),

                const SizedBox(height: AppSpacing.xl),

                // Footer option: log out
                if (widget.onLogout != null)
                  NeumorphicButton(
                    onPressed: widget.onLogout,
                    icon: Icons.logout,
                    label: 'Đăng xuất tài khoản',
                  ),

                const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(AppColorsData colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeyButton('1', colors, () => _onNumberPressed(1)),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('2', colors, () => _onNumberPressed(2)),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('3', colors, () => _onNumberPressed(3)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeyButton('4', colors, () => _onNumberPressed(4)),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('5', colors, () => _onNumberPressed(5)),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('6', colors, () => _onNumberPressed(6)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildKeyButton('7', colors, () => _onNumberPressed(7)),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('8', colors, () => _onNumberPressed(8)),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('9', colors, () => _onNumberPressed(9)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 74, height: 58),
              const SizedBox(width: AppSpacing.md),
              _buildKeyButton('0', colors, () => _onNumberPressed(0)),
              const SizedBox(width: AppSpacing.md),
              Neumorphic(
                width: 74,
                height: 58,
                radius: AppRadii.rMd,
                onTap: _onBackspacePressed,
                semanticLabel: 'Xóa một số',
                child: Icon(
                  Icons.backspace_outlined,
                  size: 20,
                  color: colors.foreground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(
    String label,
    AppColorsData colors,
    VoidCallback onTap,
  ) {
    return NeumorphicButton(
      width: 74,
      height: 58,
      compact: true,
      label: label,
      onPressed: onTap,
      textStyle: AppTypography.title.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        fontFeatures: AppTypography.tabularFigures,
      ),
    );
  }
}
