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
import 'package:mockito/mockito.dart';
import 'package:img_syncer/storage/storage_interface.dart';
import 'package:img_syncer/storage/storage.dart';

class MockRemoteStorageClient extends Mock implements RemoteStorageClient {
  @override
  Future<void> uploadAssetEntity(AssetEntity? asset, {String? album = ""}) async =>
      super.noSuchMethod(
        Invocation.method(#uploadAssetEntity, [asset], {#album: album}),
        returnValue: Future<void>.value(),
        returnValueForMissingStub: Future<void>.value(),
      );

  @override
  Future<List<RemoteImage>> listImages(String date, int offset, maxReturn,
          {String album = ""}) async =>
      [];
}

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
    global.useRemoteServer = true;
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

  testWidgets('多选模式下触发系统返回键：应退出多选状态而非退出页面/程序', (tester) async {
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

    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    state.toggleSelection(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(stateModel.isSelectionMode, isTrue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // 模拟用户按下 Android 系统返回键
    final didHandlePop = await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 断言返回事件已被拦截处理，多选模式已退出，且 GalleryBody 仍在树中（未退出页面）
    expect(didHandlePop, isTrue);
    expect(stateModel.isSelectionMode, isFalse);
    expect(find.byType(GalleryBody), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
  });

  testWidgets('多选照片点击上传：应立即自动退出多选模式并将所有选中项登记入传输队列', (tester) async {
    final mockStorage = MockRemoteStorageClient();
    setStorageForTest(mockStorage);

    assetModel.localAssets = [
      _MockAsset(id: 'photo_1'),
      _MockAsset(id: 'photo_2'),
      _MockAsset(id: 'photo_3'),
    ];
    // 模拟远端存储已配置
    settingModel.isRemoteStorageSetted = true;

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

    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    // 勾选 3 张照片
    state.toggleSelection(0);
    state.toggleSelection(1);
    state.toggleSelection(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(stateModel.isSelectionMode, isTrue);
    expect(state.selectedIndices.length, 3);

    // 触发批量上传
    state.uploadSelected();
    await tester.pump();

    // 验证 Bug 1: 立即自动退出多选模式
    expect(stateModel.isSelectionMode, isFalse);
    expect(state.selectedIndices, isEmpty);

    // 验证 Bug 2: 选中的 3 张照片全部预先登记到传输队列 uploadProgress 中
    expect(stateModel.uploadProgress.containsKey('photo_1'), isTrue);
    expect(stateModel.uploadProgress.containsKey('photo_2'), isTrue);
    expect(stateModel.uploadProgress.containsKey('photo_3'), isTrue);
    expect(stateModel.uploadProgress.length, 3);

    // 等待 mock 上传任务完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 恢复全局 storage 默认实例
    setStorageForTest(storage);
  });

  testWidgets('多选照片点击上传：自动跳过已在 syncedIDs 中的已上传照片，仅上传未上传项', (tester) async {
    final mockStorage = MockRemoteStorageClient();
    setStorageForTest(mockStorage);

    final asset1 = _MockAsset(id: 'photo_1');
    final asset2 = _MockAsset(id: 'photo_2');
    final asset3 = _MockAsset(id: 'photo_3');
    assetModel.localAssets = [asset1, asset2, asset3];
    settingModel.isRemoteStorageSetted = true;
    // photo_1 与 photo_3 已经上传过
    stateModel.setSyncedPhotos(['photo_1', 'photo_3']);

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

    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    state.toggleSelection(0);
    state.toggleSelection(1);
    state.toggleSelection(2);
    await tester.pump();

    state.uploadSelected();
    await tester.pump();

    // 仅未上传的 photo_2 被加入上传队列，已上传的 photo_1 / photo_3 被跳过
    expect(stateModel.uploadProgress.containsKey('photo_1'), isFalse);
    expect(stateModel.uploadProgress.containsKey('photo_2'), isTrue);
    expect(stateModel.uploadProgress.containsKey('photo_3'), isFalse);
    expect(stateModel.uploadProgress.length, 1);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    verifyNever(mockStorage.uploadAssetEntity(asset1.local, album: anyNamed('album')));
    verify(mockStorage.uploadAssetEntity(asset2.local, album: anyNamed('album'))).called(1);
    verifyNever(mockStorage.uploadAssetEntity(asset3.local, album: anyNamed('album')));

    setStorageForTest(storage);
  });

  testWidgets('多选照片点击上传：若选中的照片全部已上传，则全部跳过不发起任何上传', (tester) async {
    final mockStorage = MockRemoteStorageClient();
    setStorageForTest(mockStorage);

    assetModel.localAssets = [
      _MockAsset(id: 'photo_1'),
      _MockAsset(id: 'photo_2'),
    ];
    settingModel.isRemoteStorageSetted = true;
    stateModel.setSyncedPhotos(['photo_1', 'photo_2']);

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

    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    state.toggleSelection(0);
    state.toggleSelection(1);
    await tester.pump();

    state.uploadSelected();
    await tester.pump();

    expect(stateModel.isSelectionMode, isFalse);
    expect(stateModel.uploadProgress, isEmpty);
    verifyNever(mockStorage.uploadAssetEntity(any, album: anyNamed('album')));

    setStorageForTest(storage);
  });
}
