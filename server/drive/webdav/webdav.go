package webdav

import (
	"crypto/tls"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	neturl "net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/fregie/img_syncer/server/util"
	"github.com/studio-b12/gowebdav"
)

const (
	defaultThumbnailDir = ".thumbnail"
	defaultManifestDir  = ".manifest"

	// DefaultPrimaryConcurrency 主存储默认并发上限（123 云盘等对并发敏感，保持低并发）
	DefaultPrimaryConcurrency = 4
	// DefaultMetaConcurrency 副存储默认并发上限（元数据/缩略图通常在本机磁盘，可高并发）
	DefaultMetaConcurrency = 16
	// MaxRemoteConcurrency 历史全局限流值，保留作为默认上限（等价于副存储默认值）
	MaxRemoteConcurrency = DefaultMetaConcurrency
	// maxAllowedConcurrency 单实例并发硬上限，防止误配置把远端打挂
	maxAllowedConcurrency = 64
)

// semaphore 是可整体替换的计数信号量。每次 acquire 持有它拿到的 semaphore 实例，
// release 时归还到同一实例；因此配置变更（替换 chan）时在途请求不会 panic、
// 也不会归还到错误的槽位。
type semaphore struct {
	ch chan struct{}
}

func newSemaphore(n int) *semaphore {
	if n <= 0 {
		n = DefaultPrimaryConcurrency
	}
	return &semaphore{ch: make(chan struct{}, n)}
}

type Webdav struct {
	url       string
	username  string
	password  string
	rootPath  string
	cli       *gowebdav.Client
	mkdirLock sync.Mutex // serializes mkdir to avoid race in gowebdav lib
	knownDirs map[string]bool

	cfgMu          sync.Mutex // 保护 role/maxConcurrency 与 transport 空闲连接配置
	role           string
	maxConcurrency int
	concurrencySet bool // 是否被 SetMaxConcurrency 显式设置过
	sem            *semaphore
	rt             *retryTransport
	stats          *StatsCollector
}

func defaultConcurrencyForRole(role string) int {
	if role == RoleMeta {
		return DefaultMetaConcurrency
	}
	return DefaultPrimaryConcurrency
}

func normalizeRole(role string) string {
	if strings.EqualFold(strings.TrimSpace(role), RoleMeta) {
		return RoleMeta
	}
	return RolePrimary
}

type semReleaseReadCloser struct {
	io.ReadCloser
	once    sync.Once
	release func()
	size    int64
}

func (rc *semReleaseReadCloser) releaseNow() {
	if rc.release != nil {
		rc.once.Do(rc.release)
	}
}

func (rc *semReleaseReadCloser) Close() error {
	err := rc.ReadCloser.Close()
	rc.releaseNow()
	return err
}

func parseContentRangeTotal(cr string) int64 {
	if cr == "" {
		return -1
	}
	idx := strings.LastIndexByte(cr, '/')
	if idx < 0 || idx+1 >= len(cr) {
		return -1
	}
	totalStr := strings.TrimSpace(cr[idx+1:])
	if totalStr == "*" || totalStr == "" {
		return -1
	}
	n, err := strconv.ParseInt(totalStr, 10, 64)
	if err != nil || n < 0 {
		return -1
	}
	return n
}

type retryTransport struct {
	base        http.RoundTripper
	sem         atomic.Pointer[semaphore]
	basePath    string
	lastSizeMap sync.Map
	stats       *StatsCollector
	used        atomic.Bool // 是否已有请求发生过（并发上限仅允许在首次请求前调整）
}

