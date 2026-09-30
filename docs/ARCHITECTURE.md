# 1. 系统整体架构与设计模式

本文档详细描述 Pho 项目的系统架构、模块划分、通信机制以及“无数据库”的核心设计理念。

---

## 1. 系统分层全景

Pho 采用“**跨平台 UI + 原生宿主容器 + 嵌入式高并发内核**”的三层架构：

```
+-------------------------------------------------------------------------+
| [Layer 1] Flutter / Dart (UI 与业务控制层)                              |
|   - 状态模型: StateModel, AssetModel, SettingModel (Provider + RxDart)  |
|   - 页面与组件: GalleryBody (瀑布网格), SyncBody (同步中枢), Viewer (大图)  |
|   - 业务引擎: BackgroundRunner (上传并发控制), SyncTimer, EventBus       |
+-------------------------------------------------------------------------+
       | (MethodChannel)                     | (gRPC: 127.0.0.1:grpcPort) | (HTTP: 127.0.0.1:httpPort)
       v                                     v                            v
+------------------------------------+ +---------------------------------------------------+
| [Layer 2] Native 宿主层            | | [Layer 3] Go 嵌入式核心 (Gomobile 单进程内常驻)    |
| - Android: Kotlin (MainActivity)   | | - api: gRPC 服务实现 (13+ RPC) + HTTP 处理器      |
| - iOS: Swift (AppDelegate)         | | - imgmanager: 业务编排、路径规划、AES 加密解密    |
| - 生命周期响应、权限中继、后台保活 | | - drive: 底层协议实现 (SMB / WebDAV / NFS)        |
+------------------------------------+ +---------------------------------------------------+
                                                                  |
                                                                  v
                                              +---------------------------------------+
                                              | [外部目标] 远程私有存储 (NAS / 云存储) |
                                              +---------------------------------------+
```

---

## 2. 核心通信拓扑

应用运行时，Flutter 与 Go 内核位于**同一个操作系统进程**中。二者不走传统的跨进程 IPC，而是通过本地网络回环（`127.0.0.1`）通信：

### 2.1 启动与端口探测
1. Flutter 在 `Global.init()` 或后台 entrypoint 阶段，调用 MethodChannel `com.example.img_syncer/RunGrpcServer` 的 `RunGrpcServer` 方法。
2. Native 层调用 Gomobile 导出的 `Run.runGrpcServer()`（Android）或 `RunRunGrpcServer()`（iOS）。
3. Go 内核在 `10000` 到 `20000` 端口段内顺序扫描，分别绑定可用的 `grpcPort` 和 `httpPort`。
4. Go 内核向 Native 返回 `"grpcPort,httpPort"` 字符串，Native 通过 MethodChannel 返回给 Flutter。
5. Flutter 构造 `RemoteStorage("127.0.0.1", grpcPort)` 并配置 `httpBaseUrl = "http://127.0.0.1:$httpPort"`。

### 2.2 控制面（Control Plane）：gRPC
用于配置、鉴权、目录列表、照片元数据对比、文件删除等结构化指令：
- **协议**：HTTP/2 + Protobuf (`proto/img_syncer.proto`)。
- **健康检查**：`Ping(PingRequest)`，返回服务端启动时间与运行秒数。Flutter 端通过 `checkServer()` 探测，超时或失败则重新拉起 Go 服务。
- **双向流**：`FilterNotUploaded` 用于批量比对本地资产与远端资产，避免单次大数据包内存溢出。

### 2.3 数据面（Data Plane）：HTTP/1.1
用于原图、缩略图、Live Photo 视频的大文件上传与流式下载/播放：
- **上传**：
  - `POST /<fileName>`：流式上传原图原文件。
  - `POST /thumbnail/<fileName>`：上传客户端预压缩好的缩略图（JPEG 200x200 或视频首帧 800x800）。
  - `POST /live/<videoName>`：上传 Live Photo 对应的 MOV 视频。
- **下载与流媒体**：
  - `GET /<filePath>`：原图/原视频拉取。
  - `GET /thumbnail/<filePath>`：缩略图流式拉取。
  - `GET /live/<filePath>`：Live Photo 配套视频拉取。
  - **HTTP Range 支持**：当视频播放器或原图请求带有 `Range: bytes=start-end` 请求头时，Go 服务返回 `206 Partial Content`，实现大视频无需全量下载即可拖动进度条播放。

---

## 3. “无数据库”设计哲学与文件布局

