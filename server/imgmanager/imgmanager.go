package imgmanager

import (
	"encoding/binary"
	"fmt"
	"io"
	"io/fs"
	"log"
	"mime"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	pb "github.com/fregie/img_syncer/proto"
	"github.com/fregie/img_syncer/server/util"
)

const (
	defaultWorkerNum          = 2
	defaultThumbnailMaxWidth  = 500
	defaultThumbnailMaxHeight = 500
	defaultThumbnailDir       = ".thumbnail"
	DefaultAlbumName          = "相机备份"
)

type ImgManager struct {
	dri            StorageDrive
	driveMu        sync.RWMutex
	dirType        pb.DirectoryType
	dirTypeMu      sync.RWMutex
	defaultAlbum   string
	defaultAlbumMu sync.RWMutex
	manifest       *ManifestManager
	actCh          chan action
	stopCh         chan struct{}
	wg             sync.WaitGroup
	logger         *log.Logger
	opt            Option
}

type Option struct {
	WorkerNum          int
	ThumbnailMaxWidth  int
	ThumbnailMaxHeight int
	ThumbbailQuality   int
}

func NewImgManager(opt Option) *ImgManager {
	if opt.WorkerNum <= 0 {
		opt.WorkerNum = defaultWorkerNum
	}
	if opt.ThumbnailMaxWidth <= 0 {
		opt.ThumbnailMaxWidth = defaultThumbnailMaxWidth
	}
	if opt.ThumbnailMaxHeight <= 0 {
		opt.ThumbnailMaxHeight = defaultThumbnailMaxHeight
	}
	im := &ImgManager{
		actCh:        make(chan action, 10),
		stopCh:       make(chan struct{}),
		logger:       log.New(os.Stdout, "[ImgManager] ", log.LstdFlags),
		opt:          opt,
		dri:          &UnimplementedDrive{},
		defaultAlbum: DefaultAlbumName,
		manifest:     NewManifestManager(""),
	}
	im.wg.Add(im.opt.WorkerNum)
	for i := 0; i < im.opt.WorkerNum; i++ {
		go im.runWorker()
	}
	return im
}

func (im *ImgManager) SetDirectoryType(dirType pb.DirectoryType) {
	im.dirTypeMu.Lock()
	defer im.dirTypeMu.Unlock()
	im.dirType = dirType
}

func (im *ImgManager) GetDefaultAlbum() string {
	im.defaultAlbumMu.RLock()
	defer im.defaultAlbumMu.RUnlock()
	if im.defaultAlbum == "" {
		return DefaultAlbumName
	}
	return im.defaultAlbum
}

func (im *ImgManager) SetDefaultAlbum(name string) {
	im.defaultAlbumMu.Lock()
	defer im.defaultAlbumMu.Unlock()
	im.defaultAlbum = name
}

func (im *ImgManager) SetDrive(dri StorageDrive) {
	im.driveMu.Lock()
	if im.dri != nil {
		im.dri.Close()
	}
	im.dri = dri
	im.driveMu.Unlock()
	go im.MigrateLegacyRootFolders()
	go func() {
		_ = im.manifest.Sync(dri)
	}()
}

func (im *ImgManager) Manifest() *ManifestManager {
	return im.manifest
}

func (im *ImgManager) Drive() StorageDrive {
	im.driveMu.RLock()
	defer im.driveMu.RUnlock()
	return im.dri
}

// Close 优雅关闭：关闭 stopCh 通知所有 worker 退出，等待 worker 完成后返回
func (im *ImgManager) Close() error {
	close(im.stopCh)
	im.wg.Wait()
	return nil
}

func (im *ImgManager) drive() (StorageDrive, func()) {
	im.driveMu.RLock()
	return im.dri, func() { im.driveMu.RUnlock() }
}

type actType int

const (
	actDelete actType = iota
)

type action struct {
	t    actType
	path string
}

func (im *ImgManager) runWorker() {
	for {
		select {
		case <-im.stopCh:
			im.wg.Done()
			return
		case act := <-im.actCh:
			switch act.t {
			case actDelete:
				func() {
					d, unlock := im.drive()
					defer unlock()
					err := d.Delete(act.path)
					if err != nil {
						im.logger.Println("Error deleting image:", err)
					}
				}()
			}
		}
	}
}


type Options struct {
	EncyptOption EncryptOption
	IsLivePhoto  bool
	Album        string
}

// EncryptType 和常量已迁移至 encrypt.go

type EncryptOption struct {
	Type     EncryptType
	Password string
}

type OptionFunc func(*Options)

func WithEncrypt(opt EncryptOption) OptionFunc {
	return func(o *Options) {
		o.EncyptOption = opt
	}
}

func IsLivePhoto(isLivePhoto bool) OptionFunc {
	return func(o *Options) {
		o.IsLivePhoto = isLivePhoto
	}
}

func WithAlbum(album string) OptionFunc {
	return func(o *Options) {
		o.Album = album
	}
}

