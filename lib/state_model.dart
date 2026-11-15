// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';
import 'package:date_format/date_format.dart';
import 'package:grpc/grpc.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/logger/logger.dart';
import 'event_bus.dart';
import 'package:img_syncer/asset.dart';
import 'dart:async';
import 'package:photo_manager/photo_manager.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:mime/mime.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/global.dart';
import 'package:shared_preferences/shared_preferences.dart';

SettingModel settingModel = SettingModel();
AssetModel assetModel = AssetModel();
StateModel stateModel = StateModel();

// TODO(open-source): 网络存储拓展 (待开源补齐百度网盘/OneDrive/Alist等):
// enum Drive { smb, webDav, nfs, baiduNetdisk }
enum Drive { smb, webDav, nfs }

Map<Drive, String> driveName = {
  Drive.smb: 'SMB',
  Drive.webDav: 'WebDAV',
  Drive.nfs: 'NFS',
  // Drive.baiduNetdisk: 'BaiduNetdisk',
};

Drive getDrive(String drive) {
  return driveName.entries
      .firstWhere((element) => element.value.toLowerCase() == drive.toLowerCase(),
          orElse: () => const MapEntry(Drive.smb, "SMB"))
      .key;
}

enum EncryptionType { none, aesCfb, aesGcm }

class SettingModel extends ChangeNotifier {
  String localFolder = "";
  String? localFolderAbsPath;
  bool isRemoteStorageSetted = false;

  bool enableEncrypt = false;
  EncryptionType encryptionType = EncryptionType.none;
  String encryptionPassword = "";

  int galleryColumCount = 4;

  bool setGalleryColumCount(int count) {
    if (galleryColumCount == count) return false;
    galleryColumCount = count;
    notifyListeners();
    return true;
  }

  void setLocalFolder(String folder) {
    if (localFolder == folder && folder != "Recents") return;
    localFolder = folder;
    localFolderAbsPath = null;
    // 注意：不要清空 stateModel.syncedIDs。syncedIDs 里是 photo_manager 的全局
    // AssetEntity.id，与当前选中的相册无关，切换相册后依然有效。
    notifyListeners();
  }

  void setRemoteStorageSetted(bool setted) {
    if (isRemoteStorageSetted == setted) return;
    isRemoteStorageSetted = setted;
    notifyListeners();
  }

  void setEncryptSwitch(bool enable) {
    if (enableEncrypt == enable) return;
    enableEncrypt = enable;
    notifyListeners();
  }

  void setEncryptionType(EncryptionType type) {
    if (encryptionType == type) return;
    encryptionType = type;
    notifyListeners();
  }

  void setEncryptionPassword(String password) {
    if (encryptionPassword == password) return;
    encryptionPassword = password;
    notifyListeners();
  }

  // 1. 并发上传配置 (1~8, 默认 3)
  int _parallelCount = 3;
  int get parallelCount => _parallelCount;
  set parallelCount(int count) => setParallelCount(count);

  /// 兼容旧命名与测试用例 (paralleUploadCount)
  int get paralleUploadCount => _parallelCount;
  set paralleUploadCount(int count) => setParallelCount(count);

  void setParallelCount(int count) {
    final clamped = count.clamp(1, 8);
    if (_parallelCount == clamped) return;
    _parallelCount = clamped;
    notifyListeners();
    _saveParallelCount();
  }

