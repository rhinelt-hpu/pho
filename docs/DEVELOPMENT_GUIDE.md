# 4. 本地开发、构建与调试指南

本文档指导开发者快速搭建 Pho 的开发环境，完成 Android 和 iOS 双端的代码编译、真机调试以及集成测试。

---

## 1. 开发环境依赖矩阵

在开始开发前，请确保本地安装了以下工具链：

| 组件 | 推荐版本 | 检查命令 | 作用 |
| :--- | :--- | :--- | :--- |
| **Flutter** | 3.41.4 (Channel stable) | `flutter --version` | UI 与应用框架 |
| **Dart** | 3.11.1 | `dart --version` | 语言运行时 |
| **Go** | 1.25.x | `go version` | 嵌入式核心服务端 |
| **Gomobile** | latest | `gomobile version` | Go 编译为 Android AAR / iOS Framework |
| **JDK** | OpenJDK 17 | `java -version` | Android Gradle 构建 |
| **Android SDK** | API 36 (compileSdk) | `sdkmanager --list` | Android 原生构建 |
| **Android NDK** | 25+ | - | Gomobile 交叉编译 CGO/Android 库 |
| **Xcode** (仅 macOS) | 15+ / 16+ | `xcodebuild -version`| iOS 编译打包与模拟器 |
| **Protoc** | 3.x+ | `protoc --version` | Protobuf 代码生成工具 |
| **Docker & Compose** | latest | `docker compose version` | 运行 SMB/WebDAV/NFS 自动化测试容器 |

---

## 2. 初始准备与代码生成

### 2.1 安装 Protobuf 代码生成插件
运行一次安装生成插件：
```bash
make prebuild
```
该命令会自动安装：
- `protoc-gen-go@v1.27.1`
- `protoc-gen-go-grpc@v1.1.0`
- `dart pub global activate protoc_plugin 21.1.2`

### 2.2 生成 gRPC Stubs
当修改了 `proto/img_syncer.proto` 时，必须重新生成 Go 与 Dart 代码：
```bash
make protobuf
```
生成的文件位于：
- Go：`proto/img_syncer.pb.go`、`proto/img_syncer_grpc.pb.go`
- Dart：`lib/proto/img_syncer.pb*.dart`

---

## 3. 双端编译与运行步骤

> **重要警示**：直接执行 `flutter run` **不会**自动触发 Go 服务端编译！如果缺少 AAR 或 xcframework，应用在启动时调用 `RunGrpcServer` 会抛出 `MissingPluginException` 或 `UnsatisfiedLinkError`。

### 3.1 Android 端开发全流程

1. **编译 Go 嵌入式 AAR**：
   ```bash
   make server-aar
   ```
   *产物验证*：确认 `android/app/libs/server.aar` 文件已生成。
2. **获取 Flutter 依赖**：
   ```bash
   flutter pub get
   ```
3. **运行并调试 Android**：
   ```bash
   # 连接 Android 真机或启动模拟器
   flutter run -d <android-device-id>
   ```
4. **生成正式版 Release APK**：
   ```bash
   make apk
   # 产物位于 build/app/outputs/flutter-apk/
   ```

### 3.2 iOS 端开发全流程 (需 macOS 环境)

1. **编译 Go 嵌入式 XCFramework**：
   ```bash
   make server-ios
   ```
   *产物验证*：确认 `ios/Frameworks/RUN.xcframework` 已生成。
2. **安装 Pod 依赖**：
   ```bash
   cd ios && pod install && cd ..
   ```
3. **运行并调试 iOS**：
   ```bash
   flutter run -d <ios-device-id-or-simulator>
   ```
4. **生成 Release IPA**：
   ```bash
   make ipa
   ```

---

## 4. 调试技巧与日志系统

### 4.1 日志查看与级别

- **Flutter 业务日志**：
  应用内封装了 `lib/logger/logger.dart`，在开发阶段可通过 `logger.addLog(...)` 输出。
- **Go 核心日志**：
  在 `server/run/run.go` 中，Go 标准输出绑定到 `os.Stdout`，错误输出到 `os.Stderr`。这些日志会被 Android Logcat 和 iOS Xcode Console 直接捕获。
  - **Android 查看命令**：
    ```bash
    adb logcat | grep -E "com.fregie.pho|\[INFO\]|\[ERROR\]"
    ```
  - **iOS 查看方式**：
    在 Xcode 中打开 `ios/Runner.xcworkspace`，运行并观察 Console 控制台，过滤关键字 `RUN` 或 `bg-sync-engine`。

### 4.2 模拟触发 iOS 后台同步任务 (Xcode Debugger)

无需真机等待 1 小时或通宵充电，可以在联机调试时手动触发 `BGProcessingTask`：
1. 用 Xcode 运行应用到真机或模拟器上。
2. 将应用切换到后台（按 Home 键或上滑）。
3. 在 Xcode 的暂停按钮（Pause Execution）暂停应用。
4. 在 LLDB 调试器中输入以下命令：
   ```lldb
   e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.example.img_syncer.background-sync"]
   ```
5. 点击 Continue 继续运行，Xcode 将立即唤醒 `handleBgSyncTask`，拉起 Headless Engine 执行同步。

---

## 5. 自动化测试执行

项目包含全面的后端集成测试套件，测试覆盖了 SMB、WebDAV、NFS 的文件读写与断点恢复：

```bash
# 启动本地 Docker 测试集群并执行全量测试
make test
```
该命令会自动：
1. 启动 `test/docker-compose.yml` 中的三个测试容器（Samba 服务器、WebDAV 容器、NFS 服务器）。
2. 执行 `go test -v ./server/api -p 1 -failfast`。
3. 执行 `go test -v ./server/drive -p 1 -failfast`。
4. 测试完毕后自动销毁容器。

---

## 6. 常见踩坑与排错指南 (FAQ)

### Q1: Android 启动报错 `No implementation found for method RunGrpcServer`
- **原因**：没有提前编译 `server.aar`，或者 Gradle 未正确打包该文件。
- **解决**：检查 `android/app/libs/server.aar` 是否存在，运行 `make server-aar`，然后 `cd android && ./gradlew clean` 重新构建。

### Q2: iOS 编译报错 `No such module 'RUN'`
- **原因**：缺少 `ios/Frameworks/RUN.xcframework`。
- **解决**：在 macOS 上运行 `make server-ios`，并在 `ios/` 目录下重新运行 `pod install`。

### Q3: 为什么下载大视频在线播放时进度条无法拖动？
- **原因**：视频如果采用了旧版 `AES-128-CFB` 加密，不支持 HTTP Range 随机定位。
- **解决**：在设置中切换为现代的 `AES-256-GCM` 算法，新加密上传的视频即可直接拖动进度条。

### Q4: 提示 `Listen on all port failed`
- **原因**：本机 10000 到 20000 之间的可用端口耗尽，或者权限受限无法绑定回环地址。
- **排查**：检查防火墙软件或 VPN 是否阻断了 `127.0.0.1` 的 TCP 绑定。