func (im *ImgManager) genPath(name string, date time.Time, options Options) string {
	if date.IsZero() {
		date = time.Now()
	}
	if date.Before(time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC)) {
		date = time.Now()
	}
	im.dirTypeMu.RLock()
	dirType := im.dirType
	im.dirTypeMu.RUnlock()
	elems := []string{}
	album := options.Album
	if album == "" {
		album = im.GetDefaultAlbum()
	}
	if album != "" {
		elems = append(elems, album)
	}
	switch dirType {
	case pb.DirectoryType_DIRECTORY_TYPE_01:
		elems = append(elems, date.Format("2006/01/02"))
	case pb.DirectoryType_DIRECTORY_TYPE_02:
		elems = append(elems, date.Format("20060102"))
	default:
		elems = append(elems, date.Format("2006/01/02"))
	}
	if options.IsLivePhoto {
		elems = append(elems, fmt.Sprintf("live_%s", name[:len(name)-len(filepath.Ext(name))]))
	}
	elems = append(elems, name)
	path := filepath.Join(elems...)
	if options.EncyptOption.Password != "" {
		path = fixPath(path, options.EncyptOption.Type)
	}
	return path
}

func (im *ImgManager) Upload(content io.Reader, contentSize int64, name string, date time.Time, opts ...OptionFunc) error {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	path := im.genPath(name, date, options)
	if content == nil {
		return fmt.Errorf("content is nil")
	}
	reader, err := EncryptedReaderWraper(io.NopCloser(content), options.EncyptOption)
	if err != nil {
		im.logger.Println("Error encrypting:", err)
		return fmt.Errorf("error encrypting: %w", err)
	}
	if options.EncyptOption.Type != None && options.EncyptOption.Password != "" {
		contentSize = EncryptedContentSize(contentSize, options.EncyptOption.Type)
	}
	d, unlock := im.drive()
	defer unlock()
	e := d.Upload(path, io.NopCloser(reader), contentSize, date)
	if e != nil {
		im.logger.Println("Error uploading:", e)
		return fmt.Errorf("error uploading: %w", e)
	}
	targetAlbum := options.Album
	if targetAlbum == "" {
		targetAlbum = im.GetDefaultAlbum()
	}
	_ = im.manifest.AppendChunk(d, []ManifestRecord{
		{
			Fingerprint: filepath.Base(path),
			Album:       targetAlbum,
			Path:        path,
			Size:        contentSize,
			Deleted:     false,
			UpdatedAt:   time.Now().Unix(),
		},
	})
	return nil
}

func (im *ImgManager) UploadThumbnail(thumbnailContent io.Reader, thumbnailSize int64, name string, date time.Time, opts ...OptionFunc) error {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	if thumbnailContent == nil {
		return fmt.Errorf("thumbnail content is nil")
	}
	path := im.genPath(name, date, options)
	reader, err := EncryptedReaderWraper(io.NopCloser(thumbnailContent), options.EncyptOption)
	if err != nil {
		im.logger.Println("Error encrypting video:", err)
		return fmt.Errorf("error encrypting video: %w", err)
	}
	if options.EncyptOption.Type != None && options.EncyptOption.Password != "" {
		thumbnailSize = EncryptedContentSize(thumbnailSize, options.EncyptOption.Type)
	}
	d, unlock := im.drive()
	defer unlock()
	e := d.Upload(filepath.Join(defaultThumbnailDir, path),
		io.NopCloser(reader), thumbnailSize, date)
	if e != nil {
		im.logger.Printf("Error uploading %s: %s", path, e)
		return fmt.Errorf("error uploading %s thumbnail: %w", path, e)
	}
	return nil
}

func (im *ImgManager) UploadLiveVideo(content io.Reader, size int64, name string, date time.Time, opts ...OptionFunc) error {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	if content == nil {
		return fmt.Errorf("thumbnail content is nil")
	}
	path := im.genPath(name, date, options)
	reader, err := EncryptedReaderWraper(io.NopCloser(content), options.EncyptOption)
	if err != nil {
		im.logger.Println("Error encrypting video:", err)
		return fmt.Errorf("error encrypting video: %w", err)
	}
	if options.EncyptOption.Type != None && options.EncyptOption.Password != "" {
		size = EncryptedContentSize(size, options.EncyptOption.Type)
	}
	d, unlock := im.drive()
	defer unlock()
	e := d.Upload(path, io.NopCloser(reader), size, date)
	if e != nil {
		im.logger.Printf("Error uploading %s: %s", path, e)
		return fmt.Errorf("error uploading %s thumbnail: %w", path, e)
	}
	return nil
}

