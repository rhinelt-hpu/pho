# 2. Android & iOS 双端深度技术指南

本文档专门针对移动双端（Android 和 iOS）的核心机制、原生桥接、权限策略、后台执行模式以及多媒体处理细节进行深度剖析。

---

## 1. 原生嵌入式 Go 核心 (Gomobile 体系)

Pho 在移动端直接将 Go 服务端编译为原生静态链接库或动态框架，打包进客户端。

### 1.1 构建命令与产物

| 平台 | 构建命令 | 编译输出路径 | 说明 |
| :--- | :--- | :--- | :--- |
| **Android** | `make server-aar` | `android/app/libs/server.aar` | CGO_ENABLED=0，针对 Android API 21+ 静态编译 |
| **iOS** | `make server-ios` | `ios/Frameworks/RUN.xcframework` | CGO_ENABLED=0，适配 arm64 真机与模拟器 |

### 1.2 导出接口与原生调用

Go 端入口位于 `server/run/run.go`：
```go
package run

import _ "golang.org/x/mobile/bind"

// 导出的入口函数（大写）
func RunGrpcServer() (string, error)
func Shutdown()
```

- **Android 调用栈**：
  Gradle 依赖 `libs/server.aar`，Kotlin 中直接导入：
  ```kotlin
  import run.Run
  // ...
  val ports: String = Run.runGrpcServer() // 返回 "grpcPort,httpPort"
  ```
- **iOS 调用栈**：
  Xcode Framework 引入 `RUN.xcframework`，Swift 中直接导入：
  ```swift
  import RUN
  // ...
  var error: NSError? = nil
  let ports = RunRunGrpcServer(&error) // Gomobile 为 iOS 生成的 C 桥接函数
  ```

---

## 2. Android 端核心实现与深度剖析

### 2.1 原生容器与通信通道 (`MainActivity.kt`)

- **MethodChannel**：`com.example.img_syncer/RunGrpcServer`
  - `RunGrpcServer`：拉起嵌入式 Go 服务，返回端口对。
  - `scanFile`：触发系统相册图库扫描。
- **图库扫描广播 (MediaScanner)**：
  当用户从云端下载照片或视频到本地时，为了让系统相册（Google Photos、MIUI/EMUI 相册等）立即显示该文件，Native 端执行广播通知：
  ```kotlin
  private fun scanFile(path: String?, volumeName: String?, relativePath: String?, mimeType: String?) {
      val mediaScanIntent = Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
      val file = File(path)
      val contentUri = Uri.fromFile(file)
      mediaScanIntent.data = contentUri
      sendBroadcast(mediaScanIntent)
  }
  ```

### 2.2 权限机制与 Scoped Storage 适配

`AndroidManifest.xml` 中配置了多版本兼容的权限声明：
- **媒体读取权限**：
  - Android 13+ (API 33+)：`android.permission.READ_MEDIA_IMAGES`、`android.permission.READ_MEDIA_VIDEO`。
  - Android 12 及以下：`android.permission.READ_EXTERNAL_STORAGE`、`android.permission.WRITE_EXTERNAL_STORAGE`。
- **EXIF 拍摄地理位置权限**：
  - `android.permission.ACCESS_MEDIA_LOCATION`：确保解析照片 Exif 时能够读取原始经纬度。
- **网络与明文通信**：
  - `android.permission.INTERNET`、`ACCESS_NETWORK_STATE`。
  - `android:usesCleartextTraffic="true"`：**至关重要**。由于 Go 内核与 Flutter 之间通过 `http://127.0.0.1:$port` 明文通信，必须允许应用内本地回环明文流量。
  - `android:requestLegacyExternalStorage="true"`：用于兼容低版本外部存储访问。

### 2.3 Android 后台同步现状与改造建议 (重点技术点)

- **现状分析**：
  当前 Android 端的后台同步在 `sync_timer.dart` 中使用 Dart 的 `Timer.periodic`。
  - **严重缺陷**：当应用退到后台、手机锁屏、或者被系统省电策略（Doze 模式）冻结时，Dart VM 的线程会被挂起甚至直接杀死；因此**目前在 Android 上应用退后台后无法稳定触发定期同步**。
