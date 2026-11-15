import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:mockito/mockito.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/remote_storage_mock.mocks.dart';
import 'mocks/test_doubles.dart';

/// 创建一个模拟响应流，用于测试 receiveResponses。
Stream<T> _mockResponseStream<T>(List<T> items) async* {
  for (final item in items) {
    yield item;
  }
}

AssetEntity _entity(String id) => AssetEntity(
      id: id,
      typeInt: 1,
      width: 100,
      height: 100,
      createDateSecond: DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
      modifiedDateSecond: DateTime(2026, 1, 1).millisecondsSinceEpoch ~/ 1000,
      title: '$id.jpg',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('receiveResponses 两阶段提交', () {
    late StateModel state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = StateModel();
    });

    test('accumulatedIDs 模式仅积累不写入 syncedIDs', () async {
      // 预置一些旧的 syncedIDs
      state.setSyncedPhotos(['old_id_1', 'old_id_2']);
      final preAccumulate = List<String>.from(state.syncedIDs);

      final accumulatedIDs = <String>[];
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['new_id_1', 'new_id_2'],
        ),
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['new_id_3'],
        ),
      ]);

      await receiveResponses(stream, accumulatedIDs: accumulatedIDs);

      // syncedIDs 应保持旧值未被修改
      expect(state.syncedIDs, preAccumulate);
      // accumulatedIDs 应包含所有新 ID
      expect(accumulatedIDs, containsAll(['new_id_1', 'new_id_2', 'new_id_3']));
      expect(accumulatedIDs.length, 3);
    });

    test('accumulatedIDs 模式重复 ID 正常追加（去重在 setSyncedPhotos 调用方执行）', () async {
      state.setSyncedPhotos(['old_1']);
      final accumulatedIDs = <String>[];
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['dup_id', 'dup_id', 'unique_id'],
        ),
      ]);

      await receiveResponses(stream, accumulatedIDs: accumulatedIDs);

      // 积累阶段不去重，由调用方处理
      expect(accumulatedIDs.length, 3);
    });

    test('accumulatedIDs 模式遇到错误时不中断，继续处理后续响应', () async {
      state.setSyncedPhotos(['old']);
      final accumulatedIDs = <String>[];
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: false,
          message: 'simulated error',
        ),
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['ok_id'],
        ),
      ]);

      await receiveResponses(stream, accumulatedIDs: accumulatedIDs);

      expect(state.syncedIDs, ['old']);
      expect(accumulatedIDs, ['ok_id']);
    });
  });

  group('receiveResponses 去重模式', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // 直接操作顶层单例 stateModel（receiveResponses 内部引用的是它）
      stateModel.setSyncedPhotos([]);
    });

    test('无 accumulatedIDs 时直接写入并自动去重', () async {
      stateModel.setSyncedPhotos(['existing_1']);
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['existing_1', 'existing_1', 'new_2'],
        ),
      ]);

      await receiveResponses(stream);

      // 应通过 Set 去重
      final ids = stateModel.syncedIDs;
      expect(ids.toSet().length, ids.length);
      expect(ids, containsAll(['existing_1', 'new_2']));
    });

    test('多次响应累计写入并去重', () async {
      stateModel.setSyncedPhotos([]);
      final stream = _mockResponseStream([
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['id_a', 'id_b'],
        ),
        FilterNotUploadedResponse(
          success: true,
          uploadedIDs: ['id_b', 'id_c'],
        ),
      ]);

      await receiveResponses(stream);

      final ids = stateModel.syncedIDs;
      expect(ids.toSet().length, 3);
      expect(ids, containsAll(['id_a', 'id_b', 'id_c']));
    });
  });

  group('syncedIDs 去重逻辑', () {
    late StateModel state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = StateModel();
    });

    test('setSyncedPhotos 后通过 toSet 去重', () {
      final idsWithDup = ['a', 'b', 'a', 'c', 'b'];
      state.setSyncedPhotos(idsWithDup.toSet().toList());
      expect(state.syncedIDs.length, 3);
      expect(state.syncedIDs.toSet().length, 3);
    });
  });

  group('isSynced 与 syncedIDs 集合一致性', () {
    late StateModel state;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      state = StateModel();
    });

    tearDown(() async {
      // 取消防抖计时器，避免测试结束后仍有 pending timer
      await state.saveSyncedIDs();
    });

    test('setSyncedPhotos 后 isSynced 同步更新', () {
      state.setSyncedPhotos(['a', 'b']);
      expect(state.isSynced('a'), isTrue);
      expect(state.isSynced('b'), isTrue);
      expect(state.isSynced('c'), isFalse);
      expect(state.syncedIDs, ['a', 'b']);
    });

    test('finishUpload 成功时写入集合，重复 id 不重复追加', () {
      state.setSyncedPhotos(['a']);
      state.finishUpload('b', true);
      state.finishUpload('b', true);
      expect(state.syncedIDs, ['a', 'b']);
      expect(state.isSynced('b'), isTrue);
    });

    test('finishUpload 失败时不计入已上传', () {
      state.finishUpload('c', false);
      expect(state.isSynced('c'), isFalse);
      expect(state.syncedIDs, isEmpty);
    });

    test('removeSyncedPhotos 同时清理 list 与 set', () {
      state.setSyncedPhotos(['a', 'b']);
      state.removeSyncedPhotos(['a']);
      expect(state.isSynced('a'), isFalse);
      expect(state.syncedIDs, ['b']);
    });

    test('markSynced 追加去重并通知监听器', () {
      state.setSyncedPhotos(['a']);
      var notified = 0;
      state.addListener(() => notified++);
      state.markSynced(['a', 'b', 'b']);
      expect(state.syncedIDs, ['a', 'b']);
      expect(state.isSynced('b'), isTrue);
      expect(notified, 1);

      // 全部已存在时不重复通知
      state.markSynced(['a', 'b']);
      expect(notified, 1);
      expect(state.syncedIDs, ['a', 'b']);
    });
  });

  group('checkRemoteUploaded 上传前远端确认', () {
    late StateModel state;
    late SettingModel oldSettingModel;
    late RemoteStorage oldStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockPhotoManagerChannel();
      oldSettingModel = settingModel;
      oldStorage = storage;
      settingModel = SettingModel();
      settingModel.isRemoteStorageSetted = true;
      state = StateModel();
    });

    tearDown(() {
      resetPhotoManagerChannel();
      settingModel = oldSettingModel;
      setStorageForTest(oldStorage);
    });

    test('只发送传入的 entity，并返回其中远端已有的 id', () async {
      final cli = FakeImgSyncerClient(['photo_1', 'unknown_photo']);
      final mockStorage = MockRemoteStorageClient();
      when(mockStorage.cli).thenReturn(cli);
      setStorageForTest(mockStorage);

      final result = await state
          .checkRemoteUploaded([_entity('photo_1'), _entity('photo_2')]);

      // 只保留属于本次请求的 id
      expect(result, {'photo_1'});
      // 请求按 100 条一批切分，这里两张一批即可
      expect(cli.sentRequests.length, 1);
      expect(cli.sentRequests.first.photos.map((p) => p.id).toList(),
          ['photo_1', 'photo_2']);
    });

    test('超过 100 条时按批发送', () async {
      final cli = FakeImgSyncerClient(['photo_0']);
      final mockStorage = MockRemoteStorageClient();
      when(mockStorage.cli).thenReturn(cli);
      setStorageForTest(mockStorage);

      await state
          .checkRemoteUploaded(List.generate(101, (i) => _entity('photo_$i')));

      expect(cli.sentRequests.length, 2);
      expect(cli.sentRequests.first.photos.length, 100);
      expect(cli.sentRequests.last.photos.length, 1);
    });

    test('远端调用异常时返回空集合（视为不确定，继续上传）', () async {
      // 未 stub cli，调用会抛异常
      setStorageForTest(MockRemoteStorageClient());

      final result = await state.checkRemoteUploaded([_entity('photo_1')]);

      expect(result, isEmpty);
    });

    test('远端未配置时直接返回空集合', () async {
      settingModel.isRemoteStorageSetted = false;
      setStorageForTest(MockRemoteStorageClient());

      final result = await state.checkRemoteUploaded([_entity('photo_1')]);

      expect(result, isEmpty);
    });

    test('空输入不发起调用', () async {
      setStorageForTest(MockRemoteStorageClient());

      expect(await state.checkRemoteUploaded([]), isEmpty);
    });
  });
}