func (im *ImgManager) GetImg(path string, opts ...OptionFunc) (*Image, error) {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	img := &Image{}
	var err error
	var rc io.ReadCloser
	d, unlock := im.drive()
	defer unlock()
	rc, img.Size, err = d.Download(path)
	if err != nil {
		return img, err
	}
	encType := getPathEncType(path)
	if encType != None {
		detectedType, restoredRc, err := DetectEncryptFormat(rc)
		if err != nil {
			return img, err
		}
		options.EncyptOption.Type = detectedType
		img.Content, err = DecryptedReaderWraper(restoredRc, options.EncyptOption)
		if err != nil {
			return img, err
		}
		img.Size = DecryptedContentSize(img.Size, detectedType)
	} else {
		img.Content = rc
	}
	img.Path = path
	if filepath.Ext(path) == ".aes" {
		img.ContentType = mime.TypeByExtension(filepath.Ext(strings.TrimSuffix(path, ".aes")))
	} else {
		img.ContentType = mime.TypeByExtension(filepath.Ext(path))
	}
	return img, nil
}

func (im *ImgManager) GetOffset(path string, offset int64, opts ...OptionFunc) (*Image, error) {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	if getPathEncType(path) != None {
		// 加密文件：先读 header 判断 GCM/CFB
		d, unlock := im.drive()
		rc, storedSize, err := d.Download(path)
		if err != nil {
			unlock()
			return nil, err
		}
		magic := make([]byte, gcmMagicLen)
		if _, err := io.ReadFull(rc, magic); err != nil {
			rc.Close()
			unlock()
			return nil, fmt.Errorf("failed to read magic bytes: %w", err)
		}
		if string(magic) == gcmMagic {
			// GCM 路径 — 支持任意 offset
			// 继续读剩余 header: salt(16B) + chunkSize(4B)
			headerRemain := make([]byte, gcmSaltLen+4)
			if _, err := io.ReadFull(rc, headerRemain); err != nil {
				rc.Close()
				unlock()
				return nil, fmt.Errorf("failed to read GCM header: %w", err)
			}
			rc.Close() // 释放第一次 Download
			unlock()   // 释放 drive 锁

			salt := make([]byte, gcmSaltLen)
			copy(salt, headerRemain[:gcmSaltLen])
			chunkSize := binary.BigEndian.Uint32(headerRemain[gcmSaltLen:])

			chunkIndex := offset / int64(chunkSize)
			withinChunk := offset % int64(chunkSize)
			ciphertextStart := int64(gcmHeaderLen) + chunkIndex*(int64(chunkSize)+int64(gcmNonceSize)+int64(gcmTagSize))

			d2, unlock2 := im.drive()
			diskRc, diskSize, err := d2.DownloadWithOffset(path, ciphertextStart)
			if err != nil {
				unlock2()
				return nil, err
			}
			if diskSize != storedSize {
				diskRc.Close()
				unlock2()
				return nil, fmt.Errorf("stored size mismatch: first=%d second=%d", storedSize, diskSize)
			}

			seekRc, err := NewGcmSeekReader(diskRc, options.EncyptOption.Password, GcmSeekOpts{
				ChunkSize:         chunkSize,
				Salt:              salt,
				TotalStoredSize:   storedSize,
				StartChunkIndex:   chunkIndex,
				WithinChunkOffset: withinChunk,
			})
			if err != nil {
				unlock2()
				return nil, err
			}

			img := &Image{
				Content:     seekRc,
				Size:        DecryptedContentSize(storedSize, AES_256_GCM),
				Path:        path,
				ContentType: mime.TypeByExtension(strings.TrimSuffix(filepath.Ext(path), ".aes")),
			}
			// 注意：seekRc.Close() 负责关闭 diskRc，但 drive 锁需要在此释放
			unlock2()
			return img, nil
		}
		// CFB 旧路径：不支持 seek，仅 offset=0 走 GetImg 兜底
		rc.Close()
		unlock()
		if offset == 0 {
			return im.GetImg(path, opts...)
		}
		return nil, fmt.Errorf("encrypted file (CFB) not support get offset")
	}
	img := &Image{}
	var err error
	d, unlock := im.drive()
	defer unlock()
	img.Content, img.Size, err = d.DownloadWithOffset(path, offset)
	if err != nil {
		return img, err
	}
	img.Path = path
	if filepath.Ext(path) == ".aes" {
		img.ContentType = mime.TypeByExtension(filepath.Ext(strings.TrimSuffix(path, ".aes")))
	} else {
		img.ContentType = mime.TypeByExtension(filepath.Ext(path))
	}
	return img, nil
}

