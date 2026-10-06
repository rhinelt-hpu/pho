import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/setting_storage_route.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage_config.dart';
import 'package:img_syncer/storage/storage_export_dialog.dart';
import 'package:img_syncer/storage/storage_import_route.dart';
import 'package:qr_flutter/qr_flutter.dart';
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

  group('StorageExportDialog 导出组件测试', () {
    testWidgets('弹窗完整渲染二维码与配置摘要及操作按钮', (tester) async {
      final config = StorageConfig(
        drive: Drive.webDav,
        data: {
          "url": "https://dav.example.com",
          "username": "user123",
          "password": "pwd",
          "rootPath": "/backup",
        },
      );

      await tester.pumpWidget(_buildTestApp(StorageExportDialog(config: config)));
      await tester.pumpAndSettle();

      // 验证标题与描述
      expect(find.text(l10n.storageConfigQrTitle), findsOneWidget);
      expect(find.text(l10n.storageConfigQrDesc), findsOneWidget);

      // 验证二维码渲染
      expect(find.byType(QrImageView), findsOneWidget);

      // 验证摘要信息
      expect(find.text('WebDAV'), findsOneWidget);
      expect(find.text('https://dav.example.com'), findsOneWidget);
      expect(find.text('user123'), findsOneWidget);
      expect(find.text('/backup'), findsOneWidget);

      // 验证按钮
      expect(find.text(l10n.copyConfig), findsOneWidget);
      expect(find.text(l10n.shareConfig), findsOneWidget);
    });
  });

  group('StorageImportRoute 导入组件测试', () {
    testWidgets('手动粘贴有效配置后弹出预览确认对话框', (tester) async {
      final config = StorageConfig(
        drive: Drive.smb,
        data: {
          "addr": "192.168.1.88",
          "username": "smbuser",
          "share": "nas_photos",
        },
      );
      final uri = config.encodeToUri();

      await tester.pumpWidget(_buildTestApp(const StorageImportRoute()));
      await tester.pump();

      // 点击“手动粘贴配置”
      expect(find.text(l10n.pasteConfig), findsOneWidget);
      await tester.tap(find.text(l10n.pasteConfig));
      await tester.pumpAndSettle();

      // 查找输入框并填入 URI
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), uri);
      await tester.pumpAndSettle();

      // 点击确认
      await tester.tap(find.text(l10n.yes));
      await tester.pumpAndSettle();

      // 验证确认对话框出现并展示 SMB 摘要
      expect(find.text(l10n.importConfigConfirmTitle), findsOneWidget);
      expect(find.text('存储类型: SMB'), findsOneWidget);
      expect(find.text('服务器: 192.168.1.88/nas_photos'), findsOneWidget);
      expect(find.text(l10n.testAndSave), findsOneWidget);
    });

    testWidgets('剪贴板中发现 Pho 配置时自动解析并弹出确认框', (tester) async {
      final config = StorageConfig(
        drive: Drive.webDav,
        data: {
          "url": "https://nas.quick.com",
          "username": "tester",
        },
      );
      final uri = config.encodeToUri();

      // 设置剪贴板 mock 数据
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') {
            return {'text': uri};
          }
          return null;
        },
      );

      await tester.pumpWidget(_buildTestApp(const StorageImportRoute()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // 校验自动解析成功并弹出确认弹窗
      expect(find.text(l10n.importConfigConfirmTitle), findsOneWidget);
      expect(find.text('从剪贴板检测到配置'), findsOneWidget);
      expect(find.text('存储类型: WebDAV'), findsOneWidget);
    });
  });

  group('SettingStorageRoute 导出与导入入口', () {
    testWidgets('AppBar 包含导出与扫码导入按钮', (tester) async {
      await tester.pumpWidget(_buildTestApp(const SettingStorageRoute()));
      await tester.pumpAndSettle();

      // 验证右上角包含扫码和导出两个 Action 图标
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
    });

    testWidgets('单页上下排列：开启副存储开关展开第二套表单，且底部仅有一组全局测试与保存按钮', (tester) async {
      settingModel.setRemoteStorageSetted(true);
      await tester.pumpWidget(_buildTestApp(const SettingStorageRoute()));
      await tester.pumpAndSettle();

      // 默认未展开副存储类型选择器，且底部仅有唯一一组 [测试连接] 与 [保存]
      expect(find.text(l10n.enableMetaStorage), findsOneWidget);
      expect(find.text(l10n.metaStorageType), findsNothing);
      expect(find.text(l10n.testStorage), findsOneWidget);
      expect(find.text(l10n.save), findsOneWidget);
      expect(find.text(l10n.rebuildMetaAndThumbnails), findsOneWidget);

      // 打开「启用独立元数据与缩略图存储」开关（先滚动到可见区域）
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // 展开副存储配置，但底部仍然只有唯一一组全局 [测试连接] 与 [保存]
      expect(find.text(l10n.metaStorageType), findsOneWidget);
      expect(find.text(l10n.testStorage), findsOneWidget);
      expect(find.text(l10n.save), findsOneWidget);
    });
  });
}
