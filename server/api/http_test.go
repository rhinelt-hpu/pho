package api

import (
	"bytes"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"io"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/fregie/img_syncer/server/drive/webdav"
	"github.com/fregie/img_syncer/server/imgmanager"
)

// mockDrive 实现 imgmanager.StorageDrive 接口，用于测试 HTTP Range 处理
type mockDrive struct {
	content []byte
}

func (m *mockDrive) Upload(path string, content io.ReadCloser, size int64, modTime time.Time) error {
	return nil
}
func (m *mockDrive) IsExist(path string) (bool, error) { return true, nil }
func (m *mockDrive) Download(path string) (io.ReadCloser, int64, error) {
	return io.NopCloser(bytes.NewReader(m.content)), int64(len(m.content)), nil
}
func (m *mockDrive) DownloadWithOffset(path string, offset int64) (io.ReadCloser, int64, error) {
	if offset >= int64(len(m.content)) {
		return nil, 0, io.EOF
	}
	return io.NopCloser(bytes.NewReader(m.content[offset:])), int64(len(m.content)), nil
}
func (m *mockDrive) Delete(path string) error    { return nil }
func (m *mockDrive) Range(dir string, deal func(fs.FileInfo) bool) error { return nil }
func (m *mockDrive) Close() error                { return nil }
func (m *mockDrive) Move(oldPath, newPath string) error { return nil }
func (m *mockDrive) Mkdir(dir string) error      { return nil }

func newTestAPI() *api {
	im := imgmanager.NewImgManager(imgmanager.Option{WorkerNum: 1})
	im.SetDrive(&mockDrive{content: []byte("0123456789")})
	a := NewApi(im)
	a.SetHttpPort(0)
	return a
}

// newTestAPIWithEncryptedGcm 构造一个 mockDrive 持有 GCM 加密 buffer 的 test API。
func newTestAPIWithEncryptedGcm(password string, plaintext []byte) (*api, []byte) {
	im := imgmanager.NewImgManager(imgmanager.Option{WorkerNum: 1})
	encReader, err := imgmanager.EncryptedReaderWraper(
		io.NopCloser(bytes.NewReader(plaintext)),
		imgmanager.EncryptOption{Type: imgmanager.AES_256_GCM, Password: password},
	)
	if err != nil {
		panic(err)
	}
	encrypted, err := io.ReadAll(encReader)
	if err != nil {
		panic(err)
	}
	encReader.Close()
	im.SetDrive(&mockDrive{content: encrypted})
	a := NewApi(im)
	a.SetHttpPort(0)
	return a, encrypted
}

func doRangeRequest(a *api, rangeHeader string) *httptest.ResponseRecorder {
	return doRangeRequestWith(a, "test.jpg", rangeHeader, "", "")
}

func doRangeRequestWith(a *api, path, rangeHeader, encType, encPassword string) *httptest.ResponseRecorder {
	req := httptest.NewRequest(http.MethodGet, "/"+path, nil)
	// 去除前导斜杠，避免 sanitizePath 将路径视为绝对路径而拒绝
	req.URL.Path = path
	if rangeHeader != "" {
		req.Header.Set("Range", rangeHeader)
	}
	if encType != "" {
		req.Header.Set(HeaderEncryptType, encType)
	}
	if encPassword != "" {
		req.Header.Set(HeaderEncryptPassword, encPassword)
	}
	w := httptest.NewRecorder()
	a.httpHandler(w, req)
	return w
}

