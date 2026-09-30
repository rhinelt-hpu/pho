# 3. 同步流水线与网络存储协议

本文档详细解析 Pho 的核心同步算法、两阶段提交保障机制以及底层支持的三大网络存储协议（SMB、WebDAV、NFS）。

---

## 1. 增量同步流水线 (Sync Pipeline)

同步流水线负责将手机系统相册（几十 GB 至上百 GB、数万张照片）高效、断点可续、安全地同步至网络存储中。

```
[阶段 1: 相册检索] 
  PhotoManager 分页扫描 (start, offset+pageSize)
  按 createDate 倒序排序
          |
          v
[阶段 2: 差异对比 (FilterNotUploaded)]
  Flutter 客户端向 Go 内核发起双向 gRPC 流
  Go 内核遍历远程时间目录对比已存在的文件
  返回: uploadedIDs (已上传) 与 notUploadedIDs (待上传)
          |
          v
[阶段 3: 并发与断点调度 (runSyncOnce)]
  信号量限制并发 (Semaphore)
  检查 shouldStop() 取消标志与失败熔断 (failedTimes > 10)
          |
          v
[阶段 4: 三段式上传 (HTTP Streamed POST)]
  Step 4.1: POST /thumbnail/<name> (上传高质缩略图)
  Step 4.2: POST /<name> (流式上传高清原图)
  Step 4.3: POST /live/<name> (如果是 Live Photo 则上传配对视频)
          |
          v
[阶段 5: 本地清理与两阶段提交]
  iOS 沙箱清理 temp file
  更新 stateModel.syncedIDs 并持久化到 SharedPreferences
```

---

## 2. 差异比对与两阶段提交保障

### 2.1 双向流比对 (`FilterNotUploaded`)

为了在成千上万张照片时不耗尽手机内存，对比过程使用双向 gRPC 流式传输：
1. **请求流**：Flutter 客户端批量将本地照片以 100 张一组封装成 `FilterNotUploadedRequest` 发送给 Go 服务。
   每个条目包含：`id`（相册 Asset ID）、`name`（原始文件名）、`date`（拍摄时间戳，格式 `2006:01:02 15:04:05`）。
2. **服务端匹配**：
   Go 服务端计算 `encodeName(date, name)`，通过 `RangeByDate` 在远端存储中进行逆向查找。
3. **响应流**：
   返回 `uploadedIDs` 和 `notUploadedIDs`。

### 2.2 两阶段提交 (Two-Phase Commit) 防丢机制

在移动端网络不稳定或用户中途切后台时，老版本曾出现过“部分对比结果覆盖全量状态”导致未同步状态丢失的 Bug。当前版本采用**两阶段提交**设计（`lib/state_model.dart`）：
- **阶段一（收集）**：在流式接收 `receiveResponses` 期间，不直接修改全局的 `syncedIDs`，而是将结果追加至局部临时列表 `accumulatedIDs`。
- **阶段二（提交）**：仅当双向流正常结束且未被用户/系统中断（`!assetModel.refreshUnsynchronizedNeedBreak`）时，对 `accumulatedIDs` 集合执行 `toSet().toList()` 去重，一次性原子更新 `stateModel.syncedIDs` 并持久化到 `SharedPreferences` 的 `synced_ids`。

---

## 3. 并发控制与熔断保护 (`runSyncOnce`)

核心同步逻辑封装在纯函数 `runSyncOnce`（`lib/sync/background_runner.dart`）中，UI 线程与后台任务共用此逻辑：

1. **信号量控制 (`Semaphore(parallelCount)`)**：
   - 默认并发数设置为 `1`（确保移动端弱网环境和低端 NAS 的连接稳定性）。
   - 采用 `unawaited(storage.uploadAssetEntity(...))` 结合信号量实现非阻塞并发。
2. **连续失败熔断 (Circuit Breaker)**：
   - 维护 `failedTimes` 计数器。
   - 每发生一次异常（如网络断开、NAS 掉电、磁盘已满），`failedTimes++`；成功一次则递减。
   - **当 `failedTimes > 10` 时，立即中止本次同步轮次**，防止数千张照片在断网情况下持续重试造成电量和系统资源浪费。
3. **安全等待在途任务**：
   在中途 break 退出循环后，通过循环获取全部信号量 permit 等待所有飞行中的上传任务彻底完成，确保没有悬空的文件读写句柄。

