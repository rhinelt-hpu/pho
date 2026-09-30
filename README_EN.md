<br/><br/><p align="center">
<img src="assets/icon/pho_icon.png" width="150">
</p>
<h3 align="center">
Pho - A serverless application for viewing and uploading photos
</h3>
<p align="center">
  <img src="https://github.com/fregie/pho/actions/workflows/go_test.yml/badge.svg">
</p>
<p align="center">
  <a href="README.md">中文</a> | <a href="README_EN.md">English</a>
</p>

### Installation
- [GitHub Releases](https://github.com/fregie/pho/releases)
- Supports building from source for Android APK and iOS IPA (see build steps below)

### Introduction
The primary objective of this application is to serve as a replacement for the native photo gallery application on smartphones. It also offers the capability to synchronize photos with online storage.  
Pho is a simple app designed for viewing and synchronizing photos to cloud storage. It aims to provide an excellent user experience.

### Features
* Local photo and video browsing (including Live Photo playback)
* Cloud photo and video browsing
* Incremental photo synchronization to the cloud
* Background periodic synchronization
* AES-256-GCM / AES-128-CFB end-to-end encryption (encrypted video supports Range online playback)
* No database, no server-side
* Organizing cloud storage directory structure by date
* Custom theme colors

### Supported Cloud Storage
- [x] Samba
- [x] Webdav
- [x] NFS
- [ ] Alibaba Cloud Drive
- [ ] oneDrive
- [ ] google drive
- [ ] google photo

### Screenshots
<p align="left">
<img src="assets/screenshot/screenshot_local.png" width="220" alt="Local Gallery">
<img src="assets/screenshot/screenshot_cloud.png" width="220" alt="Cloud Gallery">
<img src="assets/screenshot/screenshot_sync.png" width="220" alt="Sync Page">
<img src="assets/screenshot/screenshot_view.png" width="220" alt="Photo Viewer">
</p>

### Roadmap
- [x] Support zooming in/out of images
- [x] Support uploading/browsing videos
- [x] Support NFS
- [x] Support Baidu net disk
- [x] Support iOS
- [ ] Support web version
- [x] Add Chinese

### Contribute
Thank you all for your positive feedback.

There have been quite a few people who have provided requirements for this project, but as an individual, my resources are limited. If you are interested, you are welcome to join.

You can communicate by replying in the issue section and help in developing some features by submitting your pull request.

### File Storage Logic
The application stores files based on a straightforward principle of utilizing the time as the directory structure, and the source file name as the filename for storage. A .thumbnail directory is created in the root directory to store the generated thumbnails, and the directory structure for these thumbnails aligns with that of the source files.

You can access and utilize your backed-up photos in any other manner at any time, without dependence on this application.

Directory Structure Diagram:
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

### Join QQ group
<img src="assets/pho-qq-group.jpg" width="400">