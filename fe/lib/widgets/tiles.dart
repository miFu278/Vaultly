import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';

/// Rounded pastel square holding a category icon, as in the reference design.
class TintedIconTile extends StatelessWidget {
  final IconData icon;
  final AppTintKind kind;
  final double size;

  const TintedIconTile({
    super.key,
    required this.icon,
    required this.kind,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final tint = AppTint.of(context, kind);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: BorderRadius.circular(size * 0.30),
      ),
      child: Icon(icon, size: size * 0.46, color: tint.foreground),
    );
  }
}

/// Card cut into the silhouette of a manila folder: a tab on the top-left and a
/// rounded body. Flat surfaces still read as a folder because the outline, not a
/// shadow, carries the shape.
class FolderCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry contentPadding;

  /// Height of the tab above the body.
  static const double tabHeight = 14;

  const FolderCard({
    super.key,
    required this.child,
    this.onTap,
    this.contentPadding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.md,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FolderShapePainter(
                    fill: colors.surface,
                    border: colors.border,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: tabHeight),
                child: Padding(
                  padding: contentPadding,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FolderShapePainter extends CustomPainter {
  final Color fill;
  final Color border;

  const _FolderShapePainter({required this.fill, required this.border});

  @override
  void paint(Canvas canvas, Size size) {
    const tabHeight = FolderCard.tabHeight;
    final tabWidth = math.min(size.width * 0.45, 104.0);

    final body = Path()
      ..addRRect(
        RRect.fromLTRBR(
          0.5,
          tabHeight,
          size.width - 0.5,
          size.height - 0.5,
          const Radius.circular(AppRadii.rLg),
        ),
      );
    final tab = Path()
      ..addRRect(
        RRect.fromLTRBR(
          8,
          0.5,
          8 + tabWidth,
          tabHeight + AppRadii.rLg,
          const Radius.circular(AppRadii.rSm),
        ),
      );

    final shape = Path.combine(PathOperation.union, body, tab);

    canvas.drawPath(shape, Paint()..color = fill);
    canvas.drawPath(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(_FolderShapePainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.border != border;
}

/// Donut gauge: used space split into photos and videos, with the percentage in
/// the middle. Reads real numbers from `GET /storage`.
class StorageGauge extends StatelessWidget {
  final double percent;
  final int photoBytes;
  final int videoBytes;
  final int usedBytes;
  final int quotaBytes;
  final double size;

  const StorageGauge({
    super.key,
    required this.percent,
    required this.photoBytes,
    required this.videoBytes,
    required this.usedBytes,
    required this.quotaBytes,
    this.size = 168,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final photoTint = AppTint.of(context, AppTintKind.amber);
    final videoTint = AppTint.of(context, AppTintKind.blue);
    final total = photoBytes + videoBytes;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GaugePainter(
          percent: percent.clamp(0, 100).toDouble(),
          photoShare: total <= 0 ? 0 : photoBytes / total,
          videoShare: total <= 0 ? 0 : videoBytes / total,
          track: colors.surfaceMuted,
          photo: photoTint.foreground,
          video: videoTint.foreground,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${percent.clamp(0, 100).round()}%',
                style: AppTypography.titleLg.copyWith(
                  color: colors.foreground,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatBytes(usedBytes),
                style: AppTypography.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final double photoShare;
  final double videoShare;
  final Color track;
  final Color photo;
  final Color video;

  const _GaugePainter({
    required this.percent,
    required this.photoShare,
    required this.videoShare,
    required this.track,
    required this.photo,
    required this.video,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 14.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.shortestSide - strokeWidth) / 2,
    );

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);

    if (percent <= 0) return;

    // The filled arc always shows the used share; inside it, photos and videos
    // are split by their real byte shares.
    final usedSweep = math.pi * 2 * (percent / 100);
    const start = -math.pi / 2;

    final photoPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = photo;
    final videoPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = video;

    final photoSweep = usedSweep * photoShare;
    final videoSweep = usedSweep * videoShare;
    final otherSweep = usedSweep - photoSweep - videoSweep;

    if (photoSweep > 0.01) {
      canvas.drawArc(rect, start, photoSweep, false, photoPaint);
    }
    if (videoSweep > 0.01) {
      canvas.drawArc(rect, start + photoSweep, videoSweep, false, videoPaint);
    }
    if (otherSweep > 0.01) {
      canvas.drawArc(
        rect,
        start + photoSweep + videoSweep,
        otherSweep,
        false,
        photoPaint..color = track,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.percent != percent ||
      oldDelegate.photoShare != photoShare ||
      oldDelegate.videoShare != videoShare;
}

/// Human readable byte size with one decimal, matching the reference copy.
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = value >= 100 || unit == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