func (im *ImgManager) GetThumbnail(path string, opts ...OptionFunc) (*Image, error) {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	img := &Image{}
	var err error
	var rc io.ReadCloser
	thumbnailPath := filepath.Join(defaultThumbnailDir, path)
	d, unlock := im.drive()
	defer unlock()
	rc, img.Size, err = d.Download(thumbnailPath)
	if err != nil {
		// 回退读取原图，防止缩略图缺失导致前端直接报错与渲染白块
		rc, img.Size, err = d.Download(path)
		if err != nil {
			return img, fmt.Errorf("error downloading thumbnail: %w", err)
		}
		thumbnailPath = path
	}
	encType := getPathEncType(path)
	if encType != None {
		detectedType, restoredRc, err := DetectEncryptFormat(rc)
		if err != nil {
			return img, fmt.Errorf("error detecting encrypt format: %w", err)
		}
		options.EncyptOption.Type = detectedType
		img.Content, err = DecryptedReaderWraper(restoredRc, options.EncyptOption)
		if err != nil {
			return img, fmt.Errorf("error decrypting thumbnail: %w", err)
		}
		img.Size = DecryptedContentSize(img.Size, detectedType)
	} else {
		img.Content = rc
	}
	img.Path = thumbnailPath
	if filepath.Ext(path) == ".aes" {
		img.ContentType = mime.TypeByExtension(filepath.Ext(strings.TrimSuffix(path, ".aes")))
	} else {
		img.ContentType = mime.TypeByExtension(filepath.Ext(thumbnailPath))
	}
	return img, nil
}

func (im *ImgManager) GetLiveVideoOffset(path string, offset int64, opts ...OptionFunc) (*Image, error) {
	var options Options
	for _, opt := range opts {
		opt(&options)
	}
	var videoPath string
	dir := filepath.Dir(path)
	func() {
		d, unlock := im.drive()
		defer unlock()
		d.Range(dir, func(info fs.FileInfo) bool {
			name := info.Name()
			nameWithoutExt := filepath.Base(name)[:len(filepath.Base(name))-len(filepath.Ext(name))]
			pathNameWithoutExt := filepath.Base(path)[:len(filepath.Base(path))-len(filepath.Ext(path))]
			if util.IsVideo(name) && nameWithoutExt == pathNameWithoutExt {
				videoPath = filepath.Join(dir, name)
				return false
			}
			return true
		})
	}()
	if videoPath == "" {
		return nil, fmt.Errorf("video not found")
	}
	if getPathEncType(videoPath) != None {
		// 加密视频：先读 header 判断 GCM/CFB
		d, unlock := im.drive()
		rc, storedSize, err := d.Download(videoPath)
		if err != nil {
			unlock()
			return nil, err
		}
		magic := make([]byte, gcmMagicLen)
		if _, err := io.ReadFull(rc, magic); err != nil {
			rc.Close()
			unlock()
			return nil, fmt.Errorf("failed to read magic bytes: %w", err)
		}
		if string(magic) == gcmMagic {
			// GCM 路径 — 支持任意 offset
			headerRemain := make([]byte, gcmSaltLen+4)
			if _, err := io.ReadFull(rc, headerRemain); err != nil {
				rc.Close()
				unlock()
				return nil, fmt.Errorf("failed to read GCM header: %w", err)
			}
			rc.Close()
			unlock()

			salt := make([]byte, gcmSaltLen)
			copy(salt, headerRemain[:gcmSaltLen])
			chunkSize := binary.BigEndian.Uint32(headerRemain[gcmSaltLen:])

			chunkIndex := offset / int64(chunkSize)
			withinChunk := offset % int64(chunkSize)
			ciphertextStart := int64(gcmHeaderLen) + chunkIndex*(int64(chunkSize)+int64(gcmNonceSize)+int64(gcmTagSize))

			d2, unlock2 := im.drive()
			diskRc, diskSize, err := d2.DownloadWithOffset(videoPath, ciphertextStart)
			if err != nil {
				unlock2()
				return nil, err
			}
			if diskSize != storedSize {
				diskRc.Close()
				unlock2()
				return nil, fmt.Errorf("stored size mismatch: first=%d second=%d", storedSize, diskSize)
			}

			seekRc, err := NewGcmSeekReader(diskRc, options.EncyptOption.Password, GcmSeekOpts{
				ChunkSize:         chunkSize,
				Salt:              salt,
				TotalStoredSize:   storedSize,
				StartChunkIndex:   chunkIndex,
				WithinChunkOffset: withinChunk,
			})
			if err != nil {
				unlock2()
				return nil, err
			}

			img := &Image{
				Content:     seekRc,
				Size:        DecryptedContentSize(storedSize, AES_256_GCM),
				Path:        videoPath,
				ContentType: util.ContentTypeByExtension(filepath.Ext(strings.TrimSuffix(videoPath, ".aes"))),
			}
			unlock2()
			return img, nil
		}
		// CFB 旧路径：不支持 seek，仅 offset=0 走 GetImg 兜底
		rc.Close()
		unlock()
		if offset == 0 {
			return im.GetImg(videoPath, opts...)
		}
		return nil, fmt.Errorf("encrypted file (CFB) not support get offset")
	}
	// log.Printf("load video: %s", videoPath)
	img := &Image{}
	var err error
	d, unlock := im.drive()
	defer unlock()
	img.Content, img.Size, err = d.DownloadWithOffset(videoPath, offset)
	if err != nil {
		return img, err
	}
	img.Path = videoPath
	if filepath.Ext(videoPath) == ".aes" {
		img.ContentType = util.ContentTypeByExtension(filepath.Ext(strings.TrimSuffix(videoPath, ".aes")))
	} else {
		img.ContentType = util.ContentTypeByExtension(filepath.Ext(videoPath))
	}
	// log.Printf("Live video path: %s", videoPath)
	// log.Printf("Content-Type: %s", img.ContentType)
	return img, nil
}