  Future<void> _saveParallelCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('parallel_count', _parallelCount);
    } catch (_) {}
  }

  // 2. 文件筛选器 (File Filter)
  bool filterSwitch = false; // 筛选器总开关
  bool filterNoVideo = false; // 过滤视频（只同步照片）
  bool filterNoImage = false; // 过滤图片（只同步视频）
  DateTime? filterAfter; // 只同步该日期之后的照片
  DateTime? filterBefore; // 只同步该日期之前的照片
  Map<String, bool> filterTypeMap = {}; // 扩展名白名单/黑名单

  // 3. 调试模式 (Debug Mode / Talker)
  bool _debugMode = false;
  bool get debugMode => _debugMode;
  set debugMode(bool value) => setDebugMode(value);

  void setDebugMode(bool enabled) {
    if (_debugMode == enabled) return;
    _debugMode = enabled;
    logger.setEnabled(enabled);
    notifyListeners();
    _saveDebugMode();
  }

  Future<void> _saveDebugMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('debug_mode', _debugMode);
    } catch (_) {}
  }

  // 3.1 详细日志（DEBUG）开关，落盘 key: log_verbose（默认 false）
  bool _logVerbose = false;
  bool get logVerbose => _logVerbose;
  set logVerbose(bool value) => setLogVerbose(value);

  void setLogVerbose(bool enabled) {
    if (_logVerbose == enabled) return;
    _logVerbose = enabled;
    logger.setVerbose(enabled);
    notifyListeners();
    _saveLogVerbose();
  }

  Future<void> _saveLogVerbose() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('log_verbose', _logVerbose);
    } catch (_) {}
  }

  /// 兼容旧命名与测试用例 (enableFilter)
  bool get enableFilter => filterSwitch;
  set enableFilter(bool enable) => setFilterSwitch(enable);

  void setFilterSwitch(bool enable) {
    if (filterSwitch == enable) return;
    filterSwitch = enable;
    notifyListeners();
    _saveFilterSettings();
  }

  void setFilterNoVideo(bool noVideo) {
    if (filterNoVideo == noVideo) return;
    filterNoVideo = noVideo;
    notifyListeners();
    _saveFilterSettings();
  }

  void setFilterNoImage(bool noImage) {
    if (filterNoImage == noImage) return;
    filterNoImage = noImage;
    notifyListeners();
    _saveFilterSettings();
  }

  void setFilterAfter(DateTime? after) {
    if (filterAfter == after) return;
    filterAfter = after;
    notifyListeners();
    _saveFilterSettings();
  }

  void setFilterBefore(DateTime? before) {
    if (filterBefore == before) return;
    filterBefore = before;
    notifyListeners();
    _saveFilterSettings();
  }

  void setFilterType(String type, bool enable) {
    final key = type.startsWith('.') ? type.toLowerCase() : '.$type'.toLowerCase();
    if (filterTypeMap[key] == enable) return;
    filterTypeMap[key] = enable;
    notifyListeners();
    _saveFilterSettings();
  }

  // 4. 本地相册视图：隐藏已上传（仅本地相册生效）
  bool hideSyncedLocal = false;

  void setHideSyncedLocal(bool hide) {
    if (hideSyncedLocal == hide) return;
    hideSyncedLocal = hide;
    notifyListeners();
    _saveHideSyncedLocal();
  }

  Future<void> _saveHideSyncedLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hide_synced_local', hideSyncedLocal);
    } catch (_) {}
  }

  void resetFilters() {
    filterSwitch = false;
    filterNoVideo = false;
    filterNoImage = false;
    filterAfter = null;
    filterBefore = null;
    filterTypeMap.clear();
    notifyListeners();
    _saveFilterSettings();
  }

  Future<void> _saveFilterSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('filter_switch', filterSwitch);
      await prefs.setBool('filter_no_video', filterNoVideo);
      await prefs.setBool('filter_no_image', filterNoImage);
      if (filterAfter != null) {
        await prefs.setInt('filter_after', filterAfter!.millisecondsSinceEpoch);
      } else {
        await prefs.remove('filter_after');
      }
      if (filterBefore != null) {
        await prefs.setInt('filter_before', filterBefore!.millisecondsSinceEpoch);
      } else {
        await prefs.remove('filter_before');
      }
      await prefs.setString('filter_type_map', jsonEncode(filterTypeMap));
    } catch (_) {}
  }

  Future<void> _saveDefaultAlbumName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('default_album_name', defaultAlbumName);
    } catch (_) {}
  }

  String defaultAlbumName = '相机备份';

  void setDefaultAlbumName(String name) {
    if (name.isEmpty || defaultAlbumName == name) return;
    defaultAlbumName = name;
    notifyListeners();
    _saveDefaultAlbumName();
  }

  Future<void> saveSettings() async {
    await _saveParallelCount();
    await _saveFilterSettings();
    await _saveHideSyncedLocal();
    await _saveDebugMode();
    await _saveLogVerbose();
    await _saveDefaultAlbumName();
  }

  Future<void> loadSettings([SharedPreferences? sharedPrefs]) async {
    try {
      final prefs = sharedPrefs ?? await SharedPreferences.getInstance();
      final pCount = prefs.getInt('parallel_count');
      if (pCount != null) {
        _parallelCount = pCount.clamp(1, 8);
      }
      filterSwitch = prefs.getBool('filter_switch') ?? false;
      filterNoVideo = prefs.getBool('filter_no_video') ?? false;
      filterNoImage = prefs.getBool('filter_no_image') ?? false;
      hideSyncedLocal = prefs.getBool('hide_synced_local') ?? false;
      final afterMs = prefs.getInt('filter_after');
      if (afterMs != null) {
        filterAfter = DateTime.fromMillisecondsSinceEpoch(afterMs);
      }
      final beforeMs = prefs.getInt('filter_before');
      if (beforeMs != null) {
        filterBefore = DateTime.fromMillisecondsSinceEpoch(beforeMs);
      }
      _debugMode = prefs.getBool('debug_mode') ?? false;
      logger.setEnabled(_debugMode);
      _logVerbose = prefs.getBool('log_verbose') ?? false;
      logger.setVerbose(_logVerbose);
      defaultAlbumName = prefs.getString('default_album_name') ?? '相机备份';
      final typeMapJson = prefs.getString('filter_type_map');
      if (typeMapJson != null) {
        try {
          final decoded = jsonDecode(typeMapJson);
          if (decoded is Map) {
            filterTypeMap = decoded.map((k, v) => MapEntry(k.toString(), v == true));
          }
        } catch (e) {
          logger.error('Failed to decode filter_type_map: $e');
        }
      }
      notifyListeners();
    } catch (_) {}
  }
}