func (t *retryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	t.used.Store(true)
	sem := t.sem.Load()
	if sem != nil {
		select {
		case sem.ch <- struct{}{}:
		case <-req.Context().Done():
			return nil, req.Context().Err()
		}
	}
	releaseSem := func() {
		if sem != nil {
			<-sem.ch
		}
	}
	record := func(status int, dur time.Duration) {
		if t.stats != nil {
			t.stats.Record(req.Method, req.URL.Path, status, dur.Milliseconds())
		}
		GlobalStats.Record(req.Method, req.URL.Path, status, dur.Milliseconds())
	}

	var resp *http.Response
	var err error
	start := time.Now()
	for i := 0; i < 3; i++ {
		resp, err = t.base.RoundTrip(req)
		if err == nil {
			if resp.StatusCode == http.StatusTooManyRequests {
				record(resp.StatusCode, time.Since(start))
				// 注意：重试期间继续持有本请求已占用的槽位，不重新 acquire，避免重复占用并发额度
				_ = resp.Body.Close()
				util.RateLimitedLogf("webdav-429:"+req.URL.Path,
					"[W] webdav 429 retry: method=%s path=%s attempt=%d", req.Method, req.URL.Path, i+1)
				time.Sleep(time.Duration(1<<i) * 1000 * time.Millisecond)
				continue
			}
			// 413 是服务器限制请求体体积，重试无意义，立即退出避免无效重发
			if resp.StatusCode == http.StatusRequestEntityTooLarge {
				break
			}
		}
		break
	}
	statusCode := 0
	if resp != nil {
		statusCode = resp.StatusCode
	}
	record(statusCode, time.Since(start))
	if err != nil || resp == nil || resp.Body == nil {
		releaseSem()
		return resp, err
	}

	if req.Method == http.MethodGet &&
		(resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusPartialContent) {
		var totalSize int64 = -1
		if resp.StatusCode == http.StatusPartialContent {
			totalSize = parseContentRangeTotal(resp.Header.Get("Content-Range"))
		} else if resp.StatusCode == http.StatusOK {
			totalSize = resp.ContentLength
		}
		t.lastSizeMap.Store(req.URL.Path, totalSize)
		if t.basePath != "" && strings.HasPrefix(req.URL.Path, t.basePath) {
			rel := "/" + strings.TrimPrefix(strings.TrimPrefix(req.URL.Path, t.basePath), "/")
			t.lastSizeMap.Store(rel, totalSize)
		}
		if totalSize >= 0 {
			resp.Body = &semReleaseReadCloser{
				ReadCloser: resp.Body,
				release:    releaseSem,
				size:       totalSize,
			}
			return resp, nil
		}
	}

	// 非流式成功 GET 请求（如 PROPFIND/PUT/MKCOL/401/404 或无 Content-Length 需回退 Stat 的请求）
	// 在 RoundTrip 完成时立即释放信号量槽位，防止 401 未关闭 Body 泄漏槽位或回退 Stat 时嵌套死锁
	releaseSem()
	return resp, nil
}

func NewWebdavDrive(url, username, password string, insecure bool) *Webdav {
	stats := NewStatsCollectorWithRole(50, RolePrimary)
	sem := newSemaphore(DefaultPrimaryConcurrency)
	baseTransport := &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: insecure},
		MaxIdleConns:        DefaultPrimaryConcurrency * 2,
		MaxIdleConnsPerHost: DefaultPrimaryConcurrency,
		IdleConnTimeout:     90 * time.Second,
	}
	var basePath string
	if parsed, err := neturl.Parse(url); err == nil && parsed.Path != "" && parsed.Path != "/" {
		basePath = strings.TrimSuffix(parsed.Path, "/")
	}
	rt := &retryTransport{
		base:     baseTransport,
		basePath: basePath,
		stats:    stats,
	}
	rt.sem.Store(sem)
	d := &Webdav{
		url:            url,
		username:       username,
		password:       password,
		cli:            gowebdav.NewClient(url, username, password),
		knownDirs:      make(map[string]bool),
		role:           RolePrimary,
		maxConcurrency: DefaultPrimaryConcurrency,
		sem:            sem,
		rt:             rt,
		stats:          stats,
	}
	d.cli.SetTransport(rt)
	if insecure {
		log.Printf("[W] WARNING: TLS certificate verification disabled for WebDAV at %s, do not use in production", url)
	}
	d.cli.SetTimeout(60 * time.Second)
	return d
}

