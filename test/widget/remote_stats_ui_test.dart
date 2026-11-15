import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/storage/remote_stats.dart';
import 'package:img_syncer/widgets/remote_stats_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('RemoteStats model json parsing and statistics calculation', () {
    final rawJson = {
      "total_requests": 42,
      "by_method": {
        "PROPFIND": 28,
        "GET": 10,
        "PUT": 4
      },
      "by_status": {
        "ok": 38,
        "too many requests": 4
      },
      "rate_limit_hits": 4,
      "recent_logs": [
        {
          "method": "PROPFIND",
          "path": "/dav/photo/2026/",
          "status": 207,
          "duration_ms": 15,
          "timestamp": 1727788900
        },
        {
          "method": "GET",
          "path": "/dav/photo/.thumbnail/pic.jpg",
          "status": 429,
          "duration_ms": 5,
          "timestamp": 1727788901
        }
      ]
    };

    final stats = RemoteStats.fromJson(rawJson);
    expect(stats.totalRequests, 42);
    expect(stats.rateLimitHits, 4);
    expect(stats.byMethod['PROPFIND'], 28);
    expect(stats.recentLogs.length, 2);
    // 最新记录排在首位
    expect(stats.recentLogs.first.method, 'GET');
    expect(stats.recentLogs.first.status, 429);
  });

  test('RemoteStatsBundle 解析新版 primary/meta/aggregate 结构', () {
    final rawJson = {
      "primary": {
        "role": "primary",
        "total_requests": 120,
        "by_method": {"PROPFIND": 100, "GET": 20},
        "by_status": {"ok": 118, "too many requests": 2},
        "rate_limit_hits": 2,
        "recent_logs": [
          {
            "method": "PROPFIND",
            "path": "/dav/photo/year/",
            "status": 207,
            "duration_ms": 120,
            "timestamp": 1727788900,
          }
        ],
      },
      "meta": {
        "role": "meta",
        "total_requests": 2200,
        "by_method": {"GET": 2100, "PUT": 100},
        "by_status": {"ok": 2200},
        "rate_limit_hits": 0,
        "recent_logs": [],
      },
      "aggregate": {
        "role": "aggregate",
        "total_requests": 2320,
        "by_method": {"PROPFIND": 100, "GET": 2120, "PUT": 100},
        "by_status": {"ok": 2318, "too many requests": 2},
        "rate_limit_hits": 2,
        "recent_logs": [],
      },
    };

    final bundle = RemoteStatsBundle.fromJson(rawJson);
    expect(bundle.hasSplit, isTrue);
    expect(bundle.primary, isNotNull);
    expect(bundle.meta, isNotNull);
    expect(bundle.primary!.totalRequests, 120);
    expect(bundle.primary!.byMethod['PROPFIND'], 100);
    expect(bundle.meta!.totalRequests, 2200);
    expect(bundle.aggregate.totalRequests, 2320);
    expect(bundle.primaryRequests, 120);
    expect(bundle.metaRequests, 2200);
    expect(bundle.totalRequests, 2320);
    expect(bundle.primaryRateLimitHits, 2);
    expect(bundle.metaRateLimitHits, 0);
    // 主存储 recent_logs 解析
    expect(bundle.primary!.recentLogs.single.method, 'PROPFIND');
  });

  test('RemoteStatsBundle 兼容旧扁平结构（无 primary/meta/aggregate 键）', () {
    final legacyJson = {
      "total_requests": 42,
      "by_method": {"PROPFIND": 28, "GET": 14},
      "by_status": {"ok": 38, "too many requests": 4},
      "rate_limit_hits": 4,
      "recent_logs": [
        {
          "method": "GET",
          "path": "/dav/photo/.thumbnail/pic.jpg",
          "status": 429,
          "duration_ms": 5,
          "timestamp": 1727788901,
        }
      ],
    };

    final bundle = RemoteStatsBundle.fromJson(legacyJson);
    expect(bundle.hasSplit, isFalse);
    expect(bundle.primary, isNull);
    expect(bundle.meta, isNull);
    // 整份 JSON 视为 aggregate
    expect(bundle.aggregate.totalRequests, 42);
    expect(bundle.aggregate.rateLimitHits, 4);
    expect(bundle.aggregate.byMethod['PROPFIND'], 28);
    expect(bundle.primaryRequests, 0);
    expect(bundle.metaRequests, 0);
    expect(bundle.totalRequests, 42);
  });

  test('RemoteStatsBundle 兼容 primary/meta 为 null 的新结构', () {
    final bundle = RemoteStatsBundle.fromJson({
      "primary": null,
      "meta": null,
      "aggregate": {
        "role": "aggregate",
        "total_requests": 7,
        "by_method": {"GET": 7},
        "by_status": {"ok": 7},
        "rate_limit_hits": 0,
        "recent_logs": [],
      },
    });
    expect(bundle.hasSplit, isFalse);
    expect(bundle.primary, isNull);
    expect(bundle.meta, isNull);
    expect(bundle.aggregate.totalRequests, 7);
  });

  test('RemoteStatsBundle fetch 能从 HTTP 返回值构造（用 json 串走一遍解码路径）', () {
    // 只验证 jsonDecode -> fromJson 的链路（真正网络由服务端保证）
    final decoded = jsonDecode(jsonEncode({
      "primary": {"role": "primary", "total_requests": 3},
      "meta": null,
      "aggregate": {"role": "aggregate", "total_requests": 3},
    })) as Map<String, dynamic>;
    final bundle = RemoteStatsBundle.fromJson(decoded);
    expect(bundle.primary!.totalRequests, 3);
    expect(bundle.meta, isNull);
  });

  testWidgets('RemoteStatsSheet displays UI correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RemoteStatsSheet(),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('远端请求统计'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep_outlined), findsOneWidget);
  });
}
