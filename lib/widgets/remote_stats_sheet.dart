import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/storage/remote_stats.dart';

/// 远端请求统计底板
///
/// 分开展示主存储（云盘，对并发敏感）与副存储（元数据 / 缩略图，本地磁盘）的
/// 物理请求数、按方法 / 状态分布、429 限流次数与最近请求明细；
/// 旧版服务端只返回一份聚合统计时，退化为只展示聚合数据。
class RemoteStatsSheet extends StatefulWidget {
  const RemoteStatsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
      ),
      builder: (context) => const RemoteStatsSheet(),
    );
  }

  @override
  State<RemoteStatsSheet> createState() => _RemoteStatsSheetState();
}

class _RemoteStatsSheetState extends State<RemoteStatsSheet> {
  RemoteStatsBundle? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    final res = await RemoteStatsBundle.fetch();
    if (mounted) {
      setState(() {
        _stats = res;
        _loading = false;
      });
    }
  }

  Future<void> _resetStats() async {
    final success = await RemoteStats.reset();
    if (success && mounted) {
      _fetchStats();
      SnackBarManager.showSnackBar("统计已重置归零");
    }
  }

  Color _methodColor(String method, ColorScheme scheme) {
    switch (method.toUpperCase()) {
      case 'PROPFIND':
        return Colors.deepPurple;
      case 'GET':
        return Colors.blue;
      case 'PUT':
      case 'POST':
        return Colors.green;
      case 'DELETE':
        return Colors.red;
      case 'MKCOL':
        return Colors.orange;
      case 'MOVE':
        return Colors.teal;
      default:
        return scheme.onSurfaceVariant;
    }
  }

  /// 是否出现过 413（文件体积超限）：主/副/聚合任一份命中即提示
  bool _hasPayloadTooLarge(RemoteStatsBundle bundle) {
    bool hit(Map<String, int> byStatus) =>
        byStatus.entries.any((e) => e.key.contains('413') || e.key.contains('large'));
    return hit(bundle.aggregate.byStatus) ||
        (bundle.primary != null && hit(bundle.primary!.byStatus)) ||
        (bundle.meta != null && hit(bundle.meta!.byStatus));
  }

  @override
  Widget build(BuildContext context) {
    initI18n(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // 顶部抓手与标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.remoteStats,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.refreshStats,
                    onPressed: _loading ? null : _fetchStats,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined),
                    tooltip: l10n.resetStats,
                    onPressed: _loading ? null : _resetStats,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            if (_loading && _stats == null)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_stats == null)
              Expanded(
                child: Center(
                  child: Text(
                    "未能读取远端统计数据（Go 服务未就绪）",
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.error),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.all(AppSpacing.paddingLarge),
                  children: [
                    _buildOverview(_stats!, colorScheme, textTheme),
                    if (_stats!.aggregate.rateLimitHits > 0 ||
                        _stats!.primaryRateLimitHits > 0 ||
                        _stats!.metaRateLimitHits > 0) ...[
                      const SizedBox(height: 8),
                      _buildRateLimitNotice(_stats!, colorScheme, textTheme),
                    ],
                    if (_hasPayloadTooLarge(_stats!)) ...[
                      const SizedBox(height: 8),
                      _buildPayloadTooLargeNotice(colorScheme, textTheme),
                    ],
                    if (!_stats!.hasSplit) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.remoteStatsLegacyHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // 旧版服务端没有分区数据：仍把聚合统计完整展示出来
                      _buildRoleSection(
                        roleTitle: l10n.remoteStatsAggregate,
                        emptyHint: l10n.remoteStatsPrimaryEmpty,
                        icon: Icons.donut_small_outlined,
                        stats: _stats!.aggregate,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      _buildRoleSection(
                        roleTitle: l10n.remoteStatsPrimary,
                        emptyHint: l10n.remoteStatsPrimaryEmpty,
                        icon: Icons.cloud_outlined,
                        stats: _stats!.primary,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                      const SizedBox(height: 12),
                      _buildRoleSection(
                        roleTitle: l10n.remoteStatsMeta,
                        emptyHint: l10n.remoteStatsMetaEmpty,
                        icon: Icons.storage_outlined,
                        stats: _stats!.meta,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  /// 顶部总览：总请求 / 主存储 / 副存储 + 429 分列
  Widget _buildOverview(
      RemoteStatsBundle bundle, ColorScheme colorScheme, TextTheme textTheme) {
    Widget metric(String label, String value, Color valueColor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium, maxLines: 2),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.paddingLarge),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: metric(l10n.totalRequests, '${bundle.totalRequests}', colorScheme.primary)),
                Container(width: 1, height: 40, color: colorScheme.outlineVariant),
                const SizedBox(width: 12),
                Expanded(child: metric(l10n.remoteStatsPrimary, '${bundle.primaryRequests}', colorScheme.onSurface)),
                Container(width: 1, height: 40, color: colorScheme.outlineVariant),
                const SizedBox(width: 12),
                Expanded(child: metric(l10n.remoteStatsMeta, '${bundle.metaRequests}', colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.speed_outlined, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bundle.hasSplit
                        ? "${l10n.rateLimitHits}: "
                            "${l10n.remoteStatsPrimary} ${bundle.primaryRateLimitHits} · "
                            "${l10n.remoteStatsMeta} ${bundle.metaRateLimitHits}"
                        : "${l10n.rateLimitHits}: ${bundle.aggregate.rateLimitHits}",
                    style: textTheme.bodySmall?.copyWith(
                      color: bundle.aggregate.rateLimitHits > 0
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateLimitNotice(
      RemoteStatsBundle bundle, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.paddingStandard),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              bundle.hasSplit
                  ? "注意：已触发 ${bundle.primaryRateLimitHits + bundle.metaRateLimitHits} 次 "
                      "HTTP 429 限流（主存储 ${bundle.primaryRateLimitHits} 次 / "
                      "副存储 ${bundle.metaRateLimitHits} 次）！当前 Transport 已执行指数退避重试保护。"
                  : "注意：已触发 ${bundle.aggregate.rateLimitHits} 次 HTTP 429 限流！"
                      "当前 Transport 已执行指数退避重试保护。",
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayloadTooLargeNotice(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.paddingStandard),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "检测到 HTTP 413 (文件体积超限)：有视频体积超过了远端 WebDAV 服务器限制。请调大远端 Nginx 的 client_max_body_size 配置，或在设置中开启【跳过视频】。",
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个存储角色（主/副）的分区卡片：方法分布、状态分布、最近请求
  Widget _buildRoleSection({
    required String roleTitle,
    required String emptyHint,
    required IconData icon,
    required RemoteStats? stats,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    if (stats == null) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        child: ListTile(
          leading: Icon(icon, color: colorScheme.onSurfaceVariant),
          title: Text(roleTitle, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          subtitle: Text(
            emptyHint,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(roleTitle, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${l10n.totalRequests}: ${stats.totalRequests} · 429: ${stats.rateLimitHits}",
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (stats.byMethod.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.statsByMethod,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.byMethod.entries.map((e) {
                  final color = _methodColor(e.key, colorScheme);
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Text(
                        e.key.isEmpty ? '?' : e.key.substring(0, 1),
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    label: Text("${e.key}: ${e.value}"),
                    backgroundColor: colorScheme.surface,
                  );
                }).toList(),
              ),
            ),
          ],
          if (stats.byStatus.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(l10n.statsByStatus,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stats.byStatus.entries.map((e) {
                  final isError = e.key.contains('429') ||
                      e.key.contains('413') ||
                      e.key.contains('large') ||
                      e.key.contains('error') ||
                      e.key.contains('fail');
                  return Chip(
                    label: Text("${e.key}: ${e.value}"),
                    backgroundColor: colorScheme.surface,
                    labelStyle: isError
                        ? textTheme.labelMedium?.copyWith(color: colorScheme.error)
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.recentLogs,
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              Text("共 ${stats.recentLogs.length} 条记录", style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 8),
          if (stats.recentLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text("暂无远端请求记录（点击上方按钮或进行相册操作）", style: textTheme.bodySmall),
              ),
            )
          else
            ...stats.recentLogs.map(
                (log) => _buildLogRow(log, colorScheme, textTheme)),
        ],
      ),
    );
  }

  Widget _buildLogRow(
      RemoteAccessLog log, ColorScheme colorScheme, TextTheme textTheme) {
    final mColor = _methodColor(log.method, colorScheme);
    final isMkcol405 = log.method == 'MKCOL' && log.status == 405;
    final is413 = log.status == 413;
    final isError = log.status >= 400 && !isMkcol405;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isError
              ? colorScheme.error.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: mColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                log.method,
                style: TextStyle(
                  color: mColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.path,
                style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isMkcol405
                        ? Colors.grey
                        : is413 || isError
                            ? colorScheme.error
                            : Colors.green)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isMkcol405
                    ? '405(已存在)'
                    : is413
                        ? '413(文件超限)'
                        : '${log.status}',
                style: TextStyle(
                  color: isMkcol405
                      ? colorScheme.onSurfaceVariant
                      : isError || is413
                          ? colorScheme.error
                          : Colors.green[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${log.durationMs}ms',
              style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
