package imgmanager

import (
	"bytes"
	"image"
	"image/color"
	_ "image/gif"
	"image/jpeg"
	_ "image/png"
	"io"
	"log"
	"path/filepath"
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

	// 7.1 验证 ListAlbums 计数：相册中的 Count 必须准确为 2
	albumsAfterMove, err := im.ListAlbums()
	if err != nil {
		t.Fatalf("ListAlbums after move error: %v", err)
	}
	var targetCount int64
	for _, a := range albumsAfterMove {
		if a.Name == albumName {
			targetCount = a.Count
		}
	}
	if targetCount != 2 {
		t.Fatalf("expected 2 photos count in album %s, got %d", albumName, targetCount)
	}

	// 7.2 上传一张根目录下未分相册的老版本照片（模拟旧版本存量数据）
	legacyDate := time.Date(2026, 4, 16, 12, 0, 0, 0, time.Local)
	legacyPath := filepath.Join(legacyDate.Format("2006/01/02"), "legacy.jpg")
	_ = md.Upload(legacyPath, io.NopCloser(bytes.NewReader(content)), int64(len(content)), legacyDate)

	// 7.3 查询默认相册（相机备份）：必须包含 legacy 照片
	var defaultAlbumPaths []string
	_ = im.RangeByAlbumAndDate(DefaultAlbumName, time.Time{}, func(info ImgInfo) bool {
		defaultAlbumPaths = append(defaultAlbumPaths, info.Path)
		return true
	})
	if len(defaultAlbumPaths) != 1 || defaultAlbumPaths[0] != legacyPath {
		t.Fatalf("expected legacy photo in default album query, got: %v", defaultAlbumPaths)
	}

	// 7.4 验证 ListAlbums 默认相册计数：必须为 1
	albumsWithLegacy, err := im.ListAlbums()
	if err != nil {
		t.Fatalf("ListAlbums error: %v", err)
	}
	var defaultCount int64
	for _, a := range albumsWithLegacy {
		if a.Name == DefaultAlbumName {
			defaultCount = a.Count
		}
	}
	if defaultCount != 1 {
		t.Fatalf("expected 1 photo in default album, got %d", defaultCount)
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

// TestMoveAssets_CleanEmptyDirectoriesAndAlbums 验证移动照片后若文件夹或相册变为空，会自动自底向上删除空目录与相册
func TestMoveAssets_CleanEmptyDirectoriesAndAlbums(t *testing.T) {
	md := newMockDrive()
	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.dri = md

	date := time.Date(2026, 5, 20, 10, 0, 0, 0, time.Local)
	content := []byte("dummy image content")

	// 1. 创建源相册 "临时相册" 并上传 1 张照片及缩略图
	srcAlbum := "临时相册"
	targetAlbum := "归档相册"
	srcPath := filepath.Join(srcAlbum, date.Format("2006/01/02"), "img1.jpg")
	srcThumb := filepath.Join(defaultThumbnailDir, srcPath)

	_ = md.Upload(srcPath, io.NopCloser(bytes.NewReader(content)), int64(len(content)), date)
	_ = md.Upload(srcThumb, io.NopCloser(bytes.NewReader(content)), int64(len(content)), date)

	// 验证上传后源目录及相册均存在
	exist, _ := md.IsExist(srcAlbum)
	if !exist {
		t.Fatalf("expected srcAlbum to exist")
	}
	exist, _ = md.IsExist(filepath.Dir(srcPath))
	if !exist {
		t.Fatalf("expected src dir to exist")
	}

	// 2. 将照片从 "临时相册" 移动到 "归档相册"
	newPaths, err := im.MoveAssets([]string{srcPath}, targetAlbum)
	if err != nil {
		t.Fatalf("MoveAssets failed: %v", err)
	}
	if len(newPaths) != 1 {
		t.Fatalf("expected 1 new path, got %v", newPaths)
	}

	// 3. 验证移动后：变为空的叶子日期目录、中间月份/年份目录、以及空相册自身均被自动删除
	dateDir := filepath.Dir(srcPath) // 临时相册/2026/05/20
	monthDir := filepath.Dir(dateDir) // 临时相册/2026/05
	yearDir := filepath.Dir(monthDir) // 临时相册/2026

	for _, d := range []string{dateDir, monthDir, yearDir, srcAlbum} {
		if exist, _ := md.IsExist(d); exist {
			t.Errorf("expected dir %s to be deleted after move, but it still exists", d)
		}
	}

	// 缩略图目录对应的空相册及空日期目录也应一并被删除
	thumbDateDir := filepath.Join(defaultThumbnailDir, dateDir)
	thumbAlbumDir := filepath.Join(defaultThumbnailDir, srcAlbum)
	if exist, _ := md.IsExist(thumbDateDir); exist {
		t.Errorf("expected thumb date dir %s to be deleted, but exists", thumbDateDir)
	}
	if exist, _ := md.IsExist(thumbAlbumDir); exist {
		t.Errorf("expected thumb album dir %s to be deleted, but exists", thumbAlbumDir)
	}

	// 但受保护的 .thumbnail 根目录绝对不能被删除
	if exist, _ := md.IsExist(defaultThumbnailDir); !exist {
		t.Errorf("protected thumbnail root %s should NOT be deleted", defaultThumbnailDir)
	}

	// 4. 验证 ListAlbums 不再包含已变为空并被删除的 "临时相册"
	albums, err := im.ListAlbums()
	if err != nil {
		t.Fatalf("ListAlbums error: %v", err)
	}
	for _, a := range albums {
		if a.Name == srcAlbum {
			t.Errorf("empty album %s should not appear in ListAlbums", srcAlbum)
		}
	}

	// 5. 验证部分移动（目录中仍有其他文件时）：不误删非空目录
	partAlbum := "活跃相册"
	p1 := filepath.Join(partAlbum, date.Format("2006/01/02"), "keep.jpg")
	p2 := filepath.Join(partAlbum, date.Format("2006/01/02"), "move.jpg")
	_ = md.Upload(p1, io.NopCloser(bytes.NewReader(content)), int64(len(content)), date)
	_ = md.Upload(p2, io.NopCloser(bytes.NewReader(content)), int64(len(content)), date)

	_, err = im.MoveAssets([]string{p2}, targetAlbum)
	if err != nil {
		t.Fatalf("MoveAssets partial failed: %v", err)
	}
	// 因为 keep.jpg 还在，日期目录和活跃相册均不应被删除
	partDateDir := filepath.Dir(p1)
	if exist, _ := md.IsExist(partDateDir); !exist {
		t.Errorf("non-empty dir %s should NOT be deleted", partDateDir)
	}
	if exist, _ := md.IsExist(partAlbum); !exist {
		t.Errorf("non-empty album %s should NOT be deleted", partAlbum)
	}

	// 6. 验证默认相册清空时保护机制：日期目录可删，但默认相册根目录永远保留
	defAlbum := im.GetDefaultAlbum()
	defPath := filepath.Join(defAlbum, date.Format("2006/01/02"), "def.jpg")
	_ = md.Upload(defPath, io.NopCloser(bytes.NewReader(content)), int64(len(content)), date)
	_, err = im.MoveAssets([]string{defPath}, targetAlbum)
	if err != nil {
		t.Fatalf("MoveAssets from default album failed: %v", err)
	}
	defDateDir := filepath.Dir(defPath)
	if exist, _ := md.IsExist(defDateDir); exist {
		t.Errorf("empty date dir in default album %s should be deleted", defDateDir)
	}
	if exist, _ := md.IsExist(defAlbum); !exist {
		t.Errorf("default album %s must NOT be deleted even when empty", defAlbum)
	}
}

// TestDualDriveRoutingAndRebuild 验证主存储与独立「元数据及缩略图存储后端」分离路由、回退链路、相册骨架与元数据重建
func TestDualDriveRoutingAndRebuild(t *testing.T) {
	mainDrive := newMockDrive()
	metaDrive := newMockDrive()

	im := NewImgManager(Option{WorkerNum: 1})
	defer im.Close()
	im.SetDrive(mainDrive)
	im.SetMetaDrive(metaDrive)
	// 等待异步 Sync 初始化完成
	time.Sleep(20 * time.Millisecond)

	date := time.Date(2026, 8, 10, 15, 0, 0, 0, time.Local)
	origData := []byte("original-high-res-image")
	thumbData := []byte("fast-thumbnail-image")

	// 1. 创建相册：主存储创建相册目录，副存储创建 .thumbnail/<album> 骨架
	album := "高速相册测试"
	if err := im.CreateAlbum(album); err != nil {
		t.Fatalf("CreateAlbum failed: %v", err)
	}
	if exist, _ := mainDrive.IsExist(album); !exist {
		t.Fatalf("expected album dir on mainDrive")
	}
	if exist, _ := metaDrive.IsExist(filepath.Join(defaultThumbnailDir, album)); !exist {
		t.Fatalf("expected .thumbnail/%s skeleton on metaDrive", album)
	}

	// 2. 上传缩略图与原图：缩略图与 .manifest 仅落入 metaDrive，原图仅落入 mainDrive
	if err := im.UploadThumbnail(bytes.NewReader(thumbData), int64(len(thumbData)), "picA.jpg", date, WithAlbum(album)); err != nil {
		t.Fatalf("UploadThumbnail failed: %v", err)
	}
	if err := im.Upload(bytes.NewReader(origData), int64(len(origData)), "picA.jpg", date, WithAlbum(album)); err != nil {
		t.Fatalf("Upload failed: %v", err)
	}

	expectedRelPath := filepath.Join(album, date.Format("2006/01/02"), "picA.jpg")
	expectedThumbPath := filepath.Join(defaultThumbnailDir, expectedRelPath)

	if _, ok := mainDrive.files[expectedRelPath]; !ok {
		t.Fatalf("expected original image on mainDrive at %s", expectedRelPath)
	}
	if _, ok := mainDrive.files[expectedThumbPath]; ok {
		t.Fatalf("thumbnail should NOT be written to mainDrive when metaDrive is enabled")
	}
	if _, ok := metaDrive.files[expectedThumbPath]; !ok {
		t.Fatalf("expected thumbnail on metaDrive at %s", expectedThumbPath)
	}

	// 验证 .manifest 切片写在 metaDrive 而非 mainDrive
	hasManifestOnMeta := false
	for k := range metaDrive.files {
		if strings.HasPrefix(k, ManifestDir+"/") {
			hasManifestOnMeta = true
			break
		}
	}
	if !hasManifestOnMeta {
		t.Fatalf("expected .manifest files on metaDrive")
	}
	for k := range mainDrive.files {
		if strings.HasPrefix(k, ManifestDir+"/") {
			t.Fatalf("unexpected .manifest file %s on mainDrive", k)
		}
	}

	// 3. 读取缩略图：命中 metaDrive
	thumbImg, err := im.GetThumbnail(expectedRelPath)
	if err != nil {
		t.Fatalf("GetThumbnail failed: %v", err)
	}
	gotThumb, _ := io.ReadAll(thumbImg.Content)
	thumbImg.Content.Close()
	if !bytes.Equal(gotThumb, thumbData) {
		t.Fatalf("expected thumbnail from metaDrive, got %q", string(gotThumb))
	}

	// 4. 缩略图缺失回退链路：删除 metaDrive 上的缩略图，验证直接回退到 mainDrive 原图
	_ = metaDrive.Delete(expectedThumbPath)
	fallbackImg, err := im.GetThumbnail(expectedRelPath)
	if err != nil {
		t.Fatalf("GetThumbnail fallback failed: %v", err)
	}
	gotFallback, _ := io.ReadAll(fallbackImg.Content)
	fallbackImg.Content.Close()
	if !bytes.Equal(gotFallback, origData) {
		t.Fatalf("expected fallback to mainDrive original image, got %q", string(gotFallback))
	}

	// 5. 验证 RebuildManifest：模拟切换到一个全新的空副存储 metaDrive2，执行 RebuildManifest 重建元数据与相册骨架
	metaDrive2 := newMockDrive()
	im.SetMetaDrive(metaDrive2)
	wm, count, err := im.RebuildManifest()
	if err != nil {
		t.Fatalf("RebuildManifest failed: %v", err)
	}
	if wm <= 0 || count != 1 {
		t.Fatalf("expected watermark > 0 and count == 1 after RebuildManifest, got wm=%d count=%d", wm, count)
	}
	if exist, _ := metaDrive2.IsExist(filepath.Join(defaultThumbnailDir, album)); !exist {
		t.Fatalf("expected RebuildManifest to recreate .thumbnail/%s on new metaDrive", album)
	}

	// 6. 停用副存储 (SetMetaDrive(nil))：自动切回主存储
	im.SetMetaDrive(nil)
	if im.HasDedicatedMetaDrive() {
		t.Fatalf("expected HasDedicatedMetaDrive() == false after SetMetaDrive(nil)")
	}
}

func TestThumbnailFallbackAutoGenerationAndBackfill(t *testing.T) {
	mainDrive := newMockDrive()
	metaDrive := newMockDrive()

	im := &ImgManager{
		dri:           mainDrive,
		metaDri:       metaDrive,
		localCacheDir: t.TempDir(),
		logger:        log.New(io.Discard, "", 0),
	}

	// 1. 创建一张真实的 800x600 红色测试 JPEG 图片
	src := image.NewRGBA(image.Rect(0, 0, 800, 600))
	for y := 0; y < 600; y++ {
		for x := 0; x < 800; x++ {
			src.Set(x, y, color.RGBA{R: 255, G: 0, B: 0, A: 255})
		}
	}
	var buf bytes.Buffer
	if err := jpeg.Encode(&buf, src, nil); err != nil {
		t.Fatalf("encode jpeg failed: %v", err)
	}
	rawJpeg := buf.Bytes()

	// 2. 将原图存入主存储，副存储中无任何对应缩略图
	origPath := "相机备份/2026/10/test.jpg"
	if err := mainDrive.Upload(origPath, io.NopCloser(bytes.NewReader(rawJpeg)), int64(len(rawJpeg)), time.Now()); err != nil {
		t.Fatalf("upload to mainDrive failed: %v", err)
	}

	thumbPath := filepath.Join(defaultThumbnailDir, origPath)
	if exist, _ := metaDrive.IsExist(thumbPath); exist {
		t.Fatalf("thumbnail should not exist before test")
	}

	// 3. 请求缩略图：触发兜底回退读取主存储原图 -> 服务端就地生成 400px 缩略图并返回
	thumbImg, err := im.GetThumbnail(origPath)
	if err != nil {
		t.Fatalf("GetThumbnail failed: %v", err)
	}
	if thumbImg.IsFallback {
		t.Fatalf("expected IsFallback == false when thumbnail was successfully generated")
	}
	gotThumb, err := io.ReadAll(thumbImg.Content)
	thumbImg.Content.Close()
	if err != nil {
		t.Fatalf("read thumb failed: %v", err)
	}

	// 验证返回的缩略图尺寸确已被等比压缩到 400x300
	decoded, format, err := image.Decode(bytes.NewReader(gotThumb))
	if err != nil {
		t.Fatalf("decode returned thumbnail failed: %v", err)
	}
	if format != "jpeg" {
		t.Fatalf("expected format jpeg, got %s", format)
	}
	bounds := decoded.Bounds()
	if bounds.Dx() != 400 || bounds.Dy() != 300 {
		t.Fatalf("expected thumbnail bounds 400x300, got %dx%d", bounds.Dx(), bounds.Dy())
	}

	// 4. 等待异步后台回填完成，验证副存储中已自动生成了该缩略图
	var backfilled bool
	for i := 0; i < 20; i++ {
		if exist, _ := metaDrive.IsExist(thumbPath); exist {
			backfilled = true
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	if !backfilled {
		t.Fatalf("expected fallback thumbnail to be automatically backfilled to metaDrive at %s", thumbPath)
	}

	// 5. 验证直接上传缩略图 UploadThumbnailDirect
	directData := []byte("manual-thumbnail-bytes")
	if err := im.UploadThumbnailDirect(directData, "custom/path.jpg"); err != nil {
		t.Fatalf("UploadThumbnailDirect failed: %v", err)
	}
	if exist, _ := metaDrive.IsExist(filepath.Join(defaultThumbnailDir, "custom/path.jpg")); !exist {
		t.Fatalf("expected custom/path.jpg in metaDrive thumbnail directory")
	}
}
