# 4. 本地开发、构建与调试指南

本文档指导开发者快速搭建 Pho 的开发环境，完成 Android 和 iOS 双端的代码编译、真机调试以及集成测试。

---

## 1. 开发环境依赖矩阵

在开始开发前，请确保本地安装了以下工具链：

| 组件 | 推荐版本 | 检查命令 | 作用 |
| :--- | :--- | :--- | :--- |
| **Flutter** | >= 3.44.0 (推荐 3.47.x stable) | `flutter --version` | UI 与应用框架 (`pubspec.lock` 硬性约束 >= 3.44.0) |
| **Dart** | >= 3.12.0 < 4.0.0 | `dart --version` | 语言运行时 |
| **Go** | 1.25.x / 1.26.x | `go version` | 嵌入式核心服务端 |
| **Gomobile** | latest | `gomobile version` | Go 编译为 Android AAR / iOS Framework |
| **JDK** | OpenJDK 17 | `java -version` | Android Gradle 构建 (JVM 17 锁定) |
| **Android SDK** | API 36 (compileSdk) | `sdkmanager --list` | Android 原生构建 |
| **Android NDK** | 28.2.13676358 (r28c) | `ls $ANDROID_HOME/ndk` | Flutter 3.47+ 默认要求版本，用于本地代码交叉编译 |
| **Xcode** (仅 macOS) | 15+ / 16+ | `xcodebuild -version`| iOS 编译打包与模拟器 |
| **Protoc** | 3.x+ / 29.x | `protoc --version` | Protobuf 代码生成工具 |
| **Docker & Compose** | latest | `docker compose version` | 运行 SMB/WebDAV/NFS 自动化测试容器 |

### 1.1 推荐环境变量配置速查 (~/.bashrc)
将以下环境变量加入 `~/.bashrc`（请替换相应路径）：
```bash
# 开发工具链 (JDK 17, Android SDK & NDK, Flutter, Protoc, Go)
export JAVA_HOME="$HOME/development/jdk-17"
export ANDROID_HOME="$HOME/development/android-sdk"
export ANDROID_NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"

# 必须将 cmdline-tools, platform-tools, flutter, protoc, go/bin 及 pub-cache/bin 加入 PATH
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$HOME/development/flutter/bin:$HOME/development/protoc/bin:$HOME/go/bin:$HOME/.pub-cache/bin:$PATH"
```

### 1.2 网络代理与构建避坑指南 (重要实战经验)

- **Gradle 独立代理配置**：
  Gradle 运行在独立 JVM 进程中，**默认不会继承终端 Shell 的 `http_proxy` / `https_proxy` 环境变量**！
  若在国内网络环境下构建 Android 应用，下载 Maven 依赖或触发 SDK/NDK 自动下载时容易超时卡死。必须在 `~/.gradle/gradle.properties`（全局）显式配置 JVM 系统代理：
  ```properties
  systemProp.http.proxyHost=127.0.0.1
  systemProp.http.proxyPort=10808
  systemProp.https.proxyHost=127.0.0.1
  systemProp.https.proxyPort=10808
  systemProp.http.nonProxyHosts=localhost|127.0.0.1|*.local|mirrors.tuna.tsinghua.edu.cn|mirrors.aliyun.com
  systemProp.https.nonProxyHosts=localhost|127.0.0.1|*.local|mirrors.tuna.tsinghua.edu.cn|mirrors.aliyun.com
  ```

- **SDK/NDK 大文件下载断点续传**：
  通过代理下载 Flutter SDK 或 Android NDK 等 1GB+ 大文件时，偶遇网络波动断流，推荐使用断点续传与低速重试机制：
  ```bash
  curl -C - -L --speed-limit 500000 --speed-time 10 -O "<URL>"
  ```


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

### Q5: 执行 `make apk` 或 Gradle 构建时卡在下载依赖无响应
- **原因**：Gradle 守护进程（JVM）默认不继承终端的 Shell 代理环境变量，导致下载 Google Maven 构件或 AGP 依赖时直连超时。
- **解决**：检查并配置 `~/.gradle/gradle.properties`，添加 `systemProp.http.proxyHost` 与 `systemProp.https.proxyHost`（参见 1.2 节）。

### Q6: 首次构建时 Gradle 频繁静默下载 1GB+ 的 NDK 导致构建极慢
- **原因**：`android/app/build.gradle.kts` 中配置了 `ndkVersion = flutter.ndkVersion`。新版 Flutter（3.47+）默认要求 NDK 28.2.13676358。本地若无该版本，AGP 会触发后台自动下载。
- **解决**：提前使用 `sdkmanager "ndk;28.2.13676358"` 下载并解压就位，避免构建时后台阻塞。

### Q7: 执行 `make prebuild` 或 `make protobuf` 报错 `protoc-gen-dart: command not found`
- **原因**：`dart pub global activate` 安装的二进制文件在 `~/.pub-cache/bin`，该目录未加入系统的 `PATH` 环境变量。
- **解决**：在 `~/.bashrc` 中将 `$HOME/.pub-cache/bin` 加入 `PATH`，并重新 `source ~/.bashrc`。

### Q8: 执行 `flutter pub get` 报错 SDK 版本不满足约束
- **原因**：`pubspec.lock` 硬性锁定了 `flutter: ">=3.44.0"`，若安装的 Flutter 属于更早的旧版本（如 3.41.4）将无法解析。
- **解决**：升级 Flutter SDK 至 3.44.0 以上（推荐 3.47.x 稳定版）。

