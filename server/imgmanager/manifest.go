package imgmanager

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	ManifestDir                = ".manifest"
	DefaultCompactionThreshold = 20
)

// ManifestRecord 代表单个远端文件的状态快照（以指纹为唯一主键）
type ManifestRecord struct {
	Fingerprint string `json:"fingerprint"` // 如 "20260226101441_MVIMG_101441.jpg"
	Album       string `json:"album"`       // 如 "测试" 或 "相机备份"
	Path        string `json:"path"`        // 远端完整相对路径
	Size        int64  `json:"size"`
	Deleted     bool   `json:"deleted"`
	UpdatedAt   int64  `json:"updated_at"` // Unix 秒级时间戳，用于 LWW 最终一致性
}

// ManifestChunk 代表单次或批量变更的不可变增量切片（Append-Only）
type ManifestChunk struct {
	Watermark int64            `json:"watermark"`
	DeviceID  string           `json:"device_id"`
	Timestamp int64            `json:"timestamp"`
	Records   []ManifestRecord `json:"records"`
}

// ManifestSnapshot 代表全量基线快照
type ManifestSnapshot struct {
	Watermark int64                     `json:"watermark"`
	Timestamp int64                     `json:"timestamp"`
	Records   map[string]ManifestRecord `json:"records"`
}

// ManifestManager 负责远端元数据清单的无锁追加、水位线跳过读取与状态同步
type ManifestManager struct {
	mu                    sync.RWMutex
	records               map[string]ManifestRecord // Fingerprint -> ManifestRecord
	maxWatermark          int64
	deviceID              string
	initialized           bool
	localPath             string // 本地持久化缓存路径（如 app_data/manifest_cache.json）
	chunksSinceCompaction int
}

func NewManifestManager(deviceID string) *ManifestManager {
	if deviceID == "" {
		deviceID = fmt.Sprintf("dev_%d", time.Now().UnixNano()%100000)
	}
	return &ManifestManager{
		records:  make(map[string]ManifestRecord),
		deviceID: deviceID,
	}
}

// SetLocalPath 设置本地持久化沙箱路径
func (mm *ManifestManager) SetLocalPath(path string) {
	mm.mu.Lock()
	defer mm.mu.Unlock()
	mm.localPath = path
}

// LoadLocal 从本地磁盘读取持久化快照，实现首屏 0 网络开销极速初始化
func (mm *ManifestManager) LoadLocal() error {
	mm.mu.Lock()
	defer mm.mu.Unlock()
	if mm.localPath == "" {
		return nil
	}
	data, err := os.ReadFile(mm.localPath)
	if err != nil {
		return err
	}
	var snap ManifestSnapshot
	if err := json.Unmarshal(data, &snap); err != nil {
		return err
	}
	mm.records = snap.Records
	mm.maxWatermark = snap.Watermark
	mm.initialized = true
	return nil
}

// saveLocalLocked 将当前内存元数据原子落盘到本地沙箱（调用前需持有锁）
func (mm *ManifestManager) saveLocalLocked() error {
	if mm.localPath == "" {
		return nil
	}
	_ = os.MkdirAll(filepath.Dir(mm.localPath), 0755)
	snap := ManifestSnapshot{
		Watermark: mm.maxWatermark,
		Timestamp: time.Now().Unix(),
		Records:   mm.records,
	}
	data, err := json.Marshal(snap)
	if err != nil {
		return err
	}
	tmpPath := mm.localPath + ".tmp"
	if err := os.WriteFile(tmpPath, data, 0644); err != nil {
		return err
	}
	return os.Rename(tmpPath, mm.localPath)
}

// SaveLocal 公共手动保存接口
func (mm *ManifestManager) SaveLocal() error {
	mm.mu.Lock()
	defer mm.mu.Unlock()
	return mm.saveLocalLocked()
}

