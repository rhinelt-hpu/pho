package api

import (
	"context"
	"fmt"
	"io"
	"log"
	"path/filepath"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/imgmanager"
)

type api struct {
	im                *imgmanager.ImgManager
	httpPort          int
	startTime         time.Time

	pb.UnimplementedImgSyncerServer
}

func NewApi(im *imgmanager.ImgManager) *api {
	a := &api{
		im:        im,
		startTime: time.Now(),
	}
	return a
}

func (a *api) Ping(ctx context.Context, req *pb.PingRequest) (*pb.PingResponse, error) {
	return &pb.PingResponse{
		ServerStartTime: a.startTime.Unix(),
		UptimeSeconds:   int64(time.Since(a.startTime).Seconds()),
	}, nil
}

func (a *api) SetDirectoryType(ctx context.Context, req *pb.SetDirectoryTypeRequest) (rsp *pb.SetDirectoryTypeResponse, err error) {
	rsp = &pb.SetDirectoryTypeResponse{Success: true}
	a.im.SetDirectoryType(req.DirectoryType)
	return
}

func (a *api) SetLocalCacheDir(ctx context.Context, req *pb.SetLocalCacheDirRequest) (*pb.SetLocalCacheDirResponse, error) {
	if req.Path == "" {
		return &pb.SetLocalCacheDirResponse{Success: false, Message: "path cannot be empty"}, nil
	}
	a.im.SetLocalCacheDir(req.Path)
	log.Printf("[INFO] SetLocalCacheDir: %s, loaded records: %d, watermark: %d", req.Path, a.im.Manifest().RecordCount(), a.im.Manifest().GetMaxWatermark())
	return &pb.SetLocalCacheDirResponse{Success: true}, nil
}

func (a *api) SyncManifest(ctx context.Context, req *pb.SyncManifestRequest) (*pb.SyncManifestResponse, error) {
	d := a.im.MetaDrive()
	if d == nil {
		return &pb.SyncManifestResponse{Success: false, Message: "drive not initialized"}, nil
	}
	err := a.im.Manifest().Sync(d)
	if err != nil {
		return &pb.SyncManifestResponse{Success: false, Message: err.Error()}, nil
	}
	return &pb.SyncManifestResponse{
		Success:     true,
		Watermark:   a.im.Manifest().GetMaxWatermark(),
		RecordCount: int32(a.im.Manifest().RecordCount()),
	}, nil
}

func (a *api) ClearMetaDrive(ctx context.Context, req *pb.ClearMetaDriveRequest) (*pb.ClearMetaDriveResponse, error) {
	a.im.SetMetaDrive(nil)
	return &pb.ClearMetaDriveResponse{Success: true}, nil
}

func (a *api) RebuildManifest(ctx context.Context, req *pb.RebuildManifestRequest) (*pb.RebuildManifestResponse, error) {
	watermark, count, err := a.im.RebuildManifest()
	if err != nil {
		return &pb.RebuildManifestResponse{
			Success: false,
			Message: err.Error(),
		}, nil
	}
	return &pb.RebuildManifestResponse{
		Success:     true,
		Watermark:   watermark,
		RecordCount: int32(count),
	}, nil
}

func (a *api) ListByDate(ctx context.Context, req *pb.ListByDateRequest) (rsp *pb.ListByDateResponse, err error) {
	rsp = &pb.ListByDateResponse{Success: true}
	if req.MaxReturn <= 0 {
		req.MaxReturn = 100
	}
	if req.Offset <= 0 {
		req.Offset = 0
	}
	var e error
	var start time.Time
	if req.Date != "" {
		start, e = time.Parse("2006:01:02", req.Date)
		if e != nil {
			rsp.Success, rsp.Message = false, fmt.Sprintf("param error: date format error: %s", req.Date)
			return
		}
	}
	rsp.Infos = make([]*pb.FileInfo, 0, req.MaxReturn)
	offset := req.Offset
	needReturn := req.MaxReturn
	e = a.im.RangeByAlbumAndDate(req.Album, start, func(info imgmanager.ImgInfo) bool {
		if offset > 0 {
			offset--
			return true
		}
		rsp.Infos = append(rsp.Infos, &pb.FileInfo{
			Path:        info.Path,
			Size:        info.Size,
			IsLivePhoto: info.IsLivePhoto,
		})
		needReturn--
		return needReturn > 0
	})
	if e != nil {
		rsp.Success, rsp.Message = false, e.Error()
		return
	}
	return
}

func (a *api) Delete(ctx context.Context, req *pb.DeleteRequest) (rsp *pb.DeleteResponse, err error) {
	rsp = &pb.DeleteResponse{Success: true}
	for i, p := range req.Paths {
		cleaned, err := sanitizePath(p)
		if err != nil {
			rsp.Success = false
			rsp.Message = fmt.Sprintf("invalid path at index %d: %s", i, err.Error())
			return rsp, nil
		}
		req.Paths[i] = cleaned
	}
	a.im.DeleteImg(req.Paths)
	return
}

func (a *api) ListAlbums(ctx context.Context, req *pb.ListAlbumsRequest) (*pb.ListAlbumsResponse, error) {
	albums, err := a.im.ListAlbums()
	if err != nil {
		return &pb.ListAlbumsResponse{
			Success: false,
			Message: err.Error(),
		}, nil
	}
	pbAlbums := make([]*pb.AlbumInfo, 0, len(albums))
	for _, alb := range albums {
		pbAlbums = append(pbAlbums, &pb.AlbumInfo{
			Name:      alb.Name,
			Count:     alb.Count,
			CoverPath: alb.CoverPath,
			IsDefault: alb.IsDefault,
		})
	}
	return &pb.ListAlbumsResponse{
		Success: true,
		Albums:  pbAlbums,
	}, nil
}

