import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/settings_route.dart';
import 'package:img_syncer/state_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker_flutter/talker_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingModel testSettingModel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testSettingModel = SettingModel();
    testSettingModel.setDebugMode(false);
    logger.cleanHistory();
  });

  Widget buildTestWidget() {
    return ChangeNotifierProvider<SettingModel>.value(
      value: testSettingModel,
      child: MaterialApp(
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
        home: const AboutRoute(),
      ),
    );
  }

  testWidgets('AboutRoute displays debug switch and toggles Talker entry', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 检查应用版本和调试开关存在
    expect(find.byType(SwitchListTile), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);

    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.value, false);

    // 此时控制台入口不应该展示
    expect(find.text('打开调试控制台'), findsNothing);

    // 点击开关打开调试模式
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(testSettingModel.debugMode, true);
    expect(talker.settings.enabled, true);

    // 此时应该展示“打开调试控制台”和“清空调试日志”
    expect(find.text('打开调试控制台'), findsOneWidget);
    expect(find.text('清空调试日志'), findsOneWidget);

    // 记录一条日志并点击打开调试控制台
    logger.addLog('Sync test event 1001');
    await tester.tap(find.text('打开调试控制台'));
    await tester.pumpAndSettle();

    // 验证成功跳转到 TalkerScreen
    expect(find.byType(TalkerScreen), findsOneWidget);

    // 点击返回
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // 点击清空调试日志
    await tester.tap(find.text('清空调试日志'));
    await tester.pumpAndSettle();

    expect(talker.history.length, 0);
    expect(find.text('调试日志已清空'), findsOneWidget);

    // 再次点击开关关闭调试模式
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(testSettingModel.debugMode, false);
    expect(talker.settings.enabled, false);
    expect(find.text('打开调试控制台'), findsNothing);
  });
}
