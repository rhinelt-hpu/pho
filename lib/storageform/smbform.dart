import 'package:flutter/material.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/proto/img_syncer.pbgrpc.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/design_tokens.dart';

class SMBForm extends StatefulWidget {
  final bool isMetaDrive;
  final bool showActions;
  final VoidCallback? onChanged;

  const SMBForm({
    Key? key,
    this.isMetaDrive = false,
    this.showActions = true,
    this.onChanged,
  }) : super(key: key);

  @override
  SMBFormState createState() => SMBFormState();
}

class SMBFormState extends State<SMBForm> {
  @protected
  final GlobalKey _formKey = GlobalKey<FormState>();
  TextEditingController? smbAddrController;
  TextEditingController? smbUsernameController;
  TextEditingController? smbPasswordController;
  TextEditingController? smbShareController;
  TextEditingController? smbRootPathController;
  bool testSuccess = false;
  String? errormsg;

  List<String> _optionShares = [];

  String currentPath = "";

  String get _prefix => widget.isMetaDrive ? 'meta_' : '';

  void _notifyChanged() {
    widget.onChanged?.call();
  }

  @override
  void initState() {
    super.initState();
    smbAddrController = TextEditingController()..addListener(_notifyChanged);
    smbUsernameController = TextEditingController()..addListener(_notifyChanged);
    smbPasswordController = TextEditingController()..addListener(_notifyChanged);
    smbShareController = TextEditingController()..addListener(_notifyChanged);
    smbRootPathController = TextEditingController()..addListener(_notifyChanged);
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final smbAddr = prefs.getString("${_prefix}addr");
      final smbUsername = prefs.getString("${_prefix}username");
      final smbPassword = prefs.getString("${_prefix}password");
      final smbShare = prefs.getString("${_prefix}share");
      final smbRootPath = prefs.getString("${_prefix}rootPath");
      smbAddrController!.text = smbAddr ?? "";
      smbUsernameController!.text = smbUsername ?? "";
      smbPasswordController!.text = smbPassword ?? "";
      smbShareController!.text = smbShare ?? "";
      smbRootPathController!.text = smbRootPath ?? "";

      smbShareController!.addListener(() {
        if (smbShare == smbShareController!.text) {
          return;
        }
        storage.cli.setDriveSMB(SetDriveSMBRequest(
          addr: smbAddr,
          username: smbUsername,
          password: smbPassword,
          share: smbShare,
          isMetaDrive: widget.isMetaDrive,
        ));
        smbRootPathController!.text = "";
      });
    });
  }

  Future<bool> refreshShare() async {
    final a = smbAddrController!.text;
    final u = smbUsernameController!.text;
    final p = smbPasswordController!.text;
    final rsp1 = await storage.cli.setDriveSMB(SetDriveSMBRequest(
      addr: a,
      username: u,
      password: p,
      isMetaDrive: widget.isMetaDrive,
    ));
    if (!rsp1.success) {
      setState(() {
        errormsg = rsp1.message;
      });
      return false;
    }
    final rsp2 = await storage.cli.listDriveSMBShares(
        ListDriveSMBSharesRequest(isMetaDrive: widget.isMetaDrive));
    if (!rsp2.success) {
      setState(() {
        errormsg = rsp2.message;
      });
      return false;
    }
    rsp2.shares.remove("IPC\$");
    setState(() {
      _optionShares = rsp2.shares;
    });
    return true;
  }

  Future<List<String>> getRootPath(String dir) async {
    final rsp = await storage.cli.listDriveSMBDir(ListDriveSMBDirRequest(
      share: smbShareController!.text,
      dir: dir,
      isMetaDrive: widget.isMetaDrive,
    ));
    if (!rsp.success) {
      setState(() {
        errormsg = rsp.message;
      });
      return [];
    }
    return rsp.dirs;
  }

  Widget input(
      String label, TextEditingController? c, void Function(String?)? onSaved) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
      child: TextFormField(
        controller: c,
        obscureText: false,
        onSaved: onSaved,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          labelText: label,
        ),
      ),
    );
  }

  Widget smbForm(BuildContext context) {
    List<Widget> children = [
      input(l10n.samvbaServerAddress, smbAddrController, null),
      input(l10n.username, smbUsernameController, null),
      input(l10n.password, smbPasswordController, null),
      Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
        child: TextFormField(
          controller: smbShareController,
          obscureText: false,
          enableInteractiveSelection: true,
          onSaved: null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.share,
            suffixIcon: IconButton(
              icon: const Icon(Icons.open_in_browser),
              onPressed: () => refreshShare().then((available) {
                if (!available) {
                  showErrorDialog(errormsg!);
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) => shareDialog(),
                  );
                }
              }),
            ),
          ),
        ),
      ),
      Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
        child: TextFormField(
          controller: smbRootPathController,
          obscureText: false,
          enableInteractiveSelection: true,
          onSaved: null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: l10n.rootPath,
            helperText: "eg: storage/photos (no '/' or '\\' at the start)",
            suffixIcon: smbShareController!.text == ""
                ? null
                : IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () => showDialog(
                      context: context,
                      builder: (BuildContext context) => rootPathDialog(),
                    ),
                  ),
          ),
        ),
      ),
      if (widget.showActions)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            testStorageButtun(),
            saveButtun(),
          ],
        ),
    ];
    return Form(
      key: _formKey,
      child: Column(
        children: children,
      ),
    );
  }

  Widget shareDialog() {
    return Dialog(
      child: SizedBox(
        height: 500,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
              child: Text(
                "Select share",
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Divider(
              indent: 20,
              endIndent: 20,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _optionShares.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    title: Text(_optionShares[index]),
                    onTap: () {
                      smbShareController!.text = _optionShares[index];
                      setState(() {
                        smbShareController!.text = _optionShares[index];
                        smbRootPathController!.text = "";
                      });
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
              child: Divider(
                indent: 20,
                endIndent: 20,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget rootPathDialog() {
    currentPath = "";

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Dialog(
          child: SizedBox(
            height: 500,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
                  child: Text(
                    "Select root path",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Current path: $currentPath",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Divider(
                  indent: 20,
                  endIndent: 20,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                FutureBuilder(
                  future: getRootPath(currentPath),
                  builder: (context, AsyncSnapshot<List<String>> snapshot) {
                    if (snapshot.hasData) {
                      return Expanded(
                        child: ListView.builder(
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            return InkWell(
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(25, 0, 25, 0),
                                height: 35,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  snapshot.data![index],
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              onTap: () {
                                setDialogState(() {
                                  if (currentPath == "") {
                                    currentPath = snapshot.data![index];
                                  } else {
                                    currentPath =
                                        "$currentPath/${snapshot.data![index]}";
                                  }
                                });
                              },
                            );
                          },
                        ),
                      );
                    } else {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                  child: Divider(
                    indent: 20,
                    endIndent: 20,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                      width: 120,
                      height: 55,
                      child: OutlinedButton(
                        child: const Text("Cancel"),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                      width: 120,
                      height: 55,
                      child: FilledButton(
                        child: const Text("Save"),
                        onPressed: () {
                          smbRootPathController!.text = currentPath;
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> validateAndTest() async {
    var form = _formKey.currentState as FormState;
    if (form.validate()) {
      form.save();
      if (smbAddrController!.text.trim().isEmpty ||
          smbShareController!.text.trim().isEmpty ||
          smbRootPathController!.text.trim().isEmpty) {
        setState(() {
          testSuccess = false;
          errormsg = "Address, share or root path is empty";
        });
        return errormsg;
      }
      try {
        SetDriveSMBResponse rsp =
            await storage.cli.setDriveSMB(SetDriveSMBRequest(
          addr: smbAddrController!.text.trim(),
          username: smbUsernameController!.text,
          password: smbPasswordController!.text,
          share: smbShareController!.text.trim(),
          root: smbRootPathController!.text.trim(),
          isMetaDrive: widget.isMetaDrive,
        ));
        if (rsp.success) {
          if (widget.isMetaDrive) {
            setState(() {
              testSuccess = true;
            });
            return null;
          }
          ListByDateResponse listRsp =
              await storage.cli.listByDate(ListByDateRequest());
          if (listRsp.success) {
            setState(() {
              testSuccess = true;
            });
            return null;
          } else {
            setState(() {
              testSuccess = false;
              errormsg = listRsp.message;
            });
            return errormsg;
          }
        } else {
          setState(() {
            testSuccess = false;
            errormsg = rsp.message;
          });
          return errormsg;
        }
      } catch (e) {
        setState(() {
          testSuccess = false;
          errormsg = e.toString();
        });
        return errormsg;
      }
    }
    return "Form validation failed";
  }

  Future<void> testStorage() async {
    await validateAndTest();
  }

  Future<String?> saveToPrefs([SharedPreferences? sharedPrefs]) async {
    final addr = smbAddrController!.text.trim();
    final share = smbShareController!.text.trim();
    final root = smbRootPathController!.text.trim();
    if (addr.isEmpty || share.isEmpty || root.isEmpty) {
      return "Address, share or root path is empty";
    }
    final prefs = sharedPrefs ?? await SharedPreferences.getInstance();
    await prefs.setString('${_prefix}addr', addr);
    await prefs.setString('${_prefix}username', smbUsernameController!.text);
    await prefs.setString('${_prefix}password', smbPasswordController!.text);
    await prefs.setString('${_prefix}share', share);
    await prefs.setString('${_prefix}rootPath', root);
    await prefs.setString('${_prefix}drive', driveName[Drive.smb]!);
    return null;
  }

  Widget testStorageButtun() {
    return Container(
      width: 180,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
      child: FilledButton.tonal(
        onPressed: () {
          testStorage().then((value) {
            if (testSuccess) {
              SnackBarManager.showSnackBar(l10n.testSuccess);
            } else {
              showErrorDialog(errormsg!);
            }
          });
        },
        child: Text(l10n.testStorage),
      ),
    );
  }

  Widget saveButtun() {
    return Container(
      width: 150,
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge, vertical: AppSpacing.paddingSmall),
      child: FilledButton(
        onPressed: testSuccess
            ? () async {
                final addr = smbAddrController!.text.trim();
                final share = smbShareController!.text.trim();
                final root = smbRootPathController!.text.trim();
                if (addr.isEmpty || share.isEmpty || root.isEmpty) {
                  showErrorDialog("Address, share or root path is empty");
                  return;
                }
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('addr', addr);
                await prefs.setString('username', smbUsernameController!.text);
                await prefs.setString('password', smbPasswordController!.text);
                await prefs.setString('share', share);
                await prefs.setString('rootPath', root);
                await prefs.setString('drive', driveName[Drive.smb]!);
                await initDrive();
                if (!settingModel.isRemoteStorageSetted) {
                  if (mounted) {
                    showErrorDialog(assetModel.remoteLastError ?? "Failed to set root path");
                  }
                  return;
                }
                assetModel.remoteLastError = null;
                eventBus.fire(RemoteRefreshEvent(refreshUnSync: true));
                if (mounted) {
                  Navigator.pop(context);
                }
              }
            : null,
        child: Text(l10n.save),
      ),
    );
  }

  void showErrorDialog(String msg) {
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

  @override
  Widget build(BuildContext context) {
    return smbForm(context);
  }
}
