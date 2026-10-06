// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get local => '本地';

  @override
  String get cloud => '云端';

  @override
  String get sync => '同步';

  @override
  String get cloudSync => '云端同步';

  @override
  String get localFolder => '本地相册';

  @override
  String get cloudStorage => '云端设置';

  @override
  String get backgroundSync => '后台同步';

  @override
  String get notSync => '张照片尚未同步';

  @override
  String get unsynchronizedPhotos => '未同步照片';

  @override
  String get date => '日期';

  @override
  String get delete => '删除';

  @override
  String get photos => '照片';

  @override
  String get deleteThisPhoto => '删除这张照片?';

  @override
  String get deleteThisPhotos => '删除选中的照片?';

  @override
  String get cantBeUndone => '该操作无法撤销';

  @override
  String get download => '下载';

  @override
  String get upload => '上传';

  @override
  String get success => '成功';

  @override
  String get pics => '照片';

  @override
  String get choose => '选择';

  @override
  String get stop => '停止';

  @override
  String get queued => '排队中';

  @override
  String get uploading => '上传中';

  @override
  String get downloading => '下载中';

  @override
  String get uploadFailed => '上传失败';

  @override
  String get uploaded => '已上传';

  @override
  String get notUploaded => '未上传';

  @override
  String get chooseAlbum => '选择相册';

  @override
  String get storageSetting => '网络储存设置';

  @override
  String get remoteStorageType => '网络储存类型';

  @override
  String get samvbaServerAddress => 'Samba服务器地址';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get share => '分享';

  @override
  String get rootPath => '储存根目录(照片会储存在该目录下)';

  @override
  String get optional => '可选';

  @override
  String get testStorage => '测试连接';

  @override
  String get save => '保存';

  @override
  String get enableBackgroundSync => '启用后台同步';

  @override
  String get syncOnlyOnWifi => '仅在连接WIFI时同步';

  @override
  String get syncInterval => '同步间隔';

  @override
  String get minite => '分钟';

  @override
  String get hour => '小时';

  @override
  String get day => '天';

  @override
  String get week => '周';

  @override
  String get month => '月';

  @override
  String get year => '年';

  @override
  String get chineseday => '日';

  @override
  String get yes => '确认';

  @override
  String get cancel => '取消';

  @override
  String get permissionDenied => '权限不足';

  @override
  String get setLocalFirst => '请先设置本地相册';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get storageNotSetted => '网络储存未配置,请先配置网络储存';

  @override
  String get successfullyUpload => '成功上传';

  @override
  String get testSuccess => '连接成功,请点击保存';

  @override
  String get connectFailed => '连接失败';

  @override
  String get selectRoot => '选择根目录';

  @override
  String get currentPath => '当前目录';

  @override
  String get refreshingPleaseWait =>
      '正在交叉对比你本地和云端的照片,首次运行或数量较多可能耗时较久,请耐心等待......';

  @override
  String get setRemoteStroage => '请先点击云端设置设置网络储存';

  @override
  String get needPermision => '需要访问相册的权限';

  @override
  String get gotoSystemSetting => '浏览系统相册需要授予相册访问权限,如有需要请转至系统设置授予相册的权限';

  @override
  String get openSetting => '打开设置';

  @override
  String get advancedSetting => '高级设置';

  @override
  String get goToSet => '去设置';

  @override
  String get streamFallbackDownload => '流式播放失败,正在下载后播放';

  @override
  String get dataDirWarning => '修改目录结构只会改变以后上传的文件，不会对已上传的文件进行修改';

  @override
  String get dirType01 => '按日期多层级';

  @override
  String get dirType02 => '按日期单层级';

  @override
  String get tapToSet => '点击设置';

  @override
  String get longPressToCancel => '长按取消设置';

  @override
  String get jumpTo => '快速定位到';

  @override
  String get jumpToByDate => '按日期定位';

  @override
  String get onlyCamera => '仅相机拍摄';

  @override
  String get browseInRecents => '请在Recents中浏览';

  @override
  String get failedTooMany => '失败次数过多, 已暂停同步';

  @override
  String get refreshing => '获取照片中,请耐心等待...';

  @override
  String get settings => '设置';

  @override
  String get desktopStorageSettingDesc => '设置网络储存来浏览你用Pho备份的照片';

  @override
  String get zoomIn => '放大视图';

  @override
  String get zoomOut => '缩小视图';

  @override
  String get about => '应用信息';

  @override
  String get appVersion => '应用版本';

  @override
  String get releaseStorage => '释放储存空间';

  @override
  String get deleteSynced => '删除已同步的照片';

  @override
  String get youHaveSynced => '您已经同步了';

  @override
  String get photosInCloud => '张照片或视频';

  @override
  String get canDeleteNow => '现在可以删除它们以节省空间';

  @override
  String get canBrowserAnyTime => '您可以随时在云端储存中以原画质浏览它们';

  @override
  String get pleaseConfirmBeforeDelete => '请您务必确认你已经在云端储存中备份了这些照片,否则删除后将无法恢复';

  @override
  String get installHEVCExtention =>
      '如果HEIC或HEVC格式无法正常显示，请在Microsoft Store安装\"HEVC 视频扩展\"';

  @override
  String get openMSStore => '安装';

  @override
  String get clearCache => '清除缓存';

  @override
  String get clearCacheDescription => '此操作只会清除图片缓存,不会删除你的任何配置,确认清除缓存?';

  @override
  String get clearCacheSuccess => '清除缓存成功';

  @override
  String get clearCacheFailed => '清除缓存失败';

  @override
  String get offline => '离线';

  @override
  String get noLocalPhotos => '未找到照片';

  @override
  String get noCloudPhotos => '无云端照片';

  @override
  String get refreshUnsynchronizedPhotos => '刷新未同步照片';

  @override
  String get onboardingWelcome => '欢迎使用 Pho';

  @override
  String get onboardingWelcomeDesc => '你的无服务端照片同步工具';

  @override
  String get onboardingSyncTitle => '同步到你的存储';

  @override
  String get onboardingSyncDesc => '支持 SMB、WebDAV 和 NFS，照片按日期自动组织';

  @override
  String get onboardingPrivacyTitle => '你的数据你做主';

  @override
  String get onboardingPrivacyDesc => '无服务器、无数据库，文件直接存储在你的网络存储中';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingGetStarted => '开始使用';

  @override
  String get onboardingPermissionTitle => '需要相册访问权限';

  @override
  String get onboardingPermissionDesc => 'Pho 需要访问你的相册以浏览和同步照片';

  @override
  String get onboardingGrantPermission => '授予权限';

  @override
  String get onboardingLater => '稍后设置';

  @override
  String get onboardingStorageTitle => '设置云端存储（可选）';

  @override
  String get onboardingStorageDesc => '你现在可以设置或稍后在设置中配置';

  @override
  String get onboardingSetupStorage => '设置存储';

  @override
  String get onboardingComplete => '完成';

  @override
  String get settingsBasic => '基础';

  @override
  String get settingsUtilities => '实用工具';

  @override
  String get iosBackgroundSyncDescription => 'iOS 后台同步由系统在充电时自动调度，无需手动设置间隔';

  @override
  String get notificationDenied => '通知权限未开启，同步正常但无提醒';

  @override
  String get backgroundRefreshDisabledTitle => '后台 App 刷新已关闭';

  @override
  String get backgroundRefreshDisabledDesc =>
      '后台同步将无法触发。请到 设置 -> Pho 开启后台 App 刷新，再到 设置 -> 通用 -> 后台 App 刷新 确认全局开启';

  @override
  String get backgroundRefreshDisabledAction => '打开 Pho 设置';

  @override
  String get bgSyncSuccessNotificationTitle => 'Pho 后台同步';

  @override
  String bgSyncSuccessNotificationBody(int count) {
    return '成功同步 $count 张照片';
  }

  @override
  String bgSyncSuccessNotificationBodyWithFailures(int succeeded, int failed) {
    return '成功同步 $succeeded 张照片（$failed 张失败）';
  }

  @override
  String get parallelUpload => '并发上传';

  @override
  String get parallelUploadDesc => '调整同时上传的文件数 (1~8 线程)';

  @override
  String parallelUploadCount(int count) {
    return '$count 线程';
  }

  @override
  String get parallelUploadTip =>
      '局域网或高速带宽下增加并发数可显著提升同步速度；弱网或频繁超时建议保持为 1~2 线程。';

  @override
  String get fileFilter => '文件筛选器';

  @override
  String get fileFilterDesc => '按媒体类型、拍摄时间或格式过滤不需同步的文件';

  @override
  String get filterEnabled => '已启用';

  @override
  String get filterDisabled => '未启用';

  @override
  String get filterSwitchTitle => '启用文件筛选器';

  @override
  String get filterSwitchDesc => '开启后仅同步满足以下条件的照片和视频';

  @override
  String get filterMediaGroup => '媒体类型过滤';

  @override
  String get filterNoVideoTitle => '跳过视频文件';

  @override
  String get filterNoVideoSubtitle => '仅同步照片，不上传任何视频';

  @override
  String get filterNoImageTitle => '跳过照片文件';

  @override
  String get filterNoImageSubtitle => '仅同步视频，不上传任何静态照片';

  @override
  String get filterDateGroup => '拍摄日期范围过滤';

  @override
  String get filterAfterTitle => '起始日期';

  @override
  String get filterAfterDesc => '只同步此日期之后拍摄的照片/视频';

  @override
  String get filterBeforeTitle => '截止日期';

  @override
  String get filterBeforeDesc => '只同步此日期之前拍摄的照片/视频';

  @override
  String get filterNotSet => '未设置';

  @override
  String get filterFormatGroup => '文件扩展名过滤';

  @override
  String get filterFormatDesc => '点击切换排除/包含格式，被排除的格式将跳过同步';

  @override
  String get filterReset => '重置筛选条件';

  @override
  String get filterResetConfirm => '确认将所有筛选条件恢复为默认设置？';

  @override
  String get exportConfig => '导出配置';

  @override
  String get importConfig => '导入配置';

  @override
  String get storageConfigQrTitle => '存储配置二维码';

  @override
  String get storageConfigQrDesc => '在另一台设备上扫描此二维码可一键迁移存储配置';

  @override
  String get copyConfig => '复制配置链接';

  @override
  String get configCopied => '配置已复制到剪贴板';

  @override
  String get shareConfig => '分享配置';

  @override
  String get scanStorageConfig => '扫描二维码';

  @override
  String get pickFromGallery => '从相册识别';

  @override
  String get importFromClipboard => '从剪贴板导入';

  @override
  String get pasteConfig => '手动粘贴配置';

  @override
  String get noStorageConfigFound => '当前未配置网络存储，无法导出';

  @override
  String get importConfigConfirmTitle => '确认导入存储配置';

  @override
  String get testAndSave => '测试连接并保存';

  @override
  String get configImportSuccess => '存储配置已成功导入并生效';

  @override
  String get configImportFailed => '连接失败，无法导入该配置';

  @override
  String get invalidConfig => '无法识别的配置格式';

  @override
  String get clipboardEmpty => '剪贴板中未发现 Pho 存储配置';

  @override
  String get pasteHint => '请在此粘贴 pho://storage 链接或配置文本';

  @override
  String get debugMode => '调试模式';

  @override
  String get debugModeDesc => '启用后记录详细同步、网络与运行日志';

  @override
  String get openDebugConsole => '打开调试控制台';

  @override
  String get openDebugConsoleDesc => '查看实时日志、分类过滤、异常栈与系统分享导出';

  @override
  String get clearDebugLogs => '清空调试日志';

  @override
  String get debugLogsCleared => '调试日志已清空';

  @override
  String get cloudAlbums => '云端相册';

  @override
  String get allPhotos => '全部照片';

  @override
  String get defaultAlbum => '默认相册';

  @override
  String get newAlbum => '新建相册';

  @override
  String get albumName => '相册名称';

  @override
  String get albumNameHint => '请输入相册名称';

  @override
  String get renameAlbum => '重命名相册';

  @override
  String get deleteAlbum => '删除相册';

  @override
  String get deleteAlbumConfirmTitle => '确认粉碎删除相册？';

  @override
  String deleteAlbumConfirmDesc(Object count) {
    return '警告：此操作将永久粉碎删除相册及其内部包含的所有照片（共 $count 张），云端数据将彻底抹除且不可撤销！';
  }

  @override
  String get deleteAlbumInputHint => '请输入相册名称以确认删除';

  @override
  String get cannotDeleteDefaultAlbum => '默认相册禁止删除';

  @override
  String get moveToAlbum => '移动到相册';

  @override
  String get moveSuccess => '移动成功';

  @override
  String get moveFailed => '移动失败';

  @override
  String get defaultAlbumSetting => '默认备份相册';

  @override
  String get defaultAlbumSettingDesc => '设置自动备份和上传默认流入的相册名称';

  @override
  String get remoteStats => '远端请求统计';

  @override
  String get remoteStatsDesc => '实时监控发往 WebDAV 远端存储的物理请求总数与明细';

  @override
  String get totalRequests => '总请求次数';

  @override
  String get rateLimitHits => '触发 429 限流次数';

  @override
  String get resetStats => '重置统计计数';

  @override
  String get recentLogs => '最近请求流水';

  @override
  String get refreshStats => '刷新统计';

  @override
  String get transferring => '正在传输';

  @override
  String get enableMetaStorage => '启用独立元数据与缩略图存储';

  @override
  String get enableMetaStorageDesc => '可将元数据 (.manifest) 与缩略图存放到访问速度更快的存储后端';

  @override
  String get metaStorageType => '元数据与缩略图存储类型';

  @override
  String get rebuildMetaAndThumbnails => '重建元数据与缩略图';

  @override
  String get rebuildMetaAndThumbnailsDesc => '扫描主存储重建远端元数据索引，并从本地相册补齐缩略图';

  @override
  String get rebuildingMetaAndThumbnails => '正在重建元数据与缩略图...';

  @override
  String rebuildSuccess(Object count, Object thumbCount) {
    return '重建完成：已索引 $count 张照片，补齐 $thumbCount 张缩略图';
  }
}
