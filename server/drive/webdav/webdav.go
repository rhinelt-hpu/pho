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
	"time"

	"github.com/studio-b12/gowebdav"
)

const (
	defaultThumbnailDir  = ".thumbnail"
	defaultManifestDir   = ".manifest"
	MaxRemoteConcurrency = 16
)

type Webdav struct {
	url       string
	username  string
	password  string
	rootPath  string
	cli       *gowebdav.Client
	mkdirLock sync.Mutex // serializes mkdir to avoid race in gowebdav lib
	knownDirs map[string]bool
	sem       chan struct{}
	rt        *retryTransport
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
	sem         chan struct{}
	basePath    string
	lastSizeMap sync.Map
}

func (t *retryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	if t.sem != nil {
		select {
		case t.sem <- struct{}{}:
		case <-req.Context().Done():
			return nil, req.Context().Err()
		}
	}
	releaseSem := func() {
		if t.sem != nil {
			<-t.sem
		}
	}

	var resp *http.Response
	var err error
	start := time.Now()
	for i := 0; i < 3; i++ {
		resp, err = t.base.RoundTrip(req)
		if err == nil {
			if resp.StatusCode == http.StatusTooManyRequests {
				GlobalStats.Record(req.Method, req.URL.Path, resp.StatusCode, time.Since(start).Milliseconds())
				resp.Body.Close()
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
	GlobalStats.Record(req.Method, req.URL.Path, statusCode, time.Since(start).Milliseconds())
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
	sem := make(chan struct{}, MaxRemoteConcurrency)
	baseTransport := &http.Transport{
		TLSClientConfig:     &tls.Config{InsecureSkipVerify: insecure},
		MaxIdleConns:        MaxRemoteConcurrency * 2,
		MaxIdleConnsPerHost: MaxRemoteConcurrency,
		IdleConnTimeout:     90 * time.Second,
	}
	var basePath string
	if parsed, err := neturl.Parse(url); err == nil && parsed.Path != "" && parsed.Path != "/" {
		basePath = strings.TrimSuffix(parsed.Path, "/")
	}
	rt := &retryTransport{
		base:     baseTransport,
		sem:      sem,
		basePath: basePath,
	}
	d := &Webdav{
		url:       url,
		username:  username,
		password:  password,
		cli:       gowebdav.NewClient(url, username, password),
		knownDirs: make(map[string]bool),
		sem:       sem,
		rt:        rt,
	}
	d.cli.SetTransport(rt)
	if insecure {
		log.Printf("WARNING: TLS certificate verification disabled for WebDAV at %s, do not use in production", url)
	}
	d.cli.SetTimeout(60 * time.Second)
	return d
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

	// 预置已知根目录及其核心隐藏目录，避免后续盲目发送 MKCOL 产生 405
	cleanRoot := filepath.ToSlash(filepath.Clean(rootPath))
	if d.knownDirs != nil {
		d.mkdirLock.Lock()
		d.knownDirs[cleanRoot] = true
		d.knownDirs[filepath.Join(cleanRoot, defaultThumbnailDir)] = true
		d.knownDirs[filepath.Join(cleanRoot, defaultManifestDir)] = true
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
			// WebDAV RFC 4918 Section 9.3.1: MKCOL 访问已存在集合必须返回 405 Method Not Allowed，视为成功并缓存
			if strings.Contains(errStr, "405") || strings.Contains(errStr, "Method Not Allowed") {
				if d.knownDirs != nil {
					d.knownDirs[current] = true
				}
				continue
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
	err := d.cli.WriteStream(fullPath, reader, size, 0666)
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