// Role 返回当前驱动角色（primary | meta）
func (d *Webdav) Role() string {
	d.cfgMu.Lock()
	defer d.cfgMu.Unlock()
	return d.role
}

// MaxConcurrency 返回当前生效的并发上限
func (d *Webdav) MaxConcurrency() int {
	d.cfgMu.Lock()
	defer d.cfgMu.Unlock()
	return d.maxConcurrency
}

// Stats 返回本实例独立的请求统计收集器（区别于全量聚合的 GlobalStats）
func (d *Webdav) Stats() *StatsCollector {
	return d.stats
}

// SetRole 设置驱动角色。主存储默认并发 4，副存储（元数据/缩略图）默认并发 16；
// 若调用方已显式 SetMaxConcurrency，则角色切换不会覆盖显式并发值。
func (d *Webdav) SetRole(role string) {
	role = normalizeRole(role)
	d.cfgMu.Lock()
	d.role = role
	if !d.concurrencySet && !d.rt.used.Load() {
		d.applyConcurrencyLocked(defaultConcurrencyForRole(role))
	} else if !d.concurrencySet {
		util.RateLimitedLogf("webdav-role-change:"+d.url,
			"[W] webdav role change after first request ignored for concurrency: role=%s", role)
	}
	d.cfgMu.Unlock()
	if d.stats != nil {
		d.stats.SetRole(role)
	}
}

// SetMaxConcurrency 设置本实例的远端并发上限（同时调整 http.Transport 的空闲连接数）。
// 为避免与 net/http 内部读产生数据竞争，只允许在首次网络请求前调用；
// n <= 0 或超过硬上限时回退为当前角色的默认值。运行中调用会返回 error 且不改变现有配置。
func (d *Webdav) SetMaxConcurrency(n int) error {
	d.cfgMu.Lock()
	defer d.cfgMu.Unlock()
	if d.rt.used.Load() {
		return fmt.Errorf("max concurrency must be set before the first request (current=%d)", d.maxConcurrency)
	}
	if n <= 0 || n > maxAllowedConcurrency {
		n = defaultConcurrencyForRole(d.role)
	}
	d.concurrencySet = true
	d.applyConcurrencyLocked(n)
	return nil
}

// applyConcurrencyLocked 重建信号量并同步 transport 空闲连接池配置（调用前需持有 cfgMu 且无在途请求）
func (d *Webdav) applyConcurrencyLocked(n int) {
	if n <= 0 {
		n = DefaultPrimaryConcurrency
	}
	sem := newSemaphore(n)
	d.sem = sem
	d.rt.sem.Store(sem)
	if tr, ok := d.rt.base.(*http.Transport); ok {
		tr.MaxIdleConns = n * 2
		tr.MaxIdleConnsPerHost = n
	}
	d.maxConcurrency = n
}

func (d *Webdav) Close() error {
	return nil
}

func (d *Webdav) Cli() *gowebdav.Client {
	return d.cli
}

func (d *Webdav) IsRootPathSet() bool {
	return d.rootPath != ""
}

func (d *Webdav) SetRootPath(rootPath string) error {
	if rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	rootPath = filepath.ToSlash(rootPath)
	var err error
	if rootPath[0] != '/' {
		rootPath = "/" + rootPath
	}
	if rootPath[len(rootPath)-1] != '/' {
		rootPath = rootPath + "/"
	}
	info, err := d.cli.Stat(rootPath)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("root path %s not exist", rootPath)
		}
		return err
	}
	if !info.IsDir() {
		return fmt.Errorf("root path %s is not a dir", rootPath)
	}
	d.rootPath = rootPath

	// 预置已知根目录及其祖先目录（已通过上方 Stat 校验存在）
	cleanRoot := filepath.ToSlash(filepath.Clean(rootPath))
	if d.knownDirs != nil {
		d.mkdirLock.Lock()
		d.knownDirs[cleanRoot] = true
		cur := ""
		for _, part := range strings.Split(strings.Trim(cleanRoot, "/"), "/") {
			if part == "" {
				continue
			}
			cur += "/" + part
			d.knownDirs[cur] = true
		}
		d.mkdirLock.Unlock()
	}

	return nil
}

