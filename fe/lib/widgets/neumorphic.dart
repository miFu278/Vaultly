import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_tokens.dart';

/// The single neumorphic primitive: an extruded (`raised`) or debossed (`inset`)
/// surface. Pressing a tappable surface animates raised -> inset, which is the
/// neumorphic equivalent of a press state (there are no ripples or borders).
class Neumorphic extends StatefulWidget {
  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool inset;
  final double depth;
  final Color? color;
  final double? width;
  final double? height;
  final String? semanticLabel;
  final bool clipContent;
  final bool hoverLift;

  const Neumorphic({
    super.key,
    required this.child,
    this.radius = AppRadii.rSm,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.inset = false,
    this.depth = 1.0,
    this.color,
    this.width,
    this.height,
    this.semanticLabel,
    this.clipContent = false,
    this.hoverLift = false,
  });

  @override
  State<Neumorphic> createState() => _NeumorphicState();
}

class _NeumorphicState extends State<Neumorphic> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _isInteractive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (!_isInteractive || _pressed == value) return;
    setState(() => _pressed = value);
  }

  void _setHovered(bool value) {
    if (!widget.hoverLift || _hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final base = widget.color ?? colors.surface;
    final inset = widget.inset || _pressed;
    final radius = widget.borderRadius ?? BorderRadius.circular(widget.radius);
    final lift = widget.hoverLift && _hovered && !inset;

    final surface = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.ease,
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      clipBehavior: widget.clipContent ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: inset ? null : base,
        gradient: inset ? AppShadows.insetGradient(colors, base) : null,
        borderRadius: radius,
        border: inset ? Border.all(color: colors.border, width: 1) : null,
        boxShadow: inset
            ? AppShadows.inset(colors)
            : AppShadows.raised(colors, depth: widget.depth * (lift ? 1.4 : 1.0)),
      ),
      child: widget.child,
    );

    Widget result = surface;
    if (widget.margin != null) {
      result = Padding(padding: widget.margin!, child: result);
    }
    if (!widget.hoverLift) return _wrapInteractive(result);

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: _wrapInteractive(result),
    );
  }

  Widget _wrapInteractive(Widget surface) {
    if (!_isInteractive) return surface;

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onTap,
          onLongPress: widget.onLongPress == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onLongPress!();
                },
          child: AnimatedScale(
            scale: _pressed ? 0.97 : 1.0,
            duration: AppMotion.fast,
            curve: AppMotion.ease,
            child: surface,
          ),
        ),
      ),
    );
  }
}

/// Neumorphic dialog shell: transparent Material frame + one extruded panel.
class NeumorphicDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets insetPadding;

  const NeumorphicDialog({
    super.key,
    required this.child,
    this.maxWidth = 400,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.xl,
    ),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Neumorphic(
          depth: 1.4,
          radius: AppRadii.rLg,
          clipContent: true,
          child: child,
        ),
      ),
    );
  }
}

/// Soft-UI button: same-tone extruded surface by default, ink-filled for the
/// single primary action, filled red for destructive actions.
class NeumorphicButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool danger;
  final bool compact;
  final double? width;
  final double? height;
  final TextStyle? textStyle;

  const NeumorphicButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.primary = false,
    this.danger = false,
    this.compact = false,
    this.width,
    this.height,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final disabled = onPressed == null;

    final Color background;
    final Color foreground;
    if (disabled) {
      background = colors.surfaceMuted;
      foreground = colors.foregroundMuted.withValues(alpha: 0.7);
    } else if (danger) {
      background = colors.danger;
      foreground = colors.isDark ? colors.background : Colors.white;
    } else if (primary) {
      background = colors.primary;
      foreground = Theme.of(context).colorScheme.onPrimary;
    } else {
      background = colors.surface;
      foreground = colors.foreground;
    }

    final labelStyle = (textStyle ?? AppTypography.label).copyWith(
      color: foreground,
      fontWeight: primary || danger ? FontWeight.w600 : FontWeight.w500,
    );

    return Neumorphic(
      width: width,
      height: height ?? (compact ? 44 : 46),
      radius: AppRadii.rMd,
      depth: compact ? 0.7 : 1.0,
      color: background,
      inset: disabled,
      onTap: onPressed,
      semanticLabel: label,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 15 : 16, color: foreground),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: labelStyle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular neumorphic icon control. Always keeps a 44pt hit target even when
/// the glyph is smaller.
class NeumorphicIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final double iconSize;
  final bool inset;
  final Color? iconColor;
  final double hitTarget;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.iconSize = 18,
    this.inset = false,
    this.iconColor,
    this.hitTarget = AppSpacing.touchTarget,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final disabled = onPressed == null;
    final color = disabled
        ? colors.foregroundMuted.withValues(alpha: 0.5)
        : (iconColor ?? colors.foregroundMuted);

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: hitTarget,
        height: hitTarget,
        child: Neumorphic(
          radius: AppRadii.rPill,
          inset: inset,
          onTap: disabled ? null : onPressed,
          semanticLabel: tooltip,
          child: Center(
            child: Icon(icon, size: iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