class transmitState {
  int transmitted = 0;
  int total = 0;
}

class StateModel extends ChangeNotifier {
  bool _isSelectionMode = false;
  bool refreshingUnsynchronized = false;
  List<String> syncedIDs = [];

  /// [syncedIDs] 的 Set 镜像，用于 O(1) 查询（已上传 ID 可能有几万条）
  final Set<String> _syncedIdSet = {};

  /// 是否已上传过（仅查 [_syncedIdSet]，不走 List.contains）
  bool isSynced(String id) => _syncedIdSet.contains(id);
  DateTime? lastRefreshUnsyncTime;

  Map<String, transmitState> uploadProgress = {};
  Map<String, transmitState> downloadProgress = {};

  bool get isSelectionMode => _isSelectionMode;

  bool needStopSync = false;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  void setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    notifyListeners();
  }

  int syncTotal = 0;
  int syncCompleted = 0;
  int syncFailed = 0;
  double get syncPercent => syncTotal == 0 ? 0 : syncCompleted / syncTotal;
  void setSyncProgress(int total, int completed, int failed) {
    syncTotal = total;
    syncCompleted = completed;
    syncFailed = failed;
    notifyListeners();
  }

  void updateLastRefreshUnsyncTime(DateTime? t) {
    lastRefreshUnsyncTime = t;
    notifyListeners();
  }

  void enqueueUploads(Iterable<String> ids) {
    bool changed = false;
    for (final id in ids) {
      if (!uploadProgress.containsKey(id)) {
        uploadProgress[id] = transmitState();
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  void updateUploadProgress(String id, int transmitted, int total) {
    if (!uploadProgress.containsKey(id)) {
      uploadProgress[id] = transmitState();
    }
    uploadProgress[id]!.transmitted = transmitted;
    uploadProgress[id]!.total = total;
    notifyListeners();
  }

  Timer? _saveSyncedDebounceTimer;

  void finishUpload(String id, bool success) {
    uploadProgress.remove(id);
    if (success) {
      if (_syncedIdSet.add(id)) {
        syncedIDs.add(id);
      }
      saveSyncedIDsDebounced();
    }
    notifyListeners();
  }

  /// 防抖合并写入持久化，避免并发上传数百张照片时频繁全量覆写磁盘造成 I/O 阻塞
  void saveSyncedIDsDebounced({Duration duration = const Duration(seconds: 1)}) {
    _saveSyncedDebounceTimer?.cancel();
    _saveSyncedDebounceTimer = Timer(duration, () {
      saveSyncedIDs();
    });
  }

  void updateDownloadProgress(String id, int transmitted, int total) {
    if (!downloadProgress.containsKey(id)) {
      downloadProgress[id] = transmitState();
    }
    downloadProgress[id]!.transmitted = transmitted;
    downloadProgress[id]!.total = total;
    notifyListeners();
  }

  void finishDownload(String id, bool success) {
    downloadProgress.remove(id);
    notifyListeners();
  }

  double getUploadPercent(String id) {
    if (!uploadProgress.containsKey(id)) {
      return 0;
    }
    final state = uploadProgress[id]!;
    if (state.total <= 0) return 0;
    return state.transmitted / state.total;
  }

  double getDownloadPercent(String id) {
    if (!downloadProgress.containsKey(id)) {
      return 0;
    }
    final state = downloadProgress[id]!;
    if (state.total <= 0) return 0;
    return state.transmitted / state.total;
  }

  bool isUploading() {
    return uploadProgress.isNotEmpty;
  }

  bool isDownloading() {
    return downloadProgress.isNotEmpty;
  }

  void setSelectionMode(bool mode) {
    if (_isSelectionMode == mode) return;
    _isSelectionMode = mode;
    notifyListeners();
  }

  void removeSyncedPhotos(List<String> ids) {
    for (var id in ids) {
      syncedIDs.remove(id);
      _syncedIdSet.remove(id);
    }
    notifyListeners();
  }

  void setSyncedPhotos(List<String> ids) {
    syncedIDs = ids;
    _syncedIdSet
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// 追加标记为已同步（去重），并防抖持久化
  void markSynced(Iterable<String> ids) {
    var changed = false;
    for (final id in ids) {
      if (_syncedIdSet.add(id)) {
        syncedIDs.add(id);
        changed = true;
      }
    }
    if (!changed) return;
    saveSyncedIDsDebounced();
    notifyListeners();
  }

  /// 上传前确认远端是否已存在这些照片（仅手动多选/单张上传使用）。
  ///
  /// 只发送传入的资源；远端未配置、调用异常或超时都返回空集合：
  /// 宁可重复上传，也不阻塞用户操作。
  /// 超过 [maxCheckCount] 条时直接跳过：大批量本来就不是 syncedIDs 的盲区，
  /// 逐条建请求反而把等待时间浪费在本地循环上。
  static const int maxCheckCount = 300;

  Future<Set<String>> checkRemoteUploaded(Iterable<Asset> assets) async {
    final list = assets.where((a) => a.local != null).toList();
    if (list.isEmpty || !settingModel.isRemoteStorageSetted) {
      return <String>{};
    }
    if (list.length > maxCheckCount) {
      logger.info(
          'checkRemoteUploaded: skip ${list.length} assets (>$maxCheckCount)');
      return <String>{};
    }
    final sw = Stopwatch()..start();
    final uploadedIDs = <String>{};
    StreamController<FilterNotUploadedRequest>? requests;
    try {
      requests = StreamController<FilterNotUploadedRequest>();
      final responses = storageClient.cli.filterNotUploaded(requests.stream);
      await Future.wait([
        sendUploadedCheckRequests(requests, list),
        collectUploadedIDs(responses, uploadedIDs),
      ]).timeout(const Duration(seconds: 10));
    } catch (e) {
      logger.error('checkRemoteUploaded failed: $e');
      return <String>{};
    } finally {
      if (requests != null && !requests.isClosed) {
        requests.close();
      }
    }
    // 只认回传中属于本次请求的 id，避免污染 syncedIDs
    final requestedIds = list.map((a) => a.local!.id).toSet();
    uploadedIDs.retainAll(requestedIds);
    logger.info('checkRemoteUploaded: ${list.length} assets, '
        'found ${uploadedIDs.length}, ${sw.elapsedMilliseconds}ms');
    return uploadedIDs;
  }

  void setRefreshingUnsynchronized(bool refreshing) {
    if (refreshingUnsynchronized == refreshing) return;
    refreshingUnsynchronized = refreshing;
    notifyListeners();
  }

  Future<void> saveSyncedIDs() async {
    _saveSyncedDebounceTimer?.cancel();
    _saveSyncedDebounceTimer = null;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(syncedIDs);
    await prefs.setString('synced_ids', jsonString);
    await prefs.setInt(
        'last_refersh_unsync', DateTime.now().millisecondsSinceEpoch);
  }
}

class AssetModel extends ChangeNotifier {
  AssetModel() {
    eventBus
        .on<LocalRefreshEvent>()
        .listen((event) => refreshLocal(event.refreshUnSync));
    eventBus
        .on<RemoteRefreshEvent>()
        .listen((event) => refreshRemote(event.refreshUnSync));
    eventBus.on<FinishGettingLocal>().listen((event) async {
      if (stateModel.lastRefreshUnsyncTime == null) {
        refreshUnsynchronizedPhotos();
      } else {
        if (DateTime.now().difference(stateModel.lastRefreshUnsyncTime!) >
                const Duration(days: 1) &&
            stateModel.syncedIDs.isEmpty) {
          refreshUnsynchronizedPhotos();
        }
      }
    });
    eventBus.on<FinishGettingRemote>().listen((event) async {
      if (stateModel.lastRefreshUnsyncTime == null) {
        refreshUnsynchronizedPhotos();
      } else {
        if (DateTime.now().difference(stateModel.lastRefreshUnsyncTime!) >
                const Duration(days: 1) &&
            stateModel.syncedIDs.isEmpty) {
          refreshUnsynchronizedPhotos();
        }
      }
    });
  }
  List<Asset> localAssets = [];
  List<Asset> remoteAssets = [];
  final Set<String> _localAssetIds = {};
  bool _isRefreshingLocal = false;
  int columCount = 4;
  int pageSize = 500;
  bool localHasMore = true;
  bool remoteHasMore = true;
  Completer<bool>? localGetting;
  bool localGettingNeedBreak = false;
  Completer<bool>? remoteGetting;
  bool remoteGettingNeedBreak = false;
  bool refreshUnsynchronizedNeedBreak = false;

  Map<String, String> titleCache = {};
  int cacheLastSaveLen = 0;

  String? remoteLastError;

  String currentCloudAlbum = '';
  List<AlbumInfo> cloudAlbums = [];

  Future<void> refreshCloudAlbums() async {
    try {
      final list = await storageClient.listAlbums();
      cloudAlbums = list;
      notifyListeners();
    } catch (e) {
      logger.error("refreshCloudAlbums failed: $e");
    }
  }

  Future<void> selectCloudAlbum(String albumName) async {
    if (currentCloudAlbum == albumName) return;
    currentCloudAlbum = albumName;
    await refreshRemote(false);
  }

  Future<void> createCloudAlbum(String name) async {
    await storageClient.createAlbum(name);
    await refreshCloudAlbums();
  }

  Future<void> deleteCloudAlbum(String name) async {
    await storageClient.deleteAlbum(name);
    if (currentCloudAlbum == name) {
      currentCloudAlbum = '';
    }
    await refreshCloudAlbums();
    await refreshRemote(false);
  }

  Future<void> renameCloudAlbum(String oldName, String newName) async {
    await storageClient.renameAlbum(oldName, newName);
    if (currentCloudAlbum == oldName) {
      currentCloudAlbum = newName;
    }
    await refreshCloudAlbums();
    await refreshRemote(false);
  }

  Future<List<String>> moveRemoteAssets(List<Asset> assets, String targetAlbum) async {
    final paths = assets.where((a) => a.hasRemote).map((a) => a.remote!.path).toList();
    if (paths.isEmpty) return [];
    final newPaths = await storageClient.moveAssets(paths, targetAlbum);
    if (currentCloudAlbum.isNotEmpty && currentCloudAlbum != targetAlbum) {
      remoteAssets.removeWhere((a) => a.hasRemote && paths.contains(a.remote!.path));
    } else {
      await refreshRemote(false);
    }
    await refreshCloudAlbums();
    if (currentCloudAlbum.isNotEmpty && !cloudAlbums.any((a) => a.name == currentCloudAlbum)) {
      currentCloudAlbum = "";
      await refreshRemote(false);
    }
    notifyListeners();
    return newPaths;
  }

  void addTitleCache(String id, String title) {
    titleCache[id] = title;
    if (titleCache.length - cacheLastSaveLen > 50) {
      cacheLastSaveLen = titleCache.length;
      saveTitleCache();
    }
  }

  Future<void> saveTitleCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(titleCache);
    prefs.setString('title_cache', jsonString);
  }

  Future<void> loadTitleCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('title_cache');
    if (jsonString != null) {
      final cache = jsonDecode(jsonString);
      for (var key in cache.keys) {
        titleCache[key] = cache[key];
      }
    }
  }

  Future<void> refreshLocal(bool refreshSync) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      return;
    }
    if (_isRefreshingLocal) {
      return;
    }
    _isRefreshingLocal = true;
    try {
      logger.debug("refresh local");
      if (localGetting != null) {
        if (localGettingNeedBreak == true) {
          return;
        }
        localGettingNeedBreak = true;
        await localGetting!.future;
      }
      if (stateModel.refreshingUnsynchronized) {
        refreshUnsynchronizedNeedBreak = true;
      }
      // 不再预清空 syncedIDs：refreshUnsynchronizedPhotos() 两阶段提交后会
      // 用完整结果覆盖；预清空会丢失已知的已上传 ID，导致重复上传。
      localHasMore = true;
      localAssets = [];
      _localAssetIds.clear();
      localGettingNeedBreak = false;
      notifyListeners();
      final finished = await getLocalPhotos();
      if (finished && refreshSync) {
        await refreshUnsynchronizedPhotos();
      }
    } finally {
      _isRefreshingLocal = false;
    }
  }

  Future<void> refreshRemote(bool refreshSync) async {
    logger.debug("refresh remote");
    if (remoteGetting != null) {
      if (remoteGettingNeedBreak == true) {
        return;
      }
      remoteGettingNeedBreak = true;
      await remoteGetting!.future;
    }
    if (stateModel.refreshingUnsynchronized) {
      refreshUnsynchronizedNeedBreak = true;
    }
    remoteHasMore = true;
    remoteAssets = [];
    // 同 refreshLocal：不预清空 syncedIDs，交由 refreshUnsynchronizedPhotos() 覆盖
    notifyListeners();
    remoteGetting = null;
    remoteGettingNeedBreak = false;
    final finished = await getRemotePhotos();
    if (finished && refreshSync) {
      await refreshUnsynchronizedPhotos();
    }
  }

  Future<bool> getLocalPhotos() async {
    if (localGetting != null) {
      await localGetting?.future;
    }
    logger.debug("get local photos");
    final re = await requestPermission();
    if (!re) return false;
    localGetting = Completer<bool>();
    notifyListeners();
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: true,
    );

    // choose the folder has most photos
    if (settingModel.localFolder == "") {
      int max = 0;
      for (var path in paths) {
        final count = await path.assetCountAsync;
        if (count > max) {
          max = count;
          settingModel.localFolder = path.name;
        }
      }
    }

    for (var path in paths) {
      if (settingModel.localFolder == path.name) {
        var opt = const FilterOption(needTitle: true);
        final newpath = await path.fetchPathProperties(
            filterOptionGroup: FilterOptionGroup(
          imageOption: opt,
          videoOption: opt,
          orders: [
            const OrderOption(
              type: OrderOptionType.createDate,
              asc: false,
            ),
          ],
        ));
        int offset = 0;
        while (localHasMore) {
          if (localGettingNeedBreak) {
            localGettingNeedBreak = false;
            localGetting?.complete(true);
            localGetting = null;
            notifyListeners();
            return false;
          }
          final List<AssetEntity> entities = await newpath!
              .getAssetListRange(start: offset, end: offset + pageSize);
          if (entities.length < pageSize) {
            localHasMore = false;
          }
          offset += entities.length;
          for (var i = 0; i < entities.length; i++) {
            if (localGettingNeedBreak) {
              localGettingNeedBreak = false;
              localGetting?.complete(true);
              localGetting = null;
              notifyListeners();
              return false;
            }
            if (_localAssetIds.contains(entities[i].id)) {
              continue; // 彻底去重，同一物理文件绝不二次入列
            }
            _localAssetIds.add(entities[i].id);
            final asset = Asset(local: entities[i]);
            if (settingModel.localFolderAbsPath == null) {
              final file = await entities[i].originFile;
              if (file != null) {
                settingModel.localFolderAbsPath = file.parent.path;
              }
            }
            // asset.getLocalFile();
            localAssets.add(asset);
          }
          localAssets.sort(Asset.compareByDateDesc);
          notifyListeners();
          if (!localHasMore) {
            eventBus.fire(FinishGettingLocal());
            break;
          }
        }
        break; // 只要匹配到选定的本地相册，处理完毕立即退出循环，避免扫描到系统多重同名 bucket
      }
    }

    localGetting?.complete(true);
    localGetting = null;
    notifyListeners();
    return true;
  }

  Future<bool> getRemotePhotos() async {
    await checkServer();
    if (remoteGetting != null) {
      await remoteGetting!.future;
      return false;
    }
    remoteGetting = Completer<bool>();
    notifyListeners();
    logger.debug("start getting remote assets");
    try {
      while (remoteHasMore) {
        if (remoteGettingNeedBreak) {
          remoteGettingNeedBreak = false;
          remoteGetting?.complete(true);
          remoteGetting = null;
          notifyListeners();
          return false;
        }
        final offset = remoteAssets.length;
        final sw = Stopwatch()..start();
        final List<RemoteImage> images =
            await storageClient.listImages("", offset, pageSize, album: currentCloudAlbum);
        // 每页一条即可，只在 DEBUG（详细日志 / 调试模式）下落盘
        logger.debug('remote list: offset=$offset got=${images.length} '
            'cost=${sw.elapsedMilliseconds}ms');
        if (images.length < pageSize) {
          remoteHasMore = false;
        }
        for (var i = 0; i < images.length; i++) {
          try {
            final asset = Asset(remote: images[i]);
            remoteAssets.add(asset);
          } catch (e) {
            logger.error(e.toString());
          }
        }
        remoteAssets.sort(Asset.compareByDateDesc);
        notifyListeners();
      }
    } catch (e) {
      remoteLastError = e.toString();
    }
    if (!remoteHasMore) {
      eventBus.fire(FinishGettingRemote());
    }
    remoteGetting?.complete(true);
    remoteGetting = null;
    remoteGettingNeedBreak = false;
    notifyListeners();
    return true;
  }

  void removeLocalAsset(Asset asset) {
    localAssets.remove(asset);
    notifyListeners();
  }

  void removeLocalAssetsByIDs(List<String> ids) {
    localAssets.removeWhere((element) => ids.contains(element.local!.id));
    notifyListeners();
  }

  void removeRemoteAsset(Asset asset) {
    remoteAssets.remove(asset);
    notifyListeners();
  }
}

