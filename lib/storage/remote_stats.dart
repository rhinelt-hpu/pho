import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:img_syncer/global.dart';

class RemoteAccessLog {
  final String method;
  final String path;
  final int status;
  final int durationMs;
  final int timestamp;

  RemoteAccessLog({
    required this.method,
    required this.path,
    required this.status,
    required this.durationMs,
    required this.timestamp,
  });

  factory RemoteAccessLog.fromJson(Map<String, dynamic> json) {
    return RemoteAccessLog(
      method: json['method'] as String? ?? '',
      path: json['path'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

class RemoteStats {
  final int totalRequests;
  final Map<String, int> byMethod;
  final Map<String, int> byStatus;
  final int rateLimitHits;
  final List<RemoteAccessLog> recentLogs;

  RemoteStats({
    required this.totalRequests,
    required this.byMethod,
    required this.byStatus,
    required this.rateLimitHits,
    required this.recentLogs,
  });

  factory RemoteStats.fromJson(Map<String, dynamic> json) {
    final methodMap = <String, int>{};
    if (json['by_method'] is Map) {
      (json['by_method'] as Map).forEach((k, v) {
        methodMap[k.toString()] = (v as num).toInt();
      });
    }

    final statusMap = <String, int>{};
    if (json['by_status'] is Map) {
      (json['by_status'] as Map).forEach((k, v) {
        statusMap[k.toString()] = (v as num).toInt();
      });
    }

    final logs = <RemoteAccessLog>[];
    if (json['recent_logs'] is List) {
      for (final item in json['recent_logs'] as List) {
        if (item is Map<String, dynamic>) {
          logs.add(RemoteAccessLog.fromJson(item));
        }
      }
    }

    return RemoteStats(
      totalRequests: (json['total_requests'] as num?)?.toInt() ?? 0,
      byMethod: methodMap,
      byStatus: statusMap,
      rateLimitHits: (json['rate_limit_hits'] as num?)?.toInt() ?? 0,
      recentLogs: logs.reversed.toList(), // 最新的排在前面
    );
  }

  /// 仅取聚合统计（兼容旧调用点）。新代码请用 [RemoteStatsBundle.fetch]。
  static Future<RemoteStats?> fetch() async {
    final bundle = await RemoteStatsBundle.fetch();
    return bundle?.aggregate;
  }

  /// 清空主存储 + 副存储 + 聚合统计（服务端语义不变）
  static Future<bool> reset() async {
    try {
      final res =
          await http.post(Uri.parse('$httpBaseUrl/debug/remote_stats/reset'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

/// 主存储（云盘，对并发敏感）/ 副存储（元数据，本地磁盘）/ 聚合 三份统计。
///
/// 服务端契约（新版）：
/// `{"primary":{...}|null, "meta":{...}|null, "aggregate":{...}}`
/// 旧版服务端只会返回扁平的一份统计，此时把整份 JSON 当成 [aggregate]，
/// [primary] / [meta] 为 null。
class RemoteStatsBundle {
  final RemoteStats? primary;
  final RemoteStats? meta;
  final RemoteStats aggregate;

  RemoteStatsBundle({
    required this.primary,
    required this.meta,
    required this.aggregate,
  });

  factory RemoteStatsBundle.fromJson(Map<String, dynamic> json) {
    final isNewFormat =
        json.containsKey('primary') || json.containsKey('meta') || json.containsKey('aggregate');
    if (!isNewFormat) {
      return RemoteStatsBundle(
        primary: null,
        meta: null,
        aggregate: RemoteStats.fromJson(json),
      );
    }
    return RemoteStatsBundle(
      primary: _parsePart(json['primary']),
      meta: _parsePart(json['meta']),
      aggregate: _parsePart(json['aggregate']) ?? RemoteStats.fromJson(const {}),
    );
  }

  static RemoteStats? _parsePart(Object? part) {
    if (part is Map<String, dynamic>) return RemoteStats.fromJson(part);
    if (part is Map) return RemoteStats.fromJson(part.cast<String, dynamic>());
    return null;
  }

  /// 主存储请求数（未启用/不可用时为 0）
  int get primaryRequests => primary?.totalRequests ?? 0;

  /// 副存储请求数（未启用/不可用时为 0）
  int get metaRequests => meta?.totalRequests ?? 0;

  int get totalRequests => aggregate.totalRequests;

  int get primaryRateLimitHits => primary?.rateLimitHits ?? 0;

  int get metaRateLimitHits => meta?.rateLimitHits ?? 0;

  /// 是否至少有一份分区统计（否则视为旧版服务端，只有聚合数据）
  bool get hasSplit => primary != null || meta != null;

  static Future<RemoteStatsBundle?> fetch() async {
    try {
      final res = await http.get(Uri.parse('$httpBaseUrl/debug/remote_stats'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) return RemoteStatsBundle.fromJson(data);
        if (data is Map) {
          return RemoteStatsBundle.fromJson(data.cast<String, dynamic>());
        }
      }
    } catch (_) {}
    return null;
  }
}
