import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/filter_setting_route.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/settings_route.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('zh', ''),
      Locale('en', ''),
    ],
    locale: const Locale('zh', ''),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingModel = SettingModel();
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  group('FilterSettingRoute Widget Tests', () {
    testWidgets('进入页面默认展示未启用提示，点击总开关展开子设置项', (tester) async {
      await tester.pumpWidget(_buildTestApp(const FilterSettingRoute()));
      await tester.pumpAndSettle();

      expect(find.text('文件筛选器'), findsOneWidget);
      expect(find.text('启用文件筛选器'), findsOneWidget);
      expect(find.text('筛选器未启用，同步将包含所有照片与视频'), findsOneWidget);

      // 点击开启
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(settingModel.filterSwitch, isTrue);
      // 展开子项
      expect(find.text('跳过视频文件'), findsOneWidget);
      expect(find.text('跳过照片文件'), findsOneWidget);
      expect(find.text('起始日期'), findsOneWidget);
      expect(find.text('截止日期'), findsOneWidget);
      expect(find.text('文件扩展名过滤'), findsOneWidget);
    });

    testWidgets('切换视频/照片跳过开关即时更新 settingModel', (tester) async {
      settingModel.setFilterSwitch(true);

      await tester.pumpWidget(_buildTestApp(const FilterSettingRoute()));
      await tester.pumpAndSettle();

      // 找到跳过视频的 Switch (index 1)
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(3)); // 总开关、跳过视频、跳过照片

      // 点击跳过视频
      await tester.tap(switches.at(1));
      await tester.pumpAndSettle();
      expect(settingModel.filterNoVideo, isTrue);

      // 点击跳过照片
      await tester.tap(switches.at(2));
      await tester.pumpAndSettle();
      expect(settingModel.filterNoImage, isTrue);
    });

    testWidgets('点击重置按钮弹出确认框并重置所有设置', (tester) async {
      settingModel.setFilterSwitch(true);
      settingModel.setFilterNoVideo(true);
      settingModel.setFilterType('.gif', false);

      await tester.pumpWidget(_buildTestApp(const FilterSettingRoute()));
      await tester.pumpAndSettle();

      // 点击 AppBar 上的重置按钮
      await tester.tap(find.byIcon(Icons.restart_alt));
      await tester.pumpAndSettle();

      expect(find.text('重置筛选条件'), findsOneWidget);
      expect(find.text('确认将所有筛选条件恢复为默认设置？'), findsOneWidget);

      // 点击确认 (yes -> '确认')
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(settingModel.filterSwitch, isFalse);
      expect(settingModel.filterNoVideo, isFalse);
      expect(settingModel.filterTypeMap, isEmpty);
    });
  });

  group('SettingsRoute 并发上传与筛选器入口', () {
    testWidgets('设置页包含并发上传与文件筛选器 Tile', (tester) async {
      settingModel.setParallelCount(3);
      settingModel.setFilterSwitch(true);

      await tester.pumpWidget(_buildTestApp(const SettingsRoute()));
      await tester.pumpAndSettle();

      expect(find.text('并发上传'), findsOneWidget);
      expect(find.text('3 线程'), findsOneWidget);
      expect(find.text('文件筛选器'), findsOneWidget);
      expect(find.text('已启用'), findsOneWidget);
    });

    testWidgets('点击并发上传弹出 Slider 对话框并可调整保存', (tester) async {
      settingModel.setParallelCount(1);

      await tester.pumpWidget(_buildTestApp(const SettingsRoute()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('并发上传'));
      await tester.pumpAndSettle();

      // 对话框弹出
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('1 线程'), findsNWidgets(2)); // tile上和dialog上

      // 调整 slider
      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();

      // 点击确认
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      // 校验设置已更新
      expect(settingModel.parallelCount, greaterThan(1));
    });

    testWidgets('点击文件筛选器可导航跳转到 FilterSettingRoute', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SettingsRoute()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('文件筛选器'));
      await tester.pumpAndSettle();

      expect(find.byType(FilterSettingRoute), findsOneWidget);
    });
  });
}
