import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:img_syncer/choose_album_route.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本地相册快速切换底部抽屉
class LocalAlbumSheet extends StatefulWidget {
  const LocalAlbumSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) => const LocalAlbumSheet(),
    );
  }

  @override
  State<LocalAlbumSheet> createState() => _LocalAlbumSheetState();
}

class _LocalAlbumSheetState extends State<LocalAlbumSheet> {
  bool _loading = false;
  List<AssetPathEntity> _albums = [];
  final Map<String, int> _counts = {};
  final Map<String, Uint8List?> _thumbs = {};

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return;
    }
    setState(() => _loading = true);
    try {
      final hasPerm = await requestPermission();
      if (!hasPerm) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        hasAll: true,
      );

      final Map<AssetPathEntity, int> countMap = {};
      await Future.wait(paths.map((p) async {
        try {
          final count = await p.assetCountAsync;
          countMap[p] = count;
        } catch (_) {
          countMap[p] = 0;
        }
      }));

      paths.sort((a, b) {
        final cA = countMap[a] ?? 0;
        final cB = countMap[b] ?? 0;
        return cB.compareTo(cA);
      });

      _albums = paths;
      for (final p in paths) {
        _counts[p.id] = countMap[p] ?? 0;
      }
      if (mounted) setState(() => _loading = false);

      // 异步按需加载每个相册首张缩略图
      for (final p in paths) {
        p.getAssetListPaged(page: 0, size: 1).then((entities) async {
          if (entities.isNotEmpty) {
            final data = await entities[0].thumbnailDataWithSize(
              const ThumbnailSize.square(160),
              quality: 85,
            );
            if (mounted) {
              setState(() {
                _thumbs[p.id] = data;
              });
            }
          }
        }).catchError((_) {});
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectAlbum(AssetPathEntity path) {
    stateModel.updateLastRefreshUnsyncTime(null);
    settingModel.setLocalFolder(path.name);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString("localFolder", path.name);
    });
    eventBus.fire(LocalRefreshEvent(refreshUnSync: false));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Consumer<SettingModel>(
      builder: (context, sModel, child) {
        final currentFolder = sModel.localFolder;
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
              // 标题栏
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.chooseAlbum,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.grid_view_outlined, size: 20),
                      tooltip: l10n.chooseAlbum,
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChooseAlbumRoute()),
                        );
                      },
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
              else if (_albums.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: Text(
                      l10n.noLocalPhotos,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _albums.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final path = _albums[index];
                      final albumName = path.name.trim().isNotEmpty ? path.name : '其他相册';
                      final isSelected = currentFolder == path.name;
                      final count = _counts[path.id] ?? 0;
                      final thumb = _thumbs[path.id];

                      return ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.small),
                            child: thumb != null
                                ? Image.memory(thumb, fit: BoxFit.cover)
                                : Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.photo_album_outlined,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                        ),
                        title: Text(
                          albumName,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text('$count 张照片'),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: colorScheme.primary)
                            : null,
                        onTap: () => _selectAlbum(path),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
