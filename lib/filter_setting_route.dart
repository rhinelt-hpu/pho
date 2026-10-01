import 'package:date_format/date_format.dart';
import 'package:flutter/material.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/state_model.dart';

/// 文件筛选器设置页
class FilterSettingRoute extends StatefulWidget {
  const FilterSettingRoute({super.key});

  @override
  FilterSettingRouteState createState() => FilterSettingRouteState();
}

class FilterSettingRouteState extends State<FilterSettingRoute> {
  final _formatTextController = TextEditingController();

  static const List<String> commonExtensions = [
    '.gif',
    '.heic',
    '.raw',
    '.png',
    '.jpg',
    '.mp4',
    '.mov',
  ];

  @override
  void initState() {
    super.initState();
    settingModel.addListener(_onSettingChanged);
  }

  @override
  void dispose() {
    settingModel.removeListener(_onSettingChanged);
    _formatTextController.dispose();
    super.dispose();
  }

  void _onSettingChanged() {
    if (mounted) setState(() {});
  }

  String _formatDate(DateTime dt) {
    return formatDate(dt, [yyyy, '-', mm, '-', dd]);
  }

  Future<void> _pickDate({required bool isAfter}) async {
    final now = DateTime.now();
    final initial = isAfter
        ? (settingModel.filterAfter ?? now)
        : (settingModel.filterBefore ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      if (isAfter) {
        settingModel.setFilterAfter(DateTime(picked.year, picked.month, picked.day));
      } else {
        settingModel.setFilterBefore(DateTime(picked.year, picked.month, picked.day));
      }
    }
  }

  void _showAddFormatDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.filterFormatGroup),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'e.g. .webp, .dng, .avi',
              labelText: '扩展名 (Extension)',
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
                if (raw.isNotEmpty) {
                  final ext = raw.startsWith('.') ? raw.toLowerCase() : '.$raw'.toLowerCase();
                  settingModel.setFilterType(ext, false);
                }
                Navigator.pop(context);
              },
              child: Text(l10n.yes),
            ),
          ],
        );
      },
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.filterReset),
        content: Text(l10n.filterResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              settingModel.resetFilters();
              Navigator.pop(context);
            },
            child: Text(l10n.yes),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // 聚合常见格式与用户自定义格式
    final Set<String> allExts = {
      ...commonExtensions,
      ...settingModel.filterTypeMap.keys,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fileFilter),
        actions: [
          IconButton(
            tooltip: l10n.filterReset,
            icon: const Icon(Icons.restart_alt),
            onPressed: _showResetConfirmDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingSmall),
        children: [
          SwitchListTile(
            secondary: Icon(
              Icons.filter_alt,
              color: settingModel.filterSwitch ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(l10n.filterSwitchTitle, style: textTheme.titleMedium),
            subtitle: Text(l10n.filterSwitchDesc),
            value: settingModel.filterSwitch,
            onChanged: (val) => settingModel.setFilterSwitch(val),
          ),
          const Divider(),
          if (!settingModel.filterSwitch)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.paddingLarge),
              child: Center(
                child: Text(
                  '筛选器未启用，同步将包含所有照片与视频',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            // 1. 媒体类型过滤
            _buildSectionHeader(l10n.filterMediaGroup),
            SwitchListTile(
              secondary: const Icon(Icons.videocam_off_outlined),
              title: Text(l10n.filterNoVideoTitle),
              subtitle: Text(l10n.filterNoVideoSubtitle),
              value: settingModel.filterNoVideo,
              onChanged: (val) => settingModel.setFilterNoVideo(val),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.image_not_supported_outlined),
              title: Text(l10n.filterNoImageTitle),
              subtitle: Text(l10n.filterNoImageSubtitle),
              value: settingModel.filterNoImage,
              onChanged: (val) => settingModel.setFilterNoImage(val),
            ),
            const Divider(),

            // 2. 拍摄日期过滤
            _buildSectionHeader(l10n.filterDateGroup),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: Text(l10n.filterAfterTitle),
              subtitle: Text(
                settingModel.filterAfter != null
                    ? '${l10n.filterAfterDesc} (${_formatDate(settingModel.filterAfter!)})'
                    : l10n.filterNotSet,
              ),
              trailing: settingModel.filterAfter != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => settingModel.setFilterAfter(null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _pickDate(isAfter: true),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.filterBeforeTitle),
              subtitle: Text(
                settingModel.filterBefore != null
                    ? '${l10n.filterBeforeDesc} (${_formatDate(settingModel.filterBefore!)})'
                    : l10n.filterNotSet,
              ),
              trailing: settingModel.filterBefore != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => settingModel.setFilterBefore(null),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: () => _pickDate(isAfter: false),
            ),
            const Divider(),

            // 3. 扩展名黑名单
            _buildSectionHeader(l10n.filterFormatGroup),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.paddingLarge,
                vertical: AppSpacing.paddingSmall,
              ),
              child: Text(
                l10n.filterFormatDesc,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLarge),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...allExts.map((ext) {
                    final isExcluded = settingModel.filterTypeMap[ext] == false;
                    return FilterChip(
                      selected: isExcluded,
                      selectedColor: colorScheme.errorContainer,
                      checkmarkColor: colorScheme.onErrorContainer,
                      label: Text(
                        isExcluded ? '排除 $ext' : ext,
                        style: TextStyle(
                          color: isExcluded ? colorScheme.onErrorContainer : null,
                          decoration: isExcluded ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      onSelected: (selected) {
                        settingModel.setFilterType(ext, !selected);
                      },
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('添加格式'),
                    onPressed: _showAddFormatDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.paddingLarge),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.paddingLarge,
        AppSpacing.paddingStandard,
        AppSpacing.paddingLarge,
        AppSpacing.paddingSmall,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
