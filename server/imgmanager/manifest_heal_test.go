package imgmanager

import (
	"bytes"
	"fmt"
	"io"
	"io/fs"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// countingRangeDrive 包装 mockDrive，统计主存储物理扫描（Range）次数，
// 用于验证「heal 之后第二次查询不再回退物理盘」。
type countingRangeDrive struct {
	*mockDrive
	rangeCalls atomic.Int64
}

func (c *countingRangeDrive) Range(dir string, deal func(fs.FileInfo) bool) error {
	c.rangeCalls.Add(1)
	return c.mockDrive.Range(dir, deal)
}

// newHealTestImgManager 构造主/副存储都是内存 mock 的 ImgManager，并完成 manifest 初始化
func newHealTestImgManager(t *testing.T) (*ImgManager, *mockDrive, *mockDrive) {
	t.Helper()
	mainDrive := newMockDrive()
	metaDrive := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.manifest.SetLocalPath(filepath.Join(t.TempDir(), "manifest_cache.json"))
	im.dri = mainDrive
	im.metaDri = metaDrive
	if err := im.manifest.Sync(metaDrive); err != nil {
		im.Close()
		t.Fatalf("manifest Sync: %v", err)
	}
	if !im.manifest.IsInitialized() {
		im.Close()
		t.Fatalf("expected manifest initialized after Sync")
	}
	return im, mainDrive, metaDrive
}

// dir 辅助构造目录项
func dirEntry(name string) mockDirEntry { return mockDirEntry{name: name, isDir: true} }

// fileEntry 辅助构造文件项
func fileEntry(name string, size int64) mockDirEntry {
	return mockDirEntry{name: name, size: size, isDir: false}
}

// TestManifestHealWritesMissedRecords 验证「miss 后主动补元数据」：
// 首次物理扫描到但 manifest 缺失的文件被增量回写，第二次查询纯内存命中且不再扫物理盘。
func TestManifestHealWritesMissedRecords(t *testing.T) {
	im, mainDrive, metaDrive := newHealTestImgManager(t)
	defer im.Close()

	album := "测试相册"
	// 用 UTC 与 parseRecordDate（time.Parse）保持一致
	date := time.Date(2026, 2, 15, 10, 0, 0, 0, time.UTC)
	albumPhoto := filepath.Join(album, "2026/02/15", "20260215100000_pic1.jpg")
	legacyPhoto := filepath.Join("2026/02/15", "20260215100001_legacy.jpg")
	liveDir := filepath.Join(album, "2026/02/15", "live_20260215100002_pic2")
	liveStill := filepath.Join(liveDir, "20260215100002_pic2.jpg")
	liveVideo := filepath.Join(liveDir, "20260215100002_pic2_live_video.mp4")

	// 用 rangeFiles 定义主存储目录树（mock 会在调用回调前释放锁，支持 live_ 目录嵌套 Range）
	mainDrive.rangeFiles["."] = []mockDirEntry{dirEntry("2026"), dirEntry(album)}
	mainDrive.rangeFiles["2026"] = []mockDirEntry{dirEntry("02")}
	mainDrive.rangeFiles["2026/02"] = []mockDirEntry{dirEntry("15")}
	mainDrive.rangeFiles[filepath.Join("2026", "02", "15")] = []mockDirEntry{fileEntry(filepath.Base(legacyPhoto), 11)}
	mainDrive.rangeFiles[album] = []mockDirEntry{dirEntry("2026")}
	mainDrive.rangeFiles[filepath.Join(album, "2026")] = []mockDirEntry{dirEntry("02")}
	mainDrive.rangeFiles[filepath.Join(album, "2026", "02")] = []mockDirEntry{dirEntry("15")}
	mainDrive.rangeFiles[filepath.Join(album, "2026", "02", "15")] = []mockDirEntry{
		fileEntry(filepath.Base(albumPhoto), 11),
		dirEntry(filepath.Base(liveDir)),
	}
	mainDrive.rangeFiles[liveDir] = []mockDirEntry{
		fileEntry(filepath.Base(liveStill), 12),
		fileEntry(filepath.Base(liveVideo), 5000),
	}

	countingMain := &countingRangeDrive{mockDrive: mainDrive}
	im.dri = countingMain

	// 1. 第一次查询：manifest 无记录 → 物理扫描 + heal 回写
	var visited []string
	var stats RangeStats
	minDate, maxDate := date.Add(-time.Hour), date.Add(time.Hour)
	if err := im.RangeByDateRange(minDate, maxDate, func(info ImgInfo) bool {
		visited = append(visited, info.Path)
		return true
	}, WithManifestHeal(&stats)); err != nil {
		t.Fatalf("RangeByDateRange: %v", err)
	}

	if !stats.FallbackScan {
		t.Fatalf("expected fallback physical scan on first query, stats=%+v", stats)
	}
	if stats.Source != "physical" {
		t.Fatalf("expected source=physical, got %q", stats.Source)
	}
	if stats.Healed != 3 {
		t.Fatalf("expected 3 healed records (album + legacy + live still), got %d (visited=%v)", stats.Healed, visited)
	}
	if len(visited) != 3 {
		t.Fatalf("expected 3 visited files (video in live_ dir must be skipped), got %d: %v", len(visited), visited)
	}

	// 记录写入副存储 manifest，且相册推导正确
	rec, found := im.manifest.LookupFingerprint(filepath.Base(albumPhoto))
	if !found || rec.Album != album || rec.Path != albumPhoto {
		t.Fatalf("expected healed record for %s in album %s, got %+v found=%v", albumPhoto, album, rec, found)
	}
	rec, found = im.manifest.LookupFingerprint(filepath.Base(legacyPhoto))
	if !found || rec.Album != im.GetDefaultAlbum() {
		t.Fatalf("expected legacy root date photo in default album %s, got %+v found=%v", im.GetDefaultAlbum(), rec, found)
	}
	rec, found = im.manifest.LookupFingerprint(filepath.Base(liveStill))
	if !found || rec.Album != album {
		t.Fatalf("expected live still healed into album %s, got %+v found=%v", album, rec, found)
	}
	if _, found := im.manifest.LookupFingerprint(filepath.Base(liveVideo)); found {
		t.Fatalf("live_ dir video must NOT be written to manifest")
	}

	// 为新出现的相册在副存储建 .thumbnail/<album> 骨架
	if exist, _ := metaDrive.IsExist(filepath.Join(defaultThumbnailDir, album)); !exist {
		t.Fatalf("expected .thumbnail/%s skeleton created on meta drive", album)
	}

	// 2. 第二次查询：纯内存命中，绝不再扫物理盘
	callsBefore := countingMain.rangeCalls.Load()
	var stats2 RangeStats
	visited = visited[:0]
	if err := im.RangeByDateRange(minDate, maxDate, func(info ImgInfo) bool {
		visited = append(visited, info.Path)
		return true
	}, WithManifestHeal(&stats2)); err != nil {
		t.Fatalf("second RangeByDateRange: %v", err)
	}
	if stats2.Source != "manifest" || stats2.FallbackScan {
		t.Fatalf("expected second query served from manifest, got %+v", stats2)
	}
	if stats2.Healed != 0 {
		t.Fatalf("expected no heal on manifest hit, got %d", stats2.Healed)
	}
	if len(visited) != 3 {
		t.Fatalf("expected 3 records from manifest, got %d: %v", len(visited), visited)
	}
	if after := countingMain.rangeCalls.Load(); after != callsBefore {
		t.Fatalf("expected no physical scan on manifest hit, Range calls %d -> %d", callsBefore, after)
	}
}

// TestManifestHealDedupeFiltersAndLimit 验证 heal 的去重（已存在 / 批内重复）、
// 忽略规则（隐藏目录、live_ 目录内视频、临时文件）与单次 2000 条上限。
func TestManifestHealDedupeFiltersAndLimit(t *testing.T) {
	im, _, metaDrive := newHealTestImgManager(t)
	defer im.Close()

	// 预置一条已存在记录
	existingPath := "已有相册/2026/02/15/existing.jpg"
	if err := im.manifest.AppendChunk(metaDrive, []ManifestRecord{{
		Fingerprint: "existing.jpg",
		Album:       "已有相册",
		Path:        existingPath,
		Size:        10,
		UpdatedAt:   1,
	}}); err != nil {
		t.Fatalf("append existing record: %v", err)
	}

	cands := []healCandidate{
		{path: existingPath, size: 10},                                  // 已存在 → 跳过
		{path: "新相册/2026/02/15/dup.jpg", size: 1},                       // 新增
		{path: "新相册/2026/02/15/dup.jpg", size: 1},                       // 批内重复 → 只加一次
		{path: ".hidden/2026/02/15/ignored.jpg", size: 1},               // 隐藏目录 → 跳过
		{path: "新相册/2026/02/15/.DS_Store", size: 1},                     // 忽略文件 → 跳过
		{path: "新相册/2026/02/15/tmp.tmp", size: 1},                       // .tmp → 跳过
		{path: "新相册/2026/02/15/live_x/video_x_live_video.mp4", size: 1}, // live_ 目录内视频 → 跳过
		{path: "新相册/2026/02/15/live_x/live_x.jpg", size: 1},             // live still → 新增
	}
	added, albums := im.healManifest(cands)
	if added != 2 {
		t.Fatalf("expected 2 added records, got %d (albums=%v)", added, albums)
	}
	if len(albums) != 1 || albums[0] != "新相册" {
		t.Fatalf("expected albums=[新相册], got %v", albums)
	}
	if _, found := im.manifest.LookupFingerprint("ignored.jpg"); found {
		t.Fatalf("hidden dir file must not be healed")
	}
	if _, found := im.manifest.LookupFingerprint("tmp.tmp"); found {
		t.Fatalf(".tmp file must not be healed")
	}
	if _, found := im.manifest.LookupFingerprint("video_x_live_video.mp4"); found {
		t.Fatalf("live video must not be healed")
	}

	// 单次上限 2000
	big := make([]healCandidate, 0, manifestHealMaxRecords+500)
	for i := 0; i < manifestHealMaxRecords+500; i++ {
		big = append(big, healCandidate{path: fmt.Sprintf("上限相册/2026/02/15/bulk_%05d.jpg", i), size: 1})
	}
	added, _ = im.healManifest(big)
	if added != manifestHealMaxRecords {
		t.Fatalf("expected heal capped at %d, got %d", manifestHealMaxRecords, added)
	}
	if count := im.manifest.RecordCount(); count != 3+manifestHealMaxRecords {
		t.Fatalf("expected %d records total, got %d", 3+manifestHealMaxRecords, count)
	}
}

// TestManifestHealSkippedWhenNotInitialized 验证 manifest 未初始化时不做回写
func TestManifestHealSkippedWhenNotInitialized(t *testing.T) {
	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	metaDrive := newMockDrive()
	im.dri = newMockDrive()
	im.metaDri = metaDrive

	added, _ := im.healManifest([]healCandidate{{path: "相册/2026/02/15/a.jpg", size: 1}})
	if added != 0 {
		t.Fatalf("expected no heal before manifest initialized, got %d", added)
	}
}

// TestAlbumForPath 验证相册推导规则（与 scanAllRecordsAndAlbums 一致）
func TestAlbumForPath(t *testing.T) {
	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	def := im.GetDefaultAlbum()

	cases := []struct {
		path string
		want string
	}{
		{"测试/2026/02/15/a.jpg", "测试"},
		{"测试/20260215/a.jpg", "测试"},
		{"2026/02/15/a.jpg", def},
		{"20260215/a.jpg", def},
		{"a.jpg", def},
	}
	for _, c := range cases {
		if got := im.albumForPath(c.path); got != c.want {
			t.Errorf("albumForPath(%q) = %q, want %q", c.path, got, c.want)
		}
	}
}

// TestManifestHealAlbumSkeleton 验证 heal 只在副存储建骨架、不写主存储
func TestManifestHealAlbumSkeleton(t *testing.T) {
	im, mainDrive, metaDrive := newHealTestImgManager(t)
	defer im.Close()

	if _, found := im.manifest.LookupFingerprint("x.jpg"); found {
		t.Fatalf("unexpected pre-existing record")
	}
	if err := mainDrive.Upload("骨架相册/2026/02/15/x.jpg", io.NopCloser(bytes.NewReader([]byte("x"))), 1, time.Now()); err != nil {
		t.Fatalf("upload: %v", err)
	}
	date := time.Date(2026, 2, 15, 0, 0, 0, 0, time.Local)
	var stats RangeStats
	_ = im.RangeByDateRange(date, date.Add(24*time.Hour), func(info ImgInfo) bool { return true }, WithManifestHeal(&stats))
	if stats.Healed != 1 {
		t.Fatalf("expected 1 healed record, got %d", stats.Healed)
	}
	if exist, _ := metaDrive.IsExist(filepath.Join(defaultThumbnailDir, "骨架相册")); !exist {
		t.Fatalf("expected thumbnail skeleton on meta drive")
	}
	if exist, _ := mainDrive.IsExist(filepath.Join(defaultThumbnailDir, "骨架相册")); exist {
		t.Fatalf("thumbnail skeleton must NOT be created on main drive")
	}
	for p := range metaDrive.files {
		if strings.HasPrefix(filepath.ToSlash(p), defaultThumbnailDir+"/骨架相册/x.jpg") {
			t.Fatalf("heal must not upload thumbnails, found %s", p)
		}
	}
}

// TestLookupFilesByFingerprintsTargetsMissedDate 验证「10 张里 1 张 miss」场景：
// 只扫 miss 所在日期的相册目录（不是整区间），命中后回写 manifest；第二次不再回写。
func TestLookupFilesByFingerprintsTargetsMissedDate(t *testing.T) {
	im, mainDrive, metaDrive := newHealTestImgManager(t)
	defer im.Close()

	album := "相机备份"
	day := "2026/11/15"
	existing := "20261115050000_old.jpg"
	miss := "20261115050357_miss.jpg"

	// manifest 里已有同区间的其它记录（这会让区间扫描整体命中 manifest，不再物理扫描）
	if err := im.manifest.AppendChunk(metaDrive, []ManifestRecord{{
		Fingerprint: existing,
		Album:       album,
		Path:        filepath.Join(album, day, existing),
		Size:        1,
		UpdatedAt:   1,
	}}); err != nil {
		t.Fatalf("append existing: %v", err)
	}

	mainDrive.rangeFiles["."] = []mockDirEntry{dirEntry(album)}
	mainDrive.rangeFiles[filepath.Join(album, day)] = []mockDirEntry{
		fileEntry(existing, 1),
		fileEntry(miss, 10),
	}

	found, healed := im.LookupFilesByFingerprints(map[string]bool{miss: true})
	if !found[miss] {
		t.Fatalf("expected targeted lookup to find %s, got %v", miss, found)
	}
	if healed != 1 {
		t.Fatalf("expected 1 healed record, got %d", healed)
	}
	rec, ok := im.manifest.LookupFingerprint(miss)
	if !ok || rec.Album != album || rec.Path != filepath.Join(album, day, miss) {
		t.Fatalf("unexpected healed record: %+v ok=%v", rec, ok)
	}

	// 第二次：manifest 已命中，heal 数应为 0
	_, healed2 := im.LookupFilesByFingerprints(map[string]bool{miss: true})
	if healed2 != 0 {
		t.Fatalf("expected no heal on second lookup, got %d", healed2)
	}
}

// TestLookupFilesByFingerprintsSkipsTooMany 验证规模超限时直接放弃，保护云盘主存储
func TestLookupFilesByFingerprintsSkipsTooMany(t *testing.T) {
	im, mainDrive, _ := newHealTestImgManager(t)
	defer im.Close()
	mainDrive.rangeFiles["."] = []mockDirEntry{}

	fps := make(map[string]bool, targetedLookupMaxFingerprints+1)
	for i := 0; i <= targetedLookupMaxFingerprints; i++ {
		fps[fmt.Sprintf("2026111505%04d_x.jpg", i)] = true
	}
	found, healed := im.LookupFilesByFingerprints(fps)
	if found != nil || healed != 0 {
		t.Fatalf("expected skip when fps over limit, got found=%v healed=%d", found, healed)
	}
}
