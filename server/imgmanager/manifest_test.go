package imgmanager

import (
	"path/filepath"
	"testing"
)

func TestManifestLifecycleAndWatermarkPruning(t *testing.T) {
	md := newMockDrive()
	mm1 := NewManifestManager("device_A")

	// 1. 模拟设备 A 上传两张照片并追加 chunk_1
	records1 := []ManifestRecord{
		{
			Fingerprint: "20260215_pic1.jpg",
			Album:       "相机备份",
			Path:        "相机备份/2026/02/15/20260215_pic1.jpg",
			Size:        1000,
			Deleted:     false,
			UpdatedAt:   100,
		},
		{
			Fingerprint: "20260215_pic2.jpg",
			Album:       "相机备份",
			Path:        "相机备份/2026/02/15/20260215_pic2.jpg",
			Size:        2000,
			Deleted:     false,
			UpdatedAt:   100,
		},
	}
	err := mm1.AppendChunk(md, records1)
	if err != nil {
		t.Fatalf("AppendChunk 1 error: %v", err)
	}

	// 2. 模拟设备 A 移动 pic2 至 "测试" 相册并追加 chunk_2
	records2 := []ManifestRecord{
		{
			Fingerprint: "20260215_pic2.jpg",
			Album:       "测试",
			Path:        "测试/2026/02/15/20260215_pic2.jpg",
			Size:        2000,
			Deleted:     false,
			UpdatedAt:   200, // 更高时间戳
		},
	}
	err = mm1.AppendChunk(md, records2)
	if err != nil {
		t.Fatalf("AppendChunk 2 error: %v", err)
	}

	// 3. 执行 Compact 生成基线快照 snapshot_to_0000000002
	err = mm1.Compact(md)
	if err != nil {
		t.Fatalf("Compact error: %v", err)
	}

	// 4. 设备 A 再次追加新照片 chunk_3
	records3 := []ManifestRecord{
		{
			Fingerprint: "20260216_pic3.jpg",
			Album:       "测试",
			Path:        "测试/2026/02/16/20260216_pic3.jpg",
			Size:        3000,
			Deleted:     false,
			UpdatedAt:   300,
		},
	}
	err = mm1.AppendChunk(md, records3)
	if err != nil {
		t.Fatalf("AppendChunk 3 error: %v", err)
	}

	// 5. 模拟新设备 B 加入：从远端 Sync 清单
	mm2 := NewManifestManager("device_B")
	err = mm2.Sync(md)
	if err != nil {
		t.Fatalf("device B Sync error: %v", err)
	}

	// 验证设备 B 是否拥有全量最新状态
	active := mm2.GetActiveRecords()
	if len(active) != 3 {
		t.Fatalf("expected 3 active records on device B, got: %d", len(active))
	}

	// 验证 pic2 是否正确处于 "测试" 相册（LWW 更新成功）
	rec2, found := mm2.LookupFingerprint("20260215_pic2.jpg")
	if !found || rec2.Album != "测试" {
		t.Fatalf("expected pic2 in album '测试', got: %+v", rec2)
	}

	// 6. 模拟设备 B 删除 pic1
	deleteRec := []ManifestRecord{
		{
			Fingerprint: "20260215_pic1.jpg",
			Path:        "相机备份/2026/02/15/20260215_pic1.jpg",
			Deleted:     true,
			UpdatedAt:   400,
		},
	}
	err = mm2.AppendChunk(md, deleteRec)
	if err != nil {
		t.Fatalf("AppendChunk delete error: %v", err)
	}

	// 7. 测试本地文件持久化 (LoadLocal / SaveLocal)
	tmpDir := t.TempDir()
	localCacheFile := filepath.Join(tmpDir, "manifest_cache.json")
	mm2.SetLocalPath(localCacheFile)
	err = mm2.SaveLocal()
	if err != nil {
		t.Fatalf("SaveLocal error: %v", err)
	}

	// 模拟设备 B 冷启动：创建新实例，直接从本地沙箱加载
	mmCold := NewManifestManager("device_B")
	mmCold.SetLocalPath(localCacheFile)
	err = mmCold.LoadLocal()
	if err != nil {
		t.Fatalf("LoadLocal error: %v", err)
	}
	if !mmCold.IsInitialized() {
		t.Fatalf("expected mmCold to be initialized after LoadLocal")
	}
	if mmCold.RecordCount() != 2 {
		t.Fatalf("expected 2 active records in mmCold, got: %d", mmCold.RecordCount())
	}
	if mmCold.GetMaxWatermark() != mm2.GetMaxWatermark() {
		t.Fatalf("expected watermark %d, got: %d", mm2.GetMaxWatermark(), mmCold.GetMaxWatermark())
	}

	// 8. 增量校验：当远端无新变更时，Sync 不应有任何额外下载开销
	err = mmCold.Sync(md)
	if err != nil {
		t.Fatalf("incremental Sync error: %v", err)
	}
	if mmCold.RecordCount() != 2 {
		t.Fatalf("expected still 2 active records, got: %d", mmCold.RecordCount())
	}
}
