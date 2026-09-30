# Pho (移动端重点) 开发者全景文档

欢迎阅读 Pho（相册与网络同步应用）的项目开发指南与架构文档。本文档集主要服务于接下来以 **Android 和 iOS 双端移动开发** 为主线、桌面端为辅助的工程迭代。

---

## 目录索引

| 文档 | 核心内容 | 重点受众 |
| :--- | :--- | :--- |
| **[1. 系统整体架构 (ARCHITECTURE.md)](./ARCHITECTURE.md)** | 前后端分层、无数据库设计哲学、进程内 Go 嵌入式核心、gRPC+HTTP 双通道通信机制 | 架构师 / 核心开发 |
| **[2. Android & iOS 双端深度技术指南 (MOBILE_DUAL_PLATFORM.md)](./MOBILE_DUAL_PLATFORM.md)** | Gomobile 绑定、Native 宿主通道 (MethodChannel)、PhotoKit / MediaStore 相册权限、后台同步 (iOS BGProcessingTask / Android 现状)、Live Photo 处理与沙箱临时文件生命周期 | **移动端主程 / iOS & Android 开发者** |
| **[3. 同步流水线与存储协议 (SYNC_AND_STORAGE.md)](./SYNC_AND_STORAGE.md)** | 未同步扫描与两阶段提交、并发上传调度、SMB/WebDAV/NFS 驱动实现细节、AES-128-CFB 与 AES-256-GCM (PHO1) 加密体系 | 后端驱动 / 数据同步开发 |
| **[4. 构建、开发与调试指南 (DEVELOPMENT_GUIDE.md)](./DEVELOPMENT_GUIDE.md)** | 环境依赖要求、Protobuf 与 Gomobile 编译命令、双端真机/模拟器调试、日志排查与常见踩坑 (FAQ) | 全体开发人员 |
| **[5. 移动端技术债与演进路线 (ROADMAP_AND_TECH_DEBT.md)](./ROADMAP_AND_TECH_DEBT.md)** | 已知关键缺陷（Android 真后台缺失、并发锁、目录遍历瓶颈等）、后续重构建议与关键功能演进计划 | 技术负责人 / 迭代规划 |

---

## 项目快速概览

- **定位**：替代手机自带相册的无数据库相册同步与私有云查看客户端。
- **技术栈**：
  - **移动端前端**：Flutter (Dart 3.x, Flutter 3.x), Material 3, Provider + EventBus 状态管理。
  - **底层内核**：Go 1.25, 嵌入在原生 App 进程内（通过 Gomobile 生成 Android `.aar` 和 iOS `.xcframework`），暴露出本地回环 gRPC (控制面) 和 HTTP (数据面)。
  - **网络存储**：Samba (SMB2/3)、WebDAV、NFS。
  - **组织原则**：文件系统即数据库。照片按 `YYYY/MM/DD` 或 `YYYYMMDD` 组织，根目录 `.thumbnail/` 镜像存储缩略图。

---

## 移动端核心架构图解

```
+---------------------------------------------------------------------------------+
|                                Flutter / Dart UI 层                              |
|   +-------------------+   +--------------------+   +------------------------+   |
|   | 本地相册视图        |   | 云端相册视图       |   | 同步控制面板           |   |
|   | (GalleryBody:local)|   | (GalleryBody:cloud)|   | (SyncBody / Timer)     |   |
|   +-------------------+   +--------------------+   +------------------------+   |
|            |                        |                           |               |
|            v                        v                           v               |
|   PhotoManager (相册访问)    State / Asset Models         BackgroundRunner (并发) |
+---------------------------------------------------------------------------------+
          |                                               |              |
          | (MethodChannel)                               | (gRPC 控制)  | (HTTP 数据)
          v                                               v              v
+-----------------------------------+           +---------------------------------+
|         Native 宿主层 (平台特化)    |           |    嵌入式 Go 服务端 (Gomobile)    |
| [Android]                         |           | - 127.0.0.1:grpcPort (控制指令) |
| - MainActivity.kt                 |           | - 127.0.0.1:httpPort (流式传输) |
| - MediaStore 扫描广播             |           +---------------------------------+
| [iOS]                             |                     |              |
| - AppDelegate.swift               |                     v              v
| - BGProcessingTask (后台唤醒)     |              +-----------------------------+
| - Headless FlutterEngine          |              | ImgManager (核心编排引擎)   |
| - Passive LocalNotification       |              | - 加密 (AES-256-GCM / CFB)  |
+-----------------------------------+              | - 目录生成 & 缩略图镜像     |
                                                   +-----------------------------+
                                                                  |
                                                                  v
                                                   +-----------------------------+
                                                   | 驱动层: SMB / WebDAV / NFS  |
                                                   +-----------------------------+
                                                                  |
                                                                  v
                                                   +-----------------------------+
                                                   | NAS / 私有云网络存储设备    |
                                                   +-----------------------------+
```
