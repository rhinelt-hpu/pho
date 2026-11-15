package api

import (
	"context"
	"fmt"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/drive/webdav"
)

// manifestSyncWait 为构造响应 Message 等待 manifest 首次同步完成的上限（超时则返回当前已知状态）
const manifestSyncWait = 1500 * time.Millisecond

func (a *api) SetDriveWebdav(ctx context.Context, req *pb.SetDriveWebdavRequest) (rsp *pb.SetDriveWebdavResponse, e error) {
	rsp = &pb.SetDriveWebdavResponse{Success: true}
	if req.Addr == "" {
		rsp.Success, rsp.Message = false, "param error: url is empty"
		return
	}
	d := webdav.NewWebdavDrive(req.Addr, req.Username, req.Password, req.Insecure)
	// 每驱动独立并发：主存储（云盘）保守，副存储（本机磁盘）高并发。
	// 必须在首次网络请求（下方的探活 Stat）前设置。
	if req.IsMetaDrive {
		d.SetRole(webdav.RoleMeta)
		_ = d.SetMaxConcurrency(webdav.DefaultMetaConcurrency)
	} else {
		d.SetRole(webdav.RolePrimary)
		_ = d.SetMaxConcurrency(webdav.DefaultPrimaryConcurrency)
	}
	// 握手验证阶段设置 6 秒快速探活超时，避免网络不可达/超时时协程阻塞 60 秒
	d.Cli().SetTimeout(6 * time.Second)
	_, err := d.Cli().Stat("/")
	if err != nil {
		rsp.Success, rsp.Message = false, fmt.Sprintf("connect to %s failed: %s", req.Addr, err.Error())
		return
	}
	if req.Root != "" {
		err := d.SetRootPath(req.Root)
		if err != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("set root path failed: %s", err.Error())
			return
		}
	}
	// 握手验证通过后，将 Client 超时恢复为正常数据传输超时（60秒）
	d.Cli().SetTimeout(60 * time.Second)

	syncSeq := a.im.ManifestSyncSeq()
	start := time.Now()
	if req.IsMetaDrive {
		a.im.SetMetaDrive(d)
	} else {
		a.im.SetDrive(d)
	}
	// 仅在真正会触发 manifest 同步（已设 root）时等待，最多 manifestSyncWait，
	// 以便把真实统计回传给客户端日志
	if req.Root != "" {
		deadline := time.Now().Add(manifestSyncWait)
		for a.im.ManifestSyncSeq() == syncSeq && time.Now().Before(deadline) {
			time.Sleep(20 * time.Millisecond)
		}
	}
	info := a.im.LastManifestSync()
	source := info.Source
	if source != "local-cache" && source != "remote" {
		// 同步尚未开始/元数据存储未就绪：按本地缓存是否已加载回退
		if a.im.Manifest().IsInitialized() {
			source = "local-cache"
		} else {
			source = "remote"
		}
	}
	rsp.Message = fmt.Sprintf("manifest: records=%d watermark=%d source=%s cost=%dms",
		info.Records, info.Watermark, source, time.Since(start).Milliseconds())
	return
}

func (a *api) ListDriveWebdavDir(ctx context.Context, req *pb.ListDriveWebdavDirRequest) (rsp *pb.ListDriveWebdavDirResponse, e error) {
	rsp = &pb.ListDriveWebdavDirResponse{Success: true}
	dri := a.im.Drive()
	if req.IsMetaDrive {
		dri = a.im.MetaDriveRaw()
	}
	if dri == nil {
		rsp.Success, rsp.Message = false, "drive is not set"
		return
	}
	webdav, ok := dri.(*webdav.Webdav)
	if !ok {
		rsp.Success, rsp.Message = false, "drive is not webdav"
		return
	}
	if req.Dir == "" {
		req.Dir = "/"
	}
	rsp.Dirs = make([]string, 0)
	cli := webdav.Cli()
	if cli == nil {
		rsp.Success, rsp.Message = false, "webdav client is not set"
		return
	}
	infos, err := cli.ReadDir(req.Dir)
	if err != nil {
		rsp.Success, rsp.Message = false, fmt.Sprintf("list dir failed: %s", err.Error())
		return
	}
	for _, info := range infos {
		if info.IsDir() {
			rsp.Dirs = append(rsp.Dirs, info.Name())
		}
	}

	return
}
