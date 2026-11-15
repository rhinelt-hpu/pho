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

/// 日志级别。落盘前缀分别是 [D]/[I]/[W]/[E]。
enum LogLevel { debug, info, warn, error }

/// 落盘用的单字符级别标记
String logLevelTag(LogLevel level) {
  switch (level) {
    case LogLevel.debug:
      return 'D';
    case LogLevel.info:
      return 'I';
    case LogLevel.warn:
      return 'W';
    case LogLevel.error:
      return 'E';
  }
}

class LoggerService {
  final List<String> _logs = [];

  // 内存日志只保留 500 条，另落盘一份供远程排障（上传逻辑见 log_sync.dart）
  static const int _maxFileBytes = 2 << 20;
  Directory? _logDir;
  File? _logFile;
  Timer? _flushTimer;
  bool _flushing = false;
  final List<String> _pending = [];

  /// 「详细日志（DEBUG）」开关，来自 SharedPreferences `log_verbose`（默认 false）
  bool _verbose = false;

  /// 同类日志去重：同一 level+message 在窗口内只落盘一次，被压制的次数下次输出时标记 (xN)
  static const Duration _dedupWindow = Duration(seconds: 30);
  LogLevel? _lastLevel;
  String? _lastMessage;
  DateTime? _lastAt;
  int _suppressed = 0;

  void setEnabled(bool enabled) {
    talker.configure(settings: talker.settings.copyWith(enabled: enabled));
  }

  bool get isEnabled => talker.settings.enabled;

  /// 详细日志开关（DEBUG 是否落盘）
  bool get verbose => _verbose;
  void setVerbose(bool verbose) {
    _verbose = verbose;
  }

  /// DEBUG 只在「详细日志」或「调试模式」开启时落盘，INFO/WARN/ERROR 永远写
  bool get _debugEnabled => _verbose || isEnabled;

  void log(LogLevel level, String message) {
    if (level == LogLevel.debug && !_debugEnabled) return;

    final now = DateTime.now();
    final sameAsLast = _lastLevel == level && _lastMessage == message;
    if (sameAsLast &&
        _lastAt != null &&
        now.difference(_lastAt!) < _dedupWindow) {
      _suppressed++;
      return;
    }
    // 只有同一条消息再次出现时才附带被压制的次数
    final repeat = sameAsLast ? _suppressed : 0;
    _suppressed = 0;
    _lastLevel = level;
    _lastMessage = message;
    _lastAt = now;
    _emit(level, repeat > 0 ? '$message (x${repeat + 1})' : message);
  }

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warn(String message) => log(LogLevel.warn, message);
  void error(String message) => log(LogLevel.error, message);

  /// 兼容旧调用点：等价于 INFO
  void addLog(String log) => info(log);

  void _emit(LogLevel level, String message) {
    final format = DateFormat("yyyy-MM-dd HH:mm:ss");
    final logStr =
        "[${format.format(DateTime.now())}] [${logLevelTag(level)}] $message";
    _logs.add(logStr);
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    print(logStr);
    _pending.add(logStr);
    _scheduleFlush();
    _bridgeToTalker(level, message);
  }

  void _bridgeToTalker(LogLevel level, String message) {
    if (!talker.settings.enabled) return;
    switch (level) {
      case LogLevel.debug:
        talker.debug(message);
        break;
      case LogLevel.warn:
        talker.warning(message);
        break;
      case LogLevel.error:
        talker.error(message);
        break;
      case LogLevel.info:
        // 旧代码把级别写在文案里（addLog("xxx failed: ...")），继续按文案猜测级别
        final lower = message.toLowerCase();
        if (lower.contains('fail') ||
            lower.contains('error') ||
            lower.contains('exception') ||
            lower.contains('fatal')) {
          talker.error(message);
        } else if (lower.contains('warn')) {
          talker.warning(message);
        } else {
          talker.info(message);
        }
        break;
    }
  }

  void handle(Object exception, [StackTrace? stackTrace, String? msg]) {
    if (talker.settings.enabled) {
      talker.handle(exception, stackTrace, msg);
    } else {
      error('Exception: $exception${msg != null ? " ($msg)" : ""}');
    }
  }

  void cleanHistory() {
    _logs.clear();
    _lastLevel = null;
    _lastMessage = null;
    _lastAt = null;
    _suppressed = 0;
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