func (im *ImgManager) DeleteSingleImg(path string) error {
	if path != "" {
		d, unlock := im.drive()
		defer unlock()
		err := d.Delete(filepath.Join(defaultThumbnailDir, path))
		if err != nil {
			im.logger.Println("Error deleting thumbnail:", err)
		}
		parentDir := filepath.Base(filepath.Dir(filepath.ToSlash(path)))
		if strings.HasPrefix(parentDir, "live_") {
			d.Range(filepath.Dir(path), func(info fs.FileInfo) bool {
				err := d.Delete(filepath.Join(filepath.Dir(path), info.Name()))
				if err != nil {
					im.logger.Println("Error deleting live video:", err)
				}
				return true
			})
			err := d.Delete(filepath.Dir(path))
			if err != nil {
				im.logger.Println("Error deleting live video dir:", err)
			}
		}
		delErr := d.Delete(path)
		if delErr == nil && im.manifest != nil {
			_ = im.manifest.AppendChunk(d, []ManifestRecord{
				{
					Fingerprint: filepath.Base(path),
					Path:        path,
					Deleted:     true,
					UpdatedAt:   time.Now().Unix(),
				},
			})
		}
		return delErr
	}
	return nil
}

func (im *ImgManager) DeleteSingleImgAsync(path string) {
	if path != "" {
		im.actCh <- action{t: actDelete, path: path}
	}
}

func (im *ImgManager) DeleteImg(paths []string) {
	for _, path := range paths {
		if path != "" {
			im.DeleteSingleImg(path)
		}
	}
}

type dirInfo struct {
	date time.Time
	dir  string
}

type ImgInfo struct {
	Path        string
	Size        int64
	IsLivePhoto bool
}

type AlbumInfo struct {
	Name      string
	Count     int64
	CoverPath string
	IsDefault bool
}

func isIgnoredDir(name string) bool {
	if strings.HasPrefix(name, ".") || name == "live" || name == "lost+found" {
		return true
	}
	return false
}

func isYearOrDateDir(name string) bool {
	if len(name) == 4 {
		if _, err := strconv.Atoi(name); err == nil {
			return true
		}
	}
	if len(name) == 8 {
		if _, err := strconv.Atoi(name); err == nil {
			return true
		}
	}
	return false
}

func (im *ImgManager) collectDirInfosRange(d StorageDrive, baseDir string, minDate, maxDate time.Time) []dirInfo {
	maxYear := 9999
	maxMonth := 12
	maxDay := 31
	minYear := 0
	minMonth := 0
	minDay := 0
	loc := time.Local

	if !maxDate.IsZero() {
		y, m, d := maxDate.Date()
		maxYear = y
		maxMonth = int(m)
		maxDay = d
		loc = maxDate.Location()
	}
	if !minDate.IsZero() {
		y, m, d := minDate.Date()
		minYear = y
		minMonth = int(m)
		minDay = d
		if maxDate.IsZero() {
			loc = minDate.Location()
		}
	}

	dirInfos := make([]dirInfo, 0)
	yDir, err := im.listDir(d, baseDir)
	if err != nil {
		return dirInfos
	}

	joinPath := func(parts ...string) string {
		if baseDir == "." {
			return filepath.Join(parts...)
		}
		all := append([]string{baseDir}, parts...)
		return filepath.Join(all...)
	}

	// type 02 (YYYYMMDD)
	for _, yinfo := range yDir {
		if len(yinfo.Name()) == 8 {
			dirDate, err := time.ParseInLocation("20060102", yinfo.Name(), loc)
			if err != nil {
				continue
			}
			if (!maxDate.IsZero() && dirDate.After(maxDate)) || (!minDate.IsZero() && dirDate.Before(minDate)) {
				continue
			}
			dirInfos = append(dirInfos, dirInfo{
				date: dirDate,
				dir:  joinPath(yinfo.Name()),
			})
		}
	}

	// type 01 (YYYY/MM/DD)
	for _, yinfo := range yDir {
		if yinfo.Name() == "live" || !yinfo.IsDir() || len(yinfo.Name()) != 4 {
			continue
		}
		yNum, err := strconv.Atoi(yinfo.Name())
		if err != nil {
			continue
		}
		// 年份剪枝：跳过不在 [minYear, maxYear] 区间内的所有历史/未来年份
		if (minYear > 0 && yNum < minYear) || (maxYear < 9999 && yNum > maxYear) {
			continue
		}
		mDir, err := im.listDir(d, joinPath(yinfo.Name()))
		if err != nil {
			continue
		}
		for _, minfo := range mDir {
			if minfo.Name() == "live" || !minfo.IsDir() {
				continue
			}
			mNum, err := strconv.Atoi(minfo.Name())
			if err != nil {
				continue
			}
			// 月份剪枝
			if minYear > 0 && yNum == minYear && mNum < minMonth {
				continue
			}
			if maxYear < 9999 && yNum == maxYear && mNum > maxMonth {
				continue
			}
			dDir, err := im.listDir(d, joinPath(yinfo.Name(), minfo.Name()))
			if err != nil {
				continue
			}
			for _, dinfo := range dDir {
				if !dinfo.IsDir() {
					continue
				}
				dNum, err := strconv.Atoi(dinfo.Name())
				if err != nil {
					continue
				}
				// 日期剪枝
				if minYear > 0 && yNum == minYear && mNum == minMonth && dNum < minDay {
					continue
				}
				if maxYear < 9999 && yNum == maxYear && mNum == maxMonth && dNum > maxDay {
					continue
				}
				dirPath := joinPath(yinfo.Name(), minfo.Name(), dinfo.Name())
				dirDate := time.Date(yNum, time.Month(mNum), dNum, 0, 0, 0, 0, loc)
				dirInfos = append(dirInfos, dirInfo{
					date: dirDate,
					dir:  dirPath,
				})
			}
		}
	}
	return dirInfos
}

