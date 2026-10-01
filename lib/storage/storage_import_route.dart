import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';
import 'package:img_syncer/storage/storage_config.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// 存储配置导入页：支持摄像头扫码、相册选图识别、剪贴板读取与手动粘贴
class StorageImportRoute extends StatefulWidget {
  const StorageImportRoute({super.key});

  @override
  State<StorageImportRoute> createState() => _StorageImportRouteState();
}

class _StorageImportRouteState extends State<StorageImportRoute> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // 页面打开时自动检测剪贴板是否已有 Pho 配置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkClipboardAuto();
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _checkClipboardAuto() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      if (text.startsWith('pho://storage') || text.contains('"pho_storage_config"')) {
        final config = StorageConfig.decode(text);
        if (config != null && mounted) {
          _confirmAndApply(config, fromClipboardAuto: true);
        }
      }
    } catch (_) {}
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final config = StorageConfig.decode(raw);
        if (config != null) {
          _isProcessing = true;
          HapticFeedback.mediumImpact();
          _confirmAndApply(config);
          break;
        }
      }
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path != null) {
        final capture = await _scannerController.analyzeImage(path);
        if (capture != null && capture.barcodes.isNotEmpty) {
          for (final barcode in capture.barcodes) {
            final raw = barcode.rawValue;
            if (raw != null) {
              final config = StorageConfig.decode(raw);
              if (config != null && mounted) {
                _confirmAndApply(config);
                return;
              }
            }
          }
        }
        if (mounted) {
          SnackBarManager.showSnackBar(l10n.invalidConfig);
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarManager.showSnackBar('识别失败: $e');
      }
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text == null || text.isEmpty) {
        SnackBarManager.showSnackBar(l10n.clipboardEmpty);
        return;
      }
      final config = StorageConfig.decode(text);
      if (config != null) {
        _confirmAndApply(config);
      } else {
        SnackBarManager.showSnackBar(l10n.invalidConfig);
      }
    } catch (e) {
      SnackBarManager.showSnackBar('读取剪贴板失败: $e');
    }
  }

  void _showManualPasteDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.pasteConfig),
          content: TextField(
            controller: textController,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.pasteHint,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final raw = textController.text.trim();
                Navigator.pop(context);
                final config = StorageConfig.decode(raw);
                if (config != null) {
                  _confirmAndApply(config);
                } else {
                  SnackBarManager.showSnackBar(l10n.invalidConfig);
                }
              },
              child: Text(l10n.yes),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmAndApply(StorageConfig config, {bool fromClipboardAuto = false}) async {
    _isProcessing = true;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final shouldImport = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool testing = false;
        String? testError;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.importConfigConfirmTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fromClipboardAuto)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.paddingSmall),
                        margin: const EdgeInsets.only(bottom: AppSpacing.paddingSmall),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          '从剪贴板检测到配置',
                          style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimaryContainer),
                        ),
                      ),
                    Text('存储类型: ${driveName[config.drive] ?? ""}', style: textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text('服务器: ${config.summary}', style: textTheme.bodyMedium),
                    if (config.username != null && config.username!.isNotEmpty)
                      Text('用户名: ${config.username}', style: textTheme.bodyMedium),
                    if (config.rootPath != null && config.rootPath!.isNotEmpty)
                      Text('根路径: ${config.rootPath}', style: textTheme.bodyMedium),
                    if (testError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.paddingSmall),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.small),
                        ),
                        child: Text(
                          '${l10n.configImportFailed}: $testError',
                          style: textTheme.bodySmall?.copyWith(color: colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                    if (testing) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: testing ? null : () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: testing
                      ? null
                      : () async {
                          setDialogState(() {
                            testing = true;
                            testError = null;
                          });

                          final error = await config.testConnection();
                          if (error != null) {
                            setDialogState(() {
                              testing = false;
                              testError = error;
                            });
                          } else {
                            await config.saveToPrefsAndApply();
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                          }
                        },
                  child: Text(l10n.testAndSave),
                ),
              ],
            );
          },
        );
      },
    );

    _isProcessing = false;
    if (shouldImport == true && mounted) {
      SnackBarManager.showSnackBar(l10n.configImportSuccess);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scanStorageConfig),
        actions: [
          IconButton(
            tooltip: '切换闪光灯',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
          ),
          IconButton(
            tooltip: '翻转摄像头',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _scannerController.switchCamera(),
          ),
          IconButton(
            tooltip: l10n.pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: _pickImageFromGallery,
          ),
        ],
      ),
      body: Column(
        children: [
          // 上半部分：摄像头扫码视图
          Expanded(
            flex: 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                // 扫码取景框装饰
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 2.5),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
              ],
            ),
          ),

          // 下半部分：文本与剪贴板快捷导入入口
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.paddingLarge),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.large)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '对准另一台设备的 Pho 存储配置二维码即可自动识别',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.paste, size: 18),
                          label: Text(l10n.importFromClipboard),
                          onPressed: _importFromClipboard,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: Text(l10n.pasteConfig),
                          onPressed: _showManualPasteDialog,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
