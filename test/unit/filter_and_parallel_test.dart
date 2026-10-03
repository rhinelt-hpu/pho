import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/sync/background_runner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAsset extends Asset {
  final bool _isVideo;
  final DateTime _dateCreated;

  _FakeAsset({
    required bool isVideo,
    required DateTime dateCreated,
    required String title,
  })  : _isVideo = isVideo,
        _dateCreated = dateCreated,
        super(local: null, remote: null) {
    hasLocal = true;
    localTitle = title;
  }

  @override
  bool isVideo() => _isVideo;

  @override
  DateTime dateCreated() => _dateCreated;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingModel 并发上传调优 (Parallel Upload Tuning)', () {
    late SettingModel sm;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sm = SettingModel();
    });

    test('默认并发数为 3', () {
      expect(sm.parallelCount, 3);
      expect(sm.paralleUploadCount, 3);
    });

    test('设置并发数在 1~8 范围内有效', () {
      sm.setParallelCount(4);
      expect(sm.parallelCount, 4);
      expect(sm.paralleUploadCount, 4);

      sm.paralleUploadCount = 8;
      expect(sm.parallelCount, 8);
    });

    test('并发数小于 1 时截断为 1，大于 8 时截断为 8', () {
      sm.setParallelCount(0);
      expect(sm.parallelCount, 1);

      sm.setParallelCount(-5);
      expect(sm.parallelCount, 1);

      sm.setParallelCount(9);
      expect(sm.parallelCount, 8);

      sm.setParallelCount(100);
      expect(sm.parallelCount, 8);
    });

    test('并发数通知监听器', () {
      var notified = false;
      sm.addListener(() {
        notified = true;
      });

      sm.setParallelCount(5);
      expect(notified, isTrue);

      // 设置相同值不重复触发 notify
      notified = false;
      sm.setParallelCount(5);
      expect(notified, isFalse);
    });

    test('并发数持久化与从 SharedPreferences 恢复', () async {
      final prefs = await SharedPreferences.getInstance();
      sm.setParallelCount(6);
      await sm.saveSettings();

      expect(prefs.getInt('parallel_count'), 6);

      final sm2 = SettingModel();
      await sm2.loadSettings(prefs);
      expect(sm2.parallelCount, 6);
    });
  });

  group('SettingModel 文件筛选器模型 (File Filter Model)', () {
    late SettingModel sm;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      sm = SettingModel();
    });

    test('筛选器默认全为关闭/未配置', () {
      expect(sm.filterSwitch, isFalse);
      expect(sm.enableFilter, isFalse);
      expect(sm.filterNoVideo, isFalse);
      expect(sm.filterNoImage, isFalse);
      expect(sm.filterAfter, isNull);
      expect(sm.filterBefore, isNull);
      expect(sm.filterTypeMap, isEmpty);
    });

    test('enableFilter 别名双向绑定', () {
      sm.enableFilter = true;
      expect(sm.filterSwitch, isTrue);
      expect(sm.enableFilter, isTrue);

      sm.setFilterSwitch(false);
      expect(sm.enableFilter, isFalse);
    });

    test('setFilterType 格式规整化（支持带点和不带点）', () {
      sm.setFilterType('mp4', false);
      expect(sm.filterTypeMap['.mp4'], isFalse);

      sm.setFilterType('.GIF', false);
      expect(sm.filterTypeMap['.gif'], isFalse);

      sm.setFilterType('.png', true);
      expect(sm.filterTypeMap['.png'], isTrue);
    });

    test('resetFilters 重置所有状态并通知', () {
      sm.setFilterSwitch(true);
      sm.setFilterNoVideo(true);
      sm.setFilterNoImage(true);
      sm.setFilterAfter(DateTime(2025, 1, 1));
      sm.setFilterBefore(DateTime(2025, 12, 31));
      sm.setFilterType('gif', false);

      var notified = false;
      sm.addListener(() {
        notified = true;
      });

      sm.resetFilters();
      expect(notified, isTrue);
      expect(sm.filterSwitch, isFalse);
      expect(sm.filterNoVideo, isFalse);
      expect(sm.filterNoImage, isFalse);
      expect(sm.filterAfter, isNull);
      expect(sm.filterBefore, isNull);
      expect(sm.filterTypeMap, isEmpty);
    });

    test('筛选器设置持久化到 SharedPreferences 并正确恢复', () async {
      final prefs = await SharedPreferences.getInstance();
      sm.setFilterSwitch(true);
      sm.setFilterNoVideo(true);
      sm.setFilterNoImage(false);
      sm.setFilterAfter(DateTime(2024, 3, 15));
      sm.setFilterBefore(DateTime(2024, 10, 20));
      sm.setFilterType('.raw', false);

      await sm.saveSettings();

      expect(prefs.getBool('filter_switch'), isTrue);
      expect(prefs.getBool('filter_no_video'), isTrue);
      expect(prefs.getBool('filter_no_image'), isFalse);
      expect(prefs.getInt('filter_after'), DateTime(2024, 3, 15).millisecondsSinceEpoch);
      expect(prefs.getInt('filter_before'), DateTime(2024, 10, 20).millisecondsSinceEpoch);
      expect(prefs.getString('filter_type_map'), contains('.raw'));

      final sm2 = SettingModel();
      await sm2.loadSettings(prefs);

      expect(sm2.filterSwitch, isTrue);
      expect(sm2.filterNoVideo, isTrue);
      expect(sm2.filterNoImage, isFalse);
      expect(sm2.filterAfter, DateTime(2024, 3, 15));
      expect(sm2.filterBefore, DateTime(2024, 10, 20));
      expect(sm2.filterTypeMap['.raw'], isFalse);
    });
  });

  group('shouldSyncAsset 综合过滤判定', () {
    late SettingModel oldSettingModel;

    setUp(() {
      oldSettingModel = settingModel;
      settingModel = SettingModel();
    });

    tearDown(() {
      settingModel = oldSettingModel;
    });

    test('已上传的资源始终返回 false', () {
      final asset = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2025, 1, 1),
        title: 'photo.jpg',
      );
      expect(shouldSyncAsset(asset, 'id_1', {'id_1': true}, '.jpg'), isFalse);
      expect(shouldSyncAsset(asset, 'id_2', {'id_1': true}, '.jpg'), isTrue);
    });

    test('筛选器未开启时全部通过', () {
      settingModel.filterSwitch = false;
      settingModel.filterNoVideo = true;
      settingModel.filterNoImage = true;
      settingModel.filterAfter = DateTime(2099, 1, 1);
      settingModel.filterTypeMap['.jpg'] = false;

      final video = _FakeAsset(
        isVideo: true,
        dateCreated: DateTime(2020, 1, 1),
        title: 'video.mp4',
      );
      expect(shouldSyncAsset(video, 'v1', {}, '.mp4'), isTrue);

      final photo = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2020, 1, 1),
        title: 'photo.jpg',
      );
      expect(shouldSyncAsset(photo, 'p1', {}, '.jpg'), isTrue);
    });

    test('扩展名过滤支持带点与不带点匹配', () {
      settingModel.setFilterSwitch(true);
      settingModel.setFilterType('.heic', false);

      final heic1 = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2025, 1, 1),
        title: 'img.heic',
      );
      // 传入带点扩展名
      expect(shouldSyncAsset(heic1, 'h1', {}, '.heic'), isFalse);
      // 传入不带点扩展名
      expect(shouldSyncAsset(heic1, 'h1', {}, 'heic'), isFalse);
      // 传入大写扩展名
      expect(shouldSyncAsset(heic1, 'h1', {}, '.HEIC'), isFalse);

      // 其他未排除扩展名通过
      final png = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2025, 1, 1),
        title: 'img.png',
      );
      expect(shouldSyncAsset(png, 'p1', {}, '.png'), isTrue);
    });

    test('日期边界过滤（起始与截止日期）', () {
      settingModel.setFilterSwitch(true);
      settingModel.setFilterAfter(DateTime(2024, 6, 10));
      settingModel.setFilterBefore(DateTime(2024, 6, 20));

      final beforeRange = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2024, 6, 9),
        title: 'old.jpg',
      );
      expect(shouldSyncAsset(beforeRange, '1', {}, '.jpg'), isFalse);

      final inRange = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2024, 6, 15),
        title: 'mid.jpg',
      );
      expect(shouldSyncAsset(inRange, '2', {}, '.jpg'), isTrue);

      final atStartDate = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2024, 6, 10),
        title: 'start.jpg',
      );
      // 同日不属于 isBefore(filterAfter)
      expect(shouldSyncAsset(atStartDate, '3', {}, '.jpg'), isTrue);

      final atEndDate = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2024, 6, 20),
        title: 'end.jpg',
      );
      // 同日不属于 isAfter(filterBefore)
      expect(shouldSyncAsset(atEndDate, '4', {}, '.jpg'), isTrue);

      final afterRange = _FakeAsset(
        isVideo: false,
        dateCreated: DateTime(2024, 6, 21),
        title: 'new.jpg',
      );
      expect(shouldSyncAsset(afterRange, '5', {}, '.jpg'), isFalse);
    });
  });
}
