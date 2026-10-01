package webdav

import (
	"net/http"
	"strings"
	"sync"
	"time"
)

type AccessLog struct {
	Method     string `json:"method"`
	Path       string `json:"path"`
	Status     int    `json:"status"`
	DurationMs int64  `json:"duration_ms"`
	Timestamp  int64  `json:"timestamp"`
}

type RemoteStats struct {
	TotalRequests int64             `json:"total_requests"`
	ByMethod      map[string]int64  `json:"by_method"`
	ByStatus      map[string]int64  `json:"by_status"`
	RateLimitHits int64             `json:"rate_limit_hits"`
	RecentLogs    []AccessLog       `json:"recent_logs"`
}

type StatsCollector struct {
	mu            sync.RWMutex
	totalRequests int64
	byMethod      map[string]int64
	byStatus      map[string]int64
	rateLimitHits int64
	recentLogs    []AccessLog
	maxLogs       int
}

var GlobalStats = NewStatsCollector(50)

func NewStatsCollector(maxLogs int) *StatsCollector {
	return &StatsCollector{
		byMethod:   make(map[string]int64),
		byStatus:   make(map[string]int64),
		recentLogs: make([]AccessLog, 0, maxLogs),
		maxLogs:    maxLogs,
	}
}

func (sc *StatsCollector) Record(method, path string, status int, durationMs int64) {
	sc.mu.Lock()
	defer sc.mu.Unlock()

	sc.totalRequests++
	sc.byMethod[method]++
	statusKey := http.StatusText(status)
	if statusKey == "" {
		statusKey = string(rune(status))
	}
	// WebDAV RFC 4918 规范：MKCOL 作用于已存在目录必须返回 405，标记为已存在，避免用户误判为故障
	if method == "MKCOL" && status == http.StatusMethodNotAllowed {
		statusKey = "collection exists (405)"
	}
	sc.byStatus[strings.ToLower(statusKey)]++
	if status == http.StatusTooManyRequests {
		sc.rateLimitHits++
	}

	logItem := AccessLog{
		Method:     method,
		Path:       path,
		Status:     status,
		DurationMs: durationMs,
		Timestamp:  time.Now().Unix(),
	}

	if len(sc.recentLogs) >= sc.maxLogs {
		sc.recentLogs = append(sc.recentLogs[1:], logItem)
	} else {
		sc.recentLogs = append(sc.recentLogs, logItem)
	}
}

func (sc *StatsCollector) Snapshot() RemoteStats {
	sc.mu.RLock()
	defer sc.mu.RUnlock()

	methodCopy := make(map[string]int64, len(sc.byMethod))
	for k, v := range sc.byMethod {
		methodCopy[k] = v
	}

	statusCopy := make(map[string]int64, len(sc.byStatus))
	for k, v := range sc.byStatus {
		statusCopy[k] = v
	}

	logsCopy := make([]AccessLog, len(sc.recentLogs))
	copy(logsCopy, sc.recentLogs)

	return RemoteStats{
		TotalRequests: sc.totalRequests,
		ByMethod:      methodCopy,
		ByStatus:      statusCopy,
		RateLimitHits: sc.rateLimitHits,
		RecentLogs:    logsCopy,
	}
}

func (sc *StatsCollector) Reset() {
	sc.mu.Lock()
	defer sc.mu.Unlock()

	sc.totalRequests = 0
	sc.byMethod = make(map[string]int64)
	sc.byStatus = make(map[string]int64)
	sc.rateLimitHits = 0
	sc.recentLogs = make([]AccessLog, 0, sc.maxLogs)
}
