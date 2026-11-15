package util

import (
	"log"
	"sync"
	"time"
)

// LogDedupWindow 重复日志的去重时间窗（同一 key 在窗口内只输出一次）
const LogDedupWindow = 30 * time.Second

var (
	logMu   sync.Mutex
	logSeen = make(map[string]time.Time)
)

// RateLimitedLogf 按 key 做时间窗去重后输出日志，避免高频路径（分页查询、缩略图兜底、
// manifest 命中、限流重试等）刷屏。调用方负责在 format 里带上 [I]/[W]/[E] 前缀。
func RateLimitedLogf(key, format string, args ...interface{}) {
	now := time.Now()
	logMu.Lock()
	if last, ok := logSeen[key]; ok && now.Sub(last) < LogDedupWindow {
		logMu.Unlock()
		return
	}
	logSeen[key] = now
	// 长期运行时清理过期 key，避免 map 无界增长
	if len(logSeen) > 512 {
		for k, t := range logSeen {
			if now.Sub(t) >= LogDedupWindow {
				delete(logSeen, k)
			}
		}
	}
	logMu.Unlock()

	log.Printf(format, args...)
}

// ResetRateLimitedLog 清空去重状态（仅测试使用）
func ResetRateLimitedLog() {
	logMu.Lock()
	defer logMu.Unlock()
	logSeen = make(map[string]time.Time)
}
