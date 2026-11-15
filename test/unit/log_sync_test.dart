import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/logger/log_sync.dart';

void main() {
  group('LogSyncer 远端日志路径', () {
    test('远端路径为 <deviceId>/<localFileName>', () {
      expect(
        logRemotePath('ios-a1b2c3', '2026-11-15.log'),
        'ios-a1b2c3/2026-11-15.log',
      );
    });

    test('设备 ID 带平台前缀且固定 6 位十六进制后缀', () {
      final id = newLogDeviceId('android', random: Random(1));
      expect(id, startsWith('android-'));
      expect(id.length, 'android-'.length + 6);
    });

    test('设备 ID 可持久化复用（同随机种子生成稳定值）', () {
      expect(
        newLogDeviceId('ios', random: Random(42)),
        newLogDeviceId('ios', random: Random(42)),
      );
    });
  });
}
