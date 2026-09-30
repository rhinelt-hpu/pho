# 5. 移动端演进路线与技术债清单

本文档归纳了 Pho 当前代码库中已知的架构缺陷、技术债（Technical Debt）以及后续以 **Android & iOS 双端为主线** 的重点演进路线图。

---

## 1. 核心技术债与潜在缺陷

### 1.1 [严重] Android 缺乏真正的系统级后台任务调度
- **现状**：iOS 实现了完整的 `BGProcessingTask` + Headless FlutterEngine 闭环，但 Android 端在 `sync_timer.dart` 中仍使用 Dart `Timer.periodic`。
- **影响**：一旦 Android 应用切入后台、锁屏、或被系统 Doze 省电策略冻结，定时器即刻失效；用户无法在夜间充电时自动静默备份。
- **整改方案**：
  - 引入 `workmanager` 或编写 原生 Kotlin Worker。
  - 创建带有约束条件（`RequiresCharging`, `RequiredNetworkType.UNMETERED`）的 `PeriodicWorkRequest`。
  - 在 Worker 唤醒时执行无 UI 的同步流程并处理 Notification。

### 1.2 [安全] WebDAV 全局禁用 TLS 证书校验 (`InsecureSkipVerify: true`)
- **位置**：`server/drive/webdav/webdav.go:34`
- **问题**：客户端硬编码跳过了 HTTPS 证书验证。
- **影响**：在公网网络或公共 WiFi 环境下，易受到中间人攻击（MITM），密码与敏感照片数据可能被窃听。
- **整改方案**：在 WebDAV 设置界面增加“允许自签名证书”开关，默认启用严格证书校验，允许高级用户针对特定私有域名放宽。

### 1.3 [性能] SMB 驱动单互斥锁串行化下载 (`downloadLock`)
- **位置**：`server/drive/smb/smb.go`
- **问题**：所有 `Download` 和 `DownloadWithOffset` 均被一把全局互斥锁串行化。
- **影响**：画廊多图并发拉取缩略图、或一边看视频一边加载大图时，会发生严重的锁争用，网络利用率低下。
- **整改方案**：评估建立轻量级的 SMB 客户端连接池，或解耦只读文件的并发读取操作。

### 1.4 [扩展性] `FilterNotUploaded` 全量目录遍历性能瓶颈
- **位置**：`server/api/img.go` & `server/imgmanager/imgmanager.go`
- **问题**：每次刷新未同步列表时，Go 端调用 `RangeByDate(time.Now(), ...)`，从当前年份递归遍历所有远端目录构建比对基线。
- **影响**：当用户的私有云中积累了数万甚至十万张照片后，每次比对的时间将从几百毫秒飙升至数十秒，造成高频 I/O 阻塞。
- **整改方案**：
  - 在移动端本地记录上次同步成功的最大日期水线（High Watermark）。
  - 对比时仅遍历水线之后的新建日期目录；历史目录使用本地缓存的清单比对。

### 1.5 [体验] Android 14+ / iOS“部分选定照片”权限 (Limited Access)
- **现状**：应用目前主要基于“全部照片授权”设计。
- **影响**：Android 14 (API 34) 引入了部分照片访问权限，iOS 14+ 也支持“选定的照片”。如果用户仅授权了部分照片，当前应用缺乏明显的 UI 提示引导用户授予完整相册访问。
- **整改方案**：接入 `PhotoManager.requestPermissionExtend()` 返回的 `PermissionState.limited` 状态，在相册列表顶部展示轻量提示条。

---

## 2. 移动端未来版本演进路线图 (Roadmap)

```
+-------------------------------------------------------------------+
| 阶段一：后台同步健全化与生命周期闭环 (当前最高优先级)                |
|   1. 接入 Android WorkManager，补齐 Android 真后台同步能耐          |
|   2. 规范化前台服务 (Foreground Service) 通知与保活                |
|   3. 优化双端网络与电量感知（低电量/蜂窝网络自动挂起）              |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
| 阶段二：相册事件感知与增量性能飞跃                                  |
|   1. 接入相册变动监听 (PhotoKit / MediaStore Change Observer)     |
|   2. 新增照片即时加入同步队列，无需全量轮询对比                    |
|   3. 优化 SMB 并发读性能与 FilterNotUploaded 水线索引               |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
| 阶段三：多端交互与画廊体验打磨                                     |
|   1. 双端 HEIC / RAW 格式解码速度与缩略图加载平滑度优化             |
|   2. 自定义相册过滤（支持多相册同时同步、黑名单相册排除）          |
|   3. 完善离线缓存管理，提供更直观的本地缓存一键清理               |
+-------------------------------------------------------------------+
```

---

## 3. 架构演进决策速查表 (ADR - Architectural Decision Records)

