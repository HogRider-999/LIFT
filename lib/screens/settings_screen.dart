// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

// ⭐️ 引入格式化套件
import 'package:intl/intl.dart';
// ⭐️ 引入分享與路徑套件
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/app_theme.dart';
import '../services/unit_service.dart';
import '../services/lang_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _units = UnitService();
  final _lang = LangService();

  @override
  void initState() {
    super.initState();
    _units.addListener(_update);
    _lang.addListener(_update);
  }

  @override
  void dispose() {
    _units.removeListener(_update);
    _lang.removeListener(_update);
    super.dispose();
  }

  void _update() => setState(() {});

  // ⭐️ 分享檔案備份 (雲端同步)
  Future<void> _exportBackupFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      Map<String, String> allData = {};

      for (var k in keys) {
        allData[k] = prefs.get(k).toString();
      }
      final jsonStr = jsonEncode(allData);

      // 建立暫存檔
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/LIFT_Backup_${DateFormat('yyyyMMdd').format(DateTime.now())}.lift');
      await file.writeAsString(jsonStr);

      // ⭐️ 喚起原生分享介面 (新的安全寫法)
      await Share.shareXFiles([XFile(file.path)], text: 'LIFT App Data Backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Export Failed'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  // ⭐️ 貼上代碼還原所有資料
  Future<void> _importBackup() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_lang.t('RESTORE DATA'),
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: _lang.t('Paste code here...'),
            hintStyle: const TextStyle(color: AppTheme.border),
            filled: true,
            fillColor: AppTheme.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_lang.t('CANCEL'),
                  style: const TextStyle(color: AppTheme.textSecondary))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(_lang.t('IMPORT'),
                  style: const TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (code != null && code.isNotEmpty) {
      try {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(base64Decode(code)));
        final prefs = await SharedPreferences.getInstance();

        // 寫入所有資料
        for (var key in data.keys) {
          await prefs.setString(key, data[key].toString());
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lang.t('Import Successful!')),
              backgroundColor: AppTheme.accent,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lang.t('Invalid Code')),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(_lang.t('PREFERENCES')),
        const SizedBox(height: 12),
        _buildSettingTile(
          title: _lang.t('UNIT'),
          subtitle: !_units.useLbs ? 'Kilograms (KG)' : 'Pounds (LBS)',
          icon: Icons.monitor_weight_outlined,
          trailing: _buildToggle(
            left: 'KG',
            right: 'LBS',
            isLeft: !_units.useLbs,
            onTap: () {
              HapticFeedback.selectionClick();
              _units.setUnit(!_units.useLbs);
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildSettingTile(
          title: _lang.t('LANGUAGE'),
          subtitle: _lang.isEn ? 'English' : '繁 體 中 文',
          icon: Icons.language,
          trailing: _buildToggle(
            left: 'EN',
            right: '繁中',
            isLeft: _lang.isEn,
            onTap: () {
              HapticFeedback.selectionClick();
              _lang.toggleLang();
            },
          ),
        ),

        // ⭐️ 新增的資料管理區塊
        const SizedBox(height: 40),
        _buildSectionHeader('DATA MANAGEMENT'),
        const SizedBox(height: 12),

        // ⭐️ 綁定分享檔案的方法
        _buildActionTile(
          title: _lang.t('SHARE BACKUP FILE'),
          subtitle: _lang.t('BACKUP DATA'),
          icon: Icons.cloud_upload_outlined,
          onTap: _exportBackupFile,
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          title: _lang.t('IMPORT ALL'),
          subtitle: _lang.t('RESTORE DATA'),
          icon: Icons.download_rounded,
          iconColor: AppTheme.danger,
          onTap: () async {
            final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                      backgroundColor: AppTheme.card,
                      title: Text(_lang.t('RESTORE DATA'),
                          style: const TextStyle(
                              color: AppTheme.danger,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      content: const Text(
                          'This will overwrite all current data. Are you sure?',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(_lang.t('CANCEL'),
                                style: const TextStyle(
                                    color: AppTheme.textSecondary))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('OVERWRITE',
                                style: TextStyle(
                                    color: AppTheme.danger,
                                    fontWeight: FontWeight.bold))),
                      ],
                    ));
            if (confirm == true) {
              _importBackup();
            }
          },
        ),

        const SizedBox(height: 40),
        _buildSectionHeader(_lang.t('SYSTEM')),
        const SizedBox(height: 12),
        _buildInfoTile(_lang.t('APP VERSION'), 'LIFT v3.0 (Tactical)'),
        const SizedBox(height: 12),
        _buildInfoTile(
          _lang.t('STATUS'),
          'ALL SYSTEMS NOMINAL',
          color: AppTheme.accent,
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppTheme.textSecondary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String val, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          Text(
            val,
            style: TextStyle(
              color: color ?? AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle({
    required String left,
    required String right,
    required bool isLeft,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 50,
                decoration: BoxDecoration(
                  // ⭐️ 修復了 withOpacity 警告的問題
                  color: AppTheme.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accent),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      left,
                      style: TextStyle(
                        color:
                            isLeft ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      right,
                      style: TextStyle(
                        color:
                            !isLeft ? AppTheme.accent : AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
