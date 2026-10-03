import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 缩略图本地磁盘缓存管理器
/// 针对弱网及限流 WebDAV 服务器，将已下载的缩略图落盘缓存，
/// 避免相册滑动、刷新、切换时重复触发高频 HTTP 请求。
class ThumbnailCache {
  static Directory? _cacheDir;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized && _cacheDir != null) return;
    try {
      final appDir = await getApplicationSupportDirectory();
      _cacheDir = Directory(p.join(appDir.path, 'pho_thumbnail_cache'));
    } catch (_) {
      try {
        final tempDir = await getTemporaryDirectory();
        _cacheDir = Directory(p.join(tempDir.path, 'pho_thumbnail_cache'));
      } catch (_) {
        _cacheDir = Directory(p.join(Directory.systemTemp.path, 'pho_thumbnail_cache'));
      }
    }
    try {
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      _initialized = true;
    } catch (_) {
      // 容错：若无法获取路径，降级为无缓存模式
    }
  }

  static String _hashKey(String remotePath) {
    return md5.convert(utf8.encode(remotePath)).toString();
  }

  static File? _fileForPath(String remotePath) {
    if (_cacheDir == null) return null;
    final name = '${_hashKey(remotePath)}.thumb';
    return File(p.join(_cacheDir!.path, name));
  }

  /// 同步尝试获取缓存（最快路径）
  static Uint8List? getSync(String remotePath) {
    try {
      final file = _fileForPath(remotePath);
      if (file != null && file.existsSync()) {
        return file.readAsBytesSync();
      }
    } catch (_) {}
    return null;
  }

  /// 异步读取本地磁盘缓存
  static Future<Uint8List?> get(String remotePath) async {
    if (!_initialized) {
      await init();
    }
    try {
      final file = _fileForPath(remotePath);
      if (file != null && await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}
    return null;
  }

  /// 原子写入本地磁盘缓存
  static Future<void> put(String remotePath, Uint8List bytes) async {
    if (!_initialized) {
      await init();
    }
    if (_cacheDir == null || bytes.isEmpty) return;
    try {
      final file = _fileForPath(remotePath);
      if (file == null) return;
      // 写入 .tmp 文件后原子 rename，避免写入中断产生破损缓存文件
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsBytes(bytes, flush: true);
      if (await tmpFile.exists()) {
        await tmpFile.rename(file.path);
      }
    } catch (_) {}
  }

  /// 清空本地缩略图缓存
  static Future<void> clear() async {
    try {
      if (_cacheDir != null && await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
    } catch (_) {}
  }

  /// 获取当前缓存文件大小总和（字节）
  static Future<int> getCacheSize() async {
    if (!_initialized) await init();
    if (_cacheDir == null || !await _cacheDir!.exists()) return 0;
    int total = 0;
    try {
      await for (final entity in _cacheDir!.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }
}