func (im *ImgManager) collectDirInfos(d StorageDrive, baseDir string, date time.Time) []dirInfo {
	return im.collectDirInfosRange(d, baseDir, time.Time{}, date)
}

func (im *ImgManager) RangeByDate(date time.Time, f func(info ImgInfo) bool) error {
	return im.RangeByAlbumAndDate("", date, f)
}

func (im *ImgManager) RangeByDateRange(minDate, maxDate time.Time, f func(info ImgInfo) bool) error {
	return im.RangeByAlbumAndDateRange("", minDate, maxDate, f)
}

func (im *ImgManager) RangeByAlbumAndDate(album string, date time.Time, f func(info ImgInfo) bool) error {
	return im.RangeByAlbumAndDateRange(album, time.Time{}, date, f)
}

func (im *ImgManager) RangeByAlbumAndDateRange(album string, minDate, maxDate time.Time, f func(info ImgInfo) bool) error {
	d, unlock := im.drive()
	defer unlock()

	var allDirInfos []dirInfo
	if album != "" {
		allDirInfos = im.collectDirInfosRange(d, album, minDate, maxDate)
		// 如果查询的是默认相册，根目录下未迁移的历史日期目录也应一并包含
		if album == im.GetDefaultAlbum() {
			rootInfos := im.collectDirInfosRange(d, ".", minDate, maxDate)
			allDirInfos = append(allDirInfos, rootInfos...)
		}
	} else {
		// 1. 根目录下的历史日期文件夹（向下兼容）
		rootInfos := im.collectDirInfosRange(d, ".", minDate, maxDate)
		allDirInfos = append(allDirInfos, rootInfos...)

		// 2. 遍历所有相册目录
		entries, err := im.listDir(d, ".")
		if err == nil {
			for _, entry := range entries {
				if !entry.IsDir() || isIgnoredDir(entry.Name()) || isYearOrDateDir(entry.Name()) {
					continue
				}
				albumInfos := im.collectDirInfosRange(d, entry.Name(), minDate, maxDate)
				allDirInfos = append(allDirInfos, albumInfos...)
			}
		}
	}

	sort.Sort(dirDesc(allDirInfos))
	for _, dirInfo := range allDirInfos {
		goOn := true
		d.Range(dirInfo.dir, func(info fs.FileInfo) bool {
			if info.IsDir() {
				if strings.HasPrefix(info.Name(), "live_") {
					d.Range(filepath.Join(dirInfo.dir, info.Name()), func(info2 fs.FileInfo) bool {
						if !util.IsVideo(info2.Name()) {
							goOn = f(ImgInfo{
								Path:        filepath.Join(dirInfo.dir, info.Name(), info2.Name()),
								Size:        info2.Size(),
								IsLivePhoto: true,
							})
						}
						return true
					})
				}
				return goOn
			}
			goOn = f(ImgInfo{
				Path:        filepath.Join(dirInfo.dir, info.Name()),
				Size:        info.Size(),
				IsLivePhoto: false,
			})
			return goOn
		})
		if !goOn {
			break
		}
	}
	return nil
}

