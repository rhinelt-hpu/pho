// 测试用的轻量替身（不依赖真实网络/平台通道）。
//
// - FakeImgSyncerClient: 只实现 grpc 的 filterNotUploaded，供
//   StateModel.checkRemoteUploaded 测试注入使用。
// - mockPhotoManagerChannel: photo_manager 的 getTitleAsync 在 iOS/macOS 宿主上
//   会走平台通道，测试里统一桩掉。
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';

/// 假的 gRPC ClientCall：只承载一个响应流，供 ResponseStream 使用。
class _FakeCall<Q, R> implements ClientCall<Q, R> {
  _FakeCall(this.response);

  @override
  final Stream<R> response;
  @override
  CallOptions options = CallOptions();
  @override
  bool isCancelled = false;
  @override
  Future<Map<String, String>> get headers async => const {};
  @override
  Future<Map<String, String>> get trailers async => const {};
  @override
  Future<void> cancel() async => isCancelled = true;
  @override
  void onConnectionError(error) {}
  @override
  void onConnectionReady(dynamic connection) {}
}

/// 假的 grpc 客户端：只实现 filterNotUploaded，不建立真实连接。
class FakeImgSyncerClient extends ImgSyncerClient {
  FakeImgSyncerClient(this.uploadedIDs)
      : super(ClientChannel('127.0.0.1', port: 1));

  /// 远端回传的「已上传」ID
  final List<String> uploadedIDs;

  /// 记录收到的请求批次，便于断言分批行为
  final List<FilterNotUploadedRequest> sentRequests = [];

  @override
  ResponseStream<FilterNotUploadedResponse> filterNotUploaded(
      Stream<FilterNotUploadedRequest> request,
      {CallOptions? options}) {
    request.listen(sentRequests.add);
    return ResponseStream(_FakeCall(Stream.value(FilterNotUploadedResponse(
      success: true,
      uploadedIDs: uploadedIDs,
    ))));
  }
}

const _pmChannel = MethodChannel('com.fluttercandies/photo_manager');

/// 桩掉 photo_manager 的 getTitleAsync（返回 `<id>.jpg`）
void mockPhotoManagerChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pmChannel, (call) async {
    if (call.method == 'getTitleAsync') {
      return '${(call.arguments as Map)['id']}.jpg';
    }
    return null;
  });
}

void resetPhotoManagerChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pmChannel, null);
}
