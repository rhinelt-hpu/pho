import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/gallery_body.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:mockito/mockito.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../unit/mocks/remote_storage_mock.mocks.dart';
import '../unit/mocks/test_doubles.dart';

class _MockAsset extends Asset {
  final String _id;
  final DateTime _date;

  _MockAsset({required String id})
      : _id = id,
        _date = DateTime(2026, 1, 1),
        super(
          local: AssetEntity(
            id: id,
            typeInt: 1,
            width: 100,
            height: 100,
            createDateSecond:
                DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
            modifiedDateSecond:
                DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
            title: 'photo_$id.jpg',
          ),
          remote: null,
        ) {
    hasLocal = true;
    localTitle = 'photo_$id.jpg';
  }

  @override
  bool isVideo() => false;

  @override
  bool isLivePhoto() => false;

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

Widget _buildGallery({required bool showAppBar}) {
  return MultiProvider(
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
        body: GalleryBody(useLocal: true, showAppBar: showAppBar),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    global.useRemoteServer = true;
    settingModel = SettingModel();
    settingModel.isRemoteStorageSetted = true;
    assetModel = AssetModel();
    stateModel = StateModel();
    global.l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    mockPhotoManagerChannel();
  });

  tearDown(() {
    resetPhotoManagerChannel();
    setStorageForTest(storage);
  });

  testWidgets('开启「隐藏已上传」后本地相册只渲染未同步照片', (tester) async {
    assetModel.localAssets = [
      _MockAsset(id: 'photo_1'),
      _MockAsset(id: 'photo_2'),
      _MockAsset(id: 'photo_3'),
    ];
    stateModel.setSyncedPhotos(['photo_1', 'photo_3']);

    await tester.pumpWidget(_buildGallery(showAppBar: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 开关关闭时三张都渲染
    expect(find.byKey(const ValueKey('gallery_photo_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery_photo_2')), findsOneWidget);

    // 点 app bar 上的一键切换按钮
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.cloud_done_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(settingModel.hideSyncedLocal, isTrue);
    // 过滤后只剩 photo_2，索引从 0 重新开始
    expect(find.byKey(const ValueKey('gallery_photo_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gallery_photo_1')), findsNothing);
    expect(find.byKey(const ValueKey('gallery_photo_2')), findsNothing);
  });

  testWidgets('切换「隐藏已上传」会清空当前多选，避免索引错位', (tester) async {
    assetModel.localAssets = [
      _MockAsset(id: 'photo_1'),
      _MockAsset(id: 'photo_2'),
    ];
    stateModel.setSyncedPhotos(['photo_2']);

    await tester.pumpWidget(_buildGallery(showAppBar: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    state.toggleSelection(1);
    await tester.pump();
    expect(stateModel.isSelectionMode, isTrue);

    await tester.tap(find.byIcon(Icons.cloud_done_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(settingModel.hideSyncedLocal, isTrue);
    expect(state.selectedIndices, isEmpty);
    expect(stateModel.isSelectionMode, isFalse);
  });

  testWidgets('手动多选上传前会向远端确认，已存在的照片被跳过并标记为已同步', (tester) async {
    final cli = FakeImgSyncerClient(['photo_2']);
    final mockStorage = MockRemoteStorageClient();
    when(mockStorage.cli).thenReturn(cli);
    setStorageForTest(mockStorage);

    final asset1 = _MockAsset(id: 'photo_1');
    final asset2 = _MockAsset(id: 'photo_2');
    final asset3 = _MockAsset(id: 'photo_3');
    assetModel.localAssets = [asset1, asset2, asset3];

    await tester.pumpWidget(_buildGallery(showAppBar: false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final state = tester.state<GalleryBodyState>(find.byType(GalleryBody));
    state.toggleSelection(0);
    state.toggleSelection(1);
    state.toggleSelection(2);
    await tester.pump();

    state.uploadSelected();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // 远端已有的 photo_2 不进队列，并被记为已同步
    expect(stateModel.uploadProgress.containsKey('photo_1'), isTrue);
    expect(stateModel.uploadProgress.containsKey('photo_2'), isFalse);
    expect(stateModel.uploadProgress.containsKey('photo_3'), isTrue);
    expect(stateModel.isSynced('photo_2'), isTrue);
    expect(stateModel.syncedIDs, contains('photo_2'));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    verifyNever(
        mockStorage.uploadAssetEntity(asset2.local, album: anyNamed('album')));
    verify(mockStorage.uploadAssetEntity(asset1.local,
            album: anyNamed('album')))
        .called(1);
    verify(mockStorage.uploadAssetEntity(asset3.local,
            album: anyNamed('album')))
        .called(1);

    // 取消 markSynced 的防抖计时器，避免测试结束仍遗留 pending timer
    await stateModel.saveSyncedIDs();
  });
}