func TestHTTPDownloadRangeNormalPass(t *testing.T) {
	a := newTestAPI()

	// 测试 bytes=start-end 格式
	w := doRangeRequest(a, "bytes=0-4")
	if w.Code != http.StatusPartialContent {
		t.Fatalf("bytes=0-4: expected 206, got %d", w.Code)
	}
	if w.Body.String() != "01234" {
		t.Fatalf("bytes=0-4: expected body '01234', got '%s'", w.Body.String())
	}

	// 测试 bytes=start- 格式（无 end）
	w2 := doRangeRequest(a, "bytes=5-")
	if w2.Code != http.StatusPartialContent {
		t.Fatalf("bytes=5-: expected 206, got %d", w2.Code)
	}
	if w2.Body.String() != "56789" {
		t.Fatalf("bytes=5-: expected body '56789', got '%s'", w2.Body.String())
	}
}

func TestHTTPDownloadRangeNegativeRejected(t *testing.T) {
	a := newTestAPI()

	tests := []struct {
		name        string
		rangeHeader string
	}{
		{"start negative", "bytes=-50"},
		{"both negative", "bytes=-50-100"},
		{"suffix range form", "bytes=-500"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			w := doRangeRequest(a, tt.rangeHeader)
			if w.Code != http.StatusBadRequest {
				t.Errorf("%s: expected 400, got %d", tt.name, w.Code)
			}
		})
	}
}

func TestHTTPDownloadRangeOnGcmEncrypted(t *testing.T) {
	password := "gcm-range-pw"
	// 2.5MB plaintext 跨多个 GCM 分块（chunkSize=1MB）
	plaintext := make([]byte, 2*1024*1024+500*1024)
	for i := range plaintext {
		plaintext[i] = byte(i % 251)
	}

	a, _ := newTestAPIWithEncryptedGcm(password, plaintext)
	w := doRangeRequestWith(a, "test.jpg.aes", "bytes=1000000-1500000", "AES_256_GCM", password)
	if w.Code != http.StatusPartialContent {
		bodyPreview := w.Body.Bytes()
		if len(bodyPreview) > 64 {
			bodyPreview = bodyPreview[:64]
		}
		t.Fatalf("expected 206, got %d (body preview=%q)", w.Code, bodyPreview)
	}
	cr := w.Header().Get("Content-Range")
	wantCR := "bytes 1000000-1500000/2609152"
	if cr != wantCR {
		t.Fatalf("Content-Range: got %q, want %q", cr, wantCR)
	}
	want := plaintext[1000000 : 1500000+1]
	if !bytes.Equal(w.Body.Bytes(), want) {
		t.Fatalf("body mismatch: got %d bytes, want %d bytes", w.Body.Len(), len(want))
	}
}

func TestHTTPDownloadRangeGcmZeroStart(t *testing.T) {
	password := "gcm-range-pw-zero"
	plaintext := make([]byte, 2*1024*1024+500*1024)
	for i := range plaintext {
		plaintext[i] = byte(i % 251)
	}

	a, _ := newTestAPIWithEncryptedGcm(password, plaintext)
	w := doRangeRequestWith(a, "test.jpg.aes", "bytes=0-", "AES_256_GCM", password)
	if w.Code != http.StatusPartialContent {
		t.Fatalf("expected 206, got %d (body len=%d)", w.Code, w.Body.Len())
	}
	cr := w.Header().Get("Content-Range")
	wantCR := "bytes 0-2609151/2609152"
	if cr != wantCR {
		t.Fatalf("Content-Range: got %q, want %q", cr, wantCR)
	}
	if !bytes.Equal(w.Body.Bytes(), plaintext) {
		t.Fatalf("body mismatch: got %d bytes, want %d bytes", w.Body.Len(), len(plaintext))
	}
}

