import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage_config.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// 存储配置导出弹窗：生成二维码与一键分享/复制配置链接
class StorageExportDialog extends StatelessWidget {
  final StorageConfig config;

  const StorageExportDialog({super.key, required this.config});

  static Future<void> show(BuildContext context, StorageConfig config) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StorageExportDialog(config: config),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final uri = config.encodeToUri();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      padding: const EdgeInsets.all(AppSpacing.paddingLarge),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 拖动把手
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.paddingStandard),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                l10n.storageConfigQrTitle,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.storageConfigQrDesc,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),

              // 二维码容器（浅底保护，确保暗黑模式下也能被高对比度扫描）
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: uri,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // 配置信息摘要卡片
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.paddingStandard),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_outlined, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          driveName[config.drive] ?? '',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('服务器', config.summary, textTheme, colorScheme),
                    if (config.username != null && config.username!.isNotEmpty)
                      _buildInfoRow('用户名', config.username!, textTheme, colorScheme),
                    if (config.rootPath != null && config.rootPath!.isNotEmpty)
                      _buildInfoRow('根路径', config.rootPath!, textTheme, colorScheme),
                    if (config.metaEnabled && config.metaDrive != null) ...[
                      const Divider(height: 16),
                      Row(
                        children: [
                          Icon(Icons.bolt_outlined, size: 18, color: colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '元数据/缩略图: ${driveName[config.metaDrive] ?? ''}',
                            style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (config.metaSummary != null)
                        _buildInfoRow('服务器', config.metaSummary!, textTheme, colorScheme),
                      if (config.metaRootPath != null && config.metaRootPath!.isNotEmpty)
                        _buildInfoRow('根路径', config.metaRootPath!, textTheme, colorScheme),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 操作按钮栏：复制链接 & 系统分享
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 18),
                      label: Text(l10n.copyConfig),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: uri));
                        SnackBarManager.showSnackBar(l10n.configCopied);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.share, size: 18),
                      label: Text(l10n.shareConfig),
                      onPressed: () {
                        Share.share(uri);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, TextTheme textTheme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              '$label:',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
