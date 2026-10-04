import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import 'neumorphic.dart';

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

/// Neumorphic segmented control: a debossed track with one extruded segment.
/// The active segment is the only raised element, so selection never relies on
/// color alone.
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

  static const double _segmentHeight = 34;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    final items = segments.map((seg) {
      final isSelected = seg.value == selectedValue;

      final content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (seg.icon != null) ...[
            seg.icon!,
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              seg.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.heading.copyWith(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? colors.foreground : colors.foregroundMuted,
              ),
            ),
          ),
        ],
      );

      final Widget item = isSelected
          ? Neumorphic(
              height: _segmentHeight,
              radius: AppRadii.rXs,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              color: colors.surface,
              onTap: () => onValueChanged(seg.value),
              semanticLabel: seg.label,
              child: content,
            )
          : InkWell(
              onTap: () => onValueChanged(seg.value),
              borderRadius: AppRadii.xs,
              child: SizedBox(
                height: _segmentHeight,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: content,
                  ),
                ),
              ),
            );

      return expand ? Expanded(child: item) : item;
    }).toList();

    return Neumorphic(
      inset: true,
      radius: AppRadii.rMd,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: items,
      ),
    );
  }
}
