package imgmanager

import (
	"io/fs"
	"log"
	"path/filepath"
	"strings"
	"sync"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/util"
)

const (
	// manifestHealMaxRecords 单次 heal 最多追加的记录数，防止一次大范围物理扫描把 manifest 撑爆
	manifestHealMaxRecords = 2000
)

// healMu 进程内互斥：并发查询同时 miss 时只让一个 goroutine 回写，避免重复追加相同记录
var healMu sync.Mutex

// healCandidate 是物理扫描中实际访问到的一个文件
type healCandidate struct {
	path string
	size int64
}

// appendHealCandidate 收集候选文件（同一批内按指纹去重，最多 manifestHealMaxRecords 条）
func appendHealCandidate(cands []healCandidate, info ImgInfo) []healCandidate {
	if len(cands) >= manifestHealMaxRecords {
		return cands
	}
	if info.Path == "" {
		return cands
	}
	cands = append(cands, healCandidate{path: info.Path, size: info.Size})
	return cands
}

// albumForPath 从相对路径推导所属相册，规则与 scanAllRecordsAndAlbums 保持一致：
//   - <album>/YYYY/MM/DD/... → 取第一段作为相册
//   - YYYY/MM/DD/... 或 YYYYMMDD/...（根级历史目录）→ 归默认相册
//   - 其余（无目录层级、忽略目录）→ 默认相册
func (im *ImgManager) albumForPath(path string) string {
	defaultAlbum := im.GetDefaultAlbum()
	parts := strings.Split(filepath.ToSlash(path), "/")
	if len(parts) < 2 {
		return defaultAlbum
	}
	first := parts[0]
	if first == "" || first == "." || isIgnoredDir(first) || isYearOrDateDir(first) {
		return defaultAlbum
	}
	return first
}

// isHealableFile 判定物理扫描到的文件是否应写入 manifest（与 Bootstrap 的收集规则一致）
func isHealableFile(path string) bool {
	base := filepath.Base(path)
	if base == "" || base == "." || base == "/" {
		return false
	}
	if isIgnoredFile(base) {
		return false
	}
	// 忽略任意层级的隐藏目录（不回写 .stversions/.git 等系统目录下的文件）
	for _, part := range strings.Split(filepath.ToSlash(filepath.Dir(path)), "/") {
		if strings.HasPrefix(part, ".") {
			return false
		}
	}
	// live_ 目录内的视频不单独记录（与 scanAllRecordsAndAlbums 一致，视频由照片记录隐式携带）
	if strings.HasPrefix(filepath.Base(filepath.Dir(path)), "live_") && util.IsVideo(base) {
		return false
	}
	return true
}

// healManifest 将物理扫描中访问到、但 manifest 中不存在的文件增量回写为 manifest 记录，
// 并为新出现的相册在副存储上补齐 .thumbnail/<album> 骨架。
// 返回新增记录数与涉及的相册列表。
func (im *ImgManager) healManifest(cands []healCandidate) (int, []string) {
	if len(cands) == 0 || im.manifest == nil || !im.manifest.IsInitialized() {
		return 0, nil
	}

	healMu.Lock()
	defer healMu.Unlock()

	now := time.Now().Unix()
	records := make([]ManifestRecord, 0, len(cands))
	albums := make([]string, 0, 4)
	albumSeen := make(map[string]bool, 4)
	seen := make(map[string]bool, len(cands))

	for _, c := range cands {
		if len(records) >= manifestHealMaxRecords {
			break
		}
		if !isHealableFile(c.path) {
			continue
		}
		fp := filepath.Base(c.path)
		if seen[fp] {
			continue
		}
		seen[fp] = true
		// 去重：manifest 中已存在（且未删除）的指纹直接跳过
		if _, found := im.manifest.LookupFingerprint(fp); found {
			continue
		}
		album := im.albumForPath(c.path)
		records = append(records, ManifestRecord{
			Fingerprint: fp,
			Album:       album,
			Path:        c.path,
			Size:        c.size,
			Deleted:     false,
			UpdatedAt:   now,
		})
		if album != "" && !albumSeen[album] {
			albumSeen[album] = true
			albums = append(albums, album)
		}
	}

	if len(records) == 0 {
		return 0, nil
	}

	// 已释放主存储读锁（调用方保证），此处才获取副存储
	md, unlock := im.metaDrive()
	err := im.manifest.AppendChunk(md, records)
	// 为新出现的相册补齐 .thumbnail/<album> 骨架（Bootstrap 同样逻辑）
	ensureAlbumThumbSkeletons(md, albums)
	unlock()
	if err != nil {
		util.RateLimitedLogf("manifest-heal-failed",
			"[W] manifest heal append failed: added=%d err=%v", len(records), err)
		return 0, nil
	}
	return len(records), albums
}

