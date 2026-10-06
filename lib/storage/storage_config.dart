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
  final bool metaEnabled;
  final Drive? metaDrive;
  final Map<String, dynamic>? metaData;
  final DateTime createdAt;

  StorageConfig({
    required this.drive,
    required this.data,
    this.metaEnabled = false,
    this.metaDrive,
    this.metaData,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 转换为规范 JSON 字典
  Map<String, dynamic> toJson() => {
        "type": "pho_storage_config",
        "version": currentVersion,
        "drive": driveName[drive] ?? "WebDAV",
        "data": data,
        if (metaEnabled && metaDrive != null && metaData != null) ...{
          "meta_enabled": true,
          "meta_drive": driveName[metaDrive] ?? "WebDAV",
          "meta_data": metaData,
        },
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
      final metaEnabled = decoded['meta_enabled'] == true;
      Drive? metaDrive;
      Map<String, dynamic>? metaData;
      if (metaEnabled && decoded['meta_data'] is Map) {
        metaDrive = getDrive(decoded['meta_drive']?.toString() ?? 'WebDAV');
        metaData = Map<String, dynamic>.from(decoded['meta_data'] as Map);
      }
      return StorageConfig(
        drive: drive,
        data: Map<String, dynamic>.from(dataMap),
        metaEnabled: metaEnabled && metaDrive != null && metaData != null,
        metaDrive: metaDrive,
        metaData: metaData,
        createdAt: createdAtMs != null ? DateTime.fromMillisecondsSinceEpoch(createdAtMs) : null,
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _readDriveDataFromPrefs(
      SharedPreferences prefs, Drive drive,
      {String prefix = ''}) {
    switch (drive) {
      case Drive.webDav:
        final url = prefs.getString('${prefix}webdav_url');
        if (url == null || url.trim().isEmpty) return null;
        return {
          "url": url,
          "username": prefs.getString('${prefix}webdav_username') ?? "",
          "password": prefs.getString('${prefix}webdav_password') ?? "",
          "rootPath": prefs.getString('${prefix}webdav_root_path') ?? "",
          "insecure": prefs.getBool('${prefix}webdav_insecure') ?? true,
        };
      case Drive.smb:
        final addr = prefs.getString("${prefix}addr");
        if (addr == null || addr.trim().isEmpty) return null;
        return {
          "addr": addr,
          "username": prefs.getString("${prefix}username") ?? "",
          "password": prefs.getString("${prefix}password") ?? "",
          "share": prefs.getString("${prefix}share") ?? "",
          "rootPath": prefs.getString("${prefix}rootPath") ?? "",
        };
      case Drive.nfs:
        final url = prefs.getString("${prefix}nfs_url");
        if (url == null || url.trim().isEmpty) return null;
        return {
          "url": url,
          "rootPath": prefs.getString("${prefix}nfs_root_path") ?? "",
        };
    }
  }

  /// 从 SharedPreferences 读取当前保存的配置
  static Future<StorageConfig?> exportCurrent([SharedPreferences? sharedPrefs]) async {
    final prefs = sharedPrefs ?? await SharedPreferences.getInstance();
    final driveStr = prefs.getString("drive") ?? "WebDAV";
    final drive = getDrive(driveStr);
    final primaryData = _readDriveDataFromPrefs(prefs, drive);
    if (primaryData == null) return null;

    final metaEnabled = prefs.getBool("meta_drive_enabled") ?? false;
    Drive? metaDrive;
    Map<String, dynamic>? metaData;
    if (metaEnabled) {
      metaDrive = getDrive(prefs.getString("meta_drive") ?? "WebDAV");
      metaData = _readDriveDataFromPrefs(prefs, metaDrive, prefix: 'meta_');
    }

    return StorageConfig(
      drive: drive,
      data: primaryData,
      metaEnabled: metaEnabled && metaData != null,
      metaDrive: metaData != null ? metaDrive : null,
      metaData: metaData,
    );
  }

  static Future<String?> _testSingleDrive(
      Drive targetDrive, Map<String, dynamic> targetData,
      {required bool isMetaDrive}) async {
    final root = targetData["rootPath"]?.toString().trim() ?? "";
    if (root.isEmpty) {
      return "root path is empty";
    }
    try {
      switch (targetDrive) {
        case Drive.webDav:
          final rsp = await storage.cli.setDriveWebdav(SetDriveWebdavRequest(
            addr: targetData["url"]?.toString() ?? "",
            username: targetData["username"]?.toString() ?? "",
            password: targetData["password"]?.toString() ?? "",
            root: root,
            insecure: targetData["insecure"] == true,
            isMetaDrive: isMetaDrive,
          ));
          if (!rsp.success) return rsp.message;
          final rspList = await storage.cli.listDriveWebdavDir(
              ListDriveWebdavDirRequest(isMetaDrive: isMetaDrive));
          if (!rspList.success) return rspList.message;
          return null;

        case Drive.smb:
          final rsp = await storage.cli.setDriveSMB(SetDriveSMBRequest(
            addr: targetData["addr"]?.toString() ?? "",
            username: targetData["username"]?.toString() ?? "",
            password: targetData["password"]?.toString() ?? "",
            share: targetData["share"]?.toString() ?? "",
            root: root,
            isMetaDrive: isMetaDrive,
          ));
          if (!rsp.success) return rsp.message;
          return null;

        case Drive.nfs:
          final rsp = await storage.cli.setDriveNFS(SetDriveNFSRequest(
            addr: targetData["url"]?.toString() ?? "",
            root: root,
            isMetaDrive: isMetaDrive,
          ));
          if (!rsp.success) return rsp.message;
          return null;
      }
    } catch (e) {
      return e.toString();
    }
  }

  /// 测试配置的连通性，成功返回 null，失败返回错误原因
  Future<String?> testConnection() async {
    final primaryErr =
        await _testSingleDrive(drive, data, isMetaDrive: false);
    if (primaryErr != null) return primaryErr;

    if (metaEnabled && metaDrive != null && metaData != null) {
      final metaErr =
          await _testSingleDrive(metaDrive!, metaData!, isMetaDrive: true);
      if (metaErr != null) return metaErr;
    }
    return null;
  }

  static Future<void> _saveDriveDataToPrefs(
      SharedPreferences prefs, Drive targetDrive, Map<String, dynamic> targetData,
      {String prefix = ''}) async {
    await prefs.setString("${prefix}drive", driveName[targetDrive]!);
    switch (targetDrive) {
      case Drive.webDav:
        await prefs.setString('${prefix}webdav_url', targetData["url"]?.toString() ?? "");
        await prefs.setString('${prefix}webdav_username', targetData["username"]?.toString() ?? "");
        await prefs.setString('${prefix}webdav_password', targetData["password"]?.toString() ?? "");
        await prefs.setString('${prefix}webdav_root_path', targetData["rootPath"]?.toString() ?? "");
        await prefs.setBool('${prefix}webdav_insecure', targetData["insecure"] == true);
        break;
      case Drive.smb:
        await prefs.setString('${prefix}addr', targetData["addr"]?.toString() ?? "");
        await prefs.setString('${prefix}username', targetData["username"]?.toString() ?? "");
        await prefs.setString('${prefix}password', targetData["password"]?.toString() ?? "");
        await prefs.setString('${prefix}share', targetData["share"]?.toString() ?? "");
        await prefs.setString('${prefix}rootPath', targetData["rootPath"]?.toString() ?? "");
        break;
      case Drive.nfs:
        await prefs.setString('${prefix}nfs_url', targetData["url"]?.toString() ?? "");
        await prefs.setString('${prefix}nfs_root_path', targetData["rootPath"]?.toString() ?? "");
        break;
    }
  }

  /// 写入本地 SharedPreferences 并立即生效
  Future<void> saveToPrefsAndApply([SharedPreferences? sharedPrefs]) async {
    final prefs = sharedPrefs ?? await SharedPreferences.getInstance();
    await _saveDriveDataToPrefs(prefs, drive, data);
    await prefs.setBool(
        'meta_drive_enabled', metaEnabled && metaDrive != null && metaData != null);
    if (metaEnabled && metaDrive != null && metaData != null) {
      await _saveDriveDataToPrefs(prefs, metaDrive!, metaData!, prefix: 'meta_');
    }
    await initDrive();
  }

  static String _formatSummary(Drive d, Map<String, dynamic> m) {
    switch (d) {
      case Drive.webDav:
        return m["url"]?.toString() ?? "";
      case Drive.smb:
        final addr = m["addr"]?.toString() ?? "";
        final share = m["share"]?.toString() ?? "";
        return "$addr/$share";
      case Drive.nfs:
        return m["url"]?.toString() ?? "";
    }
  }

  /// 获取用于 UI 展示的摘要信息
  String get summary => _formatSummary(drive, data);

  /// 获取副存储用于 UI 展示的摘要信息
  String? get metaSummary =>
      (metaEnabled && metaDrive != null && metaData != null)
          ? _formatSummary(metaDrive!, metaData!)
          : null;

  /// 获取副存储用于 UI 展示的根路径
  String? get metaRootPath => metaData?["rootPath"]?.toString();

  /// 获取用于 UI 展示的用户名
  String? get username {
    return data["username"]?.toString();
  }

  /// 获取用于 UI 展示的根路径
  String? get rootPath {
    return data["rootPath"]?.toString();
  }
}