func TestParseAlbumHeader(t *testing.T) {
	req, _ := http.NewRequest("POST", "/", nil)
	if got := parseAlbumHeader(req); got != "" {
		t.Fatalf("expected empty, got %q", got)
	}

	req.Header.Set(HeaderAlbum, "my-album")
	if got := parseAlbumHeader(req); got != "my-album" {
		t.Fatalf("expected my-album, got %q", got)
	}

	// URL encoded Chinese album name: "测试"
	req.Header.Set(HeaderAlbum, "%E6%B5%8B%E8%AF%95")
	if got := parseAlbumHeader(req); got != "测试" {
		t.Fatalf("expected 测试, got %q", got)
	}

	// URL encoded "相机备份"
	req.Header.Set(HeaderAlbum, "%E7%9B%B8%E6%9C%BA%E5%A4%87%E4%BB%BD")
	if got := parseAlbumHeader(req); got != "相机备份" {
		t.Fatalf("expected 相机备份, got %q", got)
	}

	// Path traversal attempts
	req.Header.Set(HeaderAlbum, "../etc")
	if got := parseAlbumHeader(req); got != "" {
		t.Fatalf("expected empty for traversal, got %q", got)
	}
}

func TestRemoteStatsEndpoint(t *testing.T) {
	a := newTestAPI()
	webdav.GlobalStats.Reset()
	webdav.GlobalStats.Record("PROPFIND", "/dav/photo/", 207, 15)
	webdav.GlobalStats.Record("GET", "/dav/photo/.thumbnail/pic.jpg", 200, 25)
	webdav.GlobalStats.Record("PROPFIND", "/dav/photo/2026/", 429, 5)

	req := httptest.NewRequest("GET", "/debug/remote_stats", nil)
	w := httptest.NewRecorder()
	a.HttpHandler().ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", w.Code)
	}

	var stats webdav.RemoteStats
	if err := json.Unmarshal(w.Body.Bytes(), &stats); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}
	if stats.TotalRequests != 3 {
		t.Fatalf("expected 3 total requests, got %d", stats.TotalRequests)
	}
	if stats.RateLimitHits != 1 {
		t.Fatalf("expected 1 rate limit hit, got %d", stats.RateLimitHits)
	}
	if stats.ByMethod["PROPFIND"] != 2 {
		t.Fatalf("expected 2 PROPFINDs, got %d", stats.ByMethod["PROPFIND"])
	}

	// Test reset
	reqReset := httptest.NewRequest("POST", "/debug/remote_stats/reset", nil)
	wReset := httptest.NewRecorder()
	a.HttpHandler().ServeHTTP(wReset, reqReset)
	if wReset.Code != http.StatusOK {
		t.Fatalf("reset failed: %d", wReset.Code)
	}

	snap := webdav.GlobalStats.Snapshot()
	if snap.TotalRequests != 0 {
		t.Fatalf("expected 0 requests after reset, got %d", snap.TotalRequests)
	}
}

type inMemoryDrive struct {
	mu    sync.Mutex
	files map[string][]byte
}

func newInMemoryDrive() *inMemoryDrive {
	return &inMemoryDrive{files: make(map[string][]byte)}
}

func (m *inMemoryDrive) Upload(path string, content io.ReadCloser, size int64, modTime time.Time) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, err := io.ReadAll(content)
	if err != nil {
		return err
	}
	m.files[path] = data
	return nil
}

func (m *inMemoryDrive) IsExist(path string) (bool, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	_, ok := m.files[path]
	return ok, nil
}

func (m *inMemoryDrive) Download(path string) (io.ReadCloser, int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, ok := m.files[path]
	if !ok {
		return nil, 0, fs.ErrNotExist
	}
	return io.NopCloser(bytes.NewReader(data)), int64(len(data)), nil
}

func (m *inMemoryDrive) DownloadWithOffset(path string, offset int64) (io.ReadCloser, int64, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	data, ok := m.files[path]
	if !ok {
		return nil, 0, fs.ErrNotExist
	}
	if offset >= int64(len(data)) {
		return nil, 0, io.EOF
	}
	return io.NopCloser(bytes.NewReader(data[offset:])), int64(len(data)), nil
}

func (m *inMemoryDrive) Delete(path string) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	delete(m.files, path)
	return nil
}

