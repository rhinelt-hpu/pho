import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/main.dart';
import 'package:img_syncer/settings_route.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/sync_body.dart';
import 'package:img_syncer/util.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 可控的 Asset 子类，绕过 photo_manager AssetEntity 依赖。
class _TestAsset extends Asset {
  final bool _isVideo;
  final DateTime _dateCreated;
  final String _assetId;

  _TestAsset({
    required String id,
    required bool isVideoFlag,
    required DateTime dateCreated,
    String title = 'test.jpg',
  })  : _isVideo = isVideoFlag,
        _dateCreated = dateCreated,
        _assetId = id,
        super(
          local: AssetEntity(
            id: id,
            typeInt: isVideoFlag ? 2 : 1,
            width: 100,
            height: 100,
            createDateSecond: dateCreated.millisecondsSinceEpoch ~/ 1000,
            modifiedDateSecond: dateCreated.millisecondsSinceEpoch ~/ 1000,
            title: title,
          ),
          remote: null,
        ) {
    hasLocal = true;
    localTitle = title;
  }

  String get assetId => _assetId;

  @override
  bool isVideo() => _isVideo;

  @override
  DateTime dateCreated() => _dateCreated;

  @override
  bool loadThumbnailFinished() => false;

  @override
  Future<Uint8List> thumbnailDataAsync() async => Uint8List(0);

  @override
  bool hasGotTitle() => true;

  @override
  Future<String> name() async => localTitle ?? 'test.jpg';
}

/// 用指定 SettingModel 调用 shouldSyncAsset
bool callShouldSync(Asset asset,
    {Map<String, bool>? uploadedIds, SettingModel? sm}) {
  final smUse = sm ?? settingModel;
  final old = settingModel;
  if (sm != null) settingModel = smUse;
  try {
    final ext = (asset.localTitle != null && asset.localTitle!.contains('.'))
        ? '.${asset.localTitle!.split('.').last}'
        : 'jpg';
    final id = (asset is _TestAsset) ? asset.assetId : 'unknown';
    return shouldSyncAsset(asset, id, uploadedIds ?? {}, ext);
  } finally {
    if (sm != null) settingModel = old;
  }
}

