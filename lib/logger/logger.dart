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
