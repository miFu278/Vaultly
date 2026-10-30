import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Brand mark: the official Vaultly app icon (padlock + camera aperture).
class VaultMark extends StatelessWidget {
  final double size;
  final bool onColor;

  const VaultMark({super.key, this.size = 40, this.onColor = false});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        'assets/logo_cropped.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onColor ? colors.surface : colors.primary,
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          child: Icon(
            Icons.lock_outline_rounded,
            size: size * 0.5,
            color: onColor ? colors.primary : colors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Resting surface: white card, hairline border, no shadow. Everything that is
/// not floating uses this so the canvas stays flat.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final bool bordered;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool clipContent;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadii.rMd,
    this.color,
    this.borderColor,
    this.bordered = true,
    this.onTap,
    this.width,
    this.height,
    this.clipContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: bordered
          ? BorderSide(color: borderColor ?? colors.border)
          : BorderSide.none,
    );

    return Material(
      color: color ?? colors.surface,
      shape: shape,
      clipBehavior: clipContent ? Clip.antiAlias : Clip.none,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Container(
          width: width,
          height: height,
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

enum PillVariant { primary, secondary, ghost, danger }

/// Pill button. Flat: a solid fill for the single primary action, a hairline
/// outline for secondary ones, and a tinted fill (never a shadow) for danger.
class PillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final PillVariant variant;
  final bool dense;
  final bool expand;
  final double? height;

  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = PillVariant.secondary,
    this.dense = false,
    this.expand = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final enabled = onPressed != null;

    final Color background;
    final Color foreground;
    BorderSide side = BorderSide.none;

    switch (variant) {
      case PillVariant.primary:
        background = enabled ? colors.primary : colors.surfaceMuted;
        foreground = enabled ? colors.onPrimary : colors.foregroundMuted;
      case PillVariant.secondary:
        background = colors.surface;
        foreground = enabled ? colors.foreground : colors.foregroundMuted;
        side = BorderSide(color: colors.border);
      case PillVariant.ghost:
        background = Colors.transparent;
        foreground = enabled ? colors.foregroundMuted : colors.foregroundMuted;
      case PillVariant.danger:
        background = enabled
            ? colors.danger.withValues(alpha: colors.isDark ? 0.18 : 0.10)
            : colors.surfaceMuted;
        foreground = enabled ? colors.danger : colors.foregroundMuted;
    }

    final shape = StadiumBorder(side: side);
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: dense ? 16 : 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label.copyWith(color: foreground),
          ),
        ),
      ],
    );

    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        // Min height, not a fixed one: long labels and larger text scales grow
        // the pill instead of clipping it.
        child: Container(
          constraints: BoxConstraints(minHeight: height ?? (dense ? 40 : 48)),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 14 : 20,
            vertical: 10,
          ),
          child: expand
              ? SizedBox(width: double.infinity, child: content)
              : content,
        ),
      ),
    );
  }
}

/// Circular or pill icon button used in headers, cards and toolbars.
class RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final bool filled;
  final bool bordered;

  const RoundIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 44,
    this.filled = false,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final shape = CircleBorder(
      side: bordered && !filled
          ? BorderSide(color: colors.border)
          : BorderSide.none,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? colors.primary : colors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: shape,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: size * 0.45,
              color: filled ? colors.onPrimary : colors.foregroundMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class PillSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const PillSegment({required this.value, required this.label, this.icon});
}

/// Segmented control. `activeFilled` matches the filter row from the design
/// (active pill is solid primary); the quiet form keeps an inset track.
class SegmentedPills<T> extends StatelessWidget {
  final List<PillSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expand;
  final bool activeFilled;