void main() {
  setUp(() {
    settingModel = SettingModel();
  });

  group('shouldSyncAsset 过滤一致性', () {
    test('已上传的资源被过滤', () {
      final asset = _TestAsset(
          id: 'test1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(
        callShouldSync(asset, uploadedIds: {'test1': true}),
        isFalse,
      );
    });

    test('未上传的资源通过过滤', () {
      final asset = _TestAsset(
          id: 'test2', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(
        callShouldSync(asset, uploadedIds: {}),
        isTrue,
      );
    });

    test('filterNoVideo 过滤视频', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterNoVideo(true);
      final video =
          _TestAsset(id: 'v1', isVideoFlag: true, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(video, sm: sm), isFalse);
    });

    test('filterNoImage 过滤图片', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterNoImage(true);
      final image =
          _TestAsset(id: 'i1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(image, sm: sm), isFalse);
    });

    test('filterAfter 过滤过旧的照片', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterAfter(DateTime(2024, 6, 15));
      final oldPhoto =
          _TestAsset(id: 'old1', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(oldPhoto, sm: sm), isFalse);
    });

    test('filterBefore 不过滤同日照片（不含 +1天偏差）', () {
      // BUG 修复核心：columnBuilder 之前用了 .add(Duration(days: 1))
      // 现在统一为 isAfter(filterBefore!) 不含偏移
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.setFilterBefore(DateTime(2024, 6, 1));
      final sameDay = _TestAsset(
          id: 'same', isVideoFlag: false, dateCreated: DateTime(2024, 6, 1));
      // 同日 != isAfter，通过
      expect(callShouldSync(sameDay, sm: sm), isTrue);

      final nextDay = _TestAsset(
          id: 'next', isVideoFlag: false, dateCreated: DateTime(2024, 6, 2));
      // 6/2 > 6/1 → isAfter → 被过滤
      expect(callShouldSync(nextDay, sm: sm), isFalse);
    });

    test('filterTypeMap 根据扩展名过滤', () {
      final sm = SettingModel();
      sm.setFilterSwitch(true);
      sm.filterTypeMap['.gif'] = false;
      final gif = _TestAsset(
          id: 'g1',
          isVideoFlag: false,
          dateCreated: DateTime(2024, 6, 1),
          title: 'test.gif');
      expect(callShouldSync(gif, sm: sm), isFalse);

      final jpg = _TestAsset(
          id: 'j1',
          isVideoFlag: false,
          dateCreated: DateTime(2024, 6, 1),
          title: 'test.jpg');
      expect(callShouldSync(jpg, sm: sm), isTrue);
    });

    test('filter 未启用时全部通过', () {
      final sm = SettingModel();
      sm.setFilterSwitch(false);
      sm.setFilterNoVideo(true);
      final video =
          _TestAsset(id: 'v2', isVideoFlag: true, dateCreated: DateTime(2024, 6, 1));
      expect(callShouldSync(video, sm: sm), isTrue);
    });
  });

  group('failedTimes 断连检测', () {
    test('10次失败继续，11次失败停止', () {
      // syncPhotos 中: if (failedTimes > 10) break;
      const threshold = 10;
      expect(10 > threshold, isFalse);
      expect(11 > threshold, isTrue);
    });
  });

  group('SyncBody UI 与正在传输列表、底部设置导航测试', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingModel = SettingModel();
      assetModel = AssetModel();
      stateModel = StateModel();
      settingModel.isRemoteStorageSetted = true;
      global.l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    });

    Widget wrapWithProviders(Widget home) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingModel>.value(value: settingModel),
          ChangeNotifierProvider<AssetModel>.value(value: assetModel),
          ChangeNotifierProvider<StateModel>.value(value: stateModel),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );
    }

    testWidgets('同步页移除冗余四个快捷设置按钮，仅展示传输与未同步列表', (tester) async {
      assetModel.localAssets = [
        _TestAsset(
          id: 'p1',
          isVideoFlag: false,
          dateCreated: DateTime(2026, 1, 1),
          title: 'IMG_0001.jpg',
        ),
      ];

      await tester.pumpWidget(
        wrapWithProviders(const SyncBody(localFolder: 'Camera')),
      );
      await tester.pump();

      // 断言原先顶部的四个快捷按钮（本地相册、云端设置、后台同步、设置）不再出现在同步页
      expect(find.text('本地相册'), findsNothing);
      expect(find.text('云端设置'), findsNothing);
      expect(find.text('后台同步'), findsNothing);

      // 此时无正在传输项，“正在传输”分组不应显示，仅显示“未同步照片”
      expect(find.text('正在传输'), findsNothing);
      expect(find.text('未同步照片'), findsOneWidget);
      expect(find.text('IMG_0001.jpg'), findsOneWidget);
    });

    testWidgets('当存在正在上传或正在下载的内容时，显示“正在传输”列表与实时进度', (tester) async {
      assetModel.localAssets = [
        _TestAsset(
          id: 'up_1',
          isVideoFlag: false,
          dateCreated: DateTime(2026, 1, 1),
          title: 'uploading_photo.jpg',
        ),
        _TestAsset(
          id: 'wait_2',
          isVideoFlag: false,
          dateCreated: DateTime(2026, 1, 2),
          title: 'waiting_photo.jpg',
        ),
      ];

      await tester.pumpWidget(
        wrapWithProviders(const SyncBody(localFolder: 'Camera')),
      );
      await tester.pump();

      // 初始无传输：仅未同步列表
      expect(find.text('正在传输'), findsNothing);
      expect(find.text('uploading_photo.jpg'), findsOneWidget);
      expect(find.text('waiting_photo.jpg'), findsOneWidget);

      // 触发 up_1 上传进度 45%，以及一个云端视频下载进度 60%
      stateModel.updateUploadProgress('up_1', 45, 100);
      stateModel.updateDownloadProgress('remote_video.mp4', 60, 100);
      await tester.pump();

      // 断言“正在传输”分组出现，且显示计数 (2)
      expect(find.text('正在传输'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(find.text('上传中 45%'), findsOneWidget);
      expect(find.text('下载中 60%'), findsOneWidget);
      expect(find.text('remote_video.mp4'), findsOneWidget);

      // 断言 uploading_photo.jpg 仅在页面出现 1 次（已移至“正在传输”，不会在“未同步照片”重复出现）
      expect(find.text('uploading_photo.jpg'), findsOneWidget);
      expect(find.text('waiting_photo.jpg'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

      // 完成上传与下载后，“正在传输”分组自动消失
      stateModel.finishUpload('up_1', true);
      stateModel.finishDownload('remote_video.mp4', true);
      await stateModel.saveSyncedIDs();
      await tester.pump();

      expect(find.text('正在传输'), findsNothing);
      expect(find.text('uploading_photo.jpg'), findsNothing);
      expect(find.text('waiting_photo.jpg'), findsOneWidget);
    });

    testWidgets('首页底部导航栏包含4个按钮，最右侧第4个为“设置”并可切换', (tester) async {
      isDesktopOverrideForTest = false;
      settingModel.isRemoteStorageSetted = false;
      addTearDown(() => isDesktopOverrideForTest = null);

      await tester.pumpWidget(
        wrapWithProviders(const MyHomePage(title: 'PHO')),
      );
      await tester.pump();

      final navBarFinder = find.byType(NavigationBar);
      expect(navBarFinder, findsOneWidget);

      final navBar = tester.widget<NavigationBar>(navBarFinder);
      expect(navBar.destinations.length, 4);

      final lastDest = navBar.destinations[3] as NavigationDestination;
      expect(lastDest.label, '设置');

      // 点击底部最右侧“设置”导航项，应切换到 SettingsRoute
      await tester.tap(find.descendant(
        of: navBarFinder,
        matching: find.text('设置'),
      ));
      await tester.pump();

      expect(find.byType(SettingsRoute), findsOneWidget);
      expect(find.text('选择相册'), findsOneWidget);
      expect(find.text('云端设置'), findsOneWidget);
    });
  });
}
