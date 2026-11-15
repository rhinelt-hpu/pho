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

// newConcurrencyStub 启动一个记录并发峰值的 WebDAV stub，每个请求耗时 delay
func newConcurrencyStub(t *testing.T, delay time.Duration) (srv *httptest.Server, peak *int32, handled *int32) {
	t.Helper()
	var active, maxObserved, totalHandled int32

	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		cur := atomic.AddInt32(&active, 1)
		for {
			prev := atomic.LoadInt32(&maxObserved)
			if cur <= prev || atomic.CompareAndSwapInt32(&maxObserved, prev, cur) {
				break
			}
		}

		time.Sleep(delay)

		atomic.AddInt32(&active, -1)
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
	t.Cleanup(ts.Close)
	return ts, &maxObserved, &totalHandled
}

// runConcurrentRequests 并发发起 total 个 PROPFIND/GET 请求（偶数 PROPFIND，奇数流式 GET）
func runConcurrentRequests(t *testing.T, drive *Webdav, total int) {
	t.Helper()
	var wg sync.WaitGroup
	wg.Add(total)
	errCh := make(chan error, total)

	for i := 0; i < total; i++ {
		go func(idx int) {
			defer wg.Done()
			if idx%2 == 0 {
				if _, err := drive.IsExist(fmt.Sprintf("photo_%d.jpg", idx)); err != nil {
					errCh <- err
				}
				return
			}
			rc, sz, err := drive.Download(fmt.Sprintf("photo_%d.jpg", idx))
			if err != nil {
				errCh <- err
				return
			}
			if sz != 11 {
				errCh <- fmt.Errorf("expected size 11, got %d", sz)
			}
			_, _ = io.ReadAll(rc)
			_ = rc.Close()
		}(i)
	}

	wg.Wait()
	close(errCh)
	for err := range errCh {
		t.Fatalf("unexpected request error: %v", err)
	}
}

// TestDefaultPrimaryConcurrencyLimit 验证主存储默认并发上限为 4
func TestDefaultPrimaryConcurrencyLimit(t *testing.T) {
	ts, peak, handled := newConcurrencyStub(t, 30*time.Millisecond)
	drive := NewWebdavDrive(ts.URL, "user", "pass", true)
	drive.rootPath = "/root/"

	if got := drive.MaxConcurrency(); got != DefaultPrimaryConcurrency {
		t.Fatalf("expected default primary concurrency %d, got %d", DefaultPrimaryConcurrency, got)
	}

	const totalRequests = 40
	runConcurrentRequests(t, drive, totalRequests)

	if got := atomic.LoadInt32(handled); got != totalRequests {
		t.Fatalf("expected %d handled requests, got %d", totalRequests, got)
	}
	if observed := atomic.LoadInt32(peak); observed > DefaultPrimaryConcurrency {
		t.Fatalf("expected peak concurrency <= %d, but observed %d", DefaultPrimaryConcurrency, observed)
	} else if observed < DefaultPrimaryConcurrency {
		t.Fatalf("expected concurrency to saturate the limit %d, observed %d", DefaultPrimaryConcurrency, observed)
	}
}

// TestSetMaxConcurrencyEnforced 验证 SetMaxConcurrency 后的实际并发上限生效
func TestSetMaxConcurrencyEnforced(t *testing.T) {
	ts, peak, handled := newConcurrencyStub(t, 30*time.Millisecond)
	drive := NewWebdavDrive(ts.URL, "user", "pass", true)
	drive.rootPath = "/root/"
	if err := drive.SetMaxConcurrency(2); err != nil {
		t.Fatalf("SetMaxConcurrency: %v", err)
	}
	if got := drive.MaxConcurrency(); got != 2 {
		t.Fatalf("expected concurrency 2, got %d", got)
	}

	const totalRequests = 24
	runConcurrentRequests(t, drive, totalRequests)

	if got := atomic.LoadInt32(handled); got != totalRequests {
		t.Fatalf("expected %d handled requests, got %d", totalRequests, got)
	}
	if observed := atomic.LoadInt32(peak); observed > 2 {
		t.Fatalf("expected peak concurrency <= 2, but observed %d", observed)
	} else if observed < 2 {
		t.Fatalf("expected concurrency to saturate the limit 2, observed %d", observed)
	}
}

// TestDefaultConcurrencyByRole 验证角色默认并发（主 4 / 副 16）、非法值回退与显式值保护
func TestDefaultConcurrencyByRole(t *testing.T) {
	d := NewWebdavDrive("http://127.0.0.1:1", "", "", false)
	if d.Role() != RolePrimary {
		t.Fatalf("expected default role %q, got %q", RolePrimary, d.Role())
	}
	if d.MaxConcurrency() != DefaultPrimaryConcurrency {
		t.Fatalf("expected primary default %d, got %d", DefaultPrimaryConcurrency, d.MaxConcurrency())
	}
	if d.Stats().Role() != RolePrimary {
		t.Fatalf("expected stats role primary, got %q", d.Stats().Role())
	}

	d.SetRole(RoleMeta)
	if d.Role() != RoleMeta || d.MaxConcurrency() != DefaultMetaConcurrency {
		t.Fatalf("expected meta role with concurrency %d, got role=%q concurrency=%d",
			DefaultMetaConcurrency, d.Role(), d.MaxConcurrency())
	}
	if d.Stats().Role() != RoleMeta {
		t.Fatalf("expected stats role meta, got %q", d.Stats().Role())
	}

	// 非法值（<=0 / 超上限）回退为角色默认值
	for _, n := range []int{0, -3, maxAllowedConcurrency + 1} {
		if err := d.SetMaxConcurrency(n); err != nil {
			t.Fatalf("SetMaxConcurrency(%d): %v", n, err)
		}
		if got := d.MaxConcurrency(); got != DefaultMetaConcurrency {
			t.Fatalf("SetMaxConcurrency(%d) should fall back to %d, got %d", n, DefaultMetaConcurrency, got)
		}
	}

	// 显式设置后，角色切换不得覆盖显式并发值
	d2 := NewWebdavDrive("http://127.0.0.1:1", "", "", false)
	if err := d2.SetMaxConcurrency(8); err != nil {
		t.Fatalf("SetMaxConcurrency(8): %v", err)
	}
	d2.SetRole(RoleMeta)
	if d2.MaxConcurrency() != 8 {
		t.Fatalf("expected explicit concurrency 8 to survive role switch, got %d", d2.MaxConcurrency())
	}
}

