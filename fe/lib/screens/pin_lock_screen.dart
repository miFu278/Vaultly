import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

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
  String? _firstEnteredPin; // for setup confirmation step
  bool _isConfirming = false;
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
      final isValid = _api.verifyAndUnlockPin(_enteredPin);
      if (isValid) {
        HapticFeedback.mediumImpact();
        widget.onSuccess();
      } else {
        _triggerErrorShake('Mã PIN không đúng. Vui lòng thử lại!');
      }
    } else {
      // Setup mode
      if (!_isConfirming) {
        // Step 1: Record first PIN and ask to confirm
        setState(() {
          _firstEnteredPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
          _errorMessage = null;
        });
      } else {
        // Step 2: Verify confirmation
        if (_enteredPin == _firstEnteredPin) {
          await _api.setPin(_enteredPin);
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Shield Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // PIN Dots with Shake Animation
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pinLength, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: isFilled ? 18 : 16,
                        height: isFilled ? 18 : 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled
                              ? (_errorMessage != null
                                  ? Colors.redAccent
                                  : theme.colorScheme.primary)
                              : Colors.transparent,
                          border: Border.all(
                            color: _errorMessage != null
                                ? Colors.redAccent
                                : (isFilled
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor),
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 16),

                // Error Message if any
                SizedBox(
                  height: 24,
                  child: _errorMessage != null
                      ? Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                ),

                const Spacer(flex: 1),

                // Numeric Keypad
                _buildKeypad(theme, isDark),

                const Spacer(flex: 1),

                // Footer options: Logout / Forgot PIN
                if (widget.onLogout != null)
                  TextButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout, size: 16),
                    label: const Text(
                      'Đăng xuất tài khoản',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('1', theme, isDark, () => _onNumberPressed(1)),
              _buildKeyButton('2', theme, isDark, () => _onNumberPressed(2)),
              _buildKeyButton('3', theme, isDark, () => _onNumberPressed(3)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('4', theme, isDark, () => _onNumberPressed(4)),
              _buildKeyButton('5', theme, isDark, () => _onNumberPressed(5)),
              _buildKeyButton('6', theme, isDark, () => _onNumberPressed(6)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildKeyButton('7', theme, isDark, () => _onNumberPressed(7)),
              _buildKeyButton('8', theme, isDark, () => _onNumberPressed(8)),
              _buildKeyButton('9', theme, isDark, () => _onNumberPressed(9)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 72, height: 72), // Empty placeholder
              _buildKeyButton('0', theme, isDark, () => _onNumberPressed(0)),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton(
                  onPressed: _onBackspacePressed,
                  icon: const Icon(Icons.backspace_outlined, size: 24),
                  tooltip: 'Xóa số',
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
    ThemeData theme,
    bool isDark,
    VoidCallback onTap,
  ) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLowest,
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
