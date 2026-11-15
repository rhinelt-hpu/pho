import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/run_server.dart';
import 'package:img_syncer/sync_timer.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:img_syncer/cache/thumbnail_cache.dart';
import 'package:img_syncer/logger/log_sync.dart';
import 'event_bus.dart';

String httpBaseUrl = "http://127.0.0.1:10001";
int grpcPort = 10000;
int httpPort = 10001;
bool useRemoteServer = false;
bool isDebug = false;

Color? seedColor;

/// 启动耗时埋点的计时原点，首次 [startupLog] 调用时初始化（≈ Dart main 进入时刻）。
final DateTime startupOrigin = DateTime.now();

/// 启动耗时埋点，统一 `startup:` 前缀，例如 `startup: firstFrame +123ms`。
/// 只依赖进程内 [DateTime.now]，不需要原生配合；日志会被日志同步功能上传远端。
void startupLog(String stage) {
  final elapsed = DateTime.now().difference(startupOrigin).inMilliseconds;
  logger.addLog('startup: $stage +${elapsed}ms');
}

class Global {
  static Future<void>? _startupFuture;

  /// 可重入启动入口：并发或重复调用共享同一个 Future，Go server 只会启动一次。
  /// 首帧之后调用；`checkServer()` 也通过它等待启动完成，而不是自己再 runServer。
  static Future<void> ensureStarted() {
    final existing = _startupFuture;
    if (existing != null) {
      return existing;
    }
    final future = _startup();
    _startupFuture = future;
    return future;
  }

  /// 主 isolate 的启动流程是否已被发起（headless 后台 isolate 里恒为 false）
  static bool get isStarting => _startupFuture != null;

  /// 兼容旧调用点，等价于 [ensureStarted]。
  static Future<void> init() => ensureStarted();

  /// 启动流程外壳：异常不外抛（首帧已渲染，必须能进入主界面），只记录日志。
  static Future<void> _startup() async {
    try {
      await _initOnce();
    } catch (e) {
      logger.addLog("startup: global init failed: $e");
    } finally {
      startupLog('global init end');
      // 首帧已渲染后才走到这里；日志同步内部自己读 prefs，不 await 以免拖慢启动
      unawaited(LogSyncer.instance.ensureStarted());
    }
  }

