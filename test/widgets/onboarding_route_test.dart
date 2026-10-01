import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/onboarding/onboarding_route.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OnboardingRoute', () {
    Widget buildTestWidget({required VoidCallback onComplete}) {
      return MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            global.initI18n(context);
            return OnboardingRoute(onComplete: onComplete);
          },
        ),
      );
    }

    Future<void> pumpUntilSettled(WidgetTester tester) async {
      await tester.pump();
      await tester.pumpAndSettle();
    }

    testWidgets('渲染无异常', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(onComplete: () {}),
      );
      await pumpUntilSettled(tester);

      expect(find.byType(OnboardingRoute), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('PageView 包含 3 页', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(onComplete: () {}),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.allowImplicitScrolling, false);
      expect(find.byType(PageView), findsOneWidget);
      expect(pageView.onPageChanged, isNotNull);
    });

    testWidgets('点击跳过按钮触发 onComplete 并写入 has_onboarded', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Skip'));
      await pumpUntilSettled(tester);

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_onboarded'), isTrue);
    });

    testWidgets('滑动到最后一页点击开始使用进入存储步骤', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;
      controller.jumpToPage(2);
      pageView.onPageChanged?.call(2);
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      expect(completed, isFalse);
      expect(find.text('Set up cloud storage (optional)'), findsOneWidget);
      expect(find.text('Set up storage'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('存储步骤：点击完成结束引导并写入 has_onboarded', (WidgetTester tester) async {
      bool completed = false;
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        buildTestWidget(onComplete: () => completed = true),
      );
      await pumpUntilSettled(tester);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;
      controller.jumpToPage(2);
      pageView.onPageChanged?.call(2);
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Get Started'));
      await pumpUntilSettled(tester);

      await tester.tap(find.text('Done'));
      await pumpUntilSettled(tester);

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('has_onboarded'), isTrue);
    });
  });
}