- **推荐改造架构（后续迭代首要任务）**：
  1. 引入官方 `workmanager` 插件（或原生接入 Android Jetpack WorkManager）。
  2. 注册周期性 `PeriodicWorkRequest`，设置约束条件（`setRequiredNetworkType(NetworkType.UNMETERED)` 即仅 WiFi，以及 `setRequiresCharging(true)`）。
  3. 当 WorkManager 唤醒时，启动原生前台服务（Foreground Service）或 Headless 引擎拉起 Go 服务执行 `runSyncOnce`，完成后释放 Wakelock。

---

## 3. iOS 端核心实现与深度剖析

### 3.1 原生容器架构与双入口设计 (`AppDelegate.swift`)

iOS 实现了非常规范且稳健的**双入口架构**（前台 UI 启动 vs 后台静默唤醒）：

```
                                  [iOS 系统启动事件]
                                           |
                                           v
                       application:didFinishLaunchingWithOptions:
                                           |
                +--------------------------+--------------------------+
                |                                                     |
        [常规前台启动]                                        [后台任务静默唤醒]
  (launchOptions 无 BGTask key)                  (launchOptions 携带 BGTaskScheduler key)
                |                                                     |
                v                                                     v
   获取 window.rootViewController                       **绝不触碰** window / rootViewController
   (FlutterViewController)                              (避免 force-unwrap crash)
                |                                                     |
                v                                                     v
  注册前台 MethodChannels                                  创建独立的 Headless FlutterEngine
  GeneratedPluginRegistrant.register()                  ("bg-sync-engine", allowHeadlessExecution)
                |                                                     |
                v                                                     v
          渲染 Flutter UI                              执行 Dart backgroundSyncEntrypoint()
```

### 3.2 后台处理任务 (`BGProcessingTask`) 闭环

Apple 对后台运行有极其严苛的限制，Pho 严格按照官方最佳实践落地：
1. **任务标识**：`com.example.img_syncer.background-sync`（必须在 `Info.plist` 的 `BGTaskSchedulerPermittedIdentifiers` 中声明，同时开启 `UIBackgroundModes` 的 `processing`）。
2. **提前注册**：在 `didFinishLaunchingWithOptions` **返回之前**必须完成 `BGTaskScheduler.shared.register`。
3. **环境约束**：
   ```swift
   let request = BGProcessingTaskRequest(identifier: "com.example.img_syncer.background-sync")
   request.requiresExternalPower = true       // 必须接通电源（夜间充电时）
   request.requiresNetworkConnectivity = true // 必须有网络
   request.earliestBeginDate = Date(timeIntervalSinceNow: 3600) // 最快 1 小时后唤醒
   ```
4. **任务超时与取消 (Expiration Handling)**：
   当 iOS 决定收回后台资源时，会触发 `task.expirationHandler`。AppDelegate 通过 `backgroundSync` Channel 向 Dart 发送 `cancel` 事件，`runSyncOnce` 检查到取消标记立即退出并保存断点状态。
5. **任务完成销毁**：
   Dart 端完成同步后，回传 `complete` 方法。AppDelegate 调用 `task.setTaskCompleted(success: true)` 并执行 `engine.destroyContext()`，彻底释放内存。

### 3.3 沙箱临时文件内存/磁盘爆炸防护 (核心经验)

这是 iOS 相册同步最致命的隐坑：
- **问题原因**：
  在 iOS 上，`photo_manager` 获取本地大图/视频原始文件（`asset.originFile`、`asset.originFileWithSubtype`）时，系统相册接口必须先将原数据从系统 PhotoKit 数据库解压/拷贝到应用的沙箱临时目录（`tmp/` 或 `Caches/`）。
- **灾难后果**：
  如果不主动清理，如果用户相册有 20GB 照片正在同步，应用沙箱会在几分钟内填满 20GB 临时文件，触发系统杀进程或报设备存储空间不足。
- **源码中的防御代码 (`lib/storage/storage.dart:187`)**：
  ```dart
  } finally {
    if (Platform.isIOS) {
      Future.delayed(const Duration(milliseconds: 200), () {
        try {
          file.deleteSync();
          liveVideoFile?.deleteSync();
        } catch (e) {
          logger.addLog("delete file failed: $e");
        }
      });
    }
  }
  ```
  在照片上传成功或失败后，必须立即主动删除沙箱临时缓存。

