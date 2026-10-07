// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/storage/storage.dart';

/// [RemoteStorage] 的抽象接口，用于单元测试 mock 注入。
abstract class RemoteStorageClient {
  ImgSyncerClient get cli;
  Future<void> uploadXFile(XFile file, {String album = ""});
  Future<void> uploadAssetEntity(AssetEntity asset, {String album = ""});
  Future<List<RemoteImage>> listImages(String date, int offset, maxReturn, {String album = ""});
  Future<List<AlbumInfo>> listAlbums();
  Future<void> createAlbum(String name);
  Future<void> deleteAlbum(String name);
  Future<void> renameAlbum(String oldName, String newName);
  Future<List<String>> moveAssets(List<String> paths, String targetAlbum);
  Future<SyncManifestResponse> syncManifest();
  Future<void> setLocalCacheDir(String path);
  Future<bool> uploadThumbnailDirect(String relPath, Uint8List thumbBytes);
}
