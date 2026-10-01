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

### 4.3 Android 11+ 无线调试实战（ADB Pair & Connect 双端口机制避坑）

Android 11 及以上系统（如澎湃 OS / MIUI / 原生 Android）提供了无需插线的 WLAN 无线调试，但其底层采用了**“配对”与“连接”双端口机制**，开发联调时极其容易踩坑：

1. **第一步：设备配对 (仅需配对一次)**
   - 手机进入【开发者选项 -> 无线调试 -> 使用配对码配对设备】。
   - ⚠️ **核心注意点**：该弹窗中显示的 IP 和端口（例如 `192.168.3.51:42183`）是**动态临时配对端口**，只要弹窗关闭该端口立即失效！
   - 终端使用 `adb pair` 命令进行配对：
     ```bash
     adb pair <IP>:<临时配对端口> <6位配对码>
     # 示例：adb pair 192.168.3.51:42183 247588
     # 成功输出：Successfully paired to 192.168.3.51:42183
     ```
2. **第二步：正式建立调试连接**
   - 配对成功后，关闭配对弹窗，返回【无线调试】主界面。
   - 找到主界面上常驻显示的“IP 地址和端口”（例如 `192.168.3.51:42507`，注意此端口与配对端口不同！）。
   - 终端使用 `adb connect` 连接该常驻端口：
     ```bash
     adb connect <IP>:<常驻连接端口>
     # 示例：adb connect 192.168.3.51:42507
     # 成功输出：connected to 192.168.3.51:42507
     ```
3. **常见排错**：
   - 若误用常驻连接端口去执行 `adb pair`，会报错：`error: protocol fault (couldn't read status message): Undefined error: 0`。
   - 若连接提示 `failed to connect`，先使用 `ping <手机IP>` 确认电脑与手机处于同一网段且 AP 隔离已关闭。
   - 检查已连接设备列表：`adb devices -l` 或 `flutter devices`。
   - 无线推送安装应用：`adb install -r build/app/outputs/flutter-apk/app-release.apk`。

### 4.4 真机模拟操作与 UI 调试：结构树与视觉走查双轨制

在真机联调或自动化功能验证过程中，避免盲目依赖屏幕截图去目测坐标点击，应遵循**双轨制调试原则**：

| 调试场景 | 推荐方式 | 核心优势 | 执行方式 |
| :--- | :--- | :--- | :--- |
| **常规功能验证**（点击开关、按钮跳转、输入、状态变更） | **UI 结构树精准定位 (`uiautomator dump`)** | **毫秒级、100% 精准无点偏、零 I/O 截图开销** | 读取 Flutter 无障碍/语义树 XML，直接解析组件 `bounds` 并自动求中心点 `input tap` |
| **UI 视觉效果走查**（多选高对比度边框、暗浅色主题、蒙层对比度） | **按需单次拉取屏幕截图 (`screencap`)** | 验证真机物理屏幕的最终视觉质感与排版 | 仅在有视觉核验诉求时生成，保存至本地临时目录（必须忽略 Git） |

#### 结构树精准查找与自动点击示例 (Python 一键执行)
利用 Android `uiautomator dump` 获取当前界面的语义节点树，根据文字或描述自动求出绝对坐标完成点击：
```python
import subprocess, re

adb_cmd = ["adb", "shell"]

def tap_ui_node(keyword, prefer_right=False):
    # 1. 导出当前界面的结构树并读取
    subprocess.run(adb_cmd + ["uiautomator", "dump", "/sdcard/ui_tree.xml"], stdout=subprocess.DEVNULL)
    res = subprocess.run(adb_cmd + ["cat", "/sdcard/ui_tree.xml"], capture_output=True, text=True)
    xml_data = res.stdout

    # 2. 正则查找匹配包含目标文本的 node 节点及其边界
    for match in re.finditer(r"<node ([^>]+)>", xml_data):
        node = match.group(1)
        desc = re.search(r"content-desc=\"([^\"]*)\"", node)
        text = re.search(r"text=\"([^\"]*)\"", node)
        bounds = re.search(r"bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", node)
        node_text = f"{text.group(1) if text else ''} {desc.group(1) if desc else ''}"
        
        if keyword in node_text and bounds:
            x1, y1, x2, y2 = map(int, bounds.groups())
            # Switch 类开关点击偏右侧滑块，普通按钮点击几何中心
            tx = x2 - (x2 - x1) // 8 if prefer_right else (x1 + x2) // 2
            ty = (y1 + y2) // 2
            subprocess.run(adb_cmd + ["input", "tap", str(tx), str(ty)])
            print(f"已精准命中 [{node_text.strip()}]，点击坐标 ({tx}, {ty})")
            return True
    print(f"未找到包含 [{keyword}] 的组件")
    return False

# 示例：点击调试模式开关、点击打开控制台
tap_ui_node("调试模式", prefer_right=True)
tap_ui_node("打开调试控制台")
```

