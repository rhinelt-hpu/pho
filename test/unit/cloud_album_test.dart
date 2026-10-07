import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/storage/storage_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cross_file/cross_file.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:img_syncer/global.dart';

class MockAlbumRemoteStorage implements RemoteStorageClient {
  List<AlbumInfo> albums = [
    AlbumInfo(name: '相机备份', count: Int64(12), isDefault: true),
    AlbumInfo(name: '日本旅行 2026', count: Int64(5), isDefault: false),
  ];
  List<RemoteImage> returnedImages = [];
  String lastQueriedAlbum = '';
  List<String> lastMovedPaths = [];
  String lastTargetAlbum = '';

  @override
  ImgSyncerClient get cli => throw UnimplementedError();

  @override
  Future<void> uploadXFile(XFile file, {String album = ""}) async {}

  @override
  Future<void> uploadAssetEntity(AssetEntity asset, {String album = ""}) async {}

  @override
  Future<List<RemoteImage>> listImages(String date, int offset, maxReturn, {String album = ""}) async {
    lastQueriedAlbum = album;
    return returnedImages;
  }

  @override
  Future<List<AlbumInfo>> listAlbums() async {
    return List.from(albums);
  }

  @override
  Future<void> createAlbum(String name) async {
    albums.add(AlbumInfo(name: name, count: Int64(0), isDefault: false));
  }

  @override
  Future<void> deleteAlbum(String name) async {
    albums.removeWhere((a) => a.name == name);
  }

  @override
  Future<void> renameAlbum(String oldName, String newName) async {
    final idx = albums.indexWhere((a) => a.name == oldName);
    if (idx != -1) {
      albums[idx].name = newName;
    }
  }

  @override
  Future<List<String>> moveAssets(List<String> paths, String targetAlbum) async {
    lastMovedPaths = List.from(paths);
    lastTargetAlbum = targetAlbum;
    return paths.map((p) => '$targetAlbum/${p.split('/').last}').toList();
  }

  @override
  Future<SyncManifestResponse> syncManifest() async => SyncManifestResponse(success: true);

  @override
  Future<void> setLocalCacheDir(String path) async {}

  @override
  Future<bool> uploadThumbnailDirect(String path, List<int> jpegBytes) async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cloud Album State & Model Tests', () {
    late MockAlbumRemoteStorage mockStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockStorage = MockAlbumRemoteStorage();
      setStorageForTest(mockStorage);
      useRemoteServer = true;
      grpcPort = 50051;
      httpPort = 10000;
      assetModel.currentCloudAlbum = '';
      settingModel.defaultAlbumName = '相机备份';
    });

    tearDown(() {
      setStorageForTest(storage);
    });

    test('SettingModel 默认相册名称配置与持久化', () async {
      expect(settingModel.defaultAlbumName, '相机备份');
      settingModel.setDefaultAlbumName('K60 个人备份');
      expect(settingModel.defaultAlbumName, 'K60 个人备份');

      await settingModel.saveSettings();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('default_album_name'), 'K60 个人备份');

      settingModel.defaultAlbumName = '相机备份';
      await settingModel.loadSettings(prefs);
      expect(settingModel.defaultAlbumName, 'K60 个人备份');
    });

    test('AssetModel 云端相册列表拉取与切换', () async {
      await assetModel.refreshCloudAlbums();
      expect(assetModel.cloudAlbums.length, 2);
      expect(assetModel.cloudAlbums[0].name, '相机备份');
      expect(assetModel.cloudAlbums[0].isDefault, isTrue);

      await assetModel.selectCloudAlbum('日本旅行 2026');
      expect(assetModel.currentCloudAlbum, '日本旅行 2026');
      expect(mockStorage.lastQueriedAlbum, '日本旅行 2026');

      // 切换回全部照片 (空字符串)
      await assetModel.selectCloudAlbum('');
      expect(assetModel.currentCloudAlbum, '');
      expect(mockStorage.lastQueriedAlbum, '');
    });

    test('AssetModel 创建、重命名与删除相册', () async {
      await assetModel.createCloudAlbum('工作发票');
      expect(mockStorage.albums.any((a) => a.name == '工作发票'), isTrue);

      await assetModel.renameCloudAlbum('工作发票', '2026 发票');
      expect(mockStorage.albums.any((a) => a.name == '2026 发票'), isTrue);
      expect(mockStorage.albums.any((a) => a.name == '工作发票'), isFalse);

      await assetModel.deleteCloudAlbum('2026 发票');
      expect(mockStorage.albums.any((a) => a.name == '2026 发票'), isFalse);
    });
  });
}