### ADR-01: 坚持单进程嵌入 Go 核心，而非剥离为外部独立 Docker 容器
- **背景**：部分开发者提议将 Go 端改为独立的后端容器，手机端纯做客户端。
- **决议**：**坚决维持 Gomobile 嵌入式架构**。
- **理由**：Pho 的核心价值在于“手机随身携带，直连家庭 NAS，无中间服务端”。维持无中心服务架构，能让非技术用户零门槛部署使用，无安全隐私外泄风险。

### ADR-02: 存储结构坚持无数据库、文件系统即存储
- **背景**：是否引入 SQLite 保存文件元数据与索引。
- **决议**：**远端保持无数据库，仅允许在移动端本地做只读的持久化辅助缓存**。
- **理由**：用户可以直接拿移动硬盘插电脑拷照片，不被任何专有数据库格式绑定。

---

## 4. 原商业/会员阉割功能清单与开源补齐方案

在项目历史上，原闭源版本曾将以下 6 项核心能力作为付费会员门控或在开源发布时剥离。当前代码库均已标记 `// TODO(open-source):`，便于后续按部就班补齐：

| 阉割功能 | 涉及代码位置 | 当前现状 | 后续补齐指引 |
| :--- | :--- | :--- | :--- |
| **1. 文件筛选器 (File Filter)** | `lib/sync/background_runner.dart` (`shouldSyncAsset`)<br>`lib/state_model.dart` (`SettingModel`) | 逻辑仅判断 `uploadedIds`，视频/图片/日期/扩展名过滤被移除 | 1. 在 `SettingModel` 恢复 `filterSwitch`、`filterNoVideo`、`filterNoImage`、`filterAfter`、`filterBefore`、`filterTypeMap`。<br>2. 在 `shouldSyncAsset` 恢复对应判断。<br>3. `test/widget/sync_body_test.dart` 已包含全量过滤单元测试契约。 |
| **2. 并发上传调优 (Parallel Upload)** | `lib/sync_body.dart:242`<br>`lib/sync_timer.dart:67`<br>`lib/background_sync_entrypoint.dart:143` | 硬编码 `parallelCount: 1`，无法调优传输吞吐量 | 1. 在 `SettingModel` 引入 `parallelCount`（默认 1，允许 1~8）。<br>2. 在设置界面提供 Slider/Stepper 滑动条。<br>3. 调度时动态传给 `runSyncOnce(parallelCount: settingModel.parallelCount)`。 |
| **3. 目录结构配置 (Directory Layout)** | `lib/settings_route.dart`<br>`server/api/img.go`<br>`proto/img_syncer.proto` | Go 后端已有 `SetDirectoryType` RPC，但移动端前端缺少 UI 设置项 | 1. 在 `SettingsRoute` 增加“目录组织结构”设置项。<br>2. 提供“按日期多层级 (`YYYY/MM/DD`)”与“按日期单层级 (`YYYYMMDD`)”单选框。<br>3. 调用 `storage.cli.setDirectoryType()` 并持久化到 `SharedPreferences`。 |
| **4. AES 加密配置 UI (Encryption UI)** | `lib/settings_route.dart`<br>`lib/global.dart` | Go 后端已完整支持 AES-256-GCM / CFB 加密与 Range 播放，但设置页缺少配置入口 | 1. 在设置页增加“端到端加密”分组。<br>2. 提供启用 Switch、加密算法下拉菜单（推荐 AES-256-GCM）、密码输入与确认框。<br>3. 调用 `settingModel.setEncryptSwitch` / `setEncryptionType` / `setEncryptionPassword`。 |
| **5. 自定义主题色选择器 (Theme Picker)** | `lib/settings_route.dart`<br>`lib/theme.dart`<br>`lib/main.dart` | `main.dart` 支持从 `seed_color` 读取动态主题，`theme.dart` 预置了 7 种配色，但缺少选择界面 | 1. 在设置页增加“主题与外观”入口。<br>2. 使用圆点调色板展示 `seedThemeColors`。<br>3. 点击后调用 `AdaptiveTheme.of(context).setTheme()` 并存入 `prefs.setInt('seed_color', color.value)`。 |
| **6. 百度网盘与更多网盘支持 (Baidu / Alist)** | `lib/setting_storage_route.dart`<br>`lib/storageform/`<br>`server/drive/`<br>`proto/img_syncer.proto` | 原 `baidu_netdisk.dart` 及服务端驱动被剥离，仅保留 SMB/WebDAV/NFS | 1. 在 `Drive` 枚举恢复扩展支持。<br>2. 可优先考虑接入更通用的开源网盘中继（如支持 WebDAV 的 Alist 或 rclone），或重新实现百度开放平台 OAuth 授权。 |