Pho 遵循 **File-System-as-Database**（文件系统即数据库）理念：
- **不依赖 SQLite / MySQL / PostgreSQL**：远端存储目录完全自解释、可移植。用户随时可以使用第三方文件管理器、Windows 资源管理器或 rsync 直接访问同步上去的照片。
- **时间层级目录组织**：
  支持两种目录组织结构（由 `DirectoryType` 控制）：
  - **Type 01（默认多层级）**：`/{root}/YYYY/MM/DD/YYYYMMDDhhmmss_fileName.ext[.aes]`
  - **Type 02（单层级）**：`/{root}/YYYYMMDD/YYYYMMDDhhmmss_fileName.ext[.aes]`
- **文件名编码规则 (`encodeName`)**：
  将拍摄时间与原文件名拼接：`YYYYMMDDhhmmss_` + `原始文件名`。例如：`20231024153012_IMG_4021.JPG`。
  解码时（`decodeName`），前 14 字符加下划线为时间戳，第 15 位起为原始文件名。
- **缩略图镜像目录**：
  在远端存储根目录下自动创建 `.thumbnail/`，其内部目录结构与原图完全镜像。客户端优先拉取 `.thumbnail/` 下的微缩图，极大降低画廊加载流量。
- **Live Photo 关联**：
  Live Photo 配套的视频存放在同级目录下的 `live_<photoName>/` 文件夹中。

---

## 4. 状态与资产模型 (State & Asset Model)

Flutter 端采用响应式状态管理：

```
       [EventBus]
      /          \
LocalRefresh    RemoteRefresh
    |                  |
    v                  v
[AssetModel] <---> [StateModel] <---> [SettingModel]
- localAssets       - syncedIDs (持久化) - 存储连接参数
- remoteAssets      - uploadProgress     - 加密配置
- titleCache        - isOnline           - 本地相册路径
```

1. **`Asset` 抽象**：
   - 继承自 Flutter 原生 `ImageProvider<Asset>`，能够无缝配合 `Image`、`ExtendedImage` 等组件渲染。
   - 兼具 `local` (`AssetEntity`，来自 `photo_manager`) 与 `remote` (`RemoteImage`，来自 gRPC/HTTP)。
   - 惰性加载元数据：大小、Exif、视频时长、Live Photo 控制器均在需要时异步拉取并缓存。
2. **`StateModel`**：
   - 维护 `syncedIDs`（已同步的本地资产 ID 集合），持久化至 `SharedPreferences` 的 `synced_ids`。
   - 维护单张照片上传/下载的实时进度，驱动 UI 进度圈刷新。
3. **`AssetModel`**：
   - 维护本地和远端资产列表的分页游标与缓存。
   - 提供 `titleCache`（本地照片 ID 到文件名的缓存），解决 iOS 上高频读取 `asset.titleAsync` 导致的系统卡顿。

---

## 5. 安全与加密体系

为了保护用户在私有云或公网存储上的隐私，内核提供端到端透明加解密：

1. **AES-128-CFB（旧版兼容模式）**：
   - 流式加密，前 16 字节为随机 IV。
   - 缺陷：不支持随机偏移（Offset Seek），导致视频流式播放（HTTP Range）无法在加密文件上工作。
2. **AES-256-GCM（现代推荐模式）**：
   - 文件头部包含 4 字节魔数 `PHO1`。
   - 采用分块加密策略，具备认证加密（AEAD）防篡改能力。
   - **支持随机 Seek**：HTTP Range 请求可直接定位并解密指定字节分片，加密视频也能流畅点播。
3. **密钥派生 (KDF)**：
   - 用户密码经由迭代哈希生成加密 Key。
   - 加密上传时，文件名末尾附加 `.aes` 后缀，如 `IMG_0001.JPG.aes`；服务端与客户端读取时自动识别魔数并解密输出。

---

## 6. 双端在整体架构中的定位

| 维度 | 移动端 (Android / iOS) - **核心** | 桌面端 (macOS / Windows / Linux) - **次要** |
| :--- | :--- | :--- |
| **定位** | 核心同步工具、日常移动相册 | 辅助远端相册查看器、大屏管理 |
| **本地相册** | 完整对接（PhotoKit / MediaStore） | 仅做文件系统浏览或不接入本地同步 |
| **后台同步** | 核心需求（iOS BGProcessingTask / Android 保活） | 无此需求（常驻前台运行） |
| **底层打包** | Gomobile 绑定（`.aar` / `.xcframework`） | CGO 导出共享库（`.so` / `.dll`） |
| **传感器与特性** | 屏幕常亮控制、网络切换监听、Live Photo 播放 | 纯键盘鼠标交互 |
