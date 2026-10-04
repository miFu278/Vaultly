import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_tokens.dart';
import 'neumorphic.dart';

/// Plays an E2EE video stream served by `GET /files/{id}/view`.
///
/// Controls sit *below* the video, never on top of it: on Flutter web the
/// `<video>` element is a platform view that composites above the Flutter
/// canvas, so an overlaid control would be invisible there.
class VideoPlayerView extends StatefulWidget {
  final String url;

  const VideoPlayerView({super.key, required this.url});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  bool _dragging = false;
  double _dragValueMs = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  @override
  void dispose() {
    _release(_controller);
    super.dispose();
  }

  /// Tears the native player down without letting a rejected platform call
  /// surface as an unhandled async error.
  void _release(VideoPlayerController? controller) {
    if (controller == null) return;
    controller.removeListener(_onValueChanged);
    controller.dispose().catchError((Object _) {});
  }

  Future<void> _load() async {
    final previous = _controller;
    _controller = null;
    _release(previous);

    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    controller.addListener(_onValueChanged);
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || _controller != controller) return;
      setState(() => _initializing = false);
    } catch (_) {
      if (!mounted || _controller != controller) return;
      setState(() {
        _initializing = false;
        _error = 'Không phát được video này. Kiểm tra kết nối rồi thử lại.';
      });
    }
  }

  /// Surfaces runtime playback failures (dead stream, unsupported codec).
  void _onValueChanged() {
    if (!mounted || _error != null) return;
    final value = _controller?.value;
    if (value == null || !value.hasError) return;
    setState(() {
      _error = value.errorDescription?.isNotEmpty == true
          ? value.errorDescription!
          : 'Không phát được video này.';
    });
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  static String _format(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(hours > 0 ? 2 : 1, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final controller = _controller;

    if (_error != null) {
      return _buildMessage(colors, _error!, Icons.error_outline);
    }

    if (_initializing || controller == null || !controller.value.isInitialized) {
      return _buildLoading(colors);
    }

    final aspectRatio =
        controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Neumorphic(
              inset: true,
              radius: AppRadii.rMd,
              color: colors.mediaCanvas,
              clipContent: true,
              padding: const EdgeInsets.all(6),
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRRect(
                  borderRadius: AppRadii.xs,
                  child: GestureDetector(
                    onTap: _togglePlay,
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: controller,
                      builder: (context, value, _) => Stack(
                        fit: StackFit.expand,
                        children: [
                          VideoPlayer(controller),
                          if (value.isBuffering)
                            Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.foreground,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildControls(colors, controller),
      ],
    );
  }

  Widget _buildLoading(AppColorsData colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Neumorphic(
            width: 72,
            height: 72,
            inset: true,
            radius: AppRadii.rPill,
            color: colors.surfaceMuted,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.foregroundMuted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Đang giải mã & tải video…',
            style: AppTypography.body.copyWith(color: colors.foregroundMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(AppColorsData colors, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Neumorphic(
              width: 72,
              height: 72,
              inset: true,
              radius: AppRadii.rPill,
              color: colors.surfaceMuted,
              child: Icon(icon, size: 30, color: colors.danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.foregroundMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            NeumorphicButton(
              onPressed: _load,
              icon: Icons.refresh_rounded,
              label: 'Thử lại',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(AppColorsData colors, VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final duration = value.duration;
        final totalMs = duration.inMilliseconds;
        final position = _dragging
            ? Duration(milliseconds: _dragValueMs.round())
            : value.position;
        final positionMs =
            position.inMilliseconds.clamp(0, totalMs < 0 ? 0 : totalMs);

        return Neumorphic(
          radius: AppRadii.rMd,
          depth: 0.7,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              NeumorphicIconButton(
                icon: value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                iconSize: 22,
                iconColor: colors.foreground,
                onPressed: _togglePlay,
              ),
              Text(
                _format(position),
                style: AppTypography.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: colors.foreground,
                    inactiveTrackColor: colors.border,
                    thumbColor: colors.foreground,
                    overlayColor: colors.foreground.withValues(alpha: 0.08),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16),
                  ),
                  child: Slider(
                    value: positionMs.toDouble(),
                    max: totalMs <= 0 ? 1 : totalMs.toDouble(),
                    onChanged: totalMs <= 0
                        ? null
                        : (next) => setState(() {
                              _dragging = true;
                              _dragValueMs = next;
                            }),
                    onChangeEnd: (next) {
                      setState(() => _dragging = false);
                      controller.seekTo(Duration(milliseconds: next.round()));
                    },
                  ),
                ),
              ),
              Text(
                _format(duration),
                style: AppTypography.caption.copyWith(
                  color: colors.foregroundMuted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
