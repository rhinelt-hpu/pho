import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:img_syncer/storage/storage_config.dart';
import 'package:img_syncer/storage/storage_export_dialog.dart';
import 'package:img_syncer/storage/storage_import_route.dart';
import 'package:img_syncer/storageform/smbform.dart';
import 'package:img_syncer/storageform/webdavform.dart';
import 'package:img_syncer/storageform/nfsform.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/global.dart';

class SettingStorageRoute extends StatefulWidget {
  const SettingStorageRoute({super.key});

  @override
  State<SettingStorageRoute> createState() => _SettingStorageRouteState();
}

class _SettingStorageRouteState extends State<SettingStorageRoute> {
  Key _bodyKey = UniqueKey();

  Future<void> _handleExport() async {
    final config = await StorageConfig.exportCurrent();
    if (config != null && mounted) {
      StorageExportDialog.show(context, config);
    } else if (mounted) {
      SnackBarManager.showSnackBar(l10n.noStorageConfigFound);
    }
  }

  Future<void> _handleImport() async {
    final imported = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const StorageImportRoute()),
    );
    if (imported == true && mounted) {
      setState(() {
        _bodyKey = UniqueKey(); // 刷新表单内容
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.storageSetting),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: l10n.exportConfig,
            onPressed: _handleExport,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: l10n.importConfig,
            onPressed: _handleImport,
          ),
        ],
      ),
      body: SettingStorageRouteBody(key: _bodyKey),
    );
  }
}

class SettingStorageRouteBody extends StatefulWidget {
  const SettingStorageRouteBody({super.key});

  @override
  SettingStorageRouteBodyState createState() => SettingStorageRouteBodyState();
}

class SettingStorageRouteBodyState extends State<SettingStorageRouteBody> {
  @protected
  Drive currentDrive = Drive.smb;

  @protected
  bool enableMetaStorage = false;

  @protected
  Drive currentMetaDrive = Drive.webDav;

  bool testSuccess = false;
  bool isRebuilding = false;

  final GlobalKey<SMBFormState> _primarySmbKey = GlobalKey<SMBFormState>();
  final GlobalKey<WebDavFormState> _primaryWebdavKey =
      GlobalKey<WebDavFormState>();
  final GlobalKey<NFSFormState> _primaryNfsKey = GlobalKey<NFSFormState>();