Future<String?> findLocalIDByAsset(Asset a) async {
  if (a.hasLocal) {
    return a.local!.id;
  }
  final oName = await a.originName();
  for (var asset in assetModel.localAssets) {
    final name = await asset.originName();
    if (name == oName) {
      return asset.local!.id;
    }
  }
  return null;
}

Future<void> scanFile(String filePath) async {
  if (Platform.isAndroid) {
    try {
      final directory = await getExternalStorageDirectory();
      final path = directory?.path ?? '';
      final mimeType = lookupMimeType(filePath);
      final Map<String, dynamic> params = {
        'path': filePath,
        'volumeName': 'external_primary',
        'relativePath': filePath.replaceFirst('$path/', ''),
        'mimeType': mimeType,
      };

      await const MethodChannel('com.example.img_syncer/RunGrpcServer')
          .invokeMethod('scanFile', params);
    } on PlatformException catch (e) {
      logger.addLog('Failed to scan file $filePath: ${e.message}');
    }
  }
}

/// 一次 FilterNotUploaded 流式调用的累计统计，用于汇总成一条 INFO 日志
class FilterNotUploadedStats {
  int uploaded = 0;
  int notUploaded = 0;
  String? lastMessage;
}

Future<void> refreshUnsynchronizedPhotos() async {
  if (assetModel.localGetting != null) {
    await assetModel.localGetting!.future;
  }
  await checkServer();
  if (!settingModel.isRemoteStorageSetted) {
    // 不等于「远端没有任何已上传照片」：冷启动时 initDrive() 是异步的，
    // isRemoteStorageSetted 可能还是 false。这里清空会把持久化的 synced_ids
    // 在每次启动时抹掉，导致已上传的照片被重新上传。保持已知状态不动。
    return;
  }
  final re = await requestPermission();
  if (!re) return;
  if (stateModel.refreshingUnsynchronized) {
    return;
  }
  logger.debug("refresh unsynchronized photos");
  stateModel.setRefreshingUnsynchronized(true);
  stateModel.updateLastRefreshUnsyncTime(null);
  final requests = StreamController<FilterNotUploadedRequest>();
  final responses = storageClient.cli.filterNotUploaded(requests.stream);
  // W7-T1: 两阶段提交 - 先积累新ID，成功后一次性替换，避免中断时丢失
  final List<String> newSyncedIDs = [];
  final sw = Stopwatch()..start();
  final stats = FilterNotUploadedStats();
  await Future.wait([
    sendFilterNotUploadedRequests(requests),
    receiveResponses(responses, accumulatedIDs: newSyncedIDs, stats: stats),
  ]);
  logger.info('filter: uploaded=${stats.uploaded} '
      'notUploaded=${stats.notUploaded} cost=${sw.elapsedMilliseconds}ms');
  if (stats.lastMessage != null) {
    // 服务端诊断文本，如 `manifest_hits=9 fallback_scan=true healed=1 cost=87ms`
    logger.info('filter msg: ${stats.lastMessage}');
  }

  // 未被中断
  if (!assetModel.refreshUnsynchronizedNeedBreak) {
    // W7-T2: newSyncedIDs 只覆盖当前本地相册里的照片，直接替换会把别的相册
    // 已知的已上传 ID 抹掉（切相册后重复上传），因此与已有集合合并去重。
    final merged = {...stateModel.syncedIDs, ...newSyncedIDs};
    stateModel.setSyncedPhotos(merged.toList());
    await stateModel.saveSyncedIDs();
    stateModel.updateLastRefreshUnsyncTime(DateTime.now());
  }
  assetModel.refreshUnsynchronizedNeedBreak = false;
  stateModel.setRefreshingUnsynchronized(false);
}