### 3.4 Live Photo (实况照片) 机制

- **构成**：
  iOS Live Photo 实际上由两部分构成：一张静态高清照片（通常是 HEIC/JPG）和一段配对的高帧率短视频（通常为 `.MOV`，1.5 秒到 3 秒）。
- **提取逻辑**：
  - 静态图：`asset.local!.originFile`
  - 配套视频：`asset.local!.originFileWithSubtype`（在旧版 API 中为 `fileWithSubtype`）
- **上传路由**：
  1. 静态图上传到 `/YYYY/MM/DD/YYYYMMDDhhmmss_IMG_0001.HEIC`。
  2. 配对短视频上传到 `/live/YYYYMMDDhhmmss_IMG_0001.MOV`（在服务端自动组织在 `live_IMG_0001/` 目录下）。
- **浏览体验 (`GalleryViewerRoute`)**：
  在大图浏览界面，检测到 `asset.isLivePhoto()` 时，长按屏幕即可自动加载远端或本地配对视频，通过 `VideoPlayerController` 播放动态效果，松手淡出恢复静态大图。

### 3.5 屏幕常亮与唤醒控制

大批量同步需要数十分钟，若息屏会导致网络中断或进程被系统冻结：
- 源码绕过了 `wakelock_plus` 插件的 Method Swizzling（在部分 iOS 版本上不可靠），直接在 Native 端控制：
  ```swift
  case "keepScreenOn":
    UIApplication.shared.isIdleTimerDisabled = enable
    result(true)
  ```

### 3.6 静默本地通知 (Passive Notifications)

后台同步通常发生在深夜用户充电时：
- iOS 支持设置 `UNNotificationInterruptionLevel.passive`。
- 如果当晚同步了 0 张照片，静默不发送；当有同步完成时，投递 passive 通知，不响铃、不亮屏，静静收录在通知中心中。

---

## 4. 双端原生通道（Method Channels）全景清单

| 通道名称 (Channel Name) | 方法 (Method) | 方向 | 参数 / 返回值 | 适用平台 | 功能说明 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `com.example.img_syncer/RunGrpcServer` | `RunGrpcServer` | Flutter -> Native | 无 -> 返回 `"grpcPort,httpPort"` | 双端 | 启动嵌入式 Go 服务并获取监听端口 |
| `com.example.img_syncer/RunGrpcServer` | `scanFile` | Flutter -> Native | `{path, volumeName, relativePath, mimeType}` -> null | Android | 通知 Android MediaStore 刷新新增媒体文件 |
| `com.example.img_syncer/notifications` | `requestAuthorization` | Flutter -> Native | 无 -> 返回 `bool` | iOS | 申请 UNUserNotificationCenter 通知权限 |
| `com.example.img_syncer/notifications` | `checkAuthorizationStatus` | Flutter -> Native | 无 -> 返回 `bool` | iOS | 检查通知权限是否已授权 |
| `com.example.img_syncer/notifications` | `sendLocalNotification` | Flutter -> Native | `{title, body, isPassive}` -> 返回 `bool` | iOS | 发送本地横幅/通知中心通知 |
| `com.example.img_syncer/notifications` | `getBackgroundRefreshStatus`| Flutter -> Native | 无 -> 返回 `0/1/2` (受限/拒绝/可用) | iOS | 检查系统“后台 App 刷新”开关是否开启 |
| `com.example.img_syncer/notifications` | `scheduleBgTask` | Flutter -> Native | 无 -> 返回 `bool` | iOS | 向系统提交 `BGProcessingTaskRequest` |
| `com.example.img_syncer/notifications` | `keepScreenOn` | Flutter -> Native | `{enable: bool}` -> 返回 `bool` | iOS | 控制 `isIdleTimerDisabled` 保持屏幕常亮 |
| `com.example.img_syncer/backgroundSync` | `cancel` | Native -> Flutter | 无 | iOS | 系统即将回收后台时通知 Dart 中断同步 |
| `com.example.img_syncer/backgroundSync` | `complete` | Flutter -> Native | `bool` -> null | iOS | Dart 完成同步后通知 Native 销毁 Engine |