  static Future<void> _initOnce() async {
    startupLog('global init start');
    assert(() {
      if (!Platform.isIOS) {
        isDebug = true;
      }
      return true;
    }());
    final portsStr = await runServer();
    final ports = portsStr.split(",");
    if (ports.length != 2) {
      logger.addLog("startup: grpc server start failed: $portsStr");
      return;
    }
    httpBaseUrl = "http://127.0.0.1:${ports[1]}";
    grpcPort = int.parse(ports[0]);
    httpPort = int.parse(ports[1]);
    storage = RemoteStorage("127.0.0.1", int.parse(ports[0]));
    if (useRemoteServer) {
      httpBaseUrl = "http://192.168.100.213:8000";
      storage = RemoteStorage("192.168.100.213", 50051);
    }
    lastAliveTime = DateTime.now();
    startupLog('server ready grpc=$grpcPort http=$httpPort');
    await ThumbnailCache.init();
    startupLog('local caches ready');

    final prefs = await SharedPreferences.getInstance();
    if (isDesktop()) {
      final galleryColumCount = prefs.getInt("galleryColumCount");
      if (galleryColumCount != null) {
        settingModel.setGalleryColumCount(galleryColumCount);
      } else {
        settingModel.setGalleryColumCount(10);
      }
      var enableEncrypt = prefs.getBool("enable_encrypt");
      // 从旧 key (enalble_encrypt) 迁移
      if (enableEncrypt == null) {
        enableEncrypt = prefs.getBool("enalble_encrypt");
        if (enableEncrypt != null) {
          prefs.setBool("enable_encrypt", enableEncrypt);
          prefs.remove("enalble_encrypt");
        }
      }
      if (enableEncrypt != null) {
        settingModel.setEncryptSwitch(enableEncrypt);
      }
      final encryptionType = prefs.getInt("encryption_type");
      if (encryptionType != null) {
        settingModel.setEncryptionType(EncryptionType.values[encryptionType]);
      }
      final encPassword = prefs.getString("encryption_password");
      if (encPassword != null) {
        settingModel.setEncryptionPassword(encPassword);
      }
      await settingModel.loadSettings(prefs);
      unawaited(initDrive());
      return;
    }
    var enableEncrypt = prefs.getBool("enable_encrypt");
    // 从旧 key (enalble_encrypt) 迁移
    if (enableEncrypt == null) {
      enableEncrypt = prefs.getBool("enalble_encrypt");
      if (enableEncrypt != null) {
        prefs.setBool("enable_encrypt", enableEncrypt);
        prefs.remove("enalble_encrypt");
      }
    }
    if (enableEncrypt != null) {
      settingModel.setEncryptSwitch(enableEncrypt);
    }
    final encryptionType = prefs.getInt("encryption_type");
    if (encryptionType != null) {
      settingModel.setEncryptionType(EncryptionType.values[encryptionType]);
    }
    final encPassword = prefs.getString("encryption_password");
    if (encPassword != null) {
      settingModel.setEncryptionPassword(encPassword);
    }
    final seedColorValue = prefs.getInt("seed_color");
    if (seedColorValue != null) {
      seedColor = Color(seedColorValue);
    }
    final galleryColumCount = prefs.getInt("galleryColumCount");
    if (galleryColumCount != null) {
      settingModel.setGalleryColumCount(galleryColumCount);
    }

    // 相册权限申请与相册枚举不在启动关键路径上做：相册页首帧后
    // AssetModel.getLocalPhotos() 会自己申请权限，并在 localFolder 为空时
    // 自动挑选照片最多的相册（Android 首次启动即走这条路径）。
    final localFolder = prefs.getString("localFolder");
    if (localFolder != null && localFolder.isNotEmpty) {
      settingModel.setLocalFolder(localFolder);
      eventBus.fire(LocalRefreshEvent(refreshUnSync: false));
    } else if (Platform.isIOS) {
      // iOS 的 Recents 是系统聚合相册，不需要枚举就能定下默认值
      settingModel.setLocalFolder("Recents");
      await prefs.setString("localFolder", "Recents");
      eventBus.fire(LocalRefreshEvent(refreshUnSync: true));
    }
    final lastRefreshUnsyncTime = prefs.getInt("last_refersh_unsync");
    if (lastRefreshUnsyncTime != null) {
      stateModel.updateLastRefreshUnsyncTime(
          DateTime.fromMillisecondsSinceEpoch(lastRefreshUnsyncTime));
    }
    await settingModel.loadSettings(prefs);
    await assetModel.loadTitleCache();
    await loadUnsynchronizedPhotos();
    unawaited(initDrive());
    reloadAutoSyncTimer();
  }
}

DateTime? lastAliveTime;
Future<void> checkServer() async {
  if (useRemoteServer) {
    return;
  }
  // Go server 还没起来（或正在启动）时只等同一个启动 Future，绝不再调一次
  // runServer()：否则会双开内核、并替换掉已连上的 storage/端口。
  // 后台 headless isolate 不会跑启动流程（isStarting == false），保持原 ping 语义。
  if (Global.isStarting) {
    await Global.ensureStarted();
  }
  if (useRemoteServer) {
    return;
  }
  if (lastAliveTime != null &&
      DateTime.now().difference(lastAliveTime!) < const Duration(seconds: 60)) {
    return;
  }
  try {
    await storage.cli.ping(PingRequest()).timeout(const Duration(seconds: 3));
    lastAliveTime = DateTime.now();
  } catch (e) {
    logger.addLog("ping 127.0.0.1:$grpcPort failed: $e");
    logger.addLog("reboot server");
    final portsStr = await runServer();
    final ports = portsStr.split(",");
    if (ports.length != 2) {
      logger.addLog("grpc server start failed");
      return;
    }
    httpBaseUrl = "http://127.0.0.1:${ports[1]}";
    grpcPort = int.parse(ports[0]);
    httpPort = int.parse(ports[1]);
    storage = RemoteStorage("127.0.0.1", int.parse(ports[0]));
    await initDrive();
    lastAliveTime = DateTime.now();
  }
}

Future<void>? _activeInitDriveFuture;

