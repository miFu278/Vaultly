import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';
import '../widgets/tiles.dart';

/// First-run introduction, shown once before the shell. It mirrors the reference
/// onboarding: folder art, a headline with one pill word, and page controls.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;

  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const int _pageCount = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _pageCount - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  const VaultMark(size: 36),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Text(
                    'Vaultly',
                    style: AppTypography.brand.copyWith(color: colors.foreground),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text(
                      'Bỏ qua',
                      style: AppTypography.label.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: const [
                  _PromisePage(),
                  _SecurityPage(),
                  _ReadyPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                AppSpacing.xl,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _pageCount; i++)
                    AnimatedContainer(
                      duration: AppMotion.fast,
                      width: i == _page ? 22 : 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: i == _page ? colors.primary : colors.border,
                        borderRadius: AppRadii.pill,
                      ),
                    ),
                  const Spacer(),
                  if (_page > 0) ...[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onPressed: _back,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  RoundIconButton(
                    icon: _page == _pageCount - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    tooltip: _page == _pageCount - 1 ? 'Bắt đầu' : 'Tiếp tục',
                    filled: true,
                    size: 52,
                    onPressed: _next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stacked folder cards standing in for a vault of albums.
class _FolderStack extends StatelessWidget {
  const _FolderStack();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          for (final (top, inset, height, opacity) in const [
            (0.0, 30.0, 150.0, 0.35),
            (12.0, 15.0, 150.0, 0.6),
          ])
            Positioned(
              top: top,
              left: inset,
              right: inset,
              height: height,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity,
                  child: FolderCard(
                    child: Text(
                      'Album',
                      style: AppTypography.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 26,
            left: 0,
            right: 0,
            height: 170,
            child: FolderCard(
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  children: [
                    const TintedIconTile(
                      icon: Icons.photo_library_outlined,
                      kind: AppTintKind.violet,
                      size: 46,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Gallery',
                      style: AppTypography.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageScaffold extends StatelessWidget {
  final Widget art;
  final Widget headline;
  final String body;

  const _PageScaffold({
    required this.art,
    required this.headline,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.margin),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              art,
              const SizedBox(height: AppSpacing.xl),
              headline,
              const SizedBox(height: AppSpacing.md),
              Text(
                body,
                style: AppTypography.body.copyWith(
                  color: colors.foregroundMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromisePage extends StatelessWidget {
  const _PromisePage();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return _PageScaffold(
      art: const _FolderStack(),
      headline: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Ảnh và tệp của bạn.\nLuôn được ',
              style: AppTypography.titleLg.copyWith(
                color: colors.foreground,
                fontSize: 32,
              ),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  'bảo vệ',
                  style: AppTypography.titleLg.copyWith(
                    color: colors.primary,
                    fontSize: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body:
          'Lưu ảnh và video trong một kho riêng, tổ chức theo album và mở lại trên mọi thiết bị đã uỷ quyền.',
    );
  }
}

class _SecurityPage extends StatelessWidget {
  const _SecurityPage();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return _PageScaffold(
      art: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.xl,
            border: Border.all(color: colors.border),
          ),
          child: const TintedIconTile(
            icon: Icons.lock_outline_rounded,
            kind: AppTintKind.green,
            size: 76,
          ),
        ),
      ),
      headline: Text(
        'Mã hoá trước khi lưu',
        style: AppTypography.titleLg.copyWith(color: colors.foreground),
      ),
      body:
          'Ảnh và video được mã hoá trước khi ghi lên máy chủ. Mỗi lần mở kho đều cần mã PIN 6 số.',
    );
  }
}

class _ReadyPage extends StatelessWidget {
  const _ReadyPage();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return _PageScaffold(
      art: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.xl,
            border: Border.all(color: colors.border),
          ),
          child: const TintedIconTile(
            icon: Icons.folder_special_outlined,
            kind: AppTintKind.violet,
            size: 76,
          ),
        ),
      ),
      headline: Text(
        'Sẵn sàng xây kho riêng',
        style: AppTypography.titleLg.copyWith(color: colors.foreground),
      ),
      body:
          'Tạo album đầu tiên, tải ảnh lên và đặt mã PIN. Bạn có thể đổi giao diện sáng tối bất cứ lúc nào trong Cài đặt.',
    );
  }
}