  final GlobalKey<SMBFormState> _metaSmbKey = GlobalKey<SMBFormState>();
  final GlobalKey<WebDavFormState> _metaWebdavKey =
      GlobalKey<WebDavFormState>();
  final GlobalKey<NFSFormState> _metaNfsKey = GlobalKey<NFSFormState>();

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final drive = prefs.getString("drive");
      final metaEnabled = prefs.getBool("meta_drive_enabled") ?? false;
      final metaDrive = prefs.getString("meta_drive");
      setState(() {
        if (drive != null) {
          currentDrive = getDrive(drive);
        }
        enableMetaStorage = metaEnabled;
        if (metaDrive != null) {
          currentMetaDrive = getDrive(metaDrive);
        }
      });
    });
  }

  void _markDirty() {
    if (testSuccess && mounted) {
      setState(() {
        testSuccess = false;
      });
    }
  }

  Future<String?> _testSingleSection({required bool isMeta}) async {
    final d = isMeta ? currentMetaDrive : currentDrive;
    switch (d) {
      case Drive.smb:
        final state =
            isMeta ? _metaSmbKey.currentState : _primarySmbKey.currentState;
        if (state == null) return "SMB form not ready";
        return await state.validateAndTest();
      case Drive.webDav:
        final state = isMeta
            ? _metaWebdavKey.currentState
            : _primaryWebdavKey.currentState;
        if (state == null) return "WebDAV form not ready";
        return await state.validateAndTest();
      case Drive.nfs:
        final state =
            isMeta ? _metaNfsKey.currentState : _primaryNfsKey.currentState;
        if (state == null) return "NFS form not ready";
        return await state.validateAndTest();
    }
  }

  Future<String?> _saveSingleSection(SharedPreferences prefs,
      {required bool isMeta}) async {
    final d = isMeta ? currentMetaDrive : currentDrive;
    switch (d) {
      case Drive.smb:
        final state =
            isMeta ? _metaSmbKey.currentState : _primarySmbKey.currentState;
        if (state == null) return "SMB form not ready";
        return await state.saveToPrefs(prefs);
      case Drive.webDav:
        final state = isMeta
            ? _metaWebdavKey.currentState
            : _primaryWebdavKey.currentState;
        if (state == null) return "WebDAV form not ready";
        return await state.saveToPrefs(prefs);
      case Drive.nfs:
        final state =
            isMeta ? _metaNfsKey.currentState : _primaryNfsKey.currentState;
        if (state == null) return "NFS form not ready";
        return await state.saveToPrefs(prefs);
    }
  }

  Future<void> _handleGlobalTest() async {
    final primaryErr = await _testSingleSection(isMeta: false);
    if (primaryErr != null) {
      setState(() => testSuccess = false);
      _showErrorDialog(primaryErr);
      return;
    }
    if (enableMetaStorage) {
      final metaErr = await _testSingleSection(isMeta: true);
      if (metaErr != null) {
        setState(() => testSuccess = false);
        _showErrorDialog("[${l10n.enableMetaStorage}] $metaErr");
        return;
      }
    }
    setState(() => testSuccess = true);
    SnackBarManager.showSnackBar(l10n.testSuccess);
  }

  Future<void> _handleGlobalSave() async {
    final prefs = await SharedPreferences.getInstance();
    final primaryErr = await _saveSingleSection(prefs, isMeta: false);
    if (primaryErr != null) {
      _showErrorDialog(primaryErr);
      return;
    }
    await prefs.setBool("meta_drive_enabled", enableMetaStorage);
    if (enableMetaStorage) {
      final metaErr = await _saveSingleSection(prefs, isMeta: true);
      if (metaErr != null) {
        _showErrorDialog(metaErr);
        return;
      }
    }
    await initDrive();
    if (!settingModel.isRemoteStorageSetted) {
      if (mounted) {
        _showErrorDialog(
            assetModel.remoteLastError ?? "Failed to initialize storage");
      }
      return;
    }
    assetModel.remoteLastError = null;
    eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
    if (mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleRebuildMetaAndThumbnails() async {
    if (isRebuilding) return;
    setState(() => isRebuilding = true);
    SnackBarManager.showSnackBar(l10n.rebuildingMetaAndThumbnails);
    try {
      // 1. 服务端扫描主存储重建 .manifest 与 .thumbnail/<album> 目录骨架
      final rsp = await storage.rebuildManifest();
      if (!rsp.success) {
        if (mounted) _showErrorDialog(rsp.message);
        return;
      }
      // 2. 客户端从手机本地相册快速补齐已同步照片的缩略图（不重传原图）
      int thumbCount = 0;
      final syncedSet = stateModel.syncedIDs.toSet();
      for (final asset in assetModel.localAssets) {
        final entity = asset.local;
        if (entity == null) continue;
        if (syncedSet.isEmpty || syncedSet.contains(entity.id)) {
          try {
            await storage.uploadThumbnailOnly(entity);
            thumbCount++;
          } catch (_) {}
        }
      }
      eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
      if (mounted) {
        SnackBarManager.showSnackBar(
            l10n.rebuildSuccess(rsp.recordCount, thumbCount));
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isRebuilding = false);
      }
    }
  }

  void _showErrorDialog(String msg) {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.connectFailed),
        content: Text(msg),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveForm(Drive d, {required bool isMeta}) {
    switch (d) {
      case Drive.smb:
        return SMBForm(
          key: isMeta ? _metaSmbKey : _primarySmbKey,
          isMetaDrive: isMeta,
          showActions: false,
          onChanged: _markDirty,
        );
      case Drive.webDav:
        return WebDavForm(
          key: isMeta ? _metaWebdavKey : _primaryWebdavKey,
          isMetaDrive: isMeta,
          showActions: false,
          onChanged: _markDirty,
        );
      case Drive.nfs:
        return NFSForm(
          key: isMeta ? _metaNfsKey : _primaryNfsKey,
          isMetaDrive: isMeta,
          showActions: false,
          onChanged: _markDirty,
        );
    }
  }

  Widget _buildDriveSelector({
    required String label,
    required Drive selectedDrive,
    required ValueChanged<Drive> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLarge,
          vertical: AppSpacing.paddingSmall),
      child: TextField(
        readOnly: true,
        controller: TextEditingController(text: driveName[selectedDrive]),
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: PopupMenuButton<String>(
            icon: const Icon(Icons.arrow_drop_down),
            itemBuilder: (BuildContext context) {
              return driveName.values
                  .map((String value) => PopupMenuItem<String>(
                        value: value,
                        child: Text(value),
                      ))
                  .toList();
            },
            onSelected: (String value) {
              onSelected(getDrive(value));
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDriveSelector(
            label: l10n.remoteStorageType,
            selectedDrive: currentDrive,
            onSelected: (d) {
              setState(() {
                currentDrive = d;
                testSuccess = false;
              });
              SharedPreferences.getInstance().then((prefs) {
                prefs.setString("drive", driveName[d]!);
              });
            },
          ),
          const Divider(height: 15),
          _buildDriveForm(currentDrive, isMeta: false),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingSmall),
            child: SwitchListTile(
              title: Text(l10n.enableMetaStorage),
              subtitle: Text(l10n.enableMetaStorageDesc),
              value: enableMetaStorage,
              onChanged: (val) {
                setState(() {
                  enableMetaStorage = val;
                  testSuccess = false;
                });
              },
            ),
          ),
          if (enableMetaStorage) ...[
            _buildDriveSelector(
              label: l10n.metaStorageType,
              selectedDrive: currentMetaDrive,
              onSelected: (d) {
                setState(() {
                  currentMetaDrive = d;
                  testSuccess = false;
                });
                SharedPreferences.getInstance().then((prefs) {
                  prefs.setString("meta_drive", driveName[d]!);
                });
              },
            ),
            const Divider(height: 15),
            _buildDriveForm(currentMetaDrive, isMeta: true),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 180,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingLarge,
                    vertical: AppSpacing.paddingSmall),
                child: FilledButton.tonal(
                  onPressed: _handleGlobalTest,
                  child: Text(l10n.testStorage),
                ),
              ),
              Container(
                width: 150,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.paddingLarge,
                    vertical: AppSpacing.paddingSmall),
                child: FilledButton(
                  onPressed: testSuccess ? _handleGlobalSave : null,
                  child: Text(l10n.save),
                ),
              ),
            ],
          ),
          if (settingModel.isRemoteStorageSetted) ...[
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingSmall),
              child: ListTile(
                leading: isRebuilding
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high_outlined),
                title: Text(l10n.rebuildMetaAndThumbnails),
                subtitle: Text(l10n.rebuildMetaAndThumbnailsDesc),
                onTap: isRebuilding ? null : _handleRebuildMetaAndThumbnails,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
