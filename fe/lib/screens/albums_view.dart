import 'package:flutter/material.dart';
import '../models/folder.dart';
import '../models/photo_item.dart';
import '../theme/app_tokens.dart';
import '../widgets/album_card.dart';
import '../widgets/flat.dart';

/// Albums view: the user's folders as folder-shaped cards with cover collages.
class AlbumsView extends StatelessWidget {
  final List<Folder> albums;
  final Map<String, List<PhotoItem>> photosByAlbum;
  final ValueChanged<Folder> onOpen;
  final ValueChanged<Folder> onDelete;
  final VoidCallback onCreate;

  const AlbumsView({
    super.key,
    required this.albums,
    required this.photosByAlbum,
    required this.onOpen,
    required this.onDelete,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 620
                ? 3
                : 2;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        albums.isEmpty
                            ? 'Gom ảnh theo chủ đề riêng của bạn'
                            : '${albums.length} album • ${photosByAlbum.values.fold<int>(0, (sum, list) => sum + list.length)} mục',
                        style: AppTypography.caption.copyWith(
                          color: colors.foregroundMuted,
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                    ),
                    PillButton(
                      label: 'Album mới',
                      icon: Icons.create_new_folder_outlined,
                      variant: PillVariant.primary,
                      dense: true,
                      onPressed: onCreate,
                    ),
                  ],
                ),
              ),
            ),
            if (albums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Chưa có album nào',
                  message:
                      'Tạo album để nhóm ảnh và video theo chủ đề, ví dụ "Gia đình" hay "Hoá đơn".',
                  action: PillButton(
                    label: 'Tạo album đầu tiên',
                    icon: Icons.add_rounded,
                    variant: PillVariant.primary,
                    dense: true,
                    onPressed: onCreate,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.margin,
                  AppSpacing.lg,
                  AppSpacing.margin,
                  AppSpacing.xl + 72,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 0.82,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final album = albums[index];
                      return AlbumFolderCard(
                        album: album,
                        photos: photosByAlbum[album.id] ?? const [],
                        onTap: () => onOpen(album),
                        onDelete: () => onDelete(album),
                      );
                    },
                    childCount: albums.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
