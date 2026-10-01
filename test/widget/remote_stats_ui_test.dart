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