Future<void> sendFilterNotUploadedRequests(
    StreamController<FilterNotUploadedRequest> requests) async {
  var photos = List<FilterNotUploadedRequestInfo>.empty(growable: true);
  for (var asset in assetModel.localAssets) {
    if (assetModel.refreshUnsynchronizedNeedBreak) {
      await requests.close();
      return;
    }
    var date = asset.local!.createDateTime;
    if (date.isBefore(DateTime(1990, 1, 1))) {
      date = asset.local!.modifiedDateTime;
    }
    late String name;
    name = await asset.name();
    final dateStr =
        formatDate(date, [yyyy, ':', mm, ':', dd, ' ', HH, ':', nn, ':', ss]);
    photos.add(FilterNotUploadedRequestInfo(
      id: asset.local!.id,
      name: name,
      date: dateStr,
    ));
    if (photos.length >= 100) {
      requests.add(FilterNotUploadedRequest(photos: photos));
      photos.clear();
    }
  }
  if (photos.isNotEmpty) {
    requests.add(FilterNotUploadedRequest(photos: photos));
  }
  await requests.close();
}

Future<void> receiveResponses(
    Stream<FilterNotUploadedResponse> responses,
    {List<String>? accumulatedIDs, FilterNotUploadedStats? stats}) async {
  await for (var response in responses) {
    if (!response.success) {
      logger.error('Error: ${response.message}');
      SnackBarManager.showSnackBar("Error: ${response.message}");
      continue;
    }
    if (accumulatedIDs != null) {
      // W7-T1: 两阶段提交 - 仅积累，不立即写入
      accumulatedIDs.addAll(response.uploadedIDs);
    } else {
      // W7-T2: Set 去重
      final merged = {...stateModel.syncedIDs, ...response.uploadedIDs}.toList();
      stateModel.setSyncedPhotos(merged);
    }
    // 使用新字段名，兼容旧字段名
    final ids = response.notUploadedIDs.isEmpty
        ? response.notUploaedIDs
        : response.notUploadedIDs;
    if (stats != null) {
      stats.uploaded += response.uploadedIDs.length;
      stats.notUploaded += ids.length;
      if (response.message.isNotEmpty) stats.lastMessage = response.message;
    }
    // 每批 100 条就会回一帧，逐帧落盘会刷屏：只在 DEBUG 下写
    logger.debug('filter batch: uploaded=${response.uploadedIDs.length} '
        'notUploaded=${ids.length}');
  }
}