// Sync 从远端 .manifest/ 目录加载基线快照与增量日志
// 采用水位线跳跃读取：若快照包含至序号 W，则严格跳过所有序号 <= W 的 chunk，绝无并发读取冲突
func (mm *ManifestManager) Sync(d StorageDrive) error {
	mm.mu.Lock()
	defer mm.mu.Unlock()

	entries := make([]fs.FileInfo, 0)
	err := d.Range(ManifestDir, func(info fs.FileInfo) bool {
		entries = append(entries, info)
		return true
	})
	if err != nil || len(entries) == 0 {
		// 远端暂无 .manifest 目录，保持空即可
		mm.initialized = true
		return nil
	}

	// 1. 查找最高水位线快照 (snapshot_to_<watermark>.json)
	var bestSnapshotName string
	var snapshotWatermark int64 = 0

	type chunkItem struct {
		watermark int64
		name      string
	}
	chunks := make([]chunkItem, 0)

	for _, entry := range entries {
		name := entry.Name()
		if strings.HasPrefix(name, "snapshot_to_") && strings.HasSuffix(name, ".json") {
			parts := strings.TrimSuffix(strings.TrimPrefix(name, "snapshot_to_"), ".json")
			w, err := strconv.ParseInt(parts, 10, 64)
			if err == nil && w > snapshotWatermark {
				snapshotWatermark = w
				bestSnapshotName = name
			}
		} else if strings.HasPrefix(name, "chunk_") && strings.HasSuffix(name, ".json") {
			parts := strings.Split(strings.TrimSuffix(strings.TrimPrefix(name, "chunk_"), ".json"), "_")
			if len(parts) >= 1 {
				w, err := strconv.ParseInt(parts[0], 10, 64)
				if err == nil {
					chunks = append(chunks, chunkItem{watermark: w, name: name})
				}
			}
		}
	}

	// 2. 加载最高基线快照（仅当远端快照高于本地已同步的水位线时才下载）
	hasChanges := false
	startWatermark := mm.maxWatermark
	if bestSnapshotName != "" && snapshotWatermark > mm.maxWatermark {
		rc, _, err := d.Download(filepath.Join(ManifestDir, bestSnapshotName))
		if err == nil {
			defer rc.Close()
			var snap ManifestSnapshot
			if err := json.NewDecoder(rc).Decode(&snap); err == nil {
				mm.records = snap.Records
				mm.maxWatermark = snap.Watermark
				startWatermark = snap.Watermark
				hasChanges = true
			}
		}
	} else if snapshotWatermark > startWatermark {
		startWatermark = snapshotWatermark
	}

	// 3. 排序所有 chunk
	sort.Slice(chunks, func(i, j int) bool {
		return chunks[i].watermark < chunks[j].watermark
	})

	// 4. 水位线过滤与日志重放：严格跳过 <= startWatermark 的切片！
	for _, chunk := range chunks {
		if chunk.watermark <= startWatermark {
			continue // 绝不重复回放已纳入快照或本地已有的旧切片
		}
		rc, _, err := d.Download(filepath.Join(ManifestDir, chunk.name))
		if err != nil {
			continue // 容错跳过
		}
		var c ManifestChunk
		err = json.NewDecoder(rc).Decode(&c)
		rc.Close()
		if err != nil {
			continue
		}

		for _, rec := range c.Records {
			existing, exists := mm.records[rec.Fingerprint]
			// LWW: 时间戳更新者覆盖旧状态
			if !exists || rec.UpdatedAt >= existing.UpdatedAt {
				mm.records[rec.Fingerprint] = rec
			}
		}
		if chunk.watermark > mm.maxWatermark {
			mm.maxWatermark = chunk.watermark
		}
		hasChanges = true
	}

	if hasChanges {
		_ = mm.saveLocalLocked()
	}

	// 5. 自动碎片压缩与垃圾回收检查：
	// 若远端存在 >= DefaultCompactionThreshold 个切片文件：
	// - 若当前最高水位线高于快照，压缩并生成新快照并清理旧碎片；
	// - 若快照已是最新，直接触发异步清理旧碎片。
	if len(chunks) >= DefaultCompactionThreshold && mm.maxWatermark > 0 {
		chunksToPrune := make([]string, 0, len(chunks))
		for _, c := range chunks {
			if c.watermark <= mm.maxWatermark {
				chunksToPrune = append(chunksToPrune, filepath.Join(ManifestDir, c.name))
			}
		}
		if snapshotWatermark < mm.maxWatermark {
			_ = mm.compactLocked(d, chunksToPrune)
		} else {
			go mm.pruneObsoleteFiles(d, mm.maxWatermark, chunksToPrune)
		}
	}

	mm.initialized = true
	return nil
}

// AppendChunk 向远端追加一个新的增量切片
func (mm *ManifestManager) AppendChunk(d StorageDrive, records []ManifestRecord) error {
	if len(records) == 0 {
		return nil
	}
	mm.mu.Lock()
	defer mm.mu.Unlock()

	mm.maxWatermark++
	chunk := ManifestChunk{
		Watermark: mm.maxWatermark,
		DeviceID:  mm.deviceID,
		Timestamp: time.Now().Unix(),
		Records:   records,
	}

	data, err := json.Marshal(chunk)
	if err != nil {
		return err
	}

	chunkFileName := fmt.Sprintf("chunk_%010d_%s_%d.json",
		chunk.Watermark, mm.deviceID, time.Now().UnixNano()%10000)
	chunkPath := filepath.Join(ManifestDir, chunkFileName)

	// 上传增量切片至远端 .manifest/
	err = d.Upload(chunkPath, io.NopCloser(bytes.NewReader(data)), int64(len(data)), time.Now())
	if err != nil {
		mm.maxWatermark--
		return err
	}

	// 更新本地内存
	for _, rec := range records {
		existing, exists := mm.records[rec.Fingerprint]
		if !exists || rec.UpdatedAt >= existing.UpdatedAt {
			mm.records[rec.Fingerprint] = rec
		}
	}
	_ = mm.saveLocalLocked()

	mm.chunksSinceCompaction++
	if mm.chunksSinceCompaction >= DefaultCompactionThreshold {
		_ = mm.compactLocked(d)
	}

	return nil
}

