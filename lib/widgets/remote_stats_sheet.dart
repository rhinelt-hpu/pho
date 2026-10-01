import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/storage/remote_stats.dart';
import 'package:img_syncer/util.dart';

/// 远端请求统计底板
/// 实时查看发往 WebDAV 的物理请求总数、按方法分布、429 限流次数及最近请求明细
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
  RemoteStats? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    final res = await RemoteStats.fetch();
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
                    // 1. 核心看板卡片
                    Card(
                      elevation: 0,
                      color: colorScheme.surfaceVariant.withOpacity(0.5),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.paddingLarge),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.totalRequests, style: textTheme.labelMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_stats!.totalRequests}',
                                    style: textTheme.headlineLarge?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 48, color: colorScheme.outlineVariant),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l10n.rateLimitHits, style: textTheme.labelMedium),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_stats!.rateLimitHits}',
                                    style: textTheme.headlineLarge?.copyWith(
                                      color: _stats!.rateLimitHits > 0
                                          ? colorScheme.error
                                          : colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (_stats!.rateLimitHits > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(AppSpacing.paddingStandard),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "注意：已触发 ${_stats!.rateLimitHits} 次 HTTP 429 限流！当前 Transport 已执行指数退避重试保护。",
                                style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text("请求方法分布", style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _stats!.byMethod.entries.map((e) {
                        final color = _methodColor(e.key, colorScheme);
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: color.withOpacity(0.2),
                            child: Text(
                              e.key.substring(0, 1),
                              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          label: Text("${e.key}: ${e.value}"),
                          backgroundColor: colorScheme.surface,
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l10n.recentLogs, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text("共 ${_stats!.recentLogs.length} 条记录", style: textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_stats!.recentLogs.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text("暂无远端请求记录（点击上方按钮或进行相册操作）", style: textTheme.bodySmall),
                        ),
                      )
                    else
                      ..._stats!.recentLogs.map((log) {
                        final mColor = _methodColor(log.method, colorScheme);
                        final isError = log.status >= 400;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            side: BorderSide(
                              color: isError ? colorScheme.error.withOpacity(0.5) : colorScheme.outlineVariant.withOpacity(0.4),
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
                                    color: mColor.withOpacity(0.15),
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
                                    color: (isError ? colorScheme.error : Colors.green).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${log.status}',
                                    style: TextStyle(
                                      color: isError ? colorScheme.error : Colors.green[800],
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
                      }),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
