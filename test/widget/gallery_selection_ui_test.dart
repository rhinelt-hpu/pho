import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/gallery_body.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/state_model.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAsset extends Asset {
  final String _id;
  final bool _isVideo;
  final DateTime _date;

  _MockAsset({
    required String id,
    bool isVideo = false,
  })  : _id = id,
        _isVideo = isVideo,
        _date = DateTime(2026, 1, 1),
        super(
          local: AssetEntity(
            id: id,
            typeInt: isVideo ? 2 : 1,
            width: 100,
            height: 100,
            createDateSecond: DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
            modifiedDateSecond: DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
            title: 'photo_$id.jpg',
          ),
          remote: null,
        ) {
    hasLocal = true;
    localTitle = 'photo_$id.jpg';
  }

  @override
  bool isVideo() => _isVideo;

  @override
  bool isLivePhoto() => false; // 模拟普通 Android 照片（绝大多数非苹果机均为 false）

  @override
  bool loadThumbnailFinished() => false;

  @override
  Future<Uint8List> thumbnailDataAsync() async => Uint8List(0);

  @override
  ImageProvider thumbnailProvider() => MemoryImage(Uint8List(0));

  @override
  DateTime dateCreated() => _date;

  @override
  Future<String> name() async => 'photo_$_id.jpg';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settingModel = SettingModel();
    assetModel = AssetModel();
    stateModel = StateModel();
    global.l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  testWidgets('长按触发多选模式：非 LivePhoto 亦能清晰渲染选中/未选中勾选框与高亮边框', (tester) async {
    // 注入两张普通照片（isLivePhoto = false）
    assetModel.localAssets = [
      _MockAsset(id: '1'),
      _MockAsset(id: '2'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingModel>.value(value: settingModel),
          ChangeNotifierProvider<AssetModel>.value(value: assetModel),
          ChangeNotifierProvider<StateModel>.value(value: stateModel),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: GalleryBody(useLocal: true, showAppBar: false),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 初始状态：未处于多选模式，不应有 check_circle 或 circle_outlined 图标
    expect(stateModel.isSelectionMode, isFalse);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);

    // 调用 toggleSelection(0) 选中第 1 张照片
    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    state.toggleSelection(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 校验已进入多选模式
    expect(stateModel.isSelectionMode, isTrue);

    // 关键断言（修复验证）：
    // 1. 选中的第 1 张照片应渲染实心 check_circle
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // 2. 未选中的第 2 张照片应渲染空心 circle_outlined，提示用户处于多选且可勾选
    expect(find.byIcon(Icons.circle_outlined), findsOneWidget);
  });
}