func (m *inMemoryDrive) Range(dir string, deal func(fs.FileInfo) bool) error { return nil }
func (m *inMemoryDrive) Close() error                                        { return nil }
func (m *inMemoryDrive) Move(oldPath, newPath string) error                 { return nil }
func (m *inMemoryDrive) Mkdir(dir string) error                             { return nil }

func TestHTTPThumbnailFallbackAndBackfill(t *testing.T) {
	mainDrive := newInMemoryDrive()
	metaDrive := newInMemoryDrive()
	im := imgmanager.NewImgManager(imgmanager.Option{WorkerNum: 1})
	im.SetDrive(mainDrive)
	im.SetMetaDrive(metaDrive)
	defer im.Close()

	// 构造一张 600x400 的 JPEG 测试图片
	src := image.NewRGBA(image.Rect(0, 0, 600, 400))
	for y := 0; y < 400; y++ {
		for x := 0; x < 600; x++ {
			src.Set(x, y, color.RGBA{R: 0, G: 128, B: 255, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, src, nil); err != nil {
		t.Fatalf("encode jpeg failed: %v", err)
	}
	rawJpeg := buf.Bytes()

	// 存入主存储原图
	origPath := "2026/10/fallback_test.jpg"
	if err := mainDrive.Upload(origPath, io.NopCloser(bytes.NewReader(rawJpeg)), int64(len(rawJpeg)), time.Now()); err != nil {
		t.Fatalf("upload to mainDrive failed: %v", err)
	}

	apiHandler := &api{im: im}
	ts := httptest.NewServer(http.HandlerFunc(apiHandler.httpHandler))
	defer ts.Close()

	// 1. 发起 GET /thumbnail/ 应当触发兜底并在服务端就地缩放返回 200
	resp, err := http.Get(fmt.Sprintf("%s/thumbnail/%s", ts.URL, origPath))
	if err != nil {
		t.Fatalf("get thumbnail failed: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected status 200, got %d", resp.StatusCode)
	}
	// 验证未标记 X-Thumbnail-Fallback（因为服务端已直接成功生成高质量缩略图）
	if resp.Header.Get("X-Thumbnail-Fallback") == "true" {
		t.Fatalf("expected X-Thumbnail-Fallback to be empty for standard jpeg")
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("read body failed: %v", err)
	}
	decoded, format, err := image.Decode(bytes.NewReader(body))
	if err != nil {
		t.Fatalf("decode returned thumbnail failed: %v", err)
	}
	if format != "jpeg" {
		t.Fatalf("expected jpeg format, got %s", format)
	}
	if decoded.Bounds().Dx() != 400 {
		t.Fatalf("expected thumbnail width 400, got %d", decoded.Bounds().Dx())
	}

	// 2. 等待后台异步自动回填到副存储
	thumbPath := filepath.Join(".thumbnail", origPath)
	var backfilled bool
	for i := 0; i < 20; i++ {
		if exist, _ := metaDrive.IsExist(thumbPath); exist {
			backfilled = true
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !backfilled {
		t.Fatalf("expected thumbnail to be backfilled on metaDrive at %s", thumbPath)
	}

	// 3. 测试 POST /thumbnail_direct/ 接口直接补传缩略图
	directThumb := []byte("direct-test-thumbnail-data")
	directResp, err := http.Post(fmt.Sprintf("%s/thumbnail_direct/custom/direct.jpg", ts.URL), "image/jpeg", bytes.NewReader(directThumb))
	if err != nil {
		t.Fatalf("post thumbnail_direct failed: %v", err)
	}
	defer directResp.Body.Close()
	if directResp.StatusCode != http.StatusOK {
		t.Fatalf("expected status 200 from thumbnail_direct, got %d", directResp.StatusCode)
	}
	if exist, _ := metaDrive.IsExist(filepath.Join(".thumbnail", "custom/direct.jpg")); !exist {
		t.Fatalf("expected custom/direct.jpg to exist on metaDrive thumbnail directory")
	}
}
