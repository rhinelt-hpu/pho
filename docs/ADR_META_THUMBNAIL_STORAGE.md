# 6. 架构决策记录 (ADR) 与领域模型：独立元数据与缩略图存储后端

本文档记录「元数据及缩略图独立存储后端（冷热存储分离）」的核心领域词汇（Glossary）与架构决策记录（ADR）。

---

## 一、 领域词汇表 (Glossary)

| 领域术语 | 英文 / 代码标识 | 定义与职责 |
| :--- | :--- | :--- |
| **主存储后端** | `Primary Drive` / `dri` | 大容量远端存储（WebDAV / SMB / NFS），负责存储高体积、低频访问的**原图**、**原视频**及 **Live Photo 配套视频**。 |
| **元数据与缩略图后端（副存储）** | `Meta Drive` / `metaDri` | **可选**的高速、低延迟远端存储（WebDAV / SMB / NFS），专门存放高频访问的 **`.manifest/`（元数据快照与增量切片）** 与 **`.thumbnail/`（缩略图及相册目录骨架）**。未开启时自动指向主存储 `dri`。 |
| **相册目录骨架** | `Album Skeleton` | 在副存储 `.thumbnail/<Album>` 下与主存储同步维护的相册目录树，用于让 `ListAlbums` 在不访问慢速主存储的情况下识别所有相册（含空相册）。 |
| **元数据重建** | `RebuildManifest` | 服务端通过扫描主存储目录树（仅获取文件名、体积、修改时间，不下载文件内容），重构全量 `.manifest` 快照并同步相册骨架至副存储。 |
| **缩略图补齐** | `Thumbnail Backfill` | 当远端 `.thumbnail/` 缺失时，优先利用手机本地相册原片通过系统原生硬件解码生成缩略图重传；若本地已无原片，则在浏览回退加载主存储原图后按需回填。 |

---

## 二、 架构决策记录 (ADRs)

### ADR-01：冷热数据分离与双 `StorageDrive` 路由规则

- **背景**：部分大容量网盘/WebDAV 空间充足但高并发小文件读写（PROPFIND / 拉取缩略图 / 读写 `.manifest`）延迟极高；而轻量级 WebDAV/NAS 响应快但容量有限。
- **决策**：
  在 `ImgManager` 中维护主存储 `dri` 与可选副存储 `metaDri`（提供统一的 `metaDrive()` 访问器：当 `metaDri` 未启用时返回 `dri`）：
  1. **只走主存储 (`dri`)**：
     - `Upload`（原图流式写入）
     - `UploadLiveVideo`（Live Photo 视频写入）
     - `GetImg` / `GetOffset` / `GetLiveVideoOffset`（大图查看、视频 HTTP Range 流式播放）
  2. **只走副存储 (`metaDrive()`)**：
     - `UploadThumbnail`（上传缩略图至 `.thumbnail/<path>`）
     - `Manifest.Sync` / `AppendChunk` / `Compact`（读写 `.manifest/`）
  3. **双端协同操作 (`dri` + `metaDrive()`)**：
     - `GetThumbnail`：先从 `metaDrive()` 读取 `.thumbnail/<path>`；若缺失，直接回退读取主存储 `dri` 的 `<path>` 原图（不二次探测主存储 `.thumbnail`）。
     - `DeleteSingleImg`：`metaDrive()` 删除 `.thumbnail/<path>` 并追加删除记录至 `.manifest/`；`dri` 删除原图及 `live_` 目录。
     - `CreateAlbum` / `DeleteAlbum` / `RenameAlbum` / `MoveAssets`：同时变更 `dri` 下的原图相册目录与 `metaDrive()` 下的 `.thumbnail/<Album>` 目录，并将变更写入 `metaDrive()` 的 `.manifest`。

---

### ADR-02：上传强一致性与错误中断策略

- **背景**：当原图与缩略图/元数据分布在不同后端时，若某一方网络异常，可能导致“有原图无元数据”或“有缩略图无原图”的状态分裂。
- **决策**：
  - 上传流程中，`UploadThumbnail`（写入 `metaDrive`）、`Upload`（写入 `dri`）以及 `manifest.AppendChunk`（写入 `metaDrive`）**任一步骤返回错误均立即中断并向客户端返回失败**，触发客户端重试或失败熔断，确保双端状态严格一致。
  - 加密策略：副存储的缩略图加解密完全复用全局统一的加密开关、加密算法（`AES_128_CFB` / `AES_256_GCM`）与密码，不设独立密码。

