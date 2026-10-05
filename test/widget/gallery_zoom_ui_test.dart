import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/gallery_body.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/state_model.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocalAsset extends Asset {
  final DateTime _created;
  final String _id;
  MockLocalAsset(this._created, this._id)
      : super(
          local: AssetEntity(
            id: _id,
            typeInt: 1,
            width: 100,
            height: 100,
            createDateSecond: _created.millisecondsSinceEpoch ~/ 1000,
            modifiedDateSecond: _created.millisecondsSinceEpoch ~/ 1000,
            title: 'photo_$_id.jpg',
          ),
          remote: null,
        ) {
    hasLocal = true;
    localTitle = 'photo_$_id.jpg';
  }

  @override
  bool isVideo() => false;

  @override
  bool isLivePhoto() => false;

  @override
  DateTime dateCreated() => _created;

  @override
  bool loadThumbnailFinished() => false;

  @override
  ImageProvider thumbnailProvider() => const AssetImage('assets/icon/icon.png');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    stateModel = StateModel();
    settingModel = SettingModel();
    assetModel = AssetModel();
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  testWidgets('GalleryViewMode 支持点击顶部 pill 循环切换天/月/年，且网格列数与标题形态动态响应',
      (WidgetTester tester) async {
    // 注入跨越两个月的模拟照片
    assetModel.localAssets = [
      MockLocalAsset(DateTime(2026, 2, 26, 10, 0), '1'),
      MockLocalAsset(DateTime(2026, 2, 25, 9, 0), '2'),
      MockLocalAsset(DateTime(2026, 1, 15, 8, 0), '3'),
      MockLocalAsset(DateTime(2025, 12, 1, 7, 0), '4'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StateModel>.value(value: stateModel),
          ChangeNotifierProvider<SettingModel>.value(value: settingModel),
          ChangeNotifierProvider<AssetModel>.value(value: assetModel),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: GalleryBody(useLocal: true),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 1. 默认日视图：顶部展示“天”药丸，展示具体的每日标题
    expect(find.text('天'), findsOneWidget);
    expect(find.text('2月26日 周四'), findsOneWidget);
    expect(find.text('2月25日 周三'), findsOneWidget);

    // 2. 点击切换到“月”视图
    await tester.tap(find.text('天'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('月'), findsOneWidget);
    // 日标题被隐藏，展示月标题
    expect(find.text('2月26日 周四'), findsNothing);
    expect(find.text('2026年 2月'), findsOneWidget);
    expect(find.text('2026年 1月'), findsOneWidget);

    // 3. 点击切换到“年”视图
    await tester.tap(find.text('月'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('年'), findsOneWidget);
    // 月日标题均被隐藏，展示年份标题
    expect(find.text('2026年 2月'), findsNothing);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);

    // 4. 点击年份视图中的第 1 张照片，自动下钻到“月”视图
    final firstPhoto = find.byKey(const ValueKey('gallery_photo_0'));
    await tester.tap(firstPhoto);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('月'), findsOneWidget);

    // 5. 点击月份视图中的第 1 张照片，自动下钻到“天”视图
    await tester.tap(firstPhoto);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('天'), findsOneWidget);
    expect(find.text('2月26日 周四'), findsOneWidget);
  });

  testWidgets('双指捏合（Pinch in）缩小至月/年视图，双指张开（Pinch out）放大至日视图',
      (WidgetTester tester) async {
    assetModel.localAssets = [
      MockLocalAsset(DateTime(2026, 2, 26, 10, 0), '1'),
      MockLocalAsset(DateTime(2026, 2, 25, 9, 0), '2'),
      MockLocalAsset(DateTime(2026, 1, 15, 8, 0), '3'),
      MockLocalAsset(DateTime(2025, 12, 1, 7, 0), '4'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StateModel>.value(value: stateModel),
          ChangeNotifierProvider<SettingModel>.value(value: settingModel),
          ChangeNotifierProvider<AssetModel>.value(value: assetModel),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: GalleryBody(useLocal: true),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 默认天视图
    expect(find.text('天'), findsOneWidget);

    // 模拟双指捏合 (两指间距从 300 缩短为 100，scale = 100/300 = 0.33 < 0.72)
    final gesture1 = await tester.startGesture(const Offset(200, 200), pointer: 1);
    final gesture2 = await tester.startGesture(const Offset(200, 500), pointer: 2);
    await tester.pump();

    await gesture1.moveTo(const Offset(200, 300));
    await gesture2.moveTo(const Offset(200, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await gesture1.up();
    await gesture2.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 成功切换到“月”
    expect(find.text('月'), findsOneWidget);

    // 再次双指捏合，切换到“年”
    final g3 = await tester.startGesture(const Offset(200, 200), pointer: 3);
    final g4 = await tester.startGesture(const Offset(200, 500), pointer: 4);
    await tester.pump();

    // 保证间隔 > 350ms
    await tester.pump(const Duration(milliseconds: 400));

    await g3.moveTo(const Offset(200, 300));
    await g4.moveTo(const Offset(200, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await g3.up();
    await g4.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 成功切换到“年”
    expect(find.text('年'), findsOneWidget);

    // 现在双指张开 (两指间距从 100 扩大为 300，scale = 300/100 = 3.0 > 1.35)
    final g5 = await tester.startGesture(const Offset(200, 300), pointer: 5);
    final g6 = await tester.startGesture(const Offset(200, 400), pointer: 6);
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 400));

    await g5.moveTo(const Offset(200, 150));
    await g6.moveTo(const Offset(200, 550));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await g5.up();
    await g6.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 放大回到“月”
    expect(find.text('月'), findsOneWidget);
  });

  testWidgets('乱序时间照片通过 compareByDateDesc 排序后，年视图严格按年份聚合并支持跳转统计',
      (WidgetTester tester) async {
    assetModel.localAssets = [
      MockLocalAsset(DateTime(2026, 9, 26, 12, 0), '1'),
      MockLocalAsset(DateTime(2020, 2, 10, 10, 0), '2'),
      MockLocalAsset(DateTime(2026, 9, 26, 11, 0), '3'),
      MockLocalAsset(DateTime(2020, 2, 10, 9, 0), '4'),
    ]..sort(Asset.compareByDateDesc);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StateModel>.value(value: stateModel),
          ChangeNotifierProvider<SettingModel>.value(value: settingModel),
          ChangeNotifierProvider<AssetModel>.value(value: assetModel),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: GalleryBody(useLocal: true),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 切换到年视图
    await tester.tap(find.text('天'));
    await tester.pump();
    await tester.tap(find.text('月'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 2026 和 2020 各自只出现一次，不会出现 2026 -> 2020 -> 2026 -> 2020
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('2020'), findsOneWidget);
  });
}