Future<void> initDrive() {
  if (_activeInitDriveFuture != null) {
    return _activeInitDriveFuture!;
  }
  final future = _doInitDrive();
  _activeInitDriveFuture = future;
  future.whenComplete(() {
    if (_activeInitDriveFuture == future) {
      _activeInitDriveFuture = null;
    }
    startupLog('initDrive end');
  });
  return future;
}

Future<void> _doInitDrive() async {
  try {
    final appDir = await getApplicationSupportDirectory();
    final manifestCacheDir = Directory(p.join(appDir.path, 'manifest'));
    if (!await manifestCacheDir.exists()) {
      await manifestCacheDir.create(recursive: true);
    }
    await storage.cli
        .setLocalCacheDir(SetLocalCacheDirRequest(path: manifestCacheDir.path))
        // 首个 gRPC 请求可能赶上 Go 内核 gomobile 通道预热，3s 会偶发超时
        .timeout(const Duration(seconds: 10));
  } catch (e) {
    logger.addLog("setLocalCacheDir: $e");
  }
  final prefs = await SharedPreferences.getInstance();
  var drive = prefs.getString("drive");
  drive ??= "SMB";
  bool primaryOk = false;
  try {
    switch (getDrive(drive)) {
      case Drive.smb:
        final addr = prefs.getString("addr");
        final username = prefs.getString("username");
        final password = prefs.getString("password");
        final share = prefs.getString("share");
        final root = prefs.getString("rootPath");
        if (addr != null &&
            addr.trim().isNotEmpty &&
            username != null &&
            password != null &&
            share != null &&
            share.trim().isNotEmpty &&
            root != null &&
            root.trim().isNotEmpty) {
          final rsp = await storage.cli
              .setDriveSMB(SetDriveSMBRequest(
                addr: addr,
                username: username,
                password: password,
                share: share,
                root: root,
              ))
              .timeout(const Duration(seconds: 12));
          if (rsp.success) {
            logger.addLog("set drive smb success");
            primaryOk = true;
          } else {
            assetModel.remoteLastError = rsp.message;
          }
        }
        break;
      case Drive.webDav:
        final url = prefs.getString('webdav_url');
        final username = prefs.getString('webdav_username');
        final password = prefs.getString('webdav_password');
        final root = prefs.getString('webdav_root_path');
        final insecure = prefs.getBool('webdav_insecure') ?? true;
        if (url != null &&
            url.trim().isNotEmpty &&
            root != null &&
            root.trim().isNotEmpty) {
          final rsp = await storage.cli
              .setDriveWebdav(SetDriveWebdavRequest(
                addr: url,
                username: username,
                password: password,
                root: root,
                insecure: insecure,
              ))
              .timeout(const Duration(seconds: 12));
          if (rsp.success) {
            logger.addLog("set drive webdav success");
            primaryOk = true;
          } else {
            assetModel.remoteLastError = rsp.message;
          }
        }
        break;
      case Drive.nfs:
        final addr = prefs.getString('nfs_url');
        final root = prefs.getString('nfs_root_path');
        if (addr != null &&
            addr.trim().isNotEmpty &&
            root != null &&
            root.trim().isNotEmpty) {
          final rsp = await storage.cli
              .setDriveNFS(SetDriveNFSRequest(
                addr: addr,
                root: root,
              ))
              .timeout(const Duration(seconds: 12));
          if (rsp.success) {
            logger.addLog("set drive nfs success");
            primaryOk = true;
          } else {
            assetModel.remoteLastError = rsp.message;
          }
        }
        break;
    }
  } catch (e) {
    logger.addLog("init primary drive failed: $e");
    assetModel.remoteLastError = e.toString();
  }

  if (!primaryOk) {
    settingModel.setRemoteStorageSetted(false);
    return;
  }

  final metaEnabled = prefs.getBool('meta_drive_enabled') ?? false;
  if (!metaEnabled) {
    try {
      await storage.cli
          .clearMetaDrive(ClearMetaDriveRequest())
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    settingModel.setRemoteStorageSetted(true);
    eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
    return;
  }

  final metaDriveStr = prefs.getString('meta_drive') ?? 'WebDAV';
  bool metaOk = false;
  try {
    switch (getDrive(metaDriveStr)) {
      case Drive.smb:
        final addr = prefs.getString("meta_addr");
        final username = prefs.getString("meta_username") ?? "";
        final password = prefs.getString("meta_password") ?? "";
        final share = prefs.getString("meta_share");
        final root = prefs.getString("meta_rootPath");
        if (addr != null &&
            addr.trim().isNotEmpty &&
            share != null &&
            share.trim().isNotEmpty &&
            root != null &&
            root.trim().isNotEmpty) {
          final rsp = await storage.cli
              .setDriveSMB(SetDriveSMBRequest(
                addr: addr,
                username: username,
                password: password,
                share: share,
                root: root,
                isMetaDrive: true,
              ))
              .timeout(const Duration(seconds: 12));
          if (rsp.success) {
            logger.addLog("set meta drive smb success");
            metaOk = true;
          } else {
            assetModel.remoteLastError = rsp.message;
          }
        }
        break;
      case Drive.webDav:
        final url = prefs.getString('meta_webdav_url');
        final username = prefs.getString('meta_webdav_username') ?? "";
        final password = prefs.getString('meta_webdav_password') ?? "";
        final root = prefs.getString('meta_webdav_root_path');
        final insecure = prefs.getBool('meta_webdav_insecure') ?? true;
        if (url != null &&
            url.trim().isNotEmpty &&
            root != null &&
            root.trim().isNotEmpty) {
          final rsp = await storage.cli
              .setDriveWebdav(SetDriveWebdavRequest(
                addr: url,
                username: username,
                password: password,
                root: root,
                insecure: insecure,
                isMetaDrive: true,
              ))
              .timeout(const Duration(seconds: 12));
          if (rsp.success) {
            logger.addLog("set meta drive webdav success");
            metaOk = true;
          } else {
            assetModel.remoteLastError = rsp.message;
          }
        }
        break;
      case Drive.nfs:
        final addr = prefs.getString('meta_nfs_url');
        final root = prefs.getString('meta_nfs_root_path');
        if (addr != null &&
            addr.trim().isNotEmpty &&
            root != null &&
            root.trim().isNotEmpty) {
          final rsp = await storage.cli
              .setDriveNFS(SetDriveNFSRequest(
                addr: addr,
                root: root,
                isMetaDrive: true,
              ))
              .timeout(const Duration(seconds: 12));
          if (rsp.success) {
            logger.addLog("set meta drive nfs success");
            metaOk = true;
          } else {
            assetModel.remoteLastError = rsp.message;
          }
        }
        break;
    }
  } catch (e) {
    logger.addLog("init meta drive failed: $e");
    assetModel.remoteLastError = e.toString();
  }

  if (metaOk) {
    settingModel.setRemoteStorageSetted(true);
    eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
  } else {
    settingModel.setRemoteStorageSetted(false);
  }
}

class SnackBarManager {
  static final SnackBarManager _instance = SnackBarManager._internal();

  factory SnackBarManager() {
    return _instance;
  }

  SnackBarManager._internal();

  static BuildContext? globalContext;

  static void init(BuildContext context) {
    globalContext = context;
  }

  static void showSnackBar(String message) {
    if (globalContext != null) {
      ScaffoldMessenger.of(globalContext!).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }
}

late AppLocalizations l10n;

void initI18n(BuildContext context) {
  l10n = AppLocalizations.of(context)!;
}

Completer<bool>? requesttingPermission;
BuildContext? requestPermissionContext;
void initRequestPermission(BuildContext context) {
  requestPermissionContext = context;
}

Future<bool> requestPermission({alert = true}) async {
  if (isDesktop()) {
    return true;
  }
  bool result = false;
  if (requesttingPermission != null) {
    result = await requesttingPermission!.future;
    return result;
  }
  requesttingPermission = Completer<bool>();
  //权限申请
  final PermissionState ps = await PhotoManager.requestPermissionExtend();
  if (ps == PermissionState.authorized) {
    result = true;
  } else {
    if (alert) {
      result = false;
      if (requestPermissionContext != null) {
        showDialog(
            context: requestPermissionContext!,
            builder: (BuildContext context) => AlertDialog(
                  title: Text(l10n.needPermision),
                  content: Text(l10n.gotoSystemSetting),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () {
                        PhotoManager.openSetting();
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.openSetting),
                    ),
                  ],
                ));
      }
    }
  }
  requesttingPermission?.complete(result);
  requesttingPermission = null;
  return result;
}