---

### ADR-03：`ListAlbums` 云端相册列表零主存储 I/O 优化

- **背景**：原有 `ListAlbums()` 实现中，即便内存 `.manifest` 已就绪，仍会先调用 `im.listDir(dri, ".")` 扫描主存储根目录以获取空相册。当主存储较慢时，每次打开云相册都会卡顿。
- **决策**：
  - 当启用了独立副存储 `metaDri` 且 `.manifest` 已初始化时，`ListAlbums()` 通过扫描高速副存储的 `.thumbnail/` 根目录获取相册文件夹列表（结合 `.manifest` 中的相册名合集），**完全跳过对主存储 `dri` 的 `listDir` 调用**。
  - `CreateAlbum` / `RenameAlbum` / `DeleteAlbum` 均保证在 `metaDrive()` 的 `.thumbnail/<Album>` 下同步创建、重命名或删除对应相册目录。

---

### ADR-04：为什么程序支持视频/HEIC，但「重建缩略图」不能纯靠 Go 服务端？

- **背景**：Pho 完整支持苹果 `HEIC`、相机 `RAW/DNG` 以及各类视频（`MP4`/`MOV` 等）的上传、浏览和播放。但为何不能让 Go 服务端直接从主存储拉取文件来生成缩略图？
- **技术原因**：
  1. **日常上传时是谁生成的缩略图**：在日常同步（`lib/storage/storage.dart`）中，是 **Flutter 客户端在上传前**调用手机操作系统原生接口（iOS `PhotoKit` / Android `MediaStore`，即 `asset.thumbnailDataWithSize`）利用手机硬件解码器提取出视频首帧或将 `HEIC` 转为 `JPEG` 字节流，再通过 `POST /thumbnail/<name>` 发给 Go 服务端的。Go 服务端自始至终只负责加密和透传字节流，本身并未内置视频解码器（`ffmpeg`）或 `libheif` 解码库（Gomobile 交叉编译静态库打包 `ffmpeg` 会导致安装包膨胀数倍且存在专利/编译兼容问题）。
  2. **慢速主存储带宽瓶颈**：如果从慢速 WebDAV 拉取几十 GB 的高清视频和原图来截帧压缩，网络 I/O 代价极高。
- **决策（采用方案一：服务端重建元数据 + 客户端补齐缩略图）**：
  1. **重建元数据 (`.manifest` + 相册目录骨架)**：由 Go 服务端直接扫描主存储目录树（仅读文件名与大小，0 原图下载），秒级重建副存储的 `.manifest/` 快照与 `.thumbnail/<Album>` 目录结构。
  2. **重建/补齐缩略图 (`.thumbnail`)**：
     - **阶段 A（手机本地相册快补）**：对手机本地相册仍存在的已同步照片，客户端直接调用系统原生 `thumbnailDataWithSize` 生成缩略图，仅调用 `POST /thumbnail/<name>` 快速补齐到副存储（不重传原图，完美支持视频/HEIC/加密）。
     - **阶段 B（浏览时按需回填）**：对于手机本地已删除、仅主存储有原图的历史照片，当云端画廊加载缩略图触发回退读取主存储原图时，按需缓存并可异步回填至副存储 `.thumbnail/`。

---

### ADR-05：UI 交互与配置导入导出 (`StorageConfig`)

- **UI 布局（单页上下排列 + 唯一全局按钮）**：
  - 在「存储设置」页面中，上半部分展示「主存储（原图与视频）」协议选择与表单；
  - 下半部分提供 `启用独立元数据与缩略图存储` 开关，展开后展示完全一致的协议选择（SMB / WebDAV / NFS）与表单输入项；
  - 页面底部仅保留**唯一一组全局 `[测试连接]` 与 `[保存]` 按钮**：
    - 点击 `[测试连接]`：依次验证主存储连通性 +（若开启）副存储连通性，全部通过才标记为可保存；
    - 点击 `[保存]`：同时持久化主/副存储配置并调用 `initDrive()` 立即生效。
- **二维码配置迁移 (`StorageConfig`)**：
  - 在 `pho://storage?data=...` 的 JSON 结构中新增可选字段 `meta_enabled`、`meta_drive`、`meta_data`（向下兼容 v1 配置，导入时自动识别并同时测试与恢复主/副存储）。