func (d *Webdav) IsExist(path string) (bool, error) {
	if d.rootPath == "" {
		return false, fmt.Errorf("root path is empty")
	}
	fullPath := filepath.Join(d.rootPath, path)
	fullPath = filepath.ToSlash(fullPath)
	_, err := d.cli.Stat(fullPath)
	if err != nil {
		if os.IsNotExist(err) {
			return false, nil
		}
		if pathErr, ok := err.(*os.PathError); ok {
			if statusErr, ok := pathErr.Err.(gowebdav.StatusError); ok && statusErr.Status == 404 {
				return false, nil
			}
		}
		return false, err
	}
	return true, nil
}

func (d *Webdav) extractSizeOrStat(fullPath string, reader io.ReadCloser) (int64, error) {
	if src, ok := reader.(*semReleaseReadCloser); ok {
		if src.size >= 0 {
			return src.size, nil
		}
		// 若远端未返回 Content-Length / Content-Range，先释放当前流占用的信号量槽位，防止并发下嵌套 Stat 死锁
		src.releaseNow()
	} else if d.rt != nil {
		normPath := "/" + strings.TrimPrefix(fullPath, "/")
		if v, ok := d.rt.lastSizeMap.Load(normPath); ok {
			if sz, ok := v.(int64); ok && sz >= 0 {
				return sz, nil
			}
		}
	}
	info, err := d.cli.Stat(fullPath)
	if err != nil {
		return 0, err
	}
	return info.Size(), nil
}

func (d *Webdav) Download(path string) (io.ReadCloser, int64, error) {
	if d.rootPath == "" {
		return nil, 0, fmt.Errorf("root path is empty")
	}
	fullPath := filepath.Join(d.rootPath, path)
	fullPath = filepath.ToSlash(fullPath)
	reader, err := d.cli.ReadStream(fullPath)
	if err != nil {
		return nil, 0, err
	}
	size, err := d.extractSizeOrStat(fullPath, reader)
	if err != nil {
		reader.Close()
		return nil, 0, err
	}
	return reader, size, nil
}

func (d *Webdav) Delete(path string) error {
	if d.rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	fullPath := filepath.Join(d.rootPath, path)
	fullPath = filepath.ToSlash(fullPath)
	err := d.cli.Remove(fullPath)
	if err != nil {
		return err
	}
	if d.knownDirs != nil {
		d.mkdirLock.Lock()
		delete(d.knownDirs, fullPath)
		d.mkdirLock.Unlock()
	}
	return nil
}

func (d *Webdav) DownloadWithOffset(path string, offset int64) (io.ReadCloser, int64, error) {
	if d.rootPath == "" {
		return nil, 0, fmt.Errorf("root path is empty")
	}
	fullPath := filepath.Join(d.rootPath, path)
	fullPath = filepath.ToSlash(fullPath)
	reader, err := d.cli.ReadStreamRange(fullPath, offset, -1)
	if err != nil {
		return nil, 0, err
	}
	size, err := d.extractSizeOrStat(fullPath, reader)
	if err != nil {
		reader.Close()
		return nil, 0, err
	}
	return reader, size, nil
}