  const SegmentedPills({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = true,
    this.activeFilled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final pills = [
      for (final segment in segments)
        _pill(
          context,
          colors,
          segment,
          isActive: segment.value == selected,
        ),
    ];

    return Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (var i = 0; i < pills.length; i++) ...[
          if (expand) Expanded(child: pills[i]) else pills[i],
          if (i != pills.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }

  Widget _pill(
    BuildContext context,
    AppColorsData colors,
    PillSegment<T> segment, {
    required bool isActive,
  }) {
    final Color background;
    final Color foreground;
    BorderSide side = BorderSide.none;

    if (isActive) {
      background = activeFilled ? colors.primary : colors.surface;
      foreground = activeFilled ? colors.onPrimary : colors.foreground;
      if (!activeFilled) side = BorderSide(color: colors.border);
    } else {
      background = colors.surface;
      foreground = colors.foregroundMuted;
      side = BorderSide(color: colors.border);
    }

    final shape = StadiumBorder(side: side);

    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(segment.value),
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: 16, color: foreground),
                const SizedBox(width: AppSpacing.xs + 2),
              ],
              Flexible(
                child: Text(
                  segment.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum BadgeTone { neutral, primary, success, danger }

class AppBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color foreground;
    final Color background;

    switch (tone) {
      case BadgeTone.primary:
        foreground = colors.primary;
        background = colors.primarySoft;
      case BadgeTone.success:
        foreground = colors.success;
        background = colors.success.withValues(alpha: colors.isDark ? 0.18 : 0.10);
      case BadgeTone.danger:
        foreground = colors.danger;
        background = colors.danger.withValues(alpha: colors.isDark ? 0.20 : 0.10);
      case BadgeTone.neutral:
        foreground = colors.foregroundMuted;
        background = colors.surfaceMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTypography.micro.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline status strip: security banner, sync state, form errors.
class InfoBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final BadgeTone tone;

  const InfoBanner({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.tone = BadgeTone.success,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final Color accent;
    final Color fill;

    switch (tone) {
      case BadgeTone.success:
        accent = colors.success;
        fill = colors.success.withValues(alpha: colors.isDark ? 0.14 : 0.08);
      case BadgeTone.danger:
        accent = colors.danger;
        fill = colors.danger.withValues(alpha: colors.isDark ? 0.16 : 0.08);
      case BadgeTone.primary:
        accent = colors.primary;
        fill = colors.primarySoft;
      case BadgeTone.neutral:
        accent = colors.foregroundMuted;
        fill = colors.surfaceMuted;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadii.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(color: accent),
                ),
                if (message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    message!,
                    style: AppTypography.caption.copyWith(
                      color: colors.foregroundMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title with an optional count chip and trailing control.
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.only(
      top: AppSpacing.lg,
      bottom: AppSpacing.sm,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title.copyWith(color: colors.foreground),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: AppSpacing.sm),
            AppBadge(label: '$count'),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Empty state: icon, message, optional call to action.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: AppRadii.xl,
              ),
              child: Icon(icon, size: 30, color: colors.foregroundMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.heading.copyWith(color: colors.foreground),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.foregroundMuted),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Flat dialog: title, optional message, optional body, actions row.
class AppDialog extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;
  final IconData? icon;

  const AppDialog({
    super.key,
    required this.title,
    this.message,
    this.body,
    this.actions = const [],
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.dialogMax),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18, color: colors.foreground),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.heading.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message!,
                  style: AppTypography.body.copyWith(
                    color: colors.foregroundMuted,
                  ),
                ),
              ],
              if (body != null) ...[
                const SizedBox(height: AppSpacing.lg),
                body!,
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One tappable row inside a bottom sheet or list: icon tile, title, subtitle.
class SheetAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  const SheetAction({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final foreground = danger ? colors.danger : colors.foreground;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: danger
                    ? colors.danger.withValues(alpha: 0.10)
                    : colors.surfaceMuted,
                borderRadius: AppRadii.sm,
              ),
              child: Icon(icon, size: 18, color: foreground),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.label.copyWith(color: foreground),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: colors.foregroundMuted),
          ],
        ),
      ),
    );
  }
}
