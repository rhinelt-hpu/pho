import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/proto/img_syncer.pb.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/storage/storage_interface.dart';
import 'package:img_syncer/widgets/cloud_album_sheet.dart';
import 'package:img_syncer/settings_route.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cross_file/cross_file.dart';
import 'package:photo_manager/photo_manager.dart';

class MockUIAlbumStorage implements RemoteStorageClient {
  List<AlbumInfo> albums = [
    AlbumInfo(name: '相机备份', count: Int64(10), isDefault: true),
    AlbumInfo(name: '日本旅行 2026', count: Int64(4), isDefault: false),
  ];

  @override
  ImgSyncerClient get cli => throw UnimplementedError();

  @override
  Future<void> uploadXFile(XFile file, {String album = ""}) async {}

  @override
  Future<void> uploadAssetEntity(AssetEntity asset, {String album = ""}) async {}

  @override
  Future<List<RemoteImage>> listImages(String date, int offset, maxReturn, {String album = ""}) async => [];

  @override
  Future<List<AlbumInfo>> listAlbums() async => List.from(albums);

  @override
  Future<void> createAlbum(String name) async {
    albums.add(AlbumInfo(name: name, count: Int64(0), isDefault: false));
  }

  @override
  Future<void> deleteAlbum(String name) async {
    albums.removeWhere((a) => a.name == name);
  }

  @override
  Future<void> renameAlbum(String oldName, String newName) async {
    final idx = albums.indexWhere((a) => a.name == oldName);
    if (idx != -1) albums[idx].name = newName;
  }

  @override
  Future<List<String>> moveAssets(List<String> paths, String targetAlbum) async => paths;
}

Widget createTestApp(Widget home) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settingModel),
      ChangeNotifierProvider.value(value: assetModel),
      ChangeNotifierProvider.value(value: stateModel),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockUIAlbumStorage mockStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockUIAlbumStorage();
    setStorageForTest(mockStorage);
    useRemoteServer = true;
    grpcPort = 50051;
    httpPort = 10000;
    assetModel.currentCloudAlbum = '';
    assetModel.cloudAlbums = List.from(mockStorage.albums);
    settingModel.defaultAlbumName = '相机备份';
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  tearDown(() {
    setStorageForTest(storage);
  });

  testWidgets('CloudAlbumSheet 渲染全部照片与相册列表，点击可切换当前相册', (tester) async {
    await tester.pumpWidget(createTestApp(const CloudAlbumSheet()));
    await tester.pumpAndSettle();

    // 验证标题与默认项
    expect(find.text('云端相册'), findsOneWidget);
    expect(find.text('全部照片'), findsOneWidget);
    expect(find.text('相机备份'), findsOneWidget);
    expect(find.text('日本旅行 2026'), findsOneWidget);
    expect(find.text('默认相册'), findsOneWidget);

    // 点击切换至“日本旅行 2026”
    await tester.tap(find.text('日本旅行 2026'));
    await tester.pumpAndSettle();

    expect(assetModel.currentCloudAlbum, '日本旅行 2026');
  });

  testWidgets('Option B 粉碎删除二次确认弹窗：输入完整相册名后删除按钮方可点击', (tester) async {
    await tester.pumpWidget(createTestApp(const CloudAlbumSheet()));
    await tester.pumpAndSettle();

    // 打开“日本旅行 2026”的更多菜单
    final moreBtns = find.byIcon(Icons.more_vert);
    expect(moreBtns, findsWidgets);
    await tester.tap(moreBtns.last);
    await tester.pumpAndSettle();

    // 点击删除相册
    expect(find.text('删除相册'), findsOneWidget);
    await tester.tap(find.text('删除相册'));
    await tester.pumpAndSettle();

    // 弹出粉碎删除对话框
    expect(find.text('确认粉碎删除相册？'), findsOneWidget);

    // 此时删除按钮应处于禁用状态（未输入相册名称）
    final deleteBtnFinder = find.widgetWithText(FilledButton, '删除');
    expect(tester.widget<FilledButton>(deleteBtnFinder).onPressed, isNull);

    // 输入错误名称
    await tester.enterText(find.byType(TextField), '随便输入');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(deleteBtnFinder).onPressed, isNull);

    // 输入正确相册名称
    await tester.enterText(find.byType(TextField), '日本旅行 2026');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(deleteBtnFinder).onPressed, isNotNull);

    // 点击确认删除
    await tester.tap(deleteBtnFinder);
    await tester.pumpAndSettle();

    // 验证相册已被删除
    expect(mockStorage.albums.any((a) => a.name == '日本旅行 2026'), isFalse);
  });

  testWidgets('SettingsRoute 展示默认备份相册并支持修改', (tester) async {
    await tester.pumpWidget(createTestApp(const SettingsRoute()));
    await tester.pumpAndSettle();

    // 验证包含默认备份相册设置项
    expect(find.text('默认备份相册'), findsOneWidget);
    expect(find.text('相机备份'), findsOneWidget);

    // 点击打开修改弹窗
    await tester.tap(find.text('默认备份相册'));
    await tester.pumpAndSettle();

    expect(find.text('设置自动备份和上传默认流入的相册名称'), findsOneWidget);

    // 输入新相册名
    await tester.enterText(find.byType(TextField), 'Redmi K60 备份');
    await tester.tap(find.widgetWithText(FilledButton, l10n.yes));
    await tester.pumpAndSettle();

    expect(settingModel.defaultAlbumName, 'Redmi K60 备份');
    expect(find.text('Redmi K60 备份'), findsOneWidget);
  });
}