// ensureAlbumThumbSkeletons 在元数据存储上为给定相册创建 .thumbnail/<album> 骨架目录
func ensureAlbumThumbSkeletons(d StorageDrive, albums []string) {
	if d == nil {
		return
	}
	for _, alb := range albums {
		if alb == "" {
			continue
		}
		if err := d.Mkdir(filepath.Join(defaultThumbnailDir, alb)); err != nil {
			log.Printf("[W] ensure thumbnail skeleton failed: album=%s err=%v", alb, err)
		}
	}
}

const (
	// targetedLookupMaxFingerprints / targetedLookupMaxDates 限制定向补查的规模：
	// 只处理少量 miss（如「10 张里 1 张」），避免对云盘主存储发过多 PROPFIND。
	targetedLookupMaxFingerprints = 40
	targetedLookupMaxDates        = 6
)

// dateDirForName 从 encodeName 生成的 <YYYYMMDDhhmmss>_name 解析出日期目录（按当前目录组织格式）。
func (im *ImgManager) dateDirForName(name string) (string, bool) {
	if len(name) < 8 {
		return "", false
	}
	prefix := name[:8]
	if len(name) >= 14 {
		prefix = name[:14]
	}
	var t time.Time
	var err error
	if len(prefix) == 14 {
		t, err = time.ParseInLocation("20060102150405", prefix, time.Local)
	} else {
		t, err = time.ParseInLocation("20060102", prefix, time.Local)
	}
	if err != nil {
		return "", false
	}
	im.dirTypeMu.RLock()
	dirType := im.dirType
	im.dirTypeMu.RUnlock()
	if dirType == pb.DirectoryType_DIRECTORY_TYPE_02 {
		return t.Format("20060102"), true
	}
	return t.Format("2006/01/02"), true
}

// LookupFilesByFingerprints 只扫描 miss 文件所在日期的目录（根级 + 各相册），
// 用于 FilterNotUploaded 的「少量 miss」场景：命中后顺带回写 manifest，下次 O(1) 命中。
// 返回命中的 fingerprint 集合与回写的新记录数。规模超限时直接放弃（保护云盘主存储）。
func (im *ImgManager) LookupFilesByFingerprints(fps map[string]bool) (map[string]bool, int) {
	if len(fps) == 0 || im.manifest == nil || !im.manifest.IsInitialized() {
		return nil, 0
	}
	dateSet := make(map[string]bool, 4)
	for fp := range fps {
		if dir, ok := im.dateDirForName(fp); ok {
			dateSet[dir] = true
		}
	}
	if len(dateSet) == 0 || len(dateSet) > targetedLookupMaxDates || len(fps) > targetedLookupMaxFingerprints {
		util.RateLimitedLogf("targeted-lookup-skip",
			"[I] targeted lookup skipped: fps=%d dates=%d", len(fps), len(dateSet))
		return nil, 0
	}

	d, unlock := im.drive()
	if !isDriveReady(d) {
		unlock()
		return nil, 0
	}
	var albums []string
	if entries, err := im.listDir(d, "."); err == nil {
		for _, e := range entries {
			if e.IsDir() && !isIgnoredDir(e.Name()) && !isYearOrDateDir(e.Name()) {
				albums = append(albums, e.Name())
			}
		}
	}

	found := make(map[string]bool, len(fps))
	cands := make([]healCandidate, 0, len(fps))
	stop := false
	for datePath := range dateSet {
		if stop {
			break
		}
		dirs := make([]string, 0, len(albums)+1)
		dirs = append(dirs, datePath)
		for _, alb := range albums {
			dirs = append(dirs, filepath.Join(alb, datePath))
		}
		for _, dir := range dirs {
			if stop {
				break
			}
			// 目录可能不存在（会返回错误），忽略即可
			_ = d.Range(dir, func(info fs.FileInfo) bool {
				if info.IsDir() {
					return true
				}
				if !fps[info.Name()] || found[info.Name()] {
					return true
				}
				found[info.Name()] = true
				cands = append(cands, healCandidate{path: filepath.Join(dir, info.Name()), size: info.Size()})
				return len(found) < len(fps)
			})
			if len(found) >= len(fps) {
				stop = true
			}
		}
	}
	unlock()

	healed, _ := im.healManifest(cands)
	util.RateLimitedLogf("targeted-lookup",
		"[I] targeted lookup: fps=%d dates=%d hit=%d healed=%d", len(fps), len(dateSet), len(found), healed)
	return found, healed
}