func (a *api) CreateAlbum(ctx context.Context, req *pb.CreateAlbumRequest) (*pb.CreateAlbumResponse, error) {
	err := a.im.CreateAlbum(req.Name)
	if err != nil {
		return &pb.CreateAlbumResponse{
			Success: false,
			Message: err.Error(),
		}, nil
	}
	return &pb.CreateAlbumResponse{Success: true}, nil
}

func (a *api) DeleteAlbum(ctx context.Context, req *pb.DeleteAlbumRequest) (*pb.DeleteAlbumResponse, error) {
	err := a.im.DeleteAlbum(req.Name)
	if err != nil {
		return &pb.DeleteAlbumResponse{
			Success: false,
			Message: err.Error(),
		}, nil
	}
	return &pb.DeleteAlbumResponse{Success: true}, nil
}

func (a *api) RenameAlbum(ctx context.Context, req *pb.RenameAlbumRequest) (*pb.RenameAlbumResponse, error) {
	err := a.im.RenameAlbum(req.OldName, req.NewName)
	if err != nil {
		return &pb.RenameAlbumResponse{
			Success: false,
			Message: err.Error(),
		}, nil
	}
	return &pb.RenameAlbumResponse{Success: true}, nil
}

func (a *api) MoveAssets(ctx context.Context, req *pb.MoveAssetsRequest) (*pb.MoveAssetsResponse, error) {
	newPaths, err := a.im.MoveAssets(req.Paths, req.TargetAlbum)
	if err != nil {
		return &pb.MoveAssetsResponse{
			Success: false,
			Message: err.Error(),
		}, nil
	}
	return &pb.MoveAssetsResponse{
		Success:  true,
		NewPaths: newPaths,
	}, nil
}

func (a *api) FilterNotUploaded(stream pb.ImgSyncer_FilterNotUploadedServer) error {
	nameToID := make(map[string]string)
	targetIDs := make(map[string]bool)
	invalidIDs := make([]string, 0)
	var minDate, maxDate time.Time

	for {
		r, err := stream.Recv()
		if err != nil {
			if err == io.EOF {
				break
			}
			return err
		}
		for _, info := range r.Photos {
			t, err := time.Parse("2006:01:02 15:04:05", info.Date)
			if err != nil {
				invalidIDs = append(invalidIDs, info.Id)
				continue
			}
			if minDate.IsZero() || t.Before(minDate) {
				minDate = t
			}
			if maxDate.IsZero() || t.After(maxDate) {
				maxDate = t
			}
			encoded := encodeName(t, info.Name)
			nameToID[encoded] = info.Id
			nameToID[encoded+".aes"] = info.Id
			targetIDs[info.Id] = true
		}
		if r.IsFinished {
			break
		}
	}

	if len(targetIDs) == 0 {
		return stream.Send(&pb.FilterNotUploadedResponse{
			Success:    true,
			IsFinished: true,
			InvalidIds: invalidIDs,
		})
	}

	uploadedIDs := make([]string, 0)
	unmatchedCount := len(targetIDs)

	// 1. 优先从内存快照清单 (Manifest) 进行 O(1) 瞬时查验，完全避免网络 I/O
	if a.im.Manifest() != nil && a.im.Manifest().IsInitialized() {
		for encName, id := range nameToID {
			if targetIDs[id] {
				if _, found := a.im.Manifest().LookupFingerprint(encName); found {
					targetIDs[id] = false
					unmatchedCount--
					uploadedIDs = append(uploadedIDs, id)
				}
			}
		}
	}

	// 2. 如果还有未命中的，使用反向时间区间剪枝深搜物理目录作为最终 Ground Truth
	if unmatchedCount > 0 {
		a.im.RangeByDateRange(minDate, maxDate, func(info imgmanager.ImgInfo) bool {
			name := filepath.Base(info.Path)
			if id, ok := nameToID[name]; ok {
				if targetIDs[id] {
					targetIDs[id] = false
					unmatchedCount--
					uploadedIDs = append(uploadedIDs, id)
				}
			}
			return unmatchedCount > 0
		})
	}

	notUploadedIDs := make([]string, 0, unmatchedCount)
	for id, unmatched := range targetIDs {
		if unmatched {
			notUploadedIDs = append(notUploadedIDs, id)
		}
	}

	return stream.Send(&pb.FilterNotUploadedResponse{
		Success:        true,
		IsFinished:     true,
		NotUploaedIDs:  notUploadedIDs,
		NotUploadedIDs: notUploadedIDs,
		UploadedIDs:    uploadedIDs,
		InvalidIds:     invalidIDs,
	})
}

// func (a *api) FilterNotUploaded(ctx context.Context, req *pb.FilterNotUploadedRequest) (rsp *pb.FilterNotUploadedResponse, err error) {
// 	rsp = &pb.FilterNotUploadedResponse{Success: true}
// 	if len(req.Photos) == 0 {
// 		rsp.Success, rsp.Message = false, "param error: names is empty"
// 		return
// 	}
// 	all := make(map[string]bool)
// 	a.im.RangeByDate(time.Now(), func(path string, size int64) bool {
// 		name := filepath.Base(path)
// 		all[name] = true
// 		return true
// 	})
// 	rsp.NotUploaedIDs = make([]string, 0, 100)
// 	for _, info := range req.Photos {
// 		t, err := time.Parse("2006:01:02 15:04:05", info.Date)
// 		if err != nil {
// 			continue
// 		}
// 		if !all[encodeName(t, info.Name)] {
// 			rsp.NotUploaedIDs = append(rsp.NotUploaedIDs, info.Id)
// 		}
// 	}
// 	return
// }
