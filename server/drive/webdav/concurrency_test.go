package webdav

import (
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func TestRemoteConcurrencyLimit16(t *testing.T) {
	var activeRequests int32
	var maxObservedConcurrency int32
	var totalHandled int32

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cur := atomic.AddInt32(&activeRequests, 1)
		for {
			prevMax := atomic.LoadInt32(&maxObservedConcurrency)
			if cur <= prevMax || atomic.CompareAndSwapInt32(&maxObservedConcurrency, prevMax, cur) {
				break
			}
		}

		// 模拟远端请求耗时 30ms
		time.Sleep(30 * time.Millisecond)

		atomic.AddInt32(&activeRequests, -1)
		atomic.AddInt32(&totalHandled, 1)

		if r.Method == "PROPFIND" {
			w.Header().Set("Content-Type", "application/xml; charset=utf-8")
			w.WriteHeader(http.StatusMultiStatus)
			_, _ = w.Write([]byte(`<?xml version="1.0" encoding="utf-8"?>
<D:multistatus xmlns:D="DAV:">
  <D:response>
    <D:href>/root/</D:href>
    <D:propstat>
      <D:prop>
        <D:resourcetype><D:collection/></D:resourcetype>
        <D:getcontentlength>0</D:getcontentlength>
      </D:prop>
      <D:status>HTTP/1.1 200 OK</D:status>
    </D:propstat>
  </D:response>
</D:multistatus>`))
			return
		}

		w.Header().Set("Content-Length", "11")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("hello world"))
	}))
	defer ts.Close()

	drive := NewWebdavDrive(ts.URL, "user", "pass", true)
	drive.rootPath = "/root/"

	const totalRequests = 50
	var wg sync.WaitGroup
	wg.Add(totalRequests)
	errCh := make(chan error, totalRequests)

	for i := 0; i < totalRequests; i++ {
		go func(idx int) {
			defer wg.Done()
			if idx%2 == 0 {
				// 模拟 PROPFIND / Stat 请求
				_, err := drive.IsExist(fmt.Sprintf("photo_%d.jpg", idx))
				if err != nil {
					errCh <- err
				}
			} else {
				// 模拟 GET 下载缩略图/原图请求（验证流关闭后才释放信号量槽位）
				rc, err := drive.Cli().ReadStream(fmt.Sprintf("/root/photo_%d.jpg", idx))
				if err != nil {
					errCh <- err
					return
				}
				_, _ = io.ReadAll(rc)
				_ = rc.Close()
			}
		}(i)
	}

	wg.Wait()
	close(errCh)

	for err := range errCh {
		t.Fatalf("unexpected request error: %v", err)
	}

	peak := atomic.LoadInt32(&maxObservedConcurrency)
	handled := atomic.LoadInt32(&totalHandled)

	if handled != totalRequests {
		t.Fatalf("expected %d handled requests, got %d", totalRequests, handled)
	}
	if peak > MaxRemoteConcurrency {
		t.Fatalf("expected peak concurrency <= %d, but observed %d", MaxRemoteConcurrency, peak)
	}
	if peak < 4 {
		t.Fatalf("expected concurrent execution (peak >= 4), but observed %d", peak)
	}
	t.Logf("Successfully queued %d requests: peak concurrency = %d (limit = %d)", handled, peak, MaxRemoteConcurrency)
}