// ListAlbums 列出所有云端相册（默认相册排首位，附带数量与最新封面）
func (im *ImgManager) ListAlbums() ([]AlbumInfo, error) {
	d, unlock := im.drive()
	defer unlock()

	entries, err := im.listDir(d, ".")
	if err != nil {
		return nil, err
	}

	defaultName := im.GetDefaultAlbum()
	albumNames := make([]string, 0)

	for _, entry := range entries {
		if !entry.IsDir() || isIgnoredDir(entry.Name()) || isYearOrDateDir(entry.Name()) {
			continue
		}
		name := entry.Name()
		if name != defaultName {
			albumNames = append(albumNames, name)
		}
	}
	sort.Strings(albumNames)

	orderedNames := make([]string, 0, len(albumNames)+1)
	orderedNames = append(orderedNames, defaultName)
	orderedNames = append(orderedNames, albumNames...)

	result := make([]AlbumInfo, 0, len(orderedNames))
	for _, name := range orderedNames {
		var count int64
		var cover string
		dirInfos := im.collectDirInfos(d, name, time.Time{})
		sort.Sort(dirDesc(dirInfos))
		for _, di := range dirInfos {
			d.Range(di.dir, func(info fs.FileInfo) bool {
				if info.IsDir() {
					if strings.HasPrefix(info.Name(), "live_") {
						d.Range(filepath.Join(di.dir, info.Name()), func(info2 fs.FileInfo) bool {
							if !util.IsVideo(info2.Name()) {
								count++
								if cover == "" {
									cover = filepath.Join(di.dir, info.Name(), info2.Name())
								}
							}
							return true
						})
					}
					return true
				}
				count++
				if cover == "" {
					cover = filepath.Join(di.dir, info.Name())
				}
				return true
			})
		}

		// 若为默认相册且此时根目录下存在存量照片，也一并计入统计
		if name == defaultName {
			rootInfos := im.collectDirInfos(d, ".", time.Time{})
			sort.Sort(dirDesc(rootInfos))
			for _, di := range rootInfos {
				d.Range(di.dir, func(info fs.FileInfo) bool {
					if !info.IsDir() {
						count++
						if cover == "" {
							cover = filepath.Join(di.dir, info.Name())
						}
					}
					return true
				})
			}
		}

		result = append(result, AlbumInfo{
			Name:      name,
			Count:     count,
			CoverPath: cover,
			IsDefault: name == defaultName,
		})
	}

	return result, nil
}

// CreateAlbum 创建新相册目录
func (im *ImgManager) CreateAlbum(name string) error {
	cleaned, err := util.SanitizePath(name)
	if err != nil || strings.Contains(cleaned, "/") {
		return fmt.Errorf("invalid album name: %s", name)
	}
	if isIgnoredDir(cleaned) || isYearOrDateDir(cleaned) {
		return fmt.Errorf("album name %s is reserved", name)
	}
	d, unlock := im.drive()
	defer unlock()
	exists, _ := d.IsExist(cleaned)
	if exists {
		return fmt.Errorf("album %s already exists", name)
	}
	if err := d.Mkdir(cleaned); err != nil {
		return err
	}
	_ = d.Mkdir(filepath.Join(defaultThumbnailDir, cleaned))
	return nil
}

// DeleteAlbum 粉碎删除相册及其下所有文件（默认相册禁止删除）
func (im *ImgManager) DeleteAlbum(name string) error {
	cleaned, err := util.SanitizePath(name)
	if err != nil || strings.Contains(cleaned, "/") {
		return fmt.Errorf("invalid album name: %s", name)
	}
	if cleaned == im.GetDefaultAlbum() {
		return fmt.Errorf("cannot delete default album: %s", name)
	}
	d, unlock := im.drive()
	defer unlock()

	im.deleteDirRecursive(d, cleaned)
	im.deleteDirRecursive(d, filepath.Join(defaultThumbnailDir, cleaned))
	return nil
}

func (im *ImgManager) deleteDirRecursive(d StorageDrive, dir string) {
	_ = d.Range(dir, func(info fs.FileInfo) bool {
		sub := filepath.Join(dir, info.Name())
		if info.IsDir() {
			im.deleteDirRecursive(d, sub)
		} else {
			_ = d.Delete(sub)
		}
		return true
	})
	_ = d.Delete(dir)
}

// RenameAlbum 重命名相册
func (im *ImgManager) RenameAlbum(oldName, newName string) error {
	cleanOld, err := util.SanitizePath(oldName)
	if err != nil || strings.Contains(cleanOld, "/") {
		return fmt.Errorf("invalid old album name: %s", oldName)
	}
	cleanNew, err := util.SanitizePath(newName)
	if err != nil || strings.Contains(cleanNew, "/") {
		return fmt.Errorf("invalid new album name: %s", newName)
	}
	if isIgnoredDir(cleanNew) || isYearOrDateDir(cleanNew) {
		return fmt.Errorf("album name %s is reserved", newName)
	}
	d, unlock := im.drive()
	defer unlock()

	exists, _ := d.IsExist(cleanNew)
	if exists {
		return fmt.Errorf("target album %s already exists", newName)
	}

	if err := d.Move(cleanOld, cleanNew); err != nil {
		return fmt.Errorf("rename album failed: %w", err)
	}
	_ = d.Move(filepath.Join(defaultThumbnailDir, cleanOld), filepath.Join(defaultThumbnailDir, cleanNew))

	if cleanOld == im.GetDefaultAlbum() {
		im.SetDefaultAlbum(cleanNew)
	}
	return nil
}

