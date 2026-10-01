import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    logger.setEnabled(false);
    logger.cleanHistory();
  });

  group('Talker & Debug Mode Unit Tests', () {
    test('Initial debugMode is false and Talker is disabled', () {
      final model = SettingModel();
      expect(model.debugMode, false);
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
      expect(talker.history[0].logLevel, LogLevel.info);
      expect(talker.history[1].logLevel, LogLevel.warning);
      expect(talker.history[2].logLevel, LogLevel.error);

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
  });
}
