import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/background_sync_route.dart';
import 'package:img_syncer/choose_album_route.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/setting_storage_route.dart';
import 'package:img_syncer/filter_setting_route.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';

/// 设置页：选择相册、云存储、后台同步、清除缓存、关于。
class SettingsRoute extends StatefulWidget {
  const SettingsRoute({super.key});

  @override
  SettingsRouteState createState() => SettingsRouteState();
}

class SettingsRouteState extends State<SettingsRoute> {
  @override
  void initState() {
    super.initState();
    settingModel.addListener(_onSettingChanged);
  }

  @override
  void dispose() {
    settingModel.removeListener(_onSettingChanged);
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
  }

  void _showParallelUploadDialog() {
    int current = settingModel.parallelCount;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.parallelUpload),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.parallelUploadTip,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.parallelUploadDesc),
                      Text(
                        l10n.parallelUploadCount(current),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Slider(
                    value: current.toDouble(),
                    min: 1,
                    max: 8,
                    divisions: 7,
                    label: '$current',
                    onChanged: (val) {
                      setDialogState(() {
                        current = val.round();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    settingModel.setParallelCount(current);
                    Navigator.pop(context);
                  },
                  child: Text(l10n.yes),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          tile(
            Icons.folder_outlined,
            l10n.chooseAlbum,
            null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChooseAlbumRoute(),
              ),
            ),
          ),
          tile(
            Icons.cloud_outlined,
            l10n.cloudStorage,
            null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingStorageRoute(),
              ),
            ),
          ),
          if (Platform.isAndroid)
            tile(
              Icons.cloud_sync_outlined,
              l10n.backgroundSync,
              null,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackgroundSyncSettingRoute(),
                ),
              ),
            ),
          tile(
            Icons.speed,
            l10n.parallelUpload,
            l10n.parallelUploadCount(settingModel.parallelCount),
            onTap: _showParallelUploadDialog,
          ),
          tile(
            Icons.filter_alt_outlined,
            l10n.fileFilter,
            settingModel.filterSwitch ? l10n.filterEnabled : l10n.filterDisabled,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FilterSettingRoute(),
              ),
            ),
          ),
          // TODO(open-source): 补齐高级功能与偏好设置页面入口 (原会员功能，待开源实现):
          // 1. 目录结构配置 (Directory Structure):
          //    - 选项: 按日期多层级 (YYYY/MM/DD) vs 按日期单层级 (YYYYMMDD)
          //    - 调用: storage.cli.setDirectoryType() (后端 RPC 与 l10n.dirType01/dirType02 已实现)
          // 2. AES 端到端加密设置 (Encryption Settings):
          //    - 选项: 启用加密开关、选择加密算法 (AES_256_GCM / AES_128_CFB)、设置/修改密码
          //    - 调用: settingModel.setEncryptSwitch() / setEncryptionType() / setEncryptionPassword()
          // 3. 主题配色自定义 (Theme Color Picker):
          //    - 选项: 选择 theme.dart 中的 seedThemeColors 预置配色，写入 prefs.setInt('seed_color')
          const Divider(),
          tile(
            Icons.cleaning_services,
            l10n.clearCache,
            null,
            onTap: () => showClearCacheDialog(context),
          ),
          tile(
            Icons.info,
            l10n.about,
            null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutRoute(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget tile(IconData icon, String title, String? subtitle,
      {Function()? onTap}) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingSmall),
      child: ListTile(
        leading: Icon(
          icon,
          size: 28,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(title, style: textTheme.titleLarge),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ))
            : null,
        onTap: onTap,
      ),
    );
  }

  void showClearCacheDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) {
          return Dialog(
            child: SizedBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.fromLTRB(30, 20, 20, 5),
                    child: Text(
                      l10n.clearCache,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(30, 5, 20, 5),
                    child: Text(
                      l10n.clearCacheDescription,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(0, 0, 20, 5),
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.cancel),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(0, 0, 20, 5),
                        child: TextButton(
                          onPressed: () {
                            clearDiskCachedImages();
                            PhotoManager.clearFileCache();
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.yes),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
  }
}

/// 关于页：显示应用名与版本（来自 pubspec）。
class AboutRoute extends StatefulWidget {
  const AboutRoute({super.key});

  @override
  State<AboutRoute> createState() => _AboutRouteState();
}

class _AboutRouteState extends State<AboutRoute> {
  String _version = '2026.1001.9';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.about),
      ),
      body: ListView(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingSmall,
                vertical: AppSpacing.xs),
            child: ListTile(
              title: Text(l10n.appVersion,
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                'Pho - $_version',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
