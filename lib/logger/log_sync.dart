import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 是否自动把本机日志同步到副存储（默认开启）
const String kLogSyncEnabledPref = 'log_sync_enabled';

/// 服务端把该相对路径写到副存储的 `.logs/` 下
String logRemotePath(String deviceId, String localFileName) =>
    '$deviceId/$localFileName';

/// 设备标识形如 `ios-a1b2c3`，只用于区分多台设备，不含任何硬件信息
String newLogDeviceId(String platformTag, {Random? random}) {
  final suffix = (random ?? Random()).nextInt(1 << 24).toRadixString(16);
  return '$platformTag-${suffix.padLeft(6, '0')}';
}

/// 定时把本地日志文件上传到远端 `.logs/` 目录，方便远程排查（如 iOS 冷启动耗时）。
class LogSyncer with WidgetsBindingObserver {
  LogSyncer._();

  static final LogSyncer instance = LogSyncer._();

  static const Duration interval = Duration(minutes: 10);
  static const String _deviceIdPref = 'log_device_id';

  bool _started = false;
  bool _busy = false;
  String? _deviceId;
  final Map<String, String> _uploadedSig = {};

  /// 每 10 分钟尝试一次；启动 30 秒后补一次，避开冷启动 I/O 高峰。
  /// flutter test 下不启动定时器（否则 testWidgets 会报 pending Timer）。
  Future<void> ensureStarted() async {
    if (_started || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    Timer.periodic(interval, (_) => uploadIfDue());
    Timer(const Duration(seconds: 30), uploadIfDue);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      logger.flushFileLogs();
    } else if (state == AppLifecycleState.resumed) {
      uploadIfDue();
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kLogSyncEnabledPref) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLogSyncEnabledPref, enabled);
    if (enabled) unawaited(uploadNow());
  }

  Future<void> uploadIfDue() async {
    if (_busy) return;
    if (!await isEnabled()) return;
    if (!settingModel.isRemoteStorageSetted) return;
    await uploadNow();
  }

  /// 返回本次实际上传的文件数
  Future<int> uploadNow() async {
    if (_busy) return 0;
    if (!await isEnabled() || !settingModel.isRemoteStorageSetted) return 0;
    _busy = true;
    try {
      final device = _deviceId ??= await _loadDeviceId();
      int uploaded = 0;
      for (final file in await logger.logFiles()) {
        final sig =
            '${file.lengthSync()}@${file.lastModifiedSync().millisecondsSinceEpoch}';
        if (_uploadedSig[file.path] == sig) continue;
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        final ok = await storage.uploadLog(
            logRemotePath(device, p.basename(file.path)), bytes);
        if (ok) {
          _uploadedSig[file.path] = sig;
          uploaded++;
        }
      }
      return uploaded;
    } catch (e) {
      logger.addLog('log sync failed: $e');
      return 0;
    } finally {
      _busy = false;
    }
  }

  Future<String> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdPref);
    if (id == null || id.isEmpty) {
      id = newLogDeviceId(Platform.operatingSystem);
      await prefs.setString(_deviceIdPref, id);
    }
    return id;
  }
}
