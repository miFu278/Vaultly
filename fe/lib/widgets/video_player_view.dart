import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_tokens.dart';
import 'flat.dart';

/// Plays an E2EE video stream served by `GET /files/{id}/view`.
///
/// Supports completely immersive fullscreen playback. When [showControls] is false,
/// no chrome or headers obstruct the video. Controls overlay gently at the bottom
/// when requested and hide with a tap.
class VideoPlayerView extends StatefulWidget {
  final String url;
  final bool showControls;
  final VoidCallback? onTap;

  const VideoPlayerView({
    super.key,
    required this.url,
    this.showControls = true,
    this.onTap,
  });

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
      // Auto play video when ready
      controller.play();
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap ?? _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Edge-to-edge centered video player (pure fullscreen)
          Center(
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),

          // Buffering spinner
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (!value.isBuffering) return const SizedBox.shrink();
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),

          // Floating video controls overlay: fades with showControls
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              opacity: widget.showControls ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !widget.showControls,
                child: _buildControls(colors, controller),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(AppColorsData colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
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
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: colors.danger),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: colors.foregroundMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            PillButton(
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

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: AppRadii.pill,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: AppElevation.floating(colors),
          ),
          child: Row(
            children: [
              RoundIconButton(
                icon: value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                tooltip: value.isPlaying ? 'Tạm dừng' : 'Phát',
                size: 38,
                filled: true,
                bordered: false,
                onPressed: _togglePlay,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                _format(position),
                style: AppTypography.caption.copyWith(
                  color: Colors.white,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: colors.primary,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.24),
                    thumbColor: Colors.white,
                    overlayColor: colors.primary.withValues(alpha: 0.20),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
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
                  color: Colors.white70,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}
