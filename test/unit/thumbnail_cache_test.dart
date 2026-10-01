import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:img_syncer/cache/thumbnail_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThumbnailCache put and get roundtrip works seamlessly', () async {
    final testPath = '测试/2026/02/15/test_pic.jpg';
    final testData = Uint8List.fromList([1, 2, 3, 4, 5, 42, 99]);

    await ThumbnailCache.put(testPath, testData);

    final cached = await ThumbnailCache.get(testPath);
    expect(cached, isNotNull);
    expect(cached, equals(testData));

    final syncCached = ThumbnailCache.getSync(testPath);
    expect(syncCached, isNotNull);
    expect(syncCached, equals(testData));

    final size = await ThumbnailCache.getCacheSize();
    expect(size, greaterThanOrEqualTo(testData.length));

    await ThumbnailCache.clear();
    final afterClear = await ThumbnailCache.get(testPath);
    expect(afterClear, isNull);
  });
}
