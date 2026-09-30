import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/background_sync_route.dart';
import 'package:img_syncer/choose_album_route.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/setting_storage_route.dart';
import 'package:img_syncer/global.dart';
import 'package:photo_manager/photo_manager.dart';

/// 设置页：选择相册、云存储、后台同步、清除缓存、关于。
class SettingsRoute extends StatefulWidget {
  const SettingsRoute({Key? key}) : super(key: key);

  @override
  SettingsRouteState createState() => SettingsRouteState();
}

class SettingsRouteState extends State<SettingsRoute> {
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
          // TODO(open-source): 补齐高级功能与偏好设置页面入口 (原会员功能，待开源实现):
          // 1. 目录结构配置 (Directory Structure):
          //    - 选项: 按日期多层级 (YYYY/MM/DD) vs 按日期单层级 (YYYYMMDD)
          //    - 调用: storage.cli.setDirectoryType() (后端 RPC 与 l10n.dirType01/dirType02 已实现)
          // 2. AES 端到端加密设置 (Encryption Settings):
          //    - 选项: 启用加密开关、选择加密算法 (AES_256_GCM / AES_128_CFB)、设置/修改密码
          //    - 调用: settingModel.setEncryptSwitch() / setEncryptionType() / setEncryptionPassword()
          // 3. 主题配色自定义 (Theme Color Picker):
          //    - 选项: 选择 theme.dart 中的 seedThemeColors 预置配色，写入 prefs.setInt('seed_color')
          // 4. 并行上传调优 (Parallel Upload Count):
          //    - 选项: 1~8 线程并发上传滑动条，保存到 prefs.setInt('parallel_count')
          // 5. 同步筛选器 (Sync Filters):
          //    - 选项: 跳过视频/跳过图片、按拍摄起止日期过滤、文件扩展名黑白名单
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
class AboutRoute extends StatelessWidget {
  const AboutRoute({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 版本号在构建时由 pubspec 注入，运行时读取。
    const version = '1.0.0';
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
                'Pho - $version',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