// TestSetMaxConcurrencyRejectedAfterFirstRequest 验证运行中变更并发上限被拒绝且不改变现有配置
func TestSetMaxConcurrencyRejectedAfterFirstRequest(t *testing.T) {
	ts, _, _ := newConcurrencyStub(t, 0)
	drive := NewWebdavDrive(ts.URL, "user", "pass", true)
	drive.rootPath = "/root/"
	if err := drive.SetMaxConcurrency(3); err != nil {
		t.Fatalf("SetMaxConcurrency: %v", err)
	}
	if _, err := drive.IsExist("photo.jpg"); err != nil {
		t.Fatalf("IsExist: %v", err)
	}
	if err := drive.SetMaxConcurrency(8); err == nil {
		t.Fatalf("expected error when changing concurrency after requests started")
	}
	if got := drive.MaxConcurrency(); got != 3 {
		t.Fatalf("expected concurrency unchanged at 3, got %d", got)
	}
}

// TestStatsPerInstance 验证请求统计按驱动实例独立，GlobalStats 仍为全量聚合
func TestStatsPerInstance(t *testing.T) {
	GlobalStats.Reset()

	stubA := newWebdavStub(t, nil)
	stubB := newWebdavStub(t, nil)
	driveA := driveWithRoot(t, stubA, "storage")
	driveB := driveWithRoot(t, stubB, "storage")
	driveB.SetRole(RoleMeta)
	// SetRootPath 本身会发一次 Stat，重置各实例计数后开始统计增量
	driveA.Stats().Reset()
	driveB.Stats().Reset()
	GlobalStats.Reset()

	if _, err := driveA.IsExist("a.jpg"); err != nil {
		t.Fatalf("driveA IsExist: %v", err)
	}
	if _, err := driveA.IsExist("b.jpg"); err != nil {
		t.Fatalf("driveA IsExist: %v", err)
	}
	if _, err := driveB.IsExist("c.jpg"); err != nil {
		t.Fatalf("driveB IsExist: %v", err)
	}

	snapA := driveA.Stats().Snapshot()
	snapB := driveB.Stats().Snapshot()
	agg := GlobalStats.Snapshot()

	if snapA.TotalRequests != 2 {
		t.Fatalf("expected driveA total 2, got %d", snapA.TotalRequests)
	}
	if snapB.TotalRequests != 1 {
		t.Fatalf("expected driveB total 1, got %d", snapB.TotalRequests)
	}
	if snapA.Role != RolePrimary || snapB.Role != RoleMeta {
		t.Fatalf("expected roles primary/meta, got %q/%q", snapA.Role, snapB.Role)
	}
	if agg.TotalRequests != 3 {
		t.Fatalf("expected aggregate total 3, got %d", agg.TotalRequests)
	}
	if agg.Role != RoleAggregate {
		t.Fatalf("expected aggregate role %q, got %q", RoleAggregate, agg.Role)
	}

	// Reset 只影响目标实例
	driveA.Stats().Reset()
	if sna := driveA.Stats().Snapshot(); sna.TotalRequests != 0 {
		t.Fatalf("expected driveA reset to 0, got %d", sna.TotalRequests)
	}
	if sna := driveB.Stats().Snapshot(); sna.TotalRequests != 1 {
		t.Fatalf("expected driveB untouched after resetting A, got %d", sna.TotalRequests)
	}
	if sna := driveA.Stats().Snapshot(); sna.Role != RolePrimary {
		t.Fatalf("expected role preserved after reset, got %q", sna.Role)
	}
}

// TestStatsByMethodAndStatus 验证实例统计的方法/状态聚合与限流命中计数
func TestStatsByMethodAndStatus(t *testing.T) {
	sc := NewStatsCollectorWithRole(50, RoleMeta)
	sc.Record("PROPFIND", "/dav/photo/", 207, 15)
	sc.Record("GET", "/dav/photo/.thumbnail/pic.jpg", 200, 25)
	sc.Record("PROPFIND", "/dav/photo/2026/", 429, 5)

	snap := sc.Snapshot()
	if snap.TotalRequests != 3 {
		t.Fatalf("expected 3 total requests, got %d", snap.TotalRequests)
	}
	if snap.ByMethod["PROPFIND"] != 2 || snap.ByMethod["GET"] != 1 {
		t.Fatalf("unexpected by_method: %+v", snap.ByMethod)
	}
	if snap.RateLimitHits != 1 {
		t.Fatalf("expected 1 rate limit hit, got %d", snap.RateLimitHits)
	}
	if snap.Role != RoleMeta {
		t.Fatalf("expected role meta, got %q", snap.Role)
	}
	if len(snap.RecentLogs) != 3 {
		t.Fatalf("expected 3 recent logs, got %d", len(snap.RecentLogs))
	}
}
