import 'package:flutter/material.dart';
import '../theme/app_tokens.dart';
import '../widgets/flat.dart';

/// Settings: account, the handful of real actions, and the server the app talks
/// to. Actions live in one grouped card with hairlines, not a stack of cards
/// that each repeat the icon-tile-plus-two-lines scaffold.
class SettingsView extends StatelessWidget {
  final String? email;
  final bool isAuthenticated;
  final bool isConnected;
  final bool uploadInProgress;
  final int uploadDone;
  final int uploadTotal;
  final ThemeMode themeMode;
  final String baseUrl;
  final VoidCallback onToggleTheme;
  final VoidCallback onLock;
  final VoidCallback onLogout;
  final VoidCallback onSignIn;
  final VoidCallback onRefresh;

  const SettingsView({
    super.key,
    required this.email,
    required this.isAuthenticated,
    required this.isConnected,
    required this.uploadInProgress,
    required this.uploadDone,
    required this.uploadTotal,
    required this.themeMode,
    required this.baseUrl,
    required this.onToggleTheme,
    required this.onLock,
    required this.onLogout,
    required this.onSignIn,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = colors.isDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.margin,
        0,
        AppSpacing.margin,
        AppSpacing.xl + 80,
      ),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAuthenticated
                      ? Icons.person_rounded
                      : Icons.person_outline_rounded,
                  size: 22,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAuthenticated ? (email ?? 'Tài khoản') : 'Chưa đăng nhập',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: colors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected ? 'Đã kết nối máy chủ' : 'Không kết nối được',
                      style: AppTypography.caption.copyWith(
                        color: colors.foregroundMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: [
              if (isAuthenticated) ...[
                _Row(
                  icon: Icons.lock_outline_rounded,
                  title: 'Khoá kho bằng PIN',
                  onTap: onLock,
                ),
                const _Hairline(),
              ] else ...[
                _Row(
                  icon: Icons.login_rounded,
                  title: 'Đăng nhập hoặc tạo tài khoản',
                  onTap: onSignIn,
                ),
                const _Hairline(),
              ],
              _Row(
                icon: isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                title: isDark ? 'Chuyển sang nền sáng' : 'Chuyển sang nền tối',
                onTap: onToggleTheme,
              ),
              const _Hairline(),
              _Row(
                icon: Icons.sync_rounded,
                title: 'Đồng bộ lại',
                subtitle: uploadInProgress
                    ? 'Đang tải lên $uploadDone/$uploadTotal tệp'
                    : null,
                onTap: onRefresh,
              ),
              if (isAuthenticated) ...[
                const _Hairline(),
                _Row(
                  icon: Icons.logout_rounded,
                  title: 'Đăng xuất',
                  danger: true,
                  onTap: onLogout,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            'Máy chủ',
            style: AppTypography.label.copyWith(color: colors.foregroundMuted),
          ),
        ),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            baseUrl,
            style: AppTypography.body.copyWith(
              color: colors.foreground,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const InfoBanner(
          icon: Icons.info_outline_rounded,
          title: 'Cách kho hoạt động',
          message:
              'Ảnh và video được mã hoá trước khi ghi lên máy chủ. Mở kho bằng mã PIN 6 số trên thiết bị này.',
          tone: BadgeTone.neutral,
        ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: AppColors.of(context).border,
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  const _Row({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
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
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.body.copyWith(color: foreground),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: colors.foregroundMuted,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.foregroundMuted,
            ),
          ],
        ),
      ),
    );
  }
}
