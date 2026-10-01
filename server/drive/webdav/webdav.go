package webdav

import (
	"crypto/tls"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"sync"
	"time"

	"github.com/studio-b12/gowebdav"
)

type Webdav struct {
	url       string
	username  string
	password  string
	rootPath  string
	cli       *gowebdav.Client
	mkdirLock sync.Mutex // serializes mkdir to avoid race in gowebdav lib
}

type retryTransport struct {
	base http.RoundTripper
}

func (t *retryTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	var resp *http.Response
	var err error
	start := time.Now()
	for i := 0; i < 3; i++ {
		resp, err = t.base.RoundTrip(req)
		if err == nil && resp.StatusCode == http.StatusTooManyRequests {
			GlobalStats.Record(req.Method, req.URL.Path, resp.StatusCode, time.Since(start).Milliseconds())
			resp.Body.Close()
			time.Sleep(time.Duration(1<<i) * 1000 * time.Millisecond)
			continue
		}
		break
	}
	statusCode := 0
	if resp != nil {
		statusCode = resp.StatusCode
	}
	GlobalStats.Record(req.Method, req.URL.Path, statusCode, time.Since(start).Milliseconds())
	return resp, err
}

func NewWebdavDrive(url, username, password string, insecure bool) *Webdav {
	d := &Webdav{
		url:      url,
		username: username,
		password: password,
		cli:      gowebdav.NewClient(url, username, password),
	}
	baseTransport := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: insecure},
	}
	d.cli.SetTransport(&retryTransport{base: baseTransport})
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
	info, err := d.cli.Stat(fullPath)
	if err != nil {
		reader.Close()
		return nil, 0, err
	}
	return reader, info.Size(), nil
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
	info, err := d.cli.Stat(fullPath)
	if err != nil {
		reader.Close()
		return nil, 0, err
	}
	return reader, info.Size(), nil
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
	d.mkdirLock.Lock()
	err := d.cli.MkdirAll(filepath.Dir(fullPath), 0755)
	d.mkdirLock.Unlock()
	if err != nil {
		return err
	}
	err = d.cli.WriteStream(fullPath, reader, size, 0666)
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
	d.mkdirLock.Lock()
	_ = d.cli.MkdirAll(parent, 0755)
	d.mkdirLock.Unlock()
	return d.cli.Rename(fullOld, fullNew, true)
}

func (d *Webdav) Mkdir(dir string) error {
	if d.rootPath == "" {
		return fmt.Errorf("root path is empty")
	}
	fullDir := filepath.ToSlash(filepath.Join(d.rootPath, dir))
	d.mkdirLock.Lock()
	err := d.cli.MkdirAll(fullDir, 0755)
	d.mkdirLock.Unlock()
	return err
}

type desc []fs.FileInfo

func (d desc) Len() int      { return len(d) }
func (d desc) Swap(i, j int) { d[i], d[j] = d[j], d[i] }
func (d desc) Less(i, j int) bool {
	return d[i].ModTime().After(d[j].ModTime())
}