// MoveAssets 将指定路径的照片移动至目标相册（联动迁移主图、缩略图与 LivePhoto）
func (im *ImgManager) MoveAssets(paths []string, targetAlbum string) ([]string, error) {
	cleanTarget, err := util.SanitizePath(targetAlbum)
	if err != nil || strings.Contains(cleanTarget, "/") {
		return nil, fmt.Errorf("invalid target album: %s", targetAlbum)
	}
	d, unlock := im.drive()
	defer unlock()

	newPaths := make([]string, 0, len(paths))
	for _, p := range paths {
		cleanedPath, err := util.SanitizePath(p)
		if err != nil {
			continue
		}
		parts := strings.Split(filepath.ToSlash(cleanedPath), "/")
		var subParts []string
		if len(parts) >= 2 {
			firstPart := parts[0]
			if !isYearOrDateDir(firstPart) {
				subParts = parts[1:]
			} else {
				subParts = parts
			}
		} else {
			subParts = parts
		}
		newSubPath := filepath.Join(subParts...)
		newMainPath := filepath.Join(cleanTarget, newSubPath)

		if err := d.Move(cleanedPath, newMainPath); err != nil {
			im.logger.Printf("MoveAssets: failed to move %s -> %s: %v", cleanedPath, newMainPath, err)
			continue
		}
		newPaths = append(newPaths, newMainPath)

		// 联动迁移缩略图
		oldThumb := filepath.Join(defaultThumbnailDir, cleanedPath)
		newThumb := filepath.Join(defaultThumbnailDir, newMainPath)
		_ = d.Move(oldThumb, newThumb)

		// 联动迁移 Live Photo
		dir := filepath.Dir(cleanedPath)
		if strings.HasPrefix(filepath.Base(dir), "live_") {
			newLiveDir := filepath.Dir(newMainPath)
			_ = d.Move(dir, newLiveDir)
			_ = d.Move(filepath.Join(defaultThumbnailDir, dir), filepath.Join(defaultThumbnailDir, newLiveDir))
		}
	}
	if len(newPaths) > 0 && im.manifest != nil {
		records := make([]ManifestRecord, 0, len(newPaths))
		for _, np := range newPaths {
			records = append(records, ManifestRecord{
				Fingerprint: filepath.Base(np),
				Album:       cleanTarget,
				Path:        np,
				Deleted:     false,
				UpdatedAt:   time.Now().Unix(),
			})
		}
		_ = im.manifest.AppendChunk(d, records)
	}
	return newPaths, nil
}

// MigrateLegacyRootFolders 自动迁移老版本存量年份文件夹至默认相册
func (im *ImgManager) MigrateLegacyRootFolders() {
	d, unlock := im.drive()
	defer unlock()

	entries, err := im.listDir(d, ".")
	if err != nil {
		return
	}
	defaultName := im.GetDefaultAlbum()
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}
		if isYearOrDateDir(entry.Name()) {
			oldPath := entry.Name()
			newPath := filepath.Join(defaultName, oldPath)
			_ = d.Move(oldPath, newPath)
			oldThumb := filepath.Join(defaultThumbnailDir, oldPath)
			newThumb := filepath.Join(defaultThumbnailDir, defaultName, oldPath)
			_ = d.Move(oldThumb, newThumb)
		}
	}
}

func (im *ImgManager) listDir(d StorageDrive, path string) ([]fs.FileInfo, error) {
	infos := make([]fs.FileInfo, 0)
	err := d.Range(path, func(info fs.FileInfo) bool {
		infos = append(infos, info)
		return true
	})
	return infos, err
}

// type asc []fs.FileInfo

// func (a asc) Len() int      { return len(a) }
// func (a asc) Swap(i, j int) { a[i], a[j] = a[j], a[i] }
// func (a asc) Less(i, j int) bool {
// 	yi, err := strconv.Atoi(a[i].Name())
// 	if err != nil {
// 		return false
// 	}
// 	yj, err := strconv.Atoi(a[j].Name())
// 	if err != nil {
// 		return true
// 	}
// 	return yi < yj
// }

type desc []fs.FileInfo

func (d desc) Len() int      { return len(d) }
func (d desc) Swap(i, j int) { d[i], d[j] = d[j], d[i] }
func (d desc) Less(i, j int) bool {
	yi, err := strconv.Atoi(d[i].Name())
	if err != nil {
		return false
	}
	yj, err := strconv.Atoi(d[j].Name())
	if err != nil {
		return true
	}
	return yi > yj
}

type dirDesc []dirInfo

func (d dirDesc) Len() int      { return len(d) }
func (d dirDesc) Swap(i, j int) { d[i], d[j] = d[j], d[i] }
func (d dirDesc) Less(i, j int) bool {
	return d[i].date.After(d[j].date)
}
