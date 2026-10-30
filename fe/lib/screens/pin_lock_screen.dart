import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';

enum PinLockMode { unlock, setup }

/// Unlock screen: brand mark, account card, six-dot PIN entry, keypad and the
/// password fallback. Same PIN logic as before, rebuilt flat.
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
    if (_enteredPin.length >= _pinLength) return;

    HapticFeedback.lightImpact();
    setState(() {
      _errorMessage = null;
      _enteredPin += number.toString();
    });

    if (_enteredPin.length == _pinLength) {
      _handlePinComplete();
    }
  }

  void _onBackspacePressed() {
    if (_isVerifying || _enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _errorMessage = null;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
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
    if (_enteredPin.length != _pinLength || _isVerifying) return;

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
      return;
    }

    // Setup mode: enter, then confirm.
    if (!_isConfirming) {
      setState(() {
        _firstEnteredPin = _enteredPin;
        _enteredPin = '';
        _isConfirming = true;
        _errorMessage = null;
      });
      return;
    }

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
      return;
    }

    _triggerErrorShake('Mã PIN xác nhận không khớp. Hãy thử lại từ đầu!');
    setState(() {
      _firstEnteredPin = null;
      _isConfirming = false;
    });
  }

  String get _title {
    if (widget.mode == PinLockMode.unlock) return 'Vaultly';
    return _isConfirming ? 'Xác nhận mã PIN' : 'Tạo mã PIN';
  }

  String get _subtitle {
    if (widget.mode == PinLockMode.unlock) {
      return 'Nhập mã PIN 6 số để mở kho ảnh riêng tư';
    }
    return _isConfirming
        ? 'Nhập lại đúng 6 số bạn vừa chọn'
        : 'Chọn 6 số để bảo vệ kho ảnh trên thiết bị này';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.margin,
              vertical: AppSpacing.lg,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AppSpacing.formMax),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(color: colors.border),
                        ),
                        child: const VaultMark(size: 72),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const AppBadge(
                        label: 'Mã PIN 6 số',
                        tone: BadgeTone.primary,
                        icon: Icons.pin_outlined,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        _title,
                        style: AppTypography.titleLg.copyWith(
                          color: colors.foreground,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          color: colors.foregroundMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _buildCard(context, colors),
                      const SizedBox(height: AppSpacing.lg),
                      _buildKeypad(colors),
                      const SizedBox(height: AppSpacing.xl),
                      if (widget.onLogout != null) _buildFallback(context, colors),
                      const SizedBox(height: AppSpacing.lg),
                      const InfoBanner(
                        icon: Icons.lock_outline_rounded,
                        title: 'Khoá chỉ nằm trên thiết bị này',
                        message:
                            'Ảnh được mã hoá trước khi lưu lên máy chủ. PIN chỉ dùng để mở kho trên máy này.',
                        tone: BadgeTone.neutral,
                      ),
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

  Widget _buildCard(BuildContext context, AppColorsData colors) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.mode == PinLockMode.unlock
                      ? 'Tài khoản'
                      : 'Thiết lập',
                  style: AppTypography.label.copyWith(color: colors.foreground),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AppBadge(
                label: 'Đã bảo vệ',
                tone: BadgeTone.success,
                icon: Icons.shield_outlined,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: AppRadii.md,
            ),
            child: Row(
              children: [
                Icon(Icons.person_outline_rounded,
                    size: 18, color: colors.foregroundMuted),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    _api.userEmail ?? 'Tài khoản trên thiết bị này',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body.copyWith(color: colors.foreground),
                  ),
                ),
                Icon(Icons.lock_outline_rounded,
                    size: 16, color: colors.success),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            widget.mode == PinLockMode.unlock ? 'Mã PIN' : 'Mã PIN mới',
            style: AppTypography.caption.copyWith(color: colors.foregroundMuted),
          ),
          const SizedBox(height: AppSpacing.sm),
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = _shakeAnimation.value == 0
                  ? Offset.zero
                  : Offset(
                      _shakeAnimation.value * (_enteredPin.isEmpty ? 1 : -1),
                      0,
                    );
              return Transform.translate(offset: offset, child: child);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (index) {
                final filled = index < _enteredPin.length;
                return AnimatedContainer(
                  duration: AppMotion.fast,
                  width: filled ? 18 : 16,
                  height: filled ? 18 : 16,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: _errorMessage != null
                        ? (_enteredPin.isEmpty
                            ? colors.surfaceMuted
                            : colors.danger)
                        : (filled ? colors.primary : colors.surfaceMuted),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: filled ? Colors.transparent : colors.border,
                    ),
                  ),
                );
              }),
            ),
          ),
          SizedBox(
            height: 34,
            child: Center(
              child: _isVerifying
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.primary,
                      ),
                    )
                  : (_errorMessage != null
                      ? Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(
                            color: colors.danger,
                          ),
                        )
                      : null),
            ),
          ),
          PillButton(
            label: widget.mode == PinLockMode.unlock
                ? 'Mở khoá'
                : (_isConfirming ? 'Xác nhận PIN' : 'Tiếp tục'),
            icon: Icons.lock_open_rounded,
            variant: PillVariant.primary,
            expand: true,
            height: 52,
            onPressed: _enteredPin.length == _pinLength && !_isVerifying
                ? _handlePinComplete
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad(AppColorsData colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.lg,
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ])
            Row(
              children: [
                for (final key in row)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: key.isEmpty
                          ? const SizedBox(height: 56)
                          : _buildKeyButton(colors, key),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildKeyButton(AppColorsData colors, String key) {
    final isBackspace = key == '⌫';

    return Material(
      color: colors.surfaceMuted,
      borderRadius: AppRadii.md,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isBackspace
            ? _onBackspacePressed
            : () => _onNumberPressed(int.parse(key)),
        child: SizedBox(
          height: 56,
          child: Center(
            child: isBackspace
                ? Icon(Icons.backspace_outlined,
                    size: 20, color: colors.foregroundMuted)
                : Text(
                    key,
                    style: AppTypography.title.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: colors.foreground,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(BuildContext context, AppColorsData colors) {
    return InkWell(
      onTap: widget.onLogout,
      borderRadius: AppRadii.lg,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.lg,
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.password_rounded,
                  size: 18, color: colors.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Đăng nhập bằng mật khẩu',
                    style: AppTypography.label.copyWith(
                      color: colors.foreground,
                    ),
                  ),
                  Text(
                    'Dùng email và mật khẩu của tài khoản',
                    style: AppTypography.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded,
                size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
