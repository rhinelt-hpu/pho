package imgmanager

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

const (
	ManifestDir = ".manifest"
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
	mu           sync.RWMutex
	records      map[string]ManifestRecord // Fingerprint -> ManifestRecord
	maxWatermark int64
	deviceID     string
	initialized  bool
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

	// 2. 加载最高基线快照
	if bestSnapshotName != "" {
		rc, _, err := d.Download(filepath.Join(ManifestDir, bestSnapshotName))
		if err == nil {
			defer rc.Close()
			var snap ManifestSnapshot
			if err := json.NewDecoder(rc).Decode(&snap); err == nil {
				mm.records = snap.Records
				mm.maxWatermark = snap.Watermark
			}
		}
	}

	// 3. 排序所有 chunk
	sort.Slice(chunks, func(i, j int) bool {
		return chunks[i].watermark < chunks[j].watermark
	})

	// 4. 水位线过滤与日志重放：严格跳过 <= snapshotWatermark 的切片！
	for _, chunk := range chunks {
		if chunk.watermark <= snapshotWatermark {
			continue // 绝不重复回放已纳入快照的旧切片
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
		return err
	}

	// 更新本地内存
	for _, rec := range records {
		existing, exists := mm.records[rec.Fingerprint]
		if !exists || rec.UpdatedAt >= existing.UpdatedAt {
			mm.records[rec.Fingerprint] = rec
		}
	}
	return nil
}

// Compact 将当前内存中的全量有效状态压缩为一个基线快照，并上传至远端
func (mm *ManifestManager) Compact(d StorageDrive) error {
	mm.mu.Lock()
	defer mm.mu.Unlock()

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

	return d.Upload(snapPath, io.NopCloser(bytes.NewReader(data)), int64(len(data)), time.Now())
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
