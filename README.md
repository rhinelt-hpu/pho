<br/><br/><p align="center">
<img src="assets/icon/pho_icon.png" width="150">
</p>
<h3 align="center">
Pho - 一个用于查看和上传照片的无服务端应用
</h3>
<p align="center">
  <img src="https://github.com/fregie/pho/actions/workflows/go_test.yml/badge.svg">
</p>
<p align="center">
  <a href="README.md">中文</a> | <a href="README_EN.md">English</a>
</p>

### 安装
- [GitHub Releases 下载安装包](https://github.com/fregie/pho/releases)
- 支持源码构建 Android APK 与 iOS IPA（构建步骤详见下方说明）

### 介绍
该应用的目的是替代手机上的自带相册应用,并且能够将照片同步到网络储存.  
功能简单,只是用于查看照片以及同步照片到网络储存.试图做到优秀的体验.

### 功能
* 本地照片与视频查看 (支持 Live Photo 实况照片回放)
* 云端照片与视频查看
* 增量同步照片到云端
* 后台定期自动同步
* AES-256-GCM / AES-128-CFB 端到端加密 (加密视频支持 Range 在线播放)
* 无数据库,无服务端
* 以时间组织云端存储的目录结构 (支持自定义目录组织格式)
* 自定义主题配色

### 支持的网络储存
- [x] Samba
- [x] Webdav
- [x] NFS
- [ ] 阿里网盘
- [ ] oneDrive
- [ ] google drive
- [ ] google photo

### Screenshots
<p align="left">
<img src="assets/screenshot/screenshot_local.png" width="220" alt="本地相册">
<img src="assets/screenshot/screenshot_cloud.png" width="220" alt="云端相册">
<img src="assets/screenshot/screenshot_sync.png" width="220" alt="同步页面">
<img src="assets/screenshot/screenshot_view.png" width="220" alt="照片查看">
</p>

### roadmap
- [x] 支持放大/缩小图片
- [x] 支持上传/浏览视频
- [x] 支持NFS
- [x] 支持IOS端
- [ ] 支持desktop端
- [x] 支持中文

### 构建
#### 环境要求
- Flutter: >= 3.44.0 (推荐 3.47.x stable), Dart: >= 3.12.0
- Go: 1.25.x / 1.26.x (toolchain go1.25.4)
- JDK: 17
- Android SDK: compileSdk 36
- Android NDK: 28.2.13676358 (用于构建嵌入式 Go 服务端 gomobile bind 及 CGO)
- protoc + 插件: protoc-gen-go@v1.27.1, protoc-gen-go-grpc@v1.1.0, protoc_plugin@21.1.2 (Dart)


#### 构建步骤
```bash
# 1. 生成 protobuf 代码 (Go + Dart stubs)
make prebuild      # 安装 protoc 插件
make protobuf

# 2. 构建嵌入式 Go 服务端
make server-aar     # Android: android/app/libs/server.aar (需 gomobile)
make server-ios     # iOS: ios/Frameworks/RUN.xcframework
make server-linux   # Linux: linux/lib/run.so
make server-windows # Windows: windows/lib/run.dll

# 3. 构建 Flutter 应用
make apk           # Android APK
make ipa           # iOS IPA

# 4. 运行测试 (需要 Docker 用于 SMB/WebDAV/NFS 测试容器)
make test
```

> 注: `flutter run` 不会自动构建 `android/app/libs/server.aar`,需先执行 `make server-aar`,否则 Go 服务端无法启动.

### Contribute
感谢各位的积极反馈

给本项目提需求的还不少,但是我一个人精力有限,如果你有兴趣,欢迎加入.

可以在issue中回复沟通,帮忙一起做一些功能,提出你的pull request.

### 文件储存逻辑
本着尽可能简单的逻辑来储存文件,以时间为目录结构,以文件名为文件名储存源文件.在根目录创建一个`.thumbnail`目录来储存生成的缩略图,缩略图的目录结构与源文件相同.  
你可以随时以其他形式利用你备份上去的照片,而不用依赖此app.
目录结构示意图:
```bash
├── 2022
│   ├── 07
│   │   ├── 02
│   │   │   ├── 20220702_100940.JPG
│   │   │   ├── 20220702_111416.JPG
│   │   │   └── 20220702_111508.JPG
│   │   └── 03
│   │       ├── 20220703_101923.DNG
│   │       ├── 20220703_112336.DNG
│   │       └── 20220703_112338.DNG
├── 2023
│   └── 01
│       └── 03
│           ├── 20230103_112348.JPG
│           ├── 20230103_124634.JPG
│           └── 20230103_124918.DNG
└── .thumbnail
     └── 2022
         └── 07
             ├── 02
             │   ├── 20220702_100940.JPG
             │   ├── 20220702_111416.JPG
             │   └── 20220702_111508.JPG
             └── 03
                 ├── 20220703_101923.DNG
                 ├── 20220703_112336.DNG
                 └── 20220703_112338.DNG
```


### Star History

[![Star History Chart](https://api.star-history.com/svg?repos=fregie/pho&type=Date)](https://star-history.com/#fregie/pho&Date)
