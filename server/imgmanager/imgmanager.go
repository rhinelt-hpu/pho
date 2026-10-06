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
	dri             StorageDrive
	metaDri         StorageDrive
	driveMu         sync.RWMutex
	dirType         pb.DirectoryType
	dirTypeMu       sync.RWMutex
	defaultAlbum    string
	defaultAlbumMu  sync.RWMutex
	manifest        *ManifestManager
	localCacheDir   string
	localCacheDirMu sync.RWMutex
	actCh           chan action
	stopCh          chan struct{}
	wg              sync.WaitGroup
	logger          *log.Logger
	opt             Option
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

// SetLocalCacheDir 设置本地元数据缓存目录（通常为 App 的 Support / Data 目录）
func (im *ImgManager) SetLocalCacheDir(dir string) {
	im.localCacheDirMu.Lock()
	im.localCacheDir = dir
	im.localCacheDirMu.Unlock()

	if im.manifest != nil && dir != "" {
		_ = os.MkdirAll(dir, 0755)
		cachePath := filepath.Join(dir, "manifest_cache.json")
		im.manifest.SetLocalPath(cachePath)
		_ = im.manifest.LoadLocal()
	}
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

func isDriveReady(d StorageDrive) bool {
	if d == nil {
		return false
	}
	if _, ok := d.(*UnimplementedDrive); ok {
		return false
	}
	if r, ok := d.(interface{ IsRootPathSet() bool }); ok && !r.IsRootPathSet() {
		return false
	}
	return true
}

func (im *ImgManager) syncOrBootstrapManifest(mainD, metaD StorageDrive) {
	if !isDriveReady(metaD) {
		return
	}
	err := im.manifest.Sync(metaD)
	log.Printf("[INFO] Manifest sync complete, watermark: %d, records: %d, err: %v", im.manifest.GetMaxWatermark(), im.manifest.RecordCount(), err)
	// 如果远端没有任何 manifest 记录，且当前 manifest 也为空，执行首次自举（Bootstrap）
	if err == nil && im.manifest.RecordCount() == 0 && im.manifest.GetMaxWatermark() == 0 && isDriveReady(mainD) {
		im.bootstrapManifest(mainD, metaD)
	}
}

func (im *ImgManager) SetDrive(dri StorageDrive) {
	im.driveMu.Lock()
	if im.dri != nil && im.dri != dri {
		im.dri.Close()
	}
	im.dri = dri
	metaD := im.metaDri
	im.driveMu.Unlock()
	if !isDriveReady(dri) {
		return
	}
	go im.MigrateLegacyRootFolders()
	targetMeta := dri
	if isDriveReady(metaD) {
		targetMeta = metaD
	}
	go im.syncOrBootstrapManifest(dri, targetMeta)
}

func (im *ImgManager) SetMetaDrive(dri StorageDrive) {
	im.driveMu.Lock()
	if im.metaDri != nil && im.metaDri != dri && im.metaDri != im.dri {
		im.metaDri.Close()
	}
	im.metaDri = dri
	mainD := im.dri
	im.driveMu.Unlock()

	if dri == nil {
		// 停用独立副存储，切回主存储重新同步 Manifest
		im.manifest.Reset()
		if isDriveReady(mainD) {
			go im.syncOrBootstrapManifest(mainD, mainD)
		}
		return
	}
	if !isDriveReady(dri) {
		return
	}
	im.manifest.Reset()
	go im.syncOrBootstrapManifest(mainD, dri)
}

func (im *ImgManager) Manifest() *ManifestManager {
	return im.manifest
}

func (im *ImgManager) Drive() StorageDrive {
	im.driveMu.RLock()
	defer im.driveMu.RUnlock()
	return im.dri
}

// MetaDrive 返回当前生效的元数据与缩略图驱动（未启用独立副存储时回退为主存储）
func (im *ImgManager) MetaDrive() StorageDrive {
	im.driveMu.RLock()
	defer im.driveMu.RUnlock()
	if im.metaDri != nil {
		return im.metaDri
	}
	return im.dri
}

// MetaDriveRaw 返回独立设置的副存储驱动实例（未设置时为 nil，供目录浏览 API 使用）
func (im *ImgManager) MetaDriveRaw() StorageDrive {
	im.driveMu.RLock()
	defer im.driveMu.RUnlock()
	return im.metaDri
}

// HasDedicatedMetaDrive 返回是否已启用独立的元数据与缩略图存储后端
func (im *ImgManager) HasDedicatedMetaDrive() bool {
	im.driveMu.RLock()
	defer im.driveMu.RUnlock()
	return isDriveReady(im.metaDri)
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

func (im *ImgManager) metaDrive() (StorageDrive, func()) {
	im.driveMu.RLock()
	if im.metaDri != nil {
		return im.metaDri, func() { im.driveMu.RUnlock() }
	}
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
	e := d.Upload(path, io.NopCloser(reader), contentSize, date)
	unlock()
	if e != nil {
		im.logger.Println("Error uploading:", e)
		return fmt.Errorf("error uploading: %w", e)
	}
	targetAlbum := options.Album
	if targetAlbum == "" {
		targetAlbum = im.GetDefaultAlbum()
	}
	md, unlockMeta := im.metaDrive()
	defer unlockMeta()
	if err := im.manifest.AppendChunk(md, []ManifestRecord{
		{
			Fingerprint: filepath.Base(path),
			Album:       targetAlbum,
			Path:        path,
			Size:        contentSize,
			Deleted:     false,
			UpdatedAt:   time.Now().Unix(),
		},
	}); err != nil {
		im.logger.Println("Error updating manifest:", err)
		return fmt.Errorf("error updating manifest: %w", err)
	}
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
	md, unlock := im.metaDrive()
	defer unlock()
	e := md.Upload(filepath.Join(defaultThumbnailDir, path),
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
	md, unlockMeta := im.metaDrive()
	rc, img.Size, err = md.Download(thumbnailPath)
	unlockMeta()
	if err != nil {
		// 只查「副存储 .thumbnail -> 主存储原图」：回退读取主存储原图，防止缩略图缺失导致前端渲染白块
		d, unlockMain := im.drive()
		rc, img.Size, err = d.Download(path)
		unlockMain()
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
		md, unlockMeta := im.metaDrive()
		err := md.Delete(filepath.Join(defaultThumbnailDir, path))
		unlockMeta()
		if err != nil {
			im.logger.Println("Error deleting thumbnail:", err)
		}

		d, unlock := im.drive()
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
		unlock()
		if delErr == nil && im.manifest != nil {
			md2, unlockMeta2 := im.metaDrive()
			_ = im.manifest.AppendChunk(md2, []ManifestRecord{
				{
					Fingerprint: filepath.Base(path),
					Path:        path,
					Deleted:     true,
					UpdatedAt:   time.Now().Unix(),
				},
			})
			unlockMeta2()
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

func isIgnoredFile(name string) bool {
	return strings.HasPrefix(name, ".") || strings.HasSuffix(name, ".tmp")
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
	// 1. 如果 Manifest 处于就绪状态，优先基于内存元数据瞬时响应，彻底避免远端多级 PROPFIND
	if im.manifest != nil && im.manifest.IsInitialized() {
		records := im.manifest.GetActiveRecords()
		if len(records) > 0 {
			count := 0
			err := im.rangeRecords(records, album, minDate, maxDate, func(info ImgInfo) bool {
				count++
				return f(info)
			})
			// 如果命中记录则直接返回；若未命中则降级检查物理磁盘（兼容外部或老版本直接写入的文件）
			if err == nil && count > 0 {
				log.Printf("[INFO] RangeByAlbumAndDateRange HIT MANIFEST: album=%s, returned=%d", album, count)
				return nil
			}
		}
	}

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

func parseRecordDate(fp, path string) time.Time {
	if len(fp) >= 14 {
		if t, err := time.Parse("20060102150405", fp[:14]); err == nil {
			return t
		}
	}
	parts := strings.Split(filepath.ToSlash(path), "/")
	for i := 0; i+2 < len(parts); i++ {
		if len(parts[i]) == 4 && len(parts[i+1]) == 2 && len(parts[i+2]) == 2 {
			y, ey := strconv.Atoi(parts[i])
			m, em := strconv.Atoi(parts[i+1])
			d, ed := strconv.Atoi(parts[i+2])
			if ey == nil && em == nil && ed == nil && m >= 1 && m <= 12 && d >= 1 && d <= 31 {
				return time.Date(y, time.Month(m), d, 0, 0, 0, 0, time.Local)
			}
		}
	}
	return time.Time{}
}

func (im *ImgManager) rangeRecords(records []ManifestRecord, album string, minDate, maxDate time.Time, f func(info ImgInfo) bool) error {
	defaultAlbum := im.GetDefaultAlbum()
	filtered := make([]ManifestRecord, 0, len(records))

	for _, rec := range records {
		if album != "" {
			if album == defaultAlbum {
				if rec.Album != album && rec.Album != "" {
					continue
				}
			} else {
				if rec.Album != album {
					continue
				}
			}
		}

		recDate := parseRecordDate(rec.Fingerprint, rec.Path)
		if !minDate.IsZero() && recDate.Before(minDate) {
			continue
		}
		if !maxDate.IsZero() && recDate.After(maxDate) {
			continue
		}

		filtered = append(filtered, rec)
	}

	sort.Slice(filtered, func(i, j int) bool {
		dateI := parseRecordDate(filtered[i].Fingerprint, filtered[i].Path)
		dateJ := parseRecordDate(filtered[j].Fingerprint, filtered[j].Path)
		if dateI.Equal(dateJ) {
			return filtered[i].Fingerprint > filtered[j].Fingerprint
		}
		return dateI.After(dateJ)
	})

	for _, rec := range filtered {
		isLive := strings.HasSuffix(rec.Path, ".live.jpg") || strings.Contains(rec.Path, "_live_")
		if !f(ImgInfo{
			Path:        rec.Path,
			Size:        rec.Size,
			IsLivePhoto: isLive,
		}) {
			break
		}
	}
	return nil
}

func (im *ImgManager) scanAllRecordsAndAlbums(mainD StorageDrive) ([]ManifestRecord, []string) {
	records := make([]ManifestRecord, 0)
	defaultName := im.GetDefaultAlbum()
	albumSet := map[string]bool{defaultName: true}

	collectFromDir := func(dir, albumName string) {
		mainD.Range(dir, func(info fs.FileInfo) bool {
			if info.IsDir() {
				if strings.HasPrefix(info.Name(), "live_") {
					liveDir := filepath.Join(dir, info.Name())
					mainD.Range(liveDir, func(info2 fs.FileInfo) bool {
						if !info2.IsDir() && !isIgnoredFile(info2.Name()) && !util.IsVideo(info2.Name()) {
							p := filepath.Join(liveDir, info2.Name())
							records = append(records, ManifestRecord{
								Fingerprint: info2.Name(),
								Album:       albumName,
								Path:        p,
								Size:        info2.Size(),
								Deleted:     false,
								UpdatedAt:   info2.ModTime().Unix(),
							})
						}
						return true
					})
				}
				return true
			}
			if !isIgnoredFile(info.Name()) {
				p := filepath.Join(dir, info.Name())
				records = append(records, ManifestRecord{
					Fingerprint: info.Name(),
					Album:       albumName,
					Path:        p,
					Size:        info.Size(),
					Deleted:     false,
					UpdatedAt:   info.ModTime().Unix(),
				})
			}
			return true
		})
	}

	// 1. 扫描根目录历史照片
	rootInfos := im.collectDirInfos(mainD, ".", time.Time{})
	for _, di := range rootInfos {
		collectFromDir(di.dir, defaultName)
	}

	// 2. 扫描所有相册目录照片
	entries, err := im.listDir(mainD, ".")
	if err == nil {
		for _, entry := range entries {
			if !entry.IsDir() || isIgnoredDir(entry.Name()) || isYearOrDateDir(entry.Name()) {
				continue
			}
			albumName := entry.Name()
			albumSet[albumName] = true
			albumDirInfos := im.collectDirInfos(mainD, albumName, time.Time{})
			for _, di := range albumDirInfos {
				collectFromDir(di.dir, albumName)
			}
		}
	}

	albums := make([]string, 0, len(albumSet))
	for a := range albumSet {
		if a != "" {
			albums = append(albums, a)
		}
	}
	sort.Strings(albums)
	return records, albums
}

func (im *ImgManager) bootstrapManifest(mainD, metaD StorageDrive) {
	records, albums := im.scanAllRecordsAndAlbums(mainD)
	for _, alb := range albums {
		_ = metaD.Mkdir(filepath.Join(defaultThumbnailDir, alb))
	}
	if len(records) > 0 {
		_ = im.manifest.AppendChunk(metaD, records)
		_ = im.manifest.Compact(metaD)
		_ = im.manifest.SaveLocal()
	}
}

// RebuildManifest 全量扫描主存储目录树，重建远端（副存储或主存储）的 .manifest 快照并同步相册骨架
func (im *ImgManager) RebuildManifest() (int64, int, error) {
	d, unlock := im.drive()
	if !isDriveReady(d) {
		unlock()
		return 0, 0, fmt.Errorf("primary drive not initialized")
	}
	records, albums := im.scanAllRecordsAndAlbums(d)
	unlock()

	md, unlockMeta := im.metaDrive()
	defer unlockMeta()
	for _, alb := range albums {
		_ = md.Mkdir(filepath.Join(defaultThumbnailDir, alb))
	}
	if err := im.manifest.RebuildWithRecords(md, records); err != nil {
		return 0, 0, err
	}
	return im.manifest.GetMaxWatermark(), im.manifest.RecordCount(), nil
}

// ListAlbums 列出所有云端相册（默认相册排首位，附带数量与最新封面）
func (im *ImgManager) ListAlbums() ([]AlbumInfo, error) {
	defaultName := im.GetDefaultAlbum()
	hasDedicatedMeta := im.HasDedicatedMetaDrive()

	albumSet := make(map[string]bool)
	var records []ManifestRecord
	manifestReady := im.manifest != nil && im.manifest.IsInitialized()
	if manifestReady {
		records = im.manifest.GetActiveRecords()
		for _, rec := range records {
			if rec.Album != "" && rec.Album != defaultName {
				albumSet[rec.Album] = true
			}
		}
	}

	if hasDedicatedMeta && manifestReady {
		// 启用独立高速副存储时：仅扫描副存储 .thumbnail/ 下的相册目录骨架 + 内存 Manifest，0 主存储网络开销
		md, unlockMeta := im.metaDrive()
		thumbEntries, _ := im.listDir(md, defaultThumbnailDir)
		unlockMeta()
		for _, entry := range thumbEntries {
			if !entry.IsDir() || isIgnoredDir(entry.Name()) || isYearOrDateDir(entry.Name()) {
				continue
			}
			if entry.Name() != defaultName {
				albumSet[entry.Name()] = true
			}
		}
	} else {
		d, unlock := im.drive()
		entries, err := im.listDir(d, ".")
		unlock()
		if err != nil {
			return nil, err
		}
		for _, entry := range entries {
			if !entry.IsDir() || isIgnoredDir(entry.Name()) || isYearOrDateDir(entry.Name()) {
				continue
			}
			if entry.Name() != defaultName {
				albumSet[entry.Name()] = true
			}
		}
	}

	albumNames := make([]string, 0, len(albumSet))
	for name := range albumSet {
		albumNames = append(albumNames, name)
	}
	sort.Strings(albumNames)

	orderedNames := make([]string, 0, len(albumNames)+1)
	orderedNames = append(orderedNames, defaultName)
	orderedNames = append(orderedNames, albumNames...)

	// 1. 如果 Manifest 处于可用状态（或已启用独立副存储），优先基于内存记录计算相册内照片总数与封面，0 额外主存储开销！
	if manifestReady && (len(records) > 0 || hasDedicatedMeta) {
		result := make([]AlbumInfo, 0, len(orderedNames))
		for _, name := range orderedNames {
			var count int64
			var cover string
			var latestTime time.Time

			for _, rec := range records {
				isMatch := false
				if name == defaultName {
					isMatch = (rec.Album == defaultName || rec.Album == "")
				} else {
					isMatch = (rec.Album == name)
				}
				if isMatch {
					count++
					t := parseRecordDate(rec.Fingerprint, rec.Path)
					if cover == "" || t.After(latestTime) {
						latestTime = t
						cover = rec.Path
					}
				}
			}

			// 如果未启用独立副存储且默认相册在 manifest 中为 0，保底检查主存储根目录存量旧照片
			if count == 0 && name == defaultName && !hasDedicatedMeta {
				d, unlock := im.drive()
				rootInfos := im.collectDirInfos(d, ".", time.Time{})
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
				unlock()
			}

			result = append(result, AlbumInfo{
				Name:      name,
				Count:     count,
				CoverPath: cover,
				IsDefault: name == defaultName,
			})
		}
		log.Printf("[INFO] ListAlbums HIT MANIFEST: albums=%d", len(result))
		return result, nil
	}

	d, unlock := im.drive()
	defer unlock()
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
	exists, _ := d.IsExist(cleaned)
	if exists {
		unlock()
		return fmt.Errorf("album %s already exists", name)
	}
	if err := d.Mkdir(cleaned); err != nil {
		unlock()
		return err
	}
	unlock()

	md, unlockMeta := im.metaDrive()
	_ = md.Mkdir(filepath.Join(defaultThumbnailDir, cleaned))
	unlockMeta()
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
	im.deleteDirRecursive(d, cleaned)
	unlock()

	md, unlockMeta := im.metaDrive()
	im.deleteDirRecursive(md, filepath.Join(defaultThumbnailDir, cleaned))
	if im.manifest != nil {
		active := im.manifest.GetActiveRecords()
		toDel := make([]ManifestRecord, 0)
		now := time.Now().Unix()
		for _, rec := range active {
			if rec.Album == cleaned {
				rec.Deleted = true
				rec.UpdatedAt = now
				toDel = append(toDel, rec)
			}
		}
		if len(toDel) > 0 {
			_ = im.manifest.AppendChunk(md, toDel)
		}
	}
	unlockMeta()
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
	exists, _ := d.IsExist(cleanNew)
	if exists {
		unlock()
		return fmt.Errorf("target album %s already exists", newName)
	}

	if err := d.Move(cleanOld, cleanNew); err != nil {
		unlock()
		return fmt.Errorf("rename album failed: %w", err)
	}
	unlock()

	md, unlockMeta := im.metaDrive()
	_ = md.Move(filepath.Join(defaultThumbnailDir, cleanOld), filepath.Join(defaultThumbnailDir, cleanNew))
	if im.manifest != nil {
		active := im.manifest.GetActiveRecords()
		updated := make([]ManifestRecord, 0)
		now := time.Now().Unix()
		prefix := cleanOld + "/"
		for _, rec := range active {
			if rec.Album == cleanOld || strings.HasPrefix(filepath.ToSlash(rec.Path), prefix) {
				rec.Album = cleanNew
				if strings.HasPrefix(filepath.ToSlash(rec.Path), prefix) {
					rec.Path = filepath.Join(cleanNew, strings.TrimPrefix(filepath.ToSlash(rec.Path), prefix))
				}
				rec.UpdatedAt = now
				updated = append(updated, rec)
			}
		}
		if len(updated) > 0 {
			_ = im.manifest.AppendChunk(md, updated)
		}
	}
	unlockMeta()

	if cleanOld == im.GetDefaultAlbum() {
		im.SetDefaultAlbum(cleanNew)
	}
	return nil
}

// isProtectedDir 判定指定路径是否属于受保护的关键目录（系统目录、根目录、默认相册），不可自动删除
func (im *ImgManager) isProtectedDir(dir string) bool {
	cleaned := filepath.Clean(filepath.ToSlash(dir))
	if cleaned == "." || cleaned == "/" || cleaned == "" {
		return true
	}
	// 保护全局关键系统目录
	if cleaned == defaultThumbnailDir || cleaned == ManifestDir || cleaned == "lost+found" {
		return true
	}
	// 保护 .manifest 目录下的所有元数据文件
	if strings.HasPrefix(cleaned, ManifestDir+"/") {
		return true
	}
	// 保护默认相册（及其缩略图根目录）
	defaultAlbum := im.GetDefaultAlbum()
	if defaultAlbum != "" {
		if cleaned == defaultAlbum || cleaned == filepath.Join(defaultThumbnailDir, defaultAlbum) {
			return true
		}
	}
	// 保护除 .thumbnail 以外的其他根级隐藏目录（如 .stversions、.git 等）
	if strings.HasPrefix(cleaned, ".") && cleaned != defaultThumbnailDir && !strings.HasPrefix(cleaned, defaultThumbnailDir+"/") {
		return true
	}
	return false
}

// isDirEmpty 检查指定目录是否为空（不含任何文件或子目录）
func (im *ImgManager) isDirEmpty(d StorageDrive, dir string) (bool, error) {
	empty := true
	err := d.Range(dir, func(info fs.FileInfo) bool {
		empty = false
		return false
	})
	if err != nil {
		return false, err
	}
	return empty, nil
}

// cleanEmptyDirsUpwards 自底向上递归/迭代探测并删除所有已变为空的非受保护目录（如日期目录或非默认相册）
func (im *ImgManager) cleanEmptyDirsUpwards(d StorageDrive, startDir string, deletedDirs map[string]bool) {
	curr := filepath.Clean(filepath.ToSlash(startDir))
	for {
		if im.isProtectedDir(curr) {
			break
		}
		if deletedDirs != nil && deletedDirs[curr] {
			parent := filepath.Dir(curr)
			if parent == curr {
				break
			}
			curr = parent
			continue
		}

		exists, err := d.IsExist(curr)
		if err != nil {
			im.logger.Printf("cleanEmptyDirsUpwards: check exists %s: %v", curr, err)
			break
		}
		if !exists {
			// 当前目录可能已在外层被整目录移动或删除，继续向上探测其父目录
			parent := filepath.Dir(curr)
			if parent == curr || im.isProtectedDir(parent) {
				break
			}
			curr = parent
			continue
		}

		empty, err := im.isDirEmpty(d, curr)
		if err != nil {
			im.logger.Printf("cleanEmptyDirsUpwards: check empty %s: %v", curr, err)
			break
		}
		if !empty {
			// 当前目录非空，上层目录必然包含当前目录而无法为空，终止向上探测
			break
		}

		if err := d.Delete(curr); err != nil {
			im.logger.Printf("cleanEmptyDirsUpwards: delete empty dir %s failed: %v", curr, err)
			break
		}
		im.logger.Printf("[INFO] Cleaned empty dir after move: %s", curr)
		if deletedDirs != nil {
			deletedDirs[curr] = true
		}

		parent := filepath.Dir(curr)
		if parent == curr {
			break
		}
		curr = parent
	}
}

// MoveAssets 将指定路径的照片移动至目标相册（联动迁移主图、缩略图与 LivePhoto）
func (im *ImgManager) MoveAssets(paths []string, targetAlbum string) ([]string, error) {
	cleanTarget, err := util.SanitizePath(targetAlbum)
	if err != nil || strings.Contains(cleanTarget, "/") {
		return nil, fmt.Errorf("invalid target album: %s", targetAlbum)
	}
	d, unlock := im.drive()
	defer unlock()
	md, unlockMeta := im.metaDrive()
	defer unlockMeta()

	newPaths := make([]string, 0, len(paths))
	srcMainDirsToClean := make(map[string]bool)
	srcThumbDirsToClean := make(map[string]bool)

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

		if cleanedPath == newMainPath {
			newPaths = append(newPaths, newMainPath)
			continue
		}

		if err := d.Move(cleanedPath, newMainPath); err != nil {
			im.logger.Printf("MoveAssets: failed to move %s -> %s: %v", cleanedPath, newMainPath, err)
			continue
		}
		newPaths = append(newPaths, newMainPath)

		// 联动迁移副存储（或主存储）上的缩略图
		oldThumb := filepath.Join(defaultThumbnailDir, cleanedPath)
		newThumb := filepath.Join(defaultThumbnailDir, newMainPath)
		_ = md.Move(oldThumb, newThumb)

		// 收集待检测的源目录（主存储原图目录与副存储缩略图目录分别记录）
		srcDir := filepath.Dir(cleanedPath)
		if strings.HasPrefix(filepath.Base(srcDir), "live_") {
			newLiveDir := filepath.Dir(newMainPath)
			_ = d.Move(srcDir, newLiveDir)
			_ = md.Move(filepath.Join(defaultThumbnailDir, srcDir), filepath.Join(defaultThumbnailDir, newLiveDir))
			srcMainDirsToClean[srcDir] = true
			srcThumbDirsToClean[filepath.Join(defaultThumbnailDir, srcDir)] = true
			srcDir = filepath.Dir(srcDir)
		}
		srcMainDirsToClean[srcDir] = true
		srcThumbDirsToClean[filepath.Join(defaultThumbnailDir, srcDir)] = true
	}

	// 移动完成后，分别在主存储和副存储上自底向上清理变为空的目录
	cleanOnDrive := func(targetDrive StorageDrive, dirSet map[string]bool) {
		if len(dirSet) == 0 {
			return
		}
		sortedDirs := make([]string, 0, len(dirSet))
		for dir := range dirSet {
			sortedDirs = append(sortedDirs, dir)
		}
		sort.Slice(sortedDirs, func(i, j int) bool {
			return len(sortedDirs[i]) > len(sortedDirs[j])
		})
		deletedDirs := make(map[string]bool)
		for _, dir := range sortedDirs {
			im.cleanEmptyDirsUpwards(targetDrive, dir, deletedDirs)
		}
	}
	cleanOnDrive(d, srcMainDirsToClean)
	cleanOnDrive(md, srcThumbDirsToClean)

	if len(newPaths) > 0 && im.manifest != nil {
		records := make([]ManifestRecord, 0, len(newPaths))
		for _, np := range newPaths {
			var size int64
			if oldRec, found := im.manifest.LookupFingerprint(filepath.Base(np)); found {
				size = oldRec.Size
			}
			records = append(records, ManifestRecord{
				Fingerprint: filepath.Base(np),
				Album:       cleanTarget,
				Path:        np,
				Size:        size,
				Deleted:     false,
				UpdatedAt:   time.Now().Unix(),
			})
		}
		_ = im.manifest.AppendChunk(md, records)
	}
	return newPaths, nil
}

// MigrateLegacyRootFolders 自动迁移老版本存量年份文件夹至默认相册
func (im *ImgManager) MigrateLegacyRootFolders() {
	d, unlock := im.drive()
	defer unlock()
	md, unlockMeta := im.metaDrive()
	defer unlockMeta()

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
			_ = md.Move(oldThumb, newThumb)

			// 迁移完成后若旧目录残留变空，执行清理
			im.cleanEmptyDirsUpwards(d, oldPath, nil)
			im.cleanEmptyDirsUpwards(md, oldThumb, nil)
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
