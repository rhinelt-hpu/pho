import 'dart:convert';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 统一存储配置模型，支持 WebDAV、SMB、NFS 的无损导出、导入与扫码迁移。
class StorageConfig {
  static const String uriScheme = "pho";
  static const String uriHost = "storage";
  static const int currentVersion = 1;

  final Drive drive;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  StorageConfig({
    required this.drive,
    required this.data,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 转换为规范 JSON 字典
  Map<String, dynamic> toJson() => {
        "type": "pho_storage_config",
        "version": currentVersion,
        "drive": driveName[drive] ?? "WebDAV",
        "data": data,
        "created_at": createdAt.millisecondsSinceEpoch,
      };

  /// 编码为分享 URI：pho://storage?data=`Base64URL`
  String encodeToUri() {
    final jsonStr = jsonEncode(toJson());
    final b64 = base64Url.encode(utf8.encode(jsonStr));
    return "$uriScheme://$uriHost?data=$b64";
  }

  /// 容错解码：支持 pho://storage?data=...、纯 Base64、或明文 JSON
  static StorageConfig? decode(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return null;

    // 1. 处理 pho://storage?data=... 格式
    if (text.startsWith("$uriScheme://$uriHost")) {
      try {
        final uri = Uri.parse(text);
        final param = uri.queryParameters['data'];
        if (param != null && param.isNotEmpty) {
          text = param;
        }
      } catch (_) {}
    }

    String jsonStr;
    // 2. 尝试 Base64 解码
    try {
      final normalized = base64.normalize(text.replaceAll('-', '+').replaceAll('_', '/'));
      jsonStr = utf8.decode(base64.decode(normalized));
    } catch (_) {
      // 若不是 Base64，直接按明文 JSON 尝试
      jsonStr = text;
    }

    // 3. 解析 JSON
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return null;
      if (decoded['type'] != 'pho_storage_config') return null;

      final driveStr = decoded['drive']?.toString() ?? '';
      final drive = getDrive(driveStr);
      final dataMap = decoded['data'];
      if (dataMap is! Map) return null;

      final createdAtMs = decoded['created_at'] is int ? decoded['created_at'] as int : null;
      return StorageConfig(
        drive: drive,
        data: Map<String, dynamic>.from(dataMap),
        createdAt: createdAtMs != null ? DateTime.fromMillisecondsSinceEpoch(createdAtMs) : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// 从 SharedPreferences 读取当前保存的配置
  static Future<StorageConfig?> exportCurrent([SharedPreferences? sharedPrefs]) async {
    final prefs = sharedPrefs ?? await SharedPreferences.getInstance();
    final driveStr = prefs.getString("drive") ?? "WebDAV";
    final drive = getDrive(driveStr);

    switch (drive) {
      case Drive.webDav:
        final url = prefs.getString('webdav_url');
        if (url == null || url.trim().isEmpty) return null;
        return StorageConfig(
          drive: Drive.webDav,
          data: {
            "url": url,
            "username": prefs.getString('webdav_username') ?? "",
            "password": prefs.getString('webdav_password') ?? "",
            "rootPath": prefs.getString('webdav_root_path') ?? "",
            "insecure": prefs.getBool('webdav_insecure') ?? true,
          },
        );
      case Drive.smb:
        final addr = prefs.getString("addr");
        if (addr == null || addr.trim().isEmpty) return null;
        return StorageConfig(
          drive: Drive.smb,
          data: {
            "addr": addr,
            "username": prefs.getString("username") ?? "",
            "password": prefs.getString("password") ?? "",
            "share": prefs.getString("share") ?? "",
            "rootPath": prefs.getString("rootPath") ?? "",
          },
        );
      case Drive.nfs:
        final url = prefs.getString("nfs_url");
        if (url == null || url.trim().isEmpty) return null;
        return StorageConfig(
          drive: Drive.nfs,
          data: {
            "url": url,
            "rootPath": prefs.getString("nfs_root_path") ?? "",
          },
        );
    }
  }

  /// 测试配置的连通性，成功返回 null，失败返回错误原因
  Future<String?> testConnection() async {
    try {
      switch (drive) {
        case Drive.webDav:
          final rsp = await storage.cli.setDriveWebdav(SetDriveWebdavRequest(
            addr: data["url"]?.toString() ?? "",
            username: data["username"]?.toString() ?? "",
            password: data["password"]?.toString() ?? "",
            root: data["rootPath"]?.toString() ?? "",
            insecure: data["insecure"] == true,
          ));
          if (!rsp.success) return rsp.message;
          final rspList = await storage.cli.listDriveWebdavDir(ListDriveWebdavDirRequest());
          if (!rspList.success) return rspList.message;
          return null;

        case Drive.smb:
          final rsp = await storage.cli.setDriveSMB(SetDriveSMBRequest(
            addr: data["addr"]?.toString() ?? "",
            username: data["username"]?.toString() ?? "",
            password: data["password"]?.toString() ?? "",
            share: data["share"]?.toString() ?? "",
            root: data["rootPath"]?.toString() ?? "",
          ));
          if (!rsp.success) return rsp.message;
          return null;

        case Drive.nfs:
          final rsp = await storage.cli.setDriveNFS(SetDriveNFSRequest(
            addr: data["url"]?.toString() ?? "",
          ));
          if (!rsp.success) return rsp.message;
          return null;
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// 写入本地 SharedPreferences 并立即生效
  Future<void> saveToPrefsAndApply([SharedPreferences? sharedPrefs]) async {
    final prefs = sharedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setString("drive", driveName[drive]!);

    switch (drive) {
      case Drive.webDav:
        await prefs.setString('webdav_url', data["url"]?.toString() ?? "");
        await prefs.setString('webdav_username', data["username"]?.toString() ?? "");
        await prefs.setString('webdav_password', data["password"]?.toString() ?? "");
        await prefs.setString('webdav_root_path', data["rootPath"]?.toString() ?? "");
        await prefs.setBool('webdav_insecure', data["insecure"] == true);
        break;
      case Drive.smb:
        await prefs.setString('addr', data["addr"]?.toString() ?? "");
        await prefs.setString('username', data["username"]?.toString() ?? "");
        await prefs.setString('password', data["password"]?.toString() ?? "");
        await prefs.setString('share', data["share"]?.toString() ?? "");
        await prefs.setString('rootPath', data["rootPath"]?.toString() ?? "");
        break;
      case Drive.nfs:
        await prefs.setString('nfs_url', data["url"]?.toString() ?? "");
        await prefs.setString('nfs_root_path', data["rootPath"]?.toString() ?? "");
        break;
    }
    await initDrive();
  }

  /// 获取用于 UI 展示的摘要信息
  String get summary {
    switch (drive) {
      case Drive.webDav:
        return data["url"]?.toString() ?? "";
      case Drive.smb:
        final addr = data["addr"]?.toString() ?? "";
        final share = data["share"]?.toString() ?? "";
        return "$addr/$share";
      case Drive.nfs:
        return data["url"]?.toString() ?? "";
    }
  }

  /// 获取用于 UI 展示的用户名
  String? get username {
    return data["username"]?.toString();
  }

  /// 获取用于 UI 展示的根路径
  String? get rootPath {
    return data["rootPath"]?.toString();
  }
}
