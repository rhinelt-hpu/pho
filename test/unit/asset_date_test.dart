import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:img_syncer/asset.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:grpc/grpc.dart';

class _FakeClientChannel extends ClientChannel {
  _FakeClientChannel() : super('127.0.0.1', port: 10000, options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
}

void main() {
  group('Asset dateCreated tests', () {
    late ImgSyncerClient fakeCli;
    late http.Client fakeHttp;

    setUp(() {
      fakeCli = ImgSyncerClient(_FakeClientChannel());
      fakeHttp = http.Client();
    });

    test('从相册路径与文件名中精准解析拍摄日期时间', () {
      final remoteImg = RemoteImage(
        fakeCli,
        '相机备份/2026/02/26/20260226101441_MVIMG_20260226_101441.jpg',
        httpClient: fakeHttp,
      );
      final asset = Asset(remote: remoteImg);
      final dt = asset.dateCreated();
      expect(dt.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 26);
      expect(dt.hour, 10);
      expect(dt.minute, 14);
      expect(dt.second, 41);
    });

    test('旧版无相册前缀路径 2025/11/22/filename.jpg 同样正确解析', () {
      final remoteImg = RemoteImage(
        fakeCli,
        '2025/11/22/20251122102115_MVIMG_20251122_102115.jpg',
        httpClient: fakeHttp,
      );
      final asset = Asset(remote: remoteImg);
      final dt = asset.dateCreated();
      expect(dt.year, 2025);
      expect(dt.month, 11);
      expect(dt.day, 22);
      expect(dt.hour, 10);
      expect(dt.minute, 21);
      expect(dt.second, 15);
    });

    test('如果文件名没有时间戳前缀，回退从目录 2026/02/02 提取年月日', () {
      final remoteImg = RemoteImage(
        fakeCli,
        '自定义相册/2026/02/02/test_video.mp4',
        httpClient: fakeHttp,
      );
      final asset = Asset(remote: remoteImg);
      final dt = asset.dateCreated();
      expect(dt.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 2);
    });

    test('紧凑型日期目录 20260202 提取年月日', () {
      final remoteImg = RemoteImage(
        fakeCli,
        '自定义相册/20260202/custom_name.jpg',
        httpClient: fakeHttp,
      );
      final asset = Asset(remote: remoteImg);
      final dt = asset.dateCreated();
      expect(dt.year, 2026);
      expect(dt.month, 2);
      expect(dt.day, 2);
    });
  });
}
