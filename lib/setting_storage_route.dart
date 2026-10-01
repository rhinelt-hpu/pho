import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
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

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      final drive = prefs.getString("drive");
      if (drive != null) {
        setState(() {
          currentDrive = getDrive(drive);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    late Widget form;
    switch (currentDrive) {
      case Drive.smb:
        form = const SMBForm();
        break;
      case Drive.webDav:
        form = const WebDavForm();
        break;
      case Drive.nfs:
        form = const NFSForm();
        break;
      // TODO(open-source): 补齐更多云存储类型 (原会员功能，待开源实现):
      // case Drive.baiduNetdisk:
      //   form = const BaiduNetdiskForm(); // 百度网盘 OAuth 授权与存储表单
      //   break;
      default:
        form = const Text('Not implemented');
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingLarge,
                vertical: AppSpacing.paddingSmall),
            child: TextField(
              readOnly: true,
              controller: TextEditingController(
                  text: driveName[currentDrive]),
              decoration: InputDecoration(
                  labelText: l10n.remoteStorageType,
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
                    onSelected: (String value) => setState(() {
                      currentDrive = getDrive(value);
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setString("drive", value);
                      });
                    }),
                  )),
            ),
          ),
          const Divider(height: 15),
          form,
        ],
      ),
    );
  }
}
