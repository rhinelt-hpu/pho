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

  static Future<RemoteStats?> fetch() async {
    try {
      final res = await http.get(Uri.parse('$httpBaseUrl/debug/remote_stats'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return RemoteStats.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> reset() async {
    try {
      final res = await http.post(Uri.parse('$httpBaseUrl/debug/remote_stats/reset'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