---

## 4. 三大网络存储驱动深度对比

Go 内核通过 `server/imgmanager/interface.go` 中的 `StorageDrive` 接口抽象所有底层协议：
```go
type StorageDrive interface {
    Upload(name string, reader io.Reader) (size int64, err error)
    Download(name string) (io.ReadCloser, int64, error)
    DownloadWithOffset(name string, offset int64) (io.ReadCloser, int64, error)
    Delete(paths []string) error
    Range(f func(fs.FileInfo) bool) error
}
```

### 4.1 SMB (Samba) 驱动 (`server/drive/smb/`)

- **底层依赖**：`github.com/hirochachacha/go-smb2`（支持 SMB 2.x / 3.x 协议）。
- **认证方式**：NTLM 认证（支持通过 `domain;user:pass` 指定域）。
- **连接管理**：懒连接机制（Lazy Connect），内部维护连接时间戳，提供 5 分钟闲置超时（TTL）自动重连。
- **关键限制与已知技术债**：
  - **`downloadLock` 串行互斥锁**：SMB 驱动内部为了防止多协程并发拉取同一个会话导致协议乱序，在所有下载（包括 `Download` 和 `DownloadWithOffset`）上加了互斥锁。**这导致 SMB 的大图加载和视频播放完全串行化**。

### 4.2 WebDAV 驱动 (`server/drive/webdav/`)

- **底层依赖**：`fregie/gowebdav`（官方库的定制分支）。
- **认证方式**：HTTP Basic Auth。
- **并发控制**：`mkdirLock`。由于 WebDAV 批量创建递归多级目录（`MKCOL`）容易出现竞争导致 405 Method Not Allowed，目录创建通过全局互斥锁保护。
- **关键限制与已知技术债**：
  - **`InsecureSkipVerify: true`**：WebDAV 客户端全局跳过了 TLS 证书校验。虽然方便了使用自签名证书的家庭 NAS，但在公网传输环境下存在中间人攻击（MITM）风险。

### 4.3 NFS 驱动 (`server/drive/nfs/`)

- **底层依赖**：`fregie/go-nfs-client`。
- **协议版本**：NFS v3。
- **连接管理**：维护 2 分钟闲置超时，超时后重新 Mount 挂载，并通过 `FSInfo()` 进行健康探测。
- **关键限制与已知技术债**：
  - **`AUTH_UNIX` 默认 Root**：NFS 请求直接使用 uid=0、gid=0 发起，无用户密码加密鉴权，仅适用于可信的家庭局域网。

---

## 5. 加密体系与流媒体 Range 播放

Pho 支持在上传时对文件进行端到端加密，确保即便网络存储设备被物理盗取，照片与视频也不会泄露。

### 5.1 CFB vs GCM 机制对比

| 特性 | AES-128-CFB (旧版) | AES-256-GCM (现代版) |
| :--- | :--- | :--- |
| **文件头部** | 16 字节随机 IV | 4 字节魔数 `PHO1` + 认证 Tag |
| **认证加密** | 否（仅保密性） | 是（AEAD，防篡改） |
| **随机偏移定位 (Seek / Offset)** | **不支持**（必须从第 0 字节顺序解密） | **支持**（分块独立解密） |
| **HTTP Range 视频点播** | ❌ 失败（无法在线快进/跳转） |  完美支持（可拖动进度条） |
| **文件后缀** | `.aes` | `.aes` |

### 5.2 视频 Range 请求处理流程

在 `server/api/http.go` 中，处理客户端（如 `video_player` / `chewie`）的 Range 请求：
1. 客户端发送：`Range: bytes=1048576-2097151`。
2. Go 服务端解析偏移量 `start=1048576, end=2097151`。
3. 调用 `imgManager.GetOffset(path, start)`：
   - 若文件未加密：底层驱动通过 `DownloadWithOffset` 从远程流式 Seek 读取。
   - 若文件为 GCM 加密：自动计算对应的加密分块，跳过前半部，解密指定区间字节。
   - 若文件为 CFB 加密：直接返回错误，客户端捕获后降级为全量下载到临时文件播放。
4. Go 服务端响应 `206 Partial Content`，设置 `Content-Range: bytes 1048576-2097151/总字节数`。
