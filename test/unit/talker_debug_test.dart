import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
// talker 也导出了名为 LogLevel 的枚举（logger.dart 自己也定义了一份），
// 这里用前缀引用，避免两边的 LogLevel 撞名。
import 'package:talker/talker.dart' as talker_api;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    logger.setEnabled(false);
    logger.setVerbose(false);
    logger.cleanHistory();
  });

  group('Talker & Debug Mode Unit Tests', () {
    test('Initial debugMode is false and Talker is disabled', () {
      final model = SettingModel();
      expect(model.debugMode, false);
      expect(model.logVerbose, false);
      expect(logger.isEnabled, false);
      expect(talker.settings.enabled, false);
    });

    test('Toggling debugMode on SettingModel updates Talker enabled state', () {
      final model = SettingModel();
      model.setDebugMode(true);
      expect(model.debugMode, true);
      expect(logger.isEnabled, true);
      expect(talker.settings.enabled, true);

      model.setDebugMode(false);
      expect(model.debugMode, false);
      expect(logger.isEnabled, false);
      expect(talker.settings.enabled, false);
    });

    test('logger.addLog bridges to Talker only when enabled', () {
      logger.setEnabled(false);
      logger.addLog('Ignored debug log');
      expect(talker.history.length, 0);

      logger.setEnabled(true);
      logger.addLog('Info level message');
      logger.addLog('Warning: high disk usage');
      logger.addLog('Error: connection failed 500');

      expect(talker.history.length, 3);
      expect(talker.history[0].logLevel, talker_api.LogLevel.info);
      expect(talker.history[1].logLevel, talker_api.LogLevel.warning);
      expect(talker.history[2].logLevel, talker_api.LogLevel.error);

      logger.cleanHistory();
      expect(talker.history.length, 0);
      expect(logger.logs.length, 0);
    });

    test('loadSettings and saveSettings persist debugMode across sessions', () async {
      SharedPreferences.setMockInitialValues({'debug_mode': true});
      final prefs = await SharedPreferences.getInstance();
      final model = SettingModel();
      await model.loadSettings(prefs);

      expect(model.debugMode, true);
      expect(logger.isEnabled, true);
      expect(talker.settings.enabled, true);

      model.setDebugMode(false);
      await model.saveSettings();
      expect(prefs.getBool('debug_mode'), false);
    });

    test('log_verbose 落盘并在 loadSettings 中恢复', () async {
      SharedPreferences.setMockInitialValues({'log_verbose': true});
      final prefs = await SharedPreferences.getInstance();
      final model = SettingModel();
      await model.loadSettings(prefs);

      expect(model.logVerbose, true);
      expect(logger.verbose, true);

      model.setLogVerbose(false);
      expect(logger.verbose, false);
      await model.saveSettings();
      expect(prefs.getBool('log_verbose'), false);
    });
  });

  group('日志级别 / 前缀 / 去重', () {
    test('落盘行为 [时间] [级别] message，addLog 等价 INFO', () {
      logger.addLog('legacy line');
      expect(logger.logs.length, 1);
      expect(
        logger.logs.last,
        matches(RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[I\] legacy line$')),
      );
    });

    test('INFO/WARN/ERROR 永远写；DEBUG 默认丢弃，verbose 打开后写入', () {
      logger.info('i1');
      logger.warn('w1');
      logger.error('e1');
      logger.debug('d1');
      expect(logger.logs.length, 3);
      expect(logger.logs[0], contains('] [I] i1'));
      expect(logger.logs[1], contains('] [W] w1'));
      expect(logger.logs[2], contains('] [E] e1'));
      expect(logger.logs.where((l) => l.contains('] [D]')).isEmpty, true);

      logger.setVerbose(true);
      logger.debug('d2');
      expect(logger.logs.last, contains('] [D] d2'));
    });

    test('debugMode 打开时 DEBUG 也写（等价 verbose）', () {
      logger.setEnabled(true);
      logger.debug('d3');
      expect(logger.logs.last, contains('] [D] d3'));
    });

    test('同一 level+message 在 30 秒内只写一条', () {
      logger.info('refresh remote');
      logger.info('refresh remote');
      logger.info('refresh remote');
      expect(logger.logs.length, 1);

      // 不同消息正常写入
      logger.info('refresh local');
      expect(logger.logs.length, 2);

      // 再回到旧消息：距上次写入仍在窗口内，但已换了消息，
      // 简单实现下会再写一条（不串扰上一条的抑制计数）
      logger.info('refresh remote');
      expect(logger.logs.length, 3);
      expect(logger.logs.last, contains('refresh remote'));
      expect(logger.logs.last, isNot(contains('(x')));
    });

    test('level 不同则不去重', () {
      logger.warn('same text');
      logger.error('same text');
      expect(logger.logs.length, 2);
    });
  });
}
