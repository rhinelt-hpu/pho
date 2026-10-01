package api

import (
	"github.com/fregie/img_syncer/server/util"
)

// sanitizePath 对路径进行安全检查，防止路径遍历攻击。
func sanitizePath(name string) (string, error) {
	return util.SanitizePath(name)
}