func (d *Webdav) ensureDir(dir string) error {
	dir = filepath.ToSlash(filepath.Clean(dir))
	if dir == "." || dir == "/" || dir == "" {
		return nil
	}

	d.mkdirLock.Lock()
	defer d.mkdirLock.Unlock()

	if d.knownDirs != nil && d.knownDirs[dir] {
		return nil
	}

	// 从根路径逐级向下确保目录存在，跳过已知的祖先目录，完全避免对已存在目录盲发 MKCOL
	parts := strings.Split(strings.Trim(dir, "/"), "/")
	current := ""
	for _, part := range parts {
		if current == "" {
			current = "/" + part
		} else {
			current = current + "/" + part
		}

		if d.knownDirs != nil && d.knownDirs[current] {
			continue
		}

		err := d.cli.Mkdir(current, 0755)
		if err != nil {
			errStr := err.Error()
			// WebDAV RFC 4918: 访问已存在集合返回 405 Method Not Allowed；
			// 并发事务锁定时返回 423 Locked，均代表该集合存在，视为成功并缓存
			if strings.Contains(errStr, "405") || strings.Contains(errStr, "Method Not Allowed") ||
				strings.Contains(errStr, "423") || strings.Contains(errStr, "Locked") {
				if d.knownDirs != nil {
					d.knownDirs[current] = true
				}
				continue
			}
			// 若因父目录缺失返回 409 Conflict（例如缓存的父目录在远端被清理），回退 MkdirAll 逐级补齐
			if strings.Contains(errStr, "409") || strings.Contains(errStr, "Conflict") {
				if mkErr := d.cli.MkdirAll(current, 0755); mkErr == nil ||
					strings.Contains(mkErr.Error(), "405") ||
					strings.Contains(mkErr.Error(), "Method Not Allowed") ||
					strings.Contains(mkErr.Error(), "423") ||
					strings.Contains(mkErr.Error(), "Locked") {
					if d.knownDirs != nil {
						d.knownDirs[current] = true
					}
					continue
				}
			}
			return err
		}
		if d.knownDirs != nil {
			d.knownDirs[current] = true
		}
	}

	if d.knownDirs != nil {
		d.knownDirs[dir] = true
	}
	return nil
}

func (d *Webdav) Upload(path string, reader io.ReadCloser, size int64, lastModified time.Time) error {
	if reader == nil {
		return fmt.Errorf("reader is nil")
	}
	defer reader.Close()
	if d.rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	fullPath := filepath.Join(d.rootPath, path)
	fullPath = filepath.ToSlash(fullPath)
	if err := d.ensureDir(filepath.Dir(fullPath)); err != nil {
		return err
	}
	// ensureDir 已完整校验并缓存父目录层级；此处使用 WriteStreamRaw 直接流式 PUT，
	// 彻底避免 gowebdav 默认 WriteStream 在每次单文件写入时盲发 MKCOL 导致并发 423 Locked 报错
	err := d.cli.WriteStreamRaw(fullPath, reader, size, 0666)
	if err != nil {
		return err
	}

	return nil
}

func (d *Webdav) Range(dir string, deal func(fs.FileInfo) bool) error {
	if d.rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	fullPath := filepath.Join(d.rootPath, dir)
	fullPath = filepath.ToSlash(fullPath)
	infos, err := d.cli.ReadDir(fullPath)
	if err != nil {
		return err
	}
	// 将扫描到的所有子目录自动填充进 knownDirs，彻底消除后续对其子文件的 MKCOL
	if d.knownDirs != nil {
		d.mkdirLock.Lock()
		d.knownDirs[fullPath] = true
		for _, info := range infos {
			if info.IsDir() {
				d.knownDirs[filepath.Join(fullPath, info.Name())] = true
			}
		}
		d.mkdirLock.Unlock()
	}
	sort.Sort(desc(infos))
	for _, info := range infos {
		if !deal(info) {
			break
		}
	}
	return nil
}

func (d *Webdav) Move(oldPath, newPath string) error {
	if d.rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	fullOld := filepath.ToSlash(filepath.Join(d.rootPath, oldPath))
	fullNew := filepath.ToSlash(filepath.Join(d.rootPath, newPath))
	parent := filepath.Dir(fullNew)
	_ = d.ensureDir(parent)
	return d.cli.Rename(fullOld, fullNew, true)
}

func (d *Webdav) Mkdir(dir string) error {
	if d.rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	fullDir := filepath.ToSlash(filepath.Join(d.rootPath, dir))
	return d.ensureDir(fullDir)
}

type desc []fs.FileInfo

func (d desc) Len() int      { return len(d) }
func (d desc) Swap(i, j int) { d[i], d[j] = d[j], d[i] }
func (d desc) Less(i, j int) bool {
	return d[i].ModTime().After(d[j].ModTime())
}
