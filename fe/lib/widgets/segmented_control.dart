import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

class VaultlySegment<T> {
  final T value;
  final String label;
  final Widget? icon;

  const VaultlySegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

class VaultlySegmentedControl<T> extends StatelessWidget {
  final T selectedValue;
  final List<VaultlySegment<T>> segments;
  final ValueChanged<T> onValueChanged;
  final bool expand;

  const VaultlySegmentedControl({
    super.key,
    required this.selectedValue,
    required this.segments,
    required this.onValueChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = segments.map((seg) {
      final isSelected = seg.value == selectedValue;

      final segmentWidget = InkWell(
        onTap: () => onValueChanged(seg.value),
        borderRadius: AppRadii.xs,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? colors.surface : Colors.transparent,
            borderRadius: AppRadii.xs,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (seg.icon != null) ...[
                seg.icon!,
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                seg.label,
                style: AppTypography.heading.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colors.primary : colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      );

      if (expand) {
        return Expanded(child: segmentWidget);
      }
      return segmentWidget;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: AppRadii.sm,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: items,
      ),
    );
  }
}
