package imgmanager

import (
	"bytes"
	"strings"
	"testing"
	"time"

	pb "github.com/fregie/img_syncer/proto"
)

// TestWorkerNum 验证 NewImgManager 正确解析 WorkerNum
func TestWorkerNum(t *testing.T) {
	t.Run("explicit 4", func(t *testing.T) {
		im := NewImgManager(Option{WorkerNum: 4})
		defer im.Close()
		if im.opt.WorkerNum != 4 {
			t.Fatalf("WorkerNum = %d, want 4", im.opt.WorkerNum)
		}
	})
	t.Run("default 2 when zero", func(t *testing.T) {
		im := NewImgManager(Option{})
		defer im.Close()
		if im.opt.WorkerNum != defaultWorkerNum {
			t.Fatalf("WorkerNum = %d, want default %d", im.opt.WorkerNum, defaultWorkerNum)
		}
	})
	t.Run("default 2 when negative", func(t *testing.T) {
		im := NewImgManager(Option{WorkerNum: -1})
		defer im.Close()
		if im.opt.WorkerNum != defaultWorkerNum {
			t.Fatalf("WorkerNum = %d, want default %d", im.opt.WorkerNum, defaultWorkerNum)
		}
	})
}

// TestDeleteSingleImg_LivePhotoCleanup 验证删除 live_ 目录中的文件时会删除整个
// live_ 目录（包含 live video 等所有内容）
func TestDeleteSingleImg_LivePhotoCleanup(t *testing.T) {
	md := newMockDrive()

	// 模拟 live_ 目录结构:
	// 2023/01/01/
	//   live_IMG_0001/
	//     IMG_0001.jpg        ← 要删除的文件
	//     IMG_0001_live_video.mp4
	liveDir := "2023/01/01/live_IMG_0001"
	md.rangeFiles[liveDir] = []mockDirEntry{
		{name: "IMG_0001.jpg", size: 1000, isDir: false},
		{name: "IMG_0001_live_video.mp4", size: 5000, isDir: false},
	}

	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.dri = md

	path := "2023/01/01/live_IMG_0001/IMG_0001.jpg"
	err := im.DeleteSingleImg(path)
	if err != nil {
		t.Fatalf("DeleteSingleImg returned error: %v", err)
	}

	// 预期: 缩略图删除 + Range遍历文件删除 + 目录删除 + 最终删除
	if len(md.deleteCalls) < 5 {
		t.Fatalf("expected at least 5 delete calls, got %d: %v", len(md.deleteCalls), md.deleteCalls)
	}

	// 验证包含了视频文件删除（live video 也被清理）
	foundVideo := false
	foundDir := false
	for _, call := range md.deleteCalls {
		if call == liveDir {
			foundDir = true
		}
		if call == "2023/01/01/live_IMG_0001/IMG_0001_live_video.mp4" {
			foundVideo = true
		}
	}
	if !foundVideo {
		t.Errorf("expected live video file to be deleted too, but it wasn't. calls=%v", md.deleteCalls)
	}
	if !foundDir {
		t.Errorf("expected live photo directory to be deleted, but it wasn't. calls=%v", md.deleteCalls)
	}
}

// TestDeleteSingleImg_RegularPhotoNamedLiveNotMassDeleted 验证删除普通目录中
// 名为 live_xxx 的文件时不会误删除同目录的其他文件
func TestDeleteSingleImg_RegularPhotoNamedLiveNotMassDeleted(t *testing.T) {
	md := newMockDrive()

	// 模拟普通目录结构:
	// 2023/01/01/
	//   live_dog.jpg          ← 要删除的文件
	//   other_photo.jpg       ← 同目录其他文件，不应被删除
	md.rangeFiles["2023/01/01"] = []mockDirEntry{
		{name: "live_dog.jpg", size: 1000, isDir: false},
		{name: "other_photo.jpg", size: 2000, isDir: false},
	}

	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.dri = md

	path := "2023/01/01/live_dog.jpg"
	err := im.DeleteSingleImg(path)
	if err != nil {
		t.Fatalf("DeleteSingleImg returned error: %v", err)
	}

	// parentDir = "01"，不是 "live_xxx"，不会进 Range 分支
	if len(md.deleteCalls) != 2 {
		t.Fatalf("expected exactly 2 delete calls (thumbnail + main), got %d: %v", len(md.deleteCalls), md.deleteCalls)
	}

	for _, call := range md.deleteCalls {
		if call == "2023/01/01/other_photo.jpg" {
			t.Errorf("other_photo.jpg should NOT have been deleted, but it was. calls=%v", md.deleteCalls)
		}
	}
}