Future<void> loadUnsynchronizedPhotos() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('synced_ids');
  if (jsonString != null) {
    final cache = jsonDecode(jsonString);
    List<String> newList = [];
    for (var id in cache) {
      newList.add(id);
    }
    stateModel.setSyncedPhotos(newList);
  }
}

/// 把待检查的照片按每批 100 条写入过滤请求流（仅用于 [StateModel.checkRemoteUploaded]）
/// 名字走 [Asset.name]（有 titleCache），不要用 titleAsync：
/// iOS 上逐条 PhotoKit 取名字会把 10s 预算全耗在本地。
Future<void> sendUploadedCheckRequests(
    StreamController<FilterNotUploadedRequest> requests,
    List<Asset> assets) async {
  var photos = List<FilterNotUploadedRequestInfo>.empty(growable: true);
  for (var asset in assets) {
    photos.add(await _createFilterNotUploadedRequestInfo(asset));
    if (photos.length >= 100) {
      requests.add(FilterNotUploadedRequest(photos: photos));
      photos = List<FilterNotUploadedRequestInfo>.empty(growable: true);
    }
  }
  if (photos.isNotEmpty) {
    requests.add(FilterNotUploadedRequest(photos: photos));
  }
  await requests.close();
}

/// 收集远端回传的已上传 ID（不写入全局 stateModel.syncedIDs）
Future<void> collectUploadedIDs(
    Stream<FilterNotUploadedResponse> responses, Set<String> out) async {
  await for (var response in responses) {
    if (!response.success) {
      logger.error('Error: ${response.message}');
      continue;
    }
    out.addAll(response.uploadedIDs);
  }
}

Future<FilterNotUploadedRequestInfo> _createFilterNotUploadedRequestInfo(
    Asset asset) async {
  final local = asset.local!;
  var date = local.createDateTime;
  if (date.isBefore(DateTime(1990, 1, 1))) {
    date = local.modifiedDateTime;
  }
  final dateStr =
      formatDate(date, [yyyy, ':', mm, ':', dd, ' ', HH, ':', nn, ':', ss]);
  return FilterNotUploadedRequestInfo(
    id: local.id,
    name: await asset.name(),
    date: dateStr,
  );
}