### 4.5 应用内 Talker 调试面板使用指南

应用已全面集成现代化轻量级调试套件 `talker_flutter`：
- **入口路径**：打开【设置】-> 点击底部【应用信息】(`AboutRoute`)。
- **开闭控制 (开箱即关，零开销)**：
  - **默认状态**：调试模式处于关闭状态，Talker 不做任何堆栈捕获与历史缓存，完全不消耗额外 CPU 与内存；
  - **开启状态**：轻触【调试模式】开关，即时激活日志捕获与全局未捕获异常监控；
- **核心能力**：
  1. **动态控制台入口**：开启开关后，页面立即动态展开【打开调试控制台】与【清空调试日志】；
  2. **日志分类与色彩分级**：全应用 30+ 处 `logger.addLog` 无缝桥接，错误自动标红（`error`）、警告标黄（`warning`）、普通信息标蓝（`info`）；
  3. **实时排错与导出**：控制台内置关键字搜索、等级过滤器，右上角支持一键复制与调用系统分享面板，将完整排障日志直接导出给开发者；
  4. **异常监控**：自动挂载 `FlutterError.onError` 与 `PlatformDispatcher.instance.onError`，任何后台任务与 UI 线程抛错均能完整查看调用栈。

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

### Q9: macOS 构建时报错 impellerc failure 或 Font subsetting failed with exit code -9（Apple 不信任）
- **现象**：执行 `flutter build apk` 或 `make apk` 时终端报错：
  ```text
  impellerc failure:
  Target aot_android_asset_bundle failed: IconTreeShakerException: Font subsetting failed with exit code -9.
  ```
  macOS 可能会弹出系统安全警告提示“无法打开 impellerc，因为 Apple 无法检查其是否包含恶意软件”。
- **原因**：如果通过 Homebrew Cask（`brew install --cask flutter`）安装 Flutter，macOS 会自动递归打上 `com.apple.quarantine` 扩展隔离属性。打包时调用的编译器工具（`impellerc`、`font-subset`、`gen_snapshot`）未向苹果提交独立公证签名，触发 Gatekeeper 发送 `SIGKILL (-9)` 强制终止。
- **解决**：递归移除 Flutter SDK 目录下的隔离属性：
  ```bash
  sudo xattr -r -d com.apple.quarantine /opt/homebrew/Caskroom/flutter
  sudo xattr -r -d com.apple.quarantine /opt/homebrew/share/flutter
  ```

### Q10: 系统安装了高版本 Java（如 Java 21 / 25）导致 Gradle 构建报错
- **现象**：Gradle 报错 `Unsupported class file major version` 或 JVM 兼容性异常。
- **原因**：当前工程使用的 Gradle 8.14 对 Java 25 等前沿版本支持不完备，推荐锁定至稳定的 LTS 版本 **JDK 17**。
- **解决**：使用 Flutter 配置固定 JDK 路径（无需改动全局 `PATH`）：
  ```bash
  flutter config --jdk-dir="/Library/Java/JavaVirtualMachines/jdk-17.jdk/Contents/Home"
  ```

### Q11: Android 高版本机型相册长按多选时照片看不到框选或蒙层
- **原因**：多选渲染逻辑被错误嵌套在 `if (all[i].isLivePhoto())` 条件下。由于 Android 平台照片的 `isLivePhoto()` 恒为 `false`，导致普通照片的多选蒙层和勾选圈完全被跳过。
- **解决**：已在 `lib/gallery_body.dart` 中彻底移除该嵌套条件，并升级为 3.0px 主题色高亮外框 + 28% 半透明蒙层 + 24px 实心 `check_circle` / 空心圆圈高对比度指示器。

