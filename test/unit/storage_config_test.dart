import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StorageConfig 编解码与跨设备迁移测试', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('WebDAV 配置序列化与 URI 解码一致性', () {
      final config = StorageConfig(
        drive: Drive.webDav,
        data: {
          "url": "https://dav.my-nas.com:5006",
          "username": "alice",
          "password": "my_secret_password",
          "rootPath": "/Photos/Backup",
          "insecure": false,
        },
      );

      final uri = config.encodeToUri();
      expect(uri, startsWith("pho://storage?data="));

      final decoded = StorageConfig.decode(uri);
      expect(decoded, isNotNull);
      expect(decoded!.drive, Drive.webDav);
      expect(decoded.data['url'], "https://dav.my-nas.com:5006");
      expect(decoded.data['username'], "alice");
      expect(decoded.data['password'], "my_secret_password");
      expect(decoded.data['rootPath'], "/Photos/Backup");
      expect(decoded.data['insecure'], isFalse);
    });

    test('SMB 配置序列化与 URI 解码一致性', () {
      final config = StorageConfig(
        drive: Drive.smb,
        data: {
          "addr": "192.168.1.100:445",
          "username": "nas_user",
          "password": "smb_password",
          "share": "HomePhotos",
          "rootPath": "/2026",
        },
      );

      final uri = config.encodeToUri();
      final decoded = StorageConfig.decode(uri);

      expect(decoded, isNotNull);
      expect(decoded!.drive, Drive.smb);
      expect(decoded.data['addr'], "192.168.1.100:445");
      expect(decoded.data['share'], "HomePhotos");
      expect(decoded.summary, "192.168.1.100:445/HomePhotos");
    });

    test('NFS 配置序列化与 URI 解码一致性', () {
      final config = StorageConfig(
        drive: Drive.nfs,
        data: {
          "url": "192.168.1.50:/volume1/photos",
          "rootPath": "/mobile",
        },
      );

      final uri = config.encodeToUri();
      final decoded = StorageConfig.decode(uri);

      expect(decoded, isNotNull);
      expect(decoded!.drive, Drive.nfs);
      expect(decoded.data['url'], "192.168.1.50:/volume1/photos");
    });

    test('容错解码：纯 Base64 或明文 JSON 均能成功解析', () {
      final jsonMap = {
        "type": "pho_storage_config",
        "version": 1,
        "drive": "WebDAV",
        "data": {
          "url": "https://example.com/dav",
          "username": "user",
          "password": "pwd",
        },
        "created_at": 1700000000000,
      };

      // 1. 明文 JSON
      final fromJson = StorageConfig.decode(jsonEncode(jsonMap));
      expect(fromJson, isNotNull);
      expect(fromJson!.drive, Drive.webDav);

      // 2. 纯 Base64
      final b64 = base64.encode(utf8.encode(jsonEncode(jsonMap)));
      final fromB64 = StorageConfig.decode(b64);
      expect(fromB64, isNotNull);
      expect(fromB64!.drive, Drive.webDav);

      // 3. 无效数据返回 null
      expect(StorageConfig.decode(""), isNull);
      expect(StorageConfig.decode("invalid text"), isNull);
      expect(StorageConfig.decode('{"type": "other"}'), isNull);
    });

    test('exportCurrent 从 SharedPreferences 正确导出当前配置', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("drive", "WebDAV");
      await prefs.setString("webdav_url", "https://dav.test.com");
      await prefs.setString("webdav_username", "admin");
      await prefs.setString("webdav_password", "123456");
      await prefs.setString("webdav_root_path", "/photos");
      await prefs.setBool("webdav_insecure", true);

      final config = await StorageConfig.exportCurrent(prefs);
      expect(config, isNotNull);
      expect(config!.drive, Drive.webDav);
      expect(config.data['url'], "https://dav.test.com");
      expect(config.data['username'], "admin");
      expect(config.data['insecure'], isTrue);
    });

    test('未配置存储时 exportCurrent 返回 null', () async {
      final prefs = await SharedPreferences.getInstance();
      final config = await StorageConfig.exportCurrent(prefs);
      expect(config, isNull);
    });

    test('双存储（主存储 + 独立元数据与缩略图存储）URI 编解码与 exportCurrent 一致性', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("drive", "WebDAV");
      await prefs.setString("webdav_url", "https://large-slow.example.com/dav");
      await prefs.setString("webdav_username", "main_user");
      await prefs.setString("webdav_password", "main_pass");
      await prefs.setString("webdav_root_path", "/origin_photos");
      await prefs.setBool("webdav_insecure", false);

      await prefs.setBool("meta_drive_enabled", true);
      await prefs.setString("meta_drive", "WebDAV");
      await prefs.setString("meta_webdav_url", "https://fast-small.example.com/dav");
      await prefs.setString("meta_webdav_username", "fast_user");
      await prefs.setString("meta_webdav_password", "fast_pass");
      await prefs.setString("meta_webdav_root_path", "/pho_meta");
      await prefs.setBool("meta_webdav_insecure", true);

      final exported = await StorageConfig.exportCurrent(prefs);
      expect(exported, isNotNull);
      expect(exported!.metaEnabled, isTrue);
      expect(exported.metaDrive, Drive.webDav);
      expect(exported.metaSummary, "https://fast-small.example.com/dav");
      expect(exported.metaRootPath, "/pho_meta");

      final uri = exported.encodeToUri();
      final decoded = StorageConfig.decode(uri);
      expect(decoded, isNotNull);
      expect(decoded!.drive, Drive.webDav);
      expect(decoded.data['url'], "https://large-slow.example.com/dav");
      expect(decoded.metaEnabled, isTrue);
      expect(decoded.metaDrive, Drive.webDav);
      expect(decoded.metaData?['url'], "https://fast-small.example.com/dav");
      expect(decoded.metaData?['rootPath'], "/pho_meta");
    });
  });
}