// pruneObsoleteFiles 在后台并发回收已纳入快照的旧 chunk 与旧快照
func (mm *ManifestManager) pruneObsoleteFiles(d StorageDrive, watermark int64, hintPaths []string) {
	deleteSet := make(map[string]bool)
	for _, p := range hintPaths {
		deleteSet[p] = true
	}

	// 补充扫描 .manifest/ 目录，将残留的更老快照和其他碎片一并纳入清理队列
	err := d.Range(ManifestDir, func(info fs.FileInfo) bool {
		name := info.Name()
		if strings.HasPrefix(name, "chunk_") && strings.HasSuffix(name, ".json") {
			parts := strings.Split(strings.TrimSuffix(strings.TrimPrefix(name, "chunk_"), ".json"), "_")
			if len(parts) >= 1 {
				w, err := strconv.ParseInt(parts[0], 10, 64)
				if err == nil && w <= watermark {
					deleteSet[filepath.Join(ManifestDir, name)] = true
				}
			}
		} else if strings.HasPrefix(name, "snapshot_to_") && strings.HasSuffix(name, ".json") {
			parts := strings.TrimSuffix(strings.TrimPrefix(name, "snapshot_to_"), ".json")
			w, err := strconv.ParseInt(parts, 10, 64)
			if err == nil && w < watermark {
				deleteSet[filepath.Join(ManifestDir, name)] = true
			}
		}
		return true
	})
	if err != nil && len(deleteSet) == 0 {
		log.Printf("[WARN] pruneObsoleteFiles Range failed: %v", err)
		return
	}

	if len(deleteSet) == 0 {
		return
	}

	toDelete := make([]string, 0, len(deleteSet))
	for p := range deleteSet {
		toDelete = append(toDelete, p)
	}

	// 使用 8 并发协程安全清理过时碎片，不阻塞主线程与读锁
	var wg sync.WaitGroup
	sem := make(chan struct{}, 8)
	var deletedCount int32
	start := time.Now()

	for _, p := range toDelete {
		wg.Add(1)
		go func(path string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()
			if err := d.Delete(path); err == nil {
				atomic.AddInt32(&deletedCount, 1)
			} else {
				log.Printf("[WARN] Prune %s failed: %v", path, err)
			}
		}(p)
	}

	wg.Wait()
	log.Printf("[INFO] Manifest GC complete: pruned %d/%d obsolete files in %v (current watermark: %d)",
		deletedCount, len(toDelete), time.Since(start), watermark)
}

// compactLocked 将当前内存全量状态压缩写入 snapshot_to_<watermark>.json，并安全回收已纳入快照的旧 chunk 与旧快照
// 调用前需持有 mm.mu
func (mm *ManifestManager) compactLocked(d StorageDrive, hintPaths ...[]string) error {
	if mm.maxWatermark <= 0 || len(mm.records) == 0 {
		return nil
	}

	snap := ManifestSnapshot{
		Watermark: mm.maxWatermark,
		Timestamp: time.Now().Unix(),
		Records:   make(map[string]ManifestRecord),
	}
	// 只保留未删除的活跃记录进快照
	for fp, rec := range mm.records {
		if !rec.Deleted {
			snap.Records[fp] = rec
		}
	}

	data, err := json.Marshal(snap)
	if err != nil {
		return err
	}

	snapFileName := fmt.Sprintf("snapshot_to_%010d.json", snap.Watermark)
	snapPath := filepath.Join(ManifestDir, snapFileName)

	// 1. 上传新基线快照
	err = d.Upload(snapPath, io.NopCloser(bytes.NewReader(data)), int64(len(data)), time.Now())
	if err != nil {
		return fmt.Errorf("upload snapshot failed: %w", err)
	}

	mm.chunksSinceCompaction = 0
	_ = mm.saveLocalLocked()

	// 2. 异步安全垃圾回收（GC），不阻塞主线程与读锁
	var hints []string
	if len(hintPaths) > 0 {
		hints = hintPaths[0]
	}
	go mm.pruneObsoleteFiles(d, snap.Watermark, hints)

	return nil
}

