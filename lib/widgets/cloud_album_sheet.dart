import 'package:flutter/material.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/proto/img_syncer.pb.dart';
import 'package:img_syncer/state_model.dart';
import 'package:provider/provider.dart';

/// 云端相册管理与切换底部抽屉
class CloudAlbumSheet extends StatefulWidget {
  const CloudAlbumSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) => const CloudAlbumSheet(),
    );
  }

  @override
  State<CloudAlbumSheet> createState() => _CloudAlbumSheetState();
}

class _CloudAlbumSheetState extends State<CloudAlbumSheet> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    setState(() => _loading = true);
    await assetModel.refreshCloudAlbums();
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateAlbumDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newAlbum),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.albumNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                try {
                  await assetModel.createCloudAlbum(name);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建失败: $e')),
                    );
                  }
                }
              }
            },
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  void _showRenameAlbumDialog(AlbumInfo album) {
    final controller = TextEditingController(text: album.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameAlbum),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.albumNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != album.name) {
                Navigator.pop(ctx);
                try {
                  await assetModel.renameCloudAlbum(album.name, newName);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('重命名失败: $e')),
                    );
                  }
                }
              }
            },
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  void _showDeleteAlbumDialog(AlbumInfo album) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMatched = controller.text.trim() == album.name;
          final colorScheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            icon: Icon(Icons.warning_amber_rounded, size: 40, color: colorScheme.error),
            title: Text(
              l10n.deleteAlbumConfirmTitle,
              style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.bold),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.deleteAlbumConfirmDesc(album.count.toInt()),
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: controller,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.deleteAlbumInputHint,
                    helperText: '请输入: ${album.name}',
                    border: const OutlineInputBorder(),
                    errorText: (controller.text.isNotEmpty && !isMatched) ? '相册名称不匹配' : null,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: isMatched
                    ? () async {
                        Navigator.pop(ctx);
                        try {
                          await assetModel.deleteCloudAlbum(album.name);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已粉碎删除相册【${album.name}】')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('删除失败: $e')),
                            );
                          }
                        }
                      }
                    : null,
                child: Text(l10n.delete),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Consumer<AssetModel>(
      builder: (context, model, child) {
        final currentAlbum = model.currentCloudAlbum;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖动把手
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.extraSmall),
                ),
              ),
              // 标题与操作栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.cloudAlbums,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _showCreateAlbumDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.newAlbum),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      // 全部照片（全局聚合时间轴）
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: currentAlbum.isEmpty
                              ? colorScheme.primaryContainer
                              : colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.photo_library_outlined,
                            color: currentAlbum.isEmpty ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        title: Text(
                          l10n.allPhotos,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: currentAlbum.isEmpty ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: const Text('聚合所有相册的完整时间流'),
                        trailing: currentAlbum.isEmpty
                            ? Icon(Icons.check_circle, color: colorScheme.primary)
                            : null,
                        onTap: () {
                          model.selectCloudAlbum('');
                          Navigator.pop(context);
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      // 各独立相册
                      for (final album in model.cloudAlbums) ...[
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: currentAlbum == album.name
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            child: Icon(
                              album.isDefault ? Icons.cloud_done_outlined : Icons.folder_outlined,
                              color: currentAlbum == album.name
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  album.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: currentAlbum == album.name
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (album.isDefault) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(AppRadius.extraSmall),
                                  ),
                                  child: Text(
                                    l10n.defaultAlbum,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text('${album.count} 张照片'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (currentAlbum == album.name)
                                Icon(Icons.check_circle, color: colorScheme.primary),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert),
                                onSelected: (action) {
                                  if (action == 'rename') {
                                    _showRenameAlbumDialog(album);
                                  } else if (action == 'delete') {
                                    _showDeleteAlbumDialog(album);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined, size: 20),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(l10n.renameAlbum),
                                      ],
                                    ),
                                  ),
                                  if (!album.isDefault)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_forever, size: 20, color: colorScheme.error),
                                          const SizedBox(width: AppSpacing.sm),
                                          Text(
                                            l10n.deleteAlbum,
                                            style: TextStyle(color: colorScheme.error),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            model.selectCloudAlbum(album.name);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 移动资产至目标相册选择弹窗
class MoveToAlbumDialog extends StatefulWidget {
  final List<Asset> assets;
  const MoveToAlbumDialog({Key? key, required this.assets}) : super(key: key);

  static Future<void> show(BuildContext context, List<Asset> assets) {
    return showDialog(
      context: context,
      builder: (context) => MoveToAlbumDialog(assets: assets),
    );
  }

  @override
  State<MoveToAlbumDialog> createState() => _MoveToAlbumDialogState();
}

class _MoveToAlbumDialogState extends State<MoveToAlbumDialog> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (assetModel.cloudAlbums.isEmpty) {
      assetModel.refreshCloudAlbums();
    }
  }

  void _showCreateAlbumAndMove() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.newAlbum),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.albumNameHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await assetModel.createCloudAlbum(name);
                _executeMove(name);
              }
            },
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  Future<void> _executeMove(String targetAlbum) async {
    setState(() => _loading = true);
    try {
      final moved = await assetModel.moveRemoteAssets(widget.assets, targetAlbum);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.moveSuccess} (${moved.length} 张照片已移至【$targetAlbum】)')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.moveFailed}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.moveToAlbum),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: l10n.newAlbum,
            onPressed: _showCreateAlbumAndMove,
          ),
        ],
      ),
      content: _loading
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Consumer<AssetModel>(
              builder: (context, model, child) {
                final albums = model.cloudAlbums;
                if (albums.isEmpty) {
                  return SizedBox(
                    height: 100,
                    child: Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(l10n.newAlbum),
                        onPressed: _showCreateAlbumAndMove,
                      ),
                    ),
                  );
                }
                return SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: albums.length,
                    itemBuilder: (ctx, index) {
                      final album = albums[index];
                      final isCurrent = model.currentCloudAlbum == album.name;
                      return ListTile(
                        leading: Icon(
                          album.isDefault ? Icons.cloud_done_outlined : Icons.folder_outlined,
                          color: isCurrent ? colorScheme.outline : colorScheme.primary,
                        ),
                        title: Text(album.name),
                        subtitle: Text('${album.count} 张照片'),
                        enabled: !isCurrent,
                        trailing: isCurrent
                            ? Text('当前相册', style: textTheme.labelSmall?.copyWith(color: colorScheme.outline))
                            : const Icon(Icons.chevron_right),
                        onTap: () => _executeMove(album.name),
                      );
                    },
                  ),
                );
              },
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
