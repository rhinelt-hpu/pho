import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/gallery_body.dart';
import 'package:img_syncer/global.dart' as global;
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/widgets/local_album_sheet.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget createTestApp(Widget child) {
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
      home: Scaffold(body: child),
    ),
  );
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

  testWidgets('本地相册顶部 AppBar 显示当前选中相册名称与下拉箭头，点击触发 LocalAlbumSheet', (tester) async {
    settingModel.setLocalFolder('Camera');

    await tester.pumpWidget(createTestApp(
      GalleryBody(useLocal: true, showAppBar: true),
    ));
    await tester.pump();

    // 验证本地相册顶部展示 "Camera" 而非写死的 "Pho"
    expect(find.text('Camera'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    // 验证本地顶部包含相册快捷按钮
    final albumBtn = find.byTooltip('选择相册');
    expect(albumBtn, findsOneWidget);

    // 点击顶部标题或相册按钮弹出 LocalAlbumSheet
    await tester.tap(find.text('Camera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LocalAlbumSheet), findsOneWidget);
  });

  testWidgets('云端相册顶部默认展示全部照片而非Pho，选中具体相册时展示该相册名', (tester) async {
    assetModel.currentCloudAlbum = '';

    await tester.pumpWidget(createTestApp(
      GalleryBody(useLocal: false, showAppBar: true),
    ));
    await tester.pump();

    // 默认展示“全部照片”，不应再出现硬编码的 "Pho"
    expect(find.text('全部照片'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);

    // 切换到具体相册
    assetModel.currentCloudAlbum = '相机备份';
    assetModel.notifyListeners();
    await tester.pump();

    expect(find.text('相机备份'), findsOneWidget);
    expect(find.text('全部照片'), findsNothing);
  });
}