// Compact 将当前内存中的全量有效状态压缩为一个基线快照，并上传至远端
func (mm *ManifestManager) Compact(d StorageDrive) error {
	mm.mu.Lock()
	defer mm.mu.Unlock()
	return mm.compactLocked(d)
}

// Reset 清空内存中的元数据状态（用于切换存储后端时重新同步）
func (mm *ManifestManager) Reset() {
	mm.mu.Lock()
	defer mm.mu.Unlock()
	mm.records = make(map[string]ManifestRecord)
	mm.maxWatermark = 0
	mm.initialized = false
	mm.chunksSinceCompaction = 0
}

// RebuildWithRecords 使用全量扫描得到的记录重置内存与远端快照，并清理旧碎片
func (mm *ManifestManager) RebuildWithRecords(d StorageDrive, records []ManifestRecord) error {
	mm.mu.Lock()
	defer mm.mu.Unlock()

	var remoteMax int64
	obsoletePaths := make([]string, 0)
	_ = d.Range(ManifestDir, func(info fs.FileInfo) bool {
		name := info.Name()
		if strings.HasPrefix(name, "snapshot_to_") && strings.HasSuffix(name, ".json") {
			parts := strings.TrimSuffix(strings.TrimPrefix(name, "snapshot_to_"), ".json")
			if w, err := strconv.ParseInt(parts, 10, 64); err == nil {
				if w > remoteMax {
					remoteMax = w
				}
				obsoletePaths = append(obsoletePaths, filepath.Join(ManifestDir, name))
			}
		} else if strings.HasPrefix(name, "chunk_") && strings.HasSuffix(name, ".json") {
			parts := strings.Split(strings.TrimSuffix(strings.TrimPrefix(name, "chunk_"), ".json"), "_")
			if len(parts) >= 1 {
				if w, err := strconv.ParseInt(parts[0], 10, 64); err == nil {
					if w > remoteMax {
						remoteMax = w
					}
					obsoletePaths = append(obsoletePaths, filepath.Join(ManifestDir, name))
				}
			}
		}
		return true
	})

	if remoteMax > mm.maxWatermark {
		mm.maxWatermark = remoteMax
	}
	mm.maxWatermark++

	newMap := make(map[string]ManifestRecord, len(records))
	for _, rec := range records {
		if !rec.Deleted {
			newMap[rec.Fingerprint] = rec
		}
	}
	mm.records = newMap
	mm.chunksSinceCompaction = 0

	snap := ManifestSnapshot{
		Watermark: mm.maxWatermark,
		Timestamp: time.Now().Unix(),
		Records:   mm.records,
	}
	data, err := json.Marshal(snap)
	if err != nil {
		return err
	}
	snapFileName := fmt.Sprintf("snapshot_to_%010d.json", snap.Watermark)
	snapPath := filepath.Join(ManifestDir, snapFileName)

	if err := d.Upload(snapPath, io.NopCloser(bytes.NewReader(data)), int64(len(data)), time.Now()); err != nil {
		return fmt.Errorf("upload rebuilt snapshot failed: %w", err)
	}

	mm.initialized = true
	_ = mm.saveLocalLocked()
	if len(obsoletePaths) > 0 {
		go mm.pruneObsoleteFiles(d, snap.Watermark, obsoletePaths)
	}
	return nil
}

// LookupFingerprint 在内存中快速检索指纹，返回是否存在且未删除
func (mm *ManifestManager) LookupFingerprint(fp string) (ManifestRecord, bool) {
	mm.mu.RLock()
	defer mm.mu.RUnlock()
	rec, ok := mm.records[fp]
	if !ok || rec.Deleted {
		return ManifestRecord{}, false
	}
	return rec, true
}

// GetActiveRecords 返回所有未被删除的活跃文件记录
func (mm *ManifestManager) GetActiveRecords() []ManifestRecord {
	mm.mu.RLock()
	defer mm.mu.RUnlock()
	res := make([]ManifestRecord, 0, len(mm.records))
	for _, rec := range mm.records {
		if !rec.Deleted {
			res = append(res, rec)
		}
	}
	return res
}

// IsInitialized 返回是否已完成同步
func (mm *ManifestManager) IsInitialized() bool {
	mm.mu.RLock()
	defer mm.mu.RUnlock()
	return mm.initialized
}

// GetMaxWatermark 返回当前最高水位线序号
func (mm *ManifestManager) GetMaxWatermark() int64 {
	mm.mu.RLock()
	defer mm.mu.RUnlock()
	return mm.maxWatermark
}

// RecordCount 返回当前有效记录总数
func (mm *ManifestManager) RecordCount() int {
	mm.mu.RLock()
	defer mm.mu.RUnlock()
	count := 0
	for _, rec := range mm.records {
		if !rec.Deleted {
			count++
		}
	}
	return count
}
