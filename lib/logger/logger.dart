import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:talker_flutter/talker_flutter.dart';

final talker = TalkerFlutter.init(
  settings: TalkerSettings(
    enabled: false,
    useHistory: true,
    maxHistoryItems: 1000,
  ),
);

final logger = LoggerService();

class LoggerService {
  final List<String> _logs = [];

  // 内存日志只保留 500 条，另落盘一份供远程排障（上传逻辑见 log_sync.dart）
  static const int _maxFileBytes = 2 << 20;
  Directory? _logDir;
  File? _logFile;
  Timer? _flushTimer;
  bool _flushing = false;
  final List<String> _pending = [];

  void setEnabled(bool enabled) {
    talker.configure(settings: talker.settings.copyWith(enabled: enabled));
  }

  bool get isEnabled => talker.settings.enabled;

  void addLog(String log) {
    final format = DateFormat("yyyy-MM-dd HH:mm:ss");
    final logStr = "[${format.format(DateTime.now())}] $log";
    _logs.add(logStr);
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    print(logStr);
    _pending.add(logStr);
    _scheduleFlush();

    if (talker.settings.enabled) {
      final lower = log.toLowerCase();
      if (lower.contains('fail') ||
          lower.contains('error') ||
          lower.contains('exception') ||
          lower.contains('fatal')) {
        talker.error(log);
      } else if (lower.contains('warn')) {
        talker.warning(log);
      } else {
        talker.info(log);
      }
    }
  }

  void handle(Object exception, [StackTrace? stackTrace, String? msg]) {
    if (talker.settings.enabled) {
      talker.handle(exception, stackTrace, msg);
    } else {
      addLog('Exception: $exception${msg != null ? " ($msg)" : ""}');
    }
  }

  void cleanHistory() {
    _logs.clear();
    talker.cleanHistory();
  }

  List<String> get logs => _logs;

  Future<Directory> _ensureLogDir() async {
    final cached = _logDir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/logs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    // 只保留最近 3 天，防止无限增长
    final cutoff = DateTime.now().subtract(const Duration(days: 3));
    await for (final f in dir.list()) {
      // 含翻页备份 <date>.log.1，否则 .1 会永久堆积
      if (f is File &&
          (f.path.endsWith('.log') || f.path.endsWith('.log.1')) &&
          (await f.lastModified()).isBefore(cutoff)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _logDir = dir;
    return dir;
  }

  Future<File> currentLogFile() async {
    final cached = _logFile;
    if (cached != null) return cached;
    final dir = await _ensureLogDir();
    final name = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final file = File('${dir.path}/$name.log');
    _logFile = file;
    return file;
  }

  /// 已落盘的日志文件，供自动上传远端使用
  Future<List<File>> logFiles() async {
    await flushFileLogs();
    final dir = await _ensureLogDir();
    final files = <File>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.log')) files.add(f);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  void _scheduleFlush() {
    // flutter test 下不建定时器，避免 testWidgets 报 pending Timer
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (_flushTimer != null) return;
    _flushTimer = Timer(const Duration(seconds: 2), () {
      _flushTimer = null;
      flushFileLogs();
    });
  }

  Future<void> flushFileLogs() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    final batch = List<String>.from(_pending);
    _pending.clear();
    try {
      var file = await currentLogFile();
      if (await file.exists() && await file.length() > _maxFileBytes) {
        // shortcut: 单日超限直接覆盖 .1 备份，不保留历史
        try {
          await file.rename('${file.path}.1');
        } catch (_) {}
        _logFile = null;
        file = await currentLogFile();
      }
      await file.writeAsString('${batch.join('\n')}\n',
          mode: FileMode.append, flush: true);
    } catch (_) {
      // 日志落盘失败不能影响业务逻辑
    } finally {
      _flushing = false;
    }
  }

  // Future<void> downloadLogs() async {
  //   final logs = _logs.join('\n');
  //   final directory = await getApplicationDocumentsDirectory();
  //   final file = File('${directory.path}/log.txt');
  //   await file.writeAsString(logs);
  // }
}

class LoggerRoute extends StatefulWidget {
  const LoggerRoute({Key? key}) : super(key: key);

  @override
  State<LoggerRoute> createState() => _LoggerRouteState();
}

class _LoggerRouteState extends State<LoggerRoute> {
  @override
  Widget build(BuildContext context) {
    return TalkerScreen(talker: talker);
  }
}