// TestRangeByDate_IncludesRequestedDay 验证 RangeByDate 对 DIRECTORY_TYPE_02
// 模式包含请求日期的文件
func TestRangeByDate_IncludesRequestedDay(t *testing.T) {
	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.SetDirectoryType(pb.DirectoryType_DIRECTORY_TYPE_02)

	md := newMockDrive()

	// 根目录下有三个日期目录
	md.rangeFiles["."] = []mockDirEntry{
		{name: "20260718", size: 0, isDir: true},
		{name: "20260719", size: 0, isDir: true},
		{name: "20260720", size: 0, isDir: true},
	}
	// 每个日期目录下有一个文件
	md.rangeFiles["20260718"] = []mockDirEntry{
		{name: "photo_0718.jpg", size: 100, isDir: false},
	}
	md.rangeFiles["20260719"] = []mockDirEntry{
		{name: "photo_0719.jpg", size: 100, isDir: false},
	}
	md.rangeFiles["20260720"] = []mockDirEntry{
		{name: "photo_0720.jpg", size: 100, isDir: false},
	}

	im.dri = md

	// 查询 2026-07-19 之前（含当日）的照片
	date := time.Date(2026, 7, 19, 0, 0, 0, 0, time.Local)
	var paths []string
	err := im.RangeByDate(date, func(info ImgInfo) bool {
		paths = append(paths, info.Path)
		return true
	})
	if err != nil {
		t.Fatalf("RangeByDate error: %v", err)
	}

	// 应该包含 0718 和 0719 的照片，但不包含 0720
	if len(paths) != 2 {
		t.Fatalf("expected 2 files, got %d: %v", len(paths), paths)
	}
}

// TestImgManagerCloseStopsWorkers 验证 Close() 能优雅停止 worker goroutine
func TestImgManagerCloseStopsWorkers(t *testing.T) {
	im := NewImgManager(Option{WorkerNum: 3})

	err := im.Close()
	if err != nil {
		t.Fatalf("Close returned error: %v", err)
	}
}

// TestAlbumLifecycle 验证云端相册生命周期（默认相册、创建、重命名、删除保护、移动归类、相册隔离查询）
func TestAlbumLifecycle(t *testing.T) {
	md := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	im.SetDrive(md)
	defer im.Close()

	// 1. 验证默认相册始终存在
	albums, err := im.ListAlbums()
	if err != nil {
		t.Fatalf("ListAlbums error: %v", err)
	}
	if len(albums) == 0 || albums[0].Name != DefaultAlbumName || !albums[0].IsDefault {
		t.Fatalf("expected default album %s, got: %+v", DefaultAlbumName, albums)
	}

	// 2. 创建自定义相册
	albumName := "日本旅行 2026"
	err = im.CreateAlbum(albumName)
	if err != nil {
		t.Fatalf("CreateAlbum error: %v", err)
	}

	// 3. 上传两张照片：一张在默认相册，一张在自定义相册
	date := time.Date(2026, 4, 15, 10, 0, 0, 0, time.Local)
	content := []byte("fake image data")
	err = im.Upload(bytes.NewReader(content), int64(len(content)), "photo1.jpg", date, WithAlbum(DefaultAlbumName))
	if err != nil {
		t.Fatalf("Upload photo1 failed: %v", err)
	}
	err = im.Upload(bytes.NewReader(content), int64(len(content)), "photo2.jpg", date, WithAlbum(albumName))
	if err != nil {
		t.Fatalf("Upload photo2 failed: %v", err)
	}

	// 4. 单相册查询：日本旅行 2026 应该只有 photo2
	var albumPaths []string
	err = im.RangeByAlbumAndDate(albumName, date, func(info ImgInfo) bool {
		albumPaths = append(albumPaths, info.Path)
		return true
	})
	if err != nil {
		t.Fatalf("RangeByAlbumAndDate error: %v", err)
	}
	if len(albumPaths) != 1 || !strings.Contains(albumPaths[0], "photo2.jpg") {
		t.Fatalf("expected only photo2 in album, got: %v", albumPaths)
	}

	// 5. 全局聚合查询：album == "" 时应能扫描到全部照片 (photo1 + photo2)
	var allPaths []string
	err = im.RangeByAlbumAndDate("", date, func(info ImgInfo) bool {
		allPaths = append(allPaths, info.Path)
		return true
	})
	if err != nil {
		t.Fatalf("RangeByAlbumAndDate global error: %v", err)
	}
	if len(allPaths) != 2 {
		t.Fatalf("expected 2 photos in global timeline, got %d: %v", len(allPaths), allPaths)
	}

	// 6. 移动归类：把 photo1 从默认相册移动到自定义相册
	path1 := im.genPath("photo1.jpg", date, Options{Album: DefaultAlbumName})
	newPaths, err := im.MoveAssets([]string{path1}, albumName)
	if err != nil {
		t.Fatalf("MoveAssets error: %v", err)
	}
	if len(newPaths) != 1 || !strings.HasPrefix(newPaths[0], albumName) {
		t.Fatalf("expected photo1 moved under %s, got: %v", albumName, newPaths)
	}

	// 7. 再次查询自定义相册：现在应该包含 2 张照片
	var newAlbumPaths []string
	_ = im.RangeByAlbumAndDate(albumName, date, func(info ImgInfo) bool {
		newAlbumPaths = append(newAlbumPaths, info.Path)
		return true
	})
	if len(newAlbumPaths) != 2 {
		t.Fatalf("expected 2 photos after move, got: %v", newAlbumPaths)
	}

	// 8. 重命名相册
	renamedAlbum := "2026 东京之旅"
	err = im.RenameAlbum(albumName, renamedAlbum)
	if err != nil {
		t.Fatalf("RenameAlbum error: %v", err)
	}

	// 9. 删除相册保护：禁止删除默认相册
	err = im.DeleteAlbum(DefaultAlbumName)
	if err == nil {
		t.Fatalf("expected error deleting default album, got nil")
	}

	// 10. 删除自定义相册成功
	err = im.DeleteAlbum(renamedAlbum)
	if err != nil {
		t.Fatalf("DeleteAlbum error: %v", err)
	}
}
