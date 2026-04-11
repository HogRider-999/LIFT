import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:io' show File;
import 'package:intl/intl.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/app_theme.dart';
import '../services/lang_service.dart';
import '../models/models.dart';
import '../services/recovery_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _lang = LangService();
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  NutritionLog _todayNutrition = NutritionLog(
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()), entries: []);
  List<ProgressPhoto> _photos = [];
  List<BodyMetric> _weightLogs = [];
  int _calorieTarget = 2000;
  bool _loading = true;

  List<MuscleReadiness> _readinessData = [];
  double _systemReadiness = 100.0;
  String? _selectedZone;

  final Map<String, List<String>> _zoneMap = {
    'CHEST': [Muscles.chest, Muscles.upperChest, Muscles.lowerChest],
    'BACK': [Muscles.lats, Muscles.rhomboids, Muscles.lowerBack],
    'SHOULDERS': [Muscles.frontDelt, Muscles.sideDelt, Muscles.rearDelt],
    'ARMS': [Muscles.biceps, Muscles.triceps],
    'CORE': [Muscles.core],
    'LEGS': [Muscles.quads, Muscles.hamstrings, Muscles.glutes, Muscles.calves],
  };

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _lang.addListener(_refresh);
  }

  @override
  void dispose() {
    _lang.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _calorieTarget = prefs.getInt('calorie_target') ?? 2000;

    final nStr = prefs.getString('nutri_$todayStr');
    if (nStr != null) {
      try {
        _todayNutrition = NutritionLog.fromJson(jsonDecode(nStr));
      } catch (e) {
        _todayNutrition = NutritionLog(date: todayStr, entries: []);
      }
    }

    final pStr = prefs.getString('progress_photos') ?? '[]';
    try {
      _photos = (jsonDecode(pStr) as List)
          .map((e) => ProgressPhoto.fromJson(e))
          .toList();
      _photos.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _photos = [];
    }

    final wStr = prefs.getString('weight_logs') ?? '[]';
    try {
      _weightLogs = (jsonDecode(wStr) as List)
          .map((e) => BodyMetric.fromJson(e))
          .toList();
      _weightLogs.sort((a, b) => b.date.compareTo(a.date));
    } catch (e) {
      _weightLogs = [];
    }

    final recoveryData = await RecoveryService().calculateGlobalReadiness();
    double total = 0;
    for (var m in recoveryData) total += m.readinessScore;
    _systemReadiness =
        recoveryData.isNotEmpty ? total / recoveryData.length : 100.0;
    _readinessData = recoveryData;

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveNutrition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'nutri_${_todayNutrition.date}', jsonEncode(_todayNutrition.toJson()));
    setState(() {});
  }

  Future<void> _saveData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
    setState(() {});
  }

  Color _fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  Color _getSystemColor(double score) {
    if (score >= 80) return AppTheme.accent;
    if (score >= 50) return AppTheme.gold;
    return AppTheme.danger;
  }

  // ─── 3D Scanner Section ───────────────────────────────────────────────────

  Widget _build3DScanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(_lang.t('BIO-RECOVERY SCANNER')),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              // ── Top HUD bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SYSTEM STATUS',
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
                                fontSize: 8,
                                letterSpacing: 2)),
                        Text('${_systemReadiness.toInt()}%',
                            style: TextStyle(
                                color: _getSystemColor(_systemReadiness),
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace')),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _getSystemColor(_systemReadiness)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _getSystemColor(_systemReadiness)
                                .withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _systemReadiness >= 80
                            ? 'READY TO TRAIN'
                            : _systemReadiness >= 50
                                ? 'RECOVERING'
                                : 'REST NEEDED',
                        style: TextStyle(
                          color: _getSystemColor(_systemReadiness),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Body + Zone selector ──
              SizedBox(
                height: 330,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: kIsWeb
                            ? IgnorePointer(
                                ignoring: true,
                                child: ModelViewer(
                                  key: const ValueKey('body_scan'),
                                  src: 'assets/human_body.glb',
                                  alt: 'Body scan',
                                  backgroundColor: Colors.transparent,
                                  autoRotate: true,
                                  rotationPerSecond: '25deg',
                                  cameraControls: false,
                                  disableZoom: true,
                                  disablePan: true,
                                  disableTap: true,
                                ),
                              )
                            : CustomPaint(
                                size: const Size(double.infinity, 260),
                                painter: _BodyPainter(
                                  zone: _selectedZone,
                                  readiness: _readinessData,
                                ),
                              ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('SELECT ZONE',
                                style: TextStyle(
                                    color:
                                        AppTheme.accent.withValues(alpha: 0.5),
                                    fontSize: 9,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            ..._zoneMap.keys.map((z) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _buildZoneBtn(z),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Zone detail panel ──
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: _selectedZone == null
                    ? Container(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text('AWAITING ZONE SELECTION',
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.5),
                                fontSize: 10,
                                letterSpacing: 1.5)),
                      )
                    : _buildZoneDetail(_selectedZone!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildZoneBtn(String zone) {
    final sel = _selectedZone == zone;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedZone = sel ? null : zone);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color:
              sel ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surface,
          border: Border.all(color: sel ? AppTheme.accent : AppTheme.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: sel
              ? [
                  BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Center(
          child: Text(
            _lang.t(zone),
            style: TextStyle(
              color: sel ? AppTheme.accent : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoneDetail(String zone) {
    final muscles = _zoneMap[zone] ?? [];
    final data =
        _readinessData.where((m) => muscles.contains(m.muscleName)).toList();

    return Container(
      key: ValueKey(zone),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_lang.t(zone)} — RECOVERY',
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5)),
              GestureDetector(
                onTap: () => setState(() => _selectedZone = null),
                child: const Icon(Icons.close,
                    color: AppTheme.textSecondary, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.isEmpty)
            const Text('FULLY RECOVERED',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold))
          else
            ...data.map((m) {
              final color = _fromHex(m.colorHex);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(m.muscleName.toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                        Text('${m.readinessScore.toInt()}%',
                            style: TextStyle(
                                color: color,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: m.readinessScore / 100,
                        minHeight: 5,
                        backgroundColor: AppTheme.bg,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── Weight Dashboard ─────────────────────────────────────────────────────

  Widget _buildWeightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(_lang.t('BODY WEIGHT')),
            GestureDetector(
              onTap: _showWeightLogDialog,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.add, color: AppTheme.accent, size: 14),
                  const SizedBox(width: 4),
                  Text('LOG',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_weightLogs.isEmpty)
          _buildEmptyCard('No weight recorded')
        else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CURRENT',
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.7),
                                fontSize: 9,
                                letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${_weightLogs.first.weight}',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace')),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 4, left: 4),
                                child: Text('kg',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 14)),
                              ),
                            ]),
                        Text(_weightLogs.first.date,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 10)),
                      ]),
                ),
                if (_weightLogs.first.bodyFat != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: Column(children: [
                      Text('BODY FAT',
                          style: TextStyle(
                              color: AppTheme.gold.withValues(alpha: 0.7),
                              fontSize: 8,
                              letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text('${_weightLogs.first.bodyFat}%',
                          style: const TextStyle(
                              color: AppTheme.gold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace')),
                    ]),
                  ),
              ],
            ),
          ),
          if (_weightLogs.length > 1) ...[
            const SizedBox(height: 8),
            _buildWeightChart(),
          ],
        ],
      ],
    );
  }

  Widget _buildWeightChart() {
    final recent = _weightLogs.take(7).toList().reversed.toList();
    final weights = recent.map((w) => w.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b) - 1;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 1;
    final range = maxW - minW;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: recent.asMap().entries.map((e) {
          final idx = e.key;
          final w = e.value;
          final isLast = idx == recent.length - 1;
          final barHeight = range > 0
              ? ((w.weight - minW) / range * 50).clamp(8.0, 60.0)
              : 30.0;
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isLast)
                Text('${w.weight}',
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 8,
                        fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: 14,
                height: barHeight,
                decoration: BoxDecoration(
                  color: isLast ? AppTheme.accent : AppTheme.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 4),
              Text(w.date.substring(5),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 7)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Nutrition Section ────────────────────────────────────────────────────

  Widget _buildNutritionSection() {
    final double prog = _calorieTarget > 0
        ? (_todayNutrition.totalCalories / _calorieTarget).clamp(0, 1)
        : 0;
    final int remain = _calorieTarget - _todayNutrition.totalCalories;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(_lang.t('NUTRITION')),
            GestureDetector(
              onTap: _showTDEEWizard,
              child: Row(children: [
                const Icon(Icons.auto_awesome, color: AppTheme.gold, size: 14),
                const SizedBox(width: 4),
                Text('TDEE',
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: prog,
                strokeWidth: 8,
                color: remain < 0 ? AppTheme.danger : AppTheme.accent,
                backgroundColor: AppTheme.surface,
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${_todayNutrition.totalCalories}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      fontFamily: 'monospace')),
              Text('kcal',
                  style: TextStyle(
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      fontSize: 9)),
            ]),
          ]),
          const SizedBox(width: 20),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(_lang.t('TARGET'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 9,
                        letterSpacing: 1.5)),
                Text('$_calorieTarget kcal',
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace')),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: remain >= 0
                        ? AppTheme.surface
                        : AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    remain >= 0
                        ? '$remain kcal left'
                        : '${remain.abs()} kcal OVER',
                    style: TextStyle(
                      color: remain >= 0
                          ? AppTheme.textSecondary
                          : AppTheme.danger,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ])),
        ]),
        const SizedBox(height: 20),
        // Macro bars
        Row(children: [
          _buildMacroBar(
              'P', _todayNutrition.totalProtein, const Color(0xFF4A9EFF)),
          const SizedBox(width: 8),
          _buildMacroBar(
              'C', _todayNutrition.totalCarbs, const Color(0xFFFF6B6B)),
          const SizedBox(width: 8),
          _buildMacroBar(
              'F', _todayNutrition.totalFat, const Color(0xFFFFD93D)),
        ]),
        const SizedBox(height: 16),
        // ─── 三個按鈕並排 ───
        Row(children: [
          Expanded(
              child: _buildNutritionBtn(
                  Icons.qr_code_scanner, _lang.t('SCAN'), _scanBarcode)),
          const SizedBox(width: 6),
          Expanded(
              child: _buildNutritionBtn(
                  Icons.document_scanner, _lang.t('LABEL'), _scanLabel)),
          const SizedBox(width: 6),
          Expanded(
              child: _buildNutritionBtn(Icons.add_circle_outline,
                  _lang.t('MANUAL'), _showManualDialog)),
        ]),
      ]),
    );
  }

  Widget _buildMacroBar(String label, int grams, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text('$grams g',
              style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildNutritionBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ]),
      ),
    );
  }

  // ─── Food Log ─────────────────────────────────────────────────────────────

  Widget _buildFoodLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(_lang.t("TODAY'S LOG")),
        const SizedBox(height: 10),
        if (_todayNutrition.entries.isEmpty)
          _buildEmptyCard('No food logged today')
        else
          ...(_todayNutrition.entries.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                Container(
                  width: 4,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      Text(
                          'P ${item.protein}g · C ${item.carbs}g · F ${item.fat}g',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppTheme.textSecondary,
                              fontFamily: 'monospace')),
                    ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${item.calories}',
                      style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace')),
                  Text('kcal',
                      style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          fontSize: 9)),
                ]),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _todayNutrition.entries.removeAt(i));
                    _saveNutrition();
                  },
                  child: Icon(Icons.remove_circle_outline,
                      color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      size: 18),
                ),
              ]),
            );
          })),
      ],
    );
  }

  // ─── Photos Section ───────────────────────────────────────────────────────

  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader(_lang.t('PROGRESS PHOTOS')),
            GestureDetector(
              onTap: _addPhoto,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.add_a_photo,
                      color: AppTheme.accent, size: 13),
                  const SizedBox(width: 4),
                  const Text('ADD',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_photos.isEmpty)
          _buildEmptyCard('No progress photos yet')
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 0.75),
            itemCount: _photos.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => _showFullScreenImage(_photos[i], i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(fit: StackFit.expand, children: [
                  kIsWeb
                      ? Image.network(_photos[i].path, fit: BoxFit.cover)
                      : Image.file(File(_photos[i].path), fit: BoxFit.cover),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4)),
                      child: Text(_photos[i].date.substring(5),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontFamily: 'monospace')),
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(title,
        style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5));
  }

  Widget _buildEmptyCard(String msg) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
          child: Text(msg,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12))),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────

  Future<void> _showWeightLogDialog() async {
    final weightC = TextEditingController();
    final fatC = TextEditingController();
    if (_weightLogs.isNotEmpty) {
      weightC.text = _weightLogs.first.weight.toString();
      if (_weightLogs.first.bodyFat != null)
        fatC.text = _weightLogs.first.bodyFat.toString();
    }
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(_lang.t('BODY WEIGHT'),
                  style: const TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.bold)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogField(weightC, '${_lang.t("WEIGHT")} (kg)'),
                _dialogField(fatC, 'Body Fat %'),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(_lang.t('CANCEL'),
                        style: const TextStyle(color: AppTheme.textSecondary))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(_lang.t('SAVE'),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold))),
              ],
            ));

    if (ok == true && weightC.text.isNotEmpty) {
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
      _weightLogs.removeWhere((w) => w.date == date);
      _weightLogs.insert(
          0,
          BodyMetric(
              date: date,
              weight: double.parse(weightC.text),
              bodyFat: double.tryParse(fatC.text)));
      _saveData('weight_logs', _weightLogs.map((e) => e.toJson()).toList());
    }
  }

  Future<void> _showTDEEWizard() async {
    bool isMale = true;
    final ageC = TextEditingController();
    final heightC = TextEditingController();
    final weightC = TextEditingController();
    double activity = 1.2;
    int goalMod = 0;
    if (_weightLogs.isNotEmpty)
      weightC.text = _weightLogs.first.weight.toString();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
          builder: (context, setSheet) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 24,
                    right: 24,
                    top: 24),
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        const Icon(Icons.auto_awesome,
                            color: AppTheme.gold, size: 18),
                        const SizedBox(width: 8),
                        Text(_lang.t('TDEE WIZARD'),
                            style: const TextStyle(
                                color: AppTheme.gold,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2)),
                      ]),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: _choiceBtn(isMale, _lang.t('MALE'),
                                () => setSheet(() => isMale = true))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _choiceBtn(!isMale, _lang.t('FEMALE'),
                                () => setSheet(() => isMale = false))),
                      ]),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _dialogField(ageC, _lang.t('AGE'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child:
                                _dialogField(heightC, _lang.t('HEIGHT (cm)'))),
                        const SizedBox(width: 10),
                        Expanded(child: _dialogField(weightC, 'KG')),
                      ]),
                      const SizedBox(height: 16),
                      _dropdownField<double>(
                        label: _lang.t('ACTIVITY'),
                        value: activity,
                        items: [
                          DropdownMenuItem(
                              value: 1.2, child: Text(_lang.t('Sedentary'))),
                          DropdownMenuItem(
                              value: 1.375,
                              child: Text(_lang.t('Light (1-2x/wk)'))),
                          DropdownMenuItem(
                              value: 1.55,
                              child: Text(_lang.t('Moderate (3-5x/wk)'))),
                          DropdownMenuItem(
                              value: 1.725,
                              child: Text(_lang.t('Heavy (6-7x/wk)'))),
                        ],
                        onChanged: (v) => setSheet(() => activity = v!),
                      ),
                      const SizedBox(height: 12),
                      _dropdownField<int>(
                        label: _lang.t('GOAL'),
                        value: goalMod,
                        items: [
                          DropdownMenuItem(
                              value: -300,
                              child: Text(_lang.t('Cut (Lose Fat)'))),
                          DropdownMenuItem(
                              value: 0, child: Text(_lang.t('Maintain'))),
                          DropdownMenuItem(
                              value: 300,
                              child: Text(_lang.t('Bulk (Build Muscle)'))),
                        ],
                        onChanged: (v) => setSheet(() => goalMod = v!),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.gold,
                              foregroundColor: Colors.black),
                          onPressed: () async {
                            if (ageC.text.isEmpty ||
                                heightC.text.isEmpty ||
                                weightC.text.isEmpty) return;
                            final w = double.parse(weightC.text);
                            final h = double.parse(heightC.text);
                            final a = double.parse(ageC.text);
                            final bmr = isMale
                                ? (10 * w + 6.25 * h - 5 * a + 5)
                                : (10 * w + 6.25 * h - 5 * a - 161);
                            final res = (bmr * activity + goalMod).round();
                            await _saveData('calorie_target', res);
                            setState(() => _calorieTarget = res);
                            Navigator.pop(ctx);
                          },
                          child: Text(_lang.t('CALCULATE'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5)),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ])),
              )),
    );
  }

  Widget _dropdownField<T>(
      {required String label,
      required T value,
      required List<DropdownMenuItem<T>> items,
      required void Function(T?) onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1)),
      const SizedBox(height: 6),
      DropdownButtonFormField<T>(
        value: value,
        dropdownColor: AppTheme.surface,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.border))),
        items: items,
        onChanged: onChanged,
      ),
    ]);
  }

  // ─── OCR Label Scanner ────────────────────────────────────────────────────

  Future<void> _scanLabel() async {
    // Web 不支援 ML Kit，直接跳手動輸入
    if (kIsWeb) {
      _showManualDialog();
      return;
    }

    try {
      final XFile? image =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
      if (image == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_lang.t('Scanning label...')),
            backgroundColor: AppTheme.accent,
            duration: const Duration(seconds: 5)));
      }

      final inputImage = InputImage.fromFilePath(image.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final parsed = _parseNutritionText(recognized.text);

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => _OcrConfirmDialog(
            parsed: parsed,
            lang: _lang,
            onConfirm: (entry) {
              setState(() => _todayNutrition.entries.add(entry));
              _saveNutrition();
            },
            uuid: _uuid,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_lang.t('Scan failed, please enter manually')),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 2)));
        _showManualDialog();
      }
    }
  }

  Map<String, double> _parseNutritionText(String text) {
    // 全形數字轉半形
    final normalized = text
        .replaceAll('，', ',')
        .replaceAll('。', '.')
        .replaceAllMapped(RegExp(r'[０-９]'),
            (Match m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFEE0));

    double? extract(List<String> keywords) {
      for (final kw in keywords) {
        final pattern =
            RegExp(kw + r'[^\d]{0,10}(\d+(?:\.\d+)?)', caseSensitive: false);
        final m = pattern.firstMatch(normalized);
        if (m != null) return double.tryParse(m.group(1)!);
      }
      return null;
    }

    return {
      'calories':
          extract(['熱量', 'Energy', 'Calories', 'Cal', 'kcal', 'Calorie']) ?? 0,
      'protein': extract(['蛋白質', 'Protein', 'Proteins']) ?? 0,
      'carbs': extract([
            '碳水化合物',
            '碳水',
            'Carbohydrate',
            'Carbohydrates',
            'Carbs',
            'Total Carb'
          ]) ??
          0,
      'fat': extract(['脂肪', 'Fat', 'Total Fat']) ?? 0,
    };
  }

  // ─── Barcode Scanner ──────────────────────────────────────────────────────

  Future<void> _scanBarcode() async {
    final String? code = await Navigator.push(
        context, MaterialPageRoute(builder: (c) => const AppBarcodeScanner()));
    if (code == null || code.isEmpty) return;

    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_lang.t("Searching...")} $code'),
          backgroundColor: AppTheme.accent));

    try {
      final res = await http.get(Uri.parse(
          'https://world.openfoodfacts.org/api/v0/product/$code.json'));
      final data = jsonDecode(res.body);
      if (data['status'] == 1 && mounted) {
        final prod = data['product'];
        final n = prod['nutriments'];
        double cal =
            (n['energy-kcal_100g'] ?? n['energy-kcal'] ?? 0).toDouble();
        if (cal > 0) {
          setState(() => _todayNutrition.entries.add(FoodEntry(
              id: _uuid.v4(),
              name: prod['product_name'] ?? 'Unknown',
              calories: cal.round(),
              protein: (n['proteins_100g'] ?? 0).round(),
              carbs: (n['carbohydrates_100g'] ?? 0).round(),
              fat: (n['fat_100g'] ?? 0).round())));
          _saveNutrition();
          if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showManualDialog();
      }
    } catch (e) {
      if (mounted) _showManualDialog();
    }
  }

  Future<void> _showManualDialog({String? prefilledName}) async {
    final nameC = TextEditingController(text: prefilledName ?? '');
    final calC = TextEditingController();
    final pC = TextEditingController();
    final cC = TextEditingController();
    final fC = TextEditingController();

    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: AppTheme.card,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text(_lang.t('MANUAL LOG'),
                  style: const TextStyle(
                      color: AppTheme.accent, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogField(nameC, _lang.t('FOOD NAME'), isNum: false),
                _dialogField(calC, _lang.t('CALORIES')),
                Row(children: [
                  Expanded(child: _dialogField(pC, 'Protein(g)')),
                  const SizedBox(width: 8),
                  Expanded(child: _dialogField(cC, 'Carbs(g)')),
                  const SizedBox(width: 8),
                  Expanded(child: _dialogField(fC, 'Fat(g)')),
                ]),
              ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(_lang.t('CANCEL'),
                        style: const TextStyle(color: AppTheme.textSecondary))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(_lang.t('SAVE'),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold))),
              ],
            ));

    if (ok == true && nameC.text.isNotEmpty && calC.text.isNotEmpty) {
      setState(() => _todayNutrition.entries.add(FoodEntry(
          id: _uuid.v4(),
          name: nameC.text,
          calories: int.tryParse(calC.text) ?? 0,
          protein: int.tryParse(pC.text) ?? 0,
          carbs: int.tryParse(cC.text) ?? 0,
          fat: int.tryParse(fC.text) ?? 0)));
      _saveNutrition();
    }
  }

  Future<void> _addPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
        setState(() => _photos.insert(
            0, ProgressPhoto(id: _uuid.v4(), date: date, path: image.path)));
        await _saveData(
            'progress_photos', _photos.map((e) => e.toJson()).toList());
      }
    } catch (e) {
      debugPrint('Photo error: $e');
    }
  }

  void _showFullScreenImage(ProgressPhoto photo, int index) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (ctx) => Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    iconTheme: const IconThemeData(color: Colors.white),
                    actions: [
                      IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.danger),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (c) => AlertDialog(
                                      backgroundColor: AppTheme.card,
                                      title: const Text('Delete?',
                                          style: TextStyle(
                                              color: AppTheme.danger)),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, false),
                                            child: const Text('CANCEL',
                                                style: TextStyle(
                                                    color: AppTheme
                                                        .textSecondary))),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(c, true),
                                            child: const Text('DELETE',
                                                style: TextStyle(
                                                    color: AppTheme.danger))),
                                      ],
                                    ));
                            if (ok == true) {
                              setState(() => _photos.removeAt(index));
                              _saveData('progress_photos',
                                  _photos.map((e) => e.toJson()).toList());
                              Navigator.pop(ctx);
                            }
                          }),
                    ],
                  ),
                  body: Center(
                      child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 1.0,
                    maxScale: 4.0,
                    child: kIsWeb
                        ? Image.network(photo.path)
                        : Image.file(File(photo.path)),
                  )),
                )));
  }

  Widget _dialogField(TextEditingController c, String label,
          {bool isNum = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: isNum
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent)),
          ),
        ),
      );

  Widget _choiceBtn(bool sel, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color:
                sel ? AppTheme.gold.withValues(alpha: 0.15) : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? AppTheme.gold : AppTheme.border),
          ),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: sel ? AppTheme.gold : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold))),
        ),
      );

  // ─── Main Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_lang.t('ANALYTICS').toUpperCase(),
            style:
                const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh,
                  color: AppTheme.textSecondary, size: 20),
              onPressed: _loadAllData),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.card,
              onRefresh: _loadAllData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  _build3DScanner(),
                  const SizedBox(height: 28),
                  _buildWeightSection(),
                  const SizedBox(height: 28),
                  _buildNutritionSection(),
                  const SizedBox(height: 28),
                  _buildFoodLog(),
                  const SizedBox(height: 28),
                  _buildPhotosSection(),
                ],
              ),
            ),
    );
  }
}

// ─── Body Silhouette Painter (Android) ───────────────────────────────────────

class _BodyPainter extends CustomPainter {
  final String? zone;
  final List<MuscleReadiness> readiness;
  _BodyPainter({this.zone, required this.readiness});

  Color _zoneColor() {
    const zoneMap = {
      'CHEST': ['Chest', 'Upper Chest', 'Lower Chest'],
      'BACK': ['Lats', 'Rhomboids', 'Lower Back'],
      'SHOULDERS': ['Front Delts', 'Side Delts', 'Rear Delts'],
      'ARMS': ['Biceps', 'Triceps'],
      'CORE': ['Core'],
      'LEGS': ['Quads', 'Hamstrings', 'Glutes', 'Calves'],
    };
    if (zone == null) return const Color(0xFF39FF14);
    final muscles = zoneMap[zone] ?? [];
    final match =
        readiness.where((m) => muscles.contains(m.muscleName)).toList();
    if (match.isEmpty) return const Color(0xFF39FF14);
    final avg = match.map((m) => m.readinessScore).reduce((a, b) => a + b) /
        match.length;
    if (avg >= 80) return const Color(0xFF39FF14);
    if (avg >= 50) return const Color(0xFFFFB930);
    return const Color(0xFFFF4444);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final activeColor = _zoneColor();
    final baseFill = Paint()
      ..color = const Color(0xFF39FF14).withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final baseStroke = Paint()
      ..color = const Color(0xFF39FF14).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final activeFill = Paint()
      ..color = activeColor.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    final activeStroke = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    void draw(Path p, bool active) {
      canvas.drawPath(p, active ? activeFill : baseFill);
      canvas.drawPath(p, active ? activeStroke : baseStroke);
    }

    bool isActive(String z) => zone == z;

    // Head
    draw(
        Path()
          ..addOval(Rect.fromCenter(
              center: Offset(cx, size.height * 0.07),
              width: size.width * 0.22,
              height: size.height * 0.1)),
        false);
    // Neck
    draw(
        Path()
          ..addRect(Rect.fromCenter(
              center: Offset(cx, size.height * 0.13),
              width: size.width * 0.1,
              height: size.height * 0.04)),
        false);
    // Torso
    final torso = Path()
      ..moveTo(cx - size.width * 0.22, size.height * 0.16)
      ..lineTo(cx + size.width * 0.22, size.height * 0.16)
      ..lineTo(cx + size.width * 0.18, size.height * 0.44)
      ..lineTo(cx - size.width * 0.18, size.height * 0.44)
      ..close();
    draw(torso, isActive('CHEST') || isActive('BACK') || isActive('CORE'));
    // Shoulders
    draw(
        Path()
          ..addOval(Rect.fromCenter(
              center: Offset(cx - size.width * 0.29, size.height * 0.18),
              width: size.width * 0.14,
              height: size.height * 0.07)),
        isActive('SHOULDERS'));
    draw(
        Path()
          ..addOval(Rect.fromCenter(
              center: Offset(cx + size.width * 0.29, size.height * 0.18),
              width: size.width * 0.14,
              height: size.height * 0.07)),
        isActive('SHOULDERS'));
    // Upper arms
    final lArm = Path()
      ..moveTo(cx - size.width * 0.23, size.height * 0.17)
      ..lineTo(cx - size.width * 0.38, size.height * 0.23)
      ..lineTo(cx - size.width * 0.34, size.height * 0.40)
      ..lineTo(cx - size.width * 0.22, size.height * 0.42)
      ..close();
    draw(lArm, isActive('ARMS'));
    final rArm = Path()
      ..moveTo(cx + size.width * 0.23, size.height * 0.17)
      ..lineTo(cx + size.width * 0.38, size.height * 0.23)
      ..lineTo(cx + size.width * 0.34, size.height * 0.40)
      ..lineTo(cx + size.width * 0.22, size.height * 0.42)
      ..close();
    draw(rArm, isActive('ARMS'));
    // Forearms
    draw(
        Path()
          ..moveTo(cx - size.width * 0.34, size.height * 0.40)
          ..lineTo(cx - size.width * 0.40, size.height * 0.55)
          ..lineTo(cx - size.width * 0.32, size.height * 0.56)
          ..lineTo(cx - size.width * 0.27, size.height * 0.42)
          ..close(),
        isActive('ARMS'));
    draw(
        Path()
          ..moveTo(cx + size.width * 0.34, size.height * 0.40)
          ..lineTo(cx + size.width * 0.40, size.height * 0.55)
          ..lineTo(cx + size.width * 0.32, size.height * 0.56)
          ..lineTo(cx + size.width * 0.27, size.height * 0.42)
          ..close(),
        isActive('ARMS'));
    // Pelvis
    draw(
        Path()
          ..addRect(Rect.fromCenter(
              center: Offset(cx, size.height * 0.47),
              width: size.width * 0.36,
              height: size.height * 0.07)),
        isActive('LEGS') || isActive('CORE'));
    // Thighs
    draw(
        Path()
          ..moveTo(cx - size.width * 0.18, size.height * 0.51)
          ..lineTo(cx - size.width * 0.22, size.height * 0.70)
          ..lineTo(cx - size.width * 0.10, size.height * 0.70)
          ..lineTo(cx - size.width * 0.05, size.height * 0.51)
          ..close(),
        isActive('LEGS'));
    draw(
        Path()
          ..moveTo(cx + size.width * 0.18, size.height * 0.51)
          ..lineTo(cx + size.width * 0.22, size.height * 0.70)
          ..lineTo(cx + size.width * 0.10, size.height * 0.70)
          ..lineTo(cx + size.width * 0.05, size.height * 0.51)
          ..close(),
        isActive('LEGS'));
    // Lower legs
    draw(
        Path()
          ..moveTo(cx - size.width * 0.21, size.height * 0.70)
          ..lineTo(cx - size.width * 0.22, size.height * 0.90)
          ..lineTo(cx - size.width * 0.10, size.height * 0.90)
          ..lineTo(cx - size.width * 0.10, size.height * 0.70)
          ..close(),
        isActive('LEGS'));
    draw(
        Path()
          ..moveTo(cx + size.width * 0.21, size.height * 0.70)
          ..lineTo(cx + size.width * 0.22, size.height * 0.90)
          ..lineTo(cx + size.width * 0.10, size.height * 0.90)
          ..lineTo(cx + size.width * 0.10, size.height * 0.70)
          ..close(),
        isActive('LEGS'));
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.zone != zone || old.readiness != readiness;
}

// ─── OCR Confirm Dialog ───────────────────────────────────────────────────────

class _OcrConfirmDialog extends StatefulWidget {
  final Map<String, double> parsed;
  final LangService lang;
  final void Function(FoodEntry) onConfirm;
  final Uuid uuid;

  const _OcrConfirmDialog({
    required this.parsed,
    required this.lang,
    required this.onConfirm,
    required this.uuid,
  });

  @override
  State<_OcrConfirmDialog> createState() => _OcrConfirmDialogState();
}

class _OcrConfirmDialogState extends State<_OcrConfirmDialog> {
  late final TextEditingController _nameC;
  late final TextEditingController _calC;
  late final TextEditingController _pC;
  late final TextEditingController _cC;
  late final TextEditingController _fC;

  @override
  void initState() {
    super.initState();
    _nameC = TextEditingController();
    _calC = TextEditingController(
        text: widget.parsed['calories']!.round().toString());
    _pC = TextEditingController(
        text: widget.parsed['protein']!.round().toString());
    _cC =
        TextEditingController(text: widget.parsed['carbs']!.round().toString());
    _fC = TextEditingController(text: widget.parsed['fat']!.round().toString());
  }

  @override
  void dispose() {
    _nameC.dispose();
    _calC.dispose();
    _pC.dispose();
    _cC.dispose();
    _fC.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, {bool isNum = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: isNum
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.border)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.accent)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final allZero = widget.parsed['calories'] == 0 &&
        widget.parsed['protein'] == 0 &&
        widget.parsed['carbs'] == 0 &&
        widget.parsed['fat'] == 0;

    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.document_scanner, color: AppTheme.accent, size: 18),
        const SizedBox(width: 8),
        Text(widget.lang.t('SCAN RESULT'),
            style: const TextStyle(
                color: AppTheme.accent, fontWeight: FontWeight.bold)),
      ]),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 辨識失敗提示
          if (allZero)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber, color: AppTheme.gold, size: 14),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(
                  widget.lang
                      .t('Could not detect values, please fill in manually'),
                  style: const TextStyle(color: AppTheme.gold, fontSize: 10),
                )),
              ]),
            ),
          _field(_nameC, widget.lang.t('FOOD NAME'), isNum: false),
          _field(_calC, 'Calories (kcal)'),
          Row(children: [
            Expanded(child: _field(_pC, 'Protein (g)')),
            const SizedBox(width: 8),
            Expanded(child: _field(_cC, 'Carbs (g)')),
            const SizedBox(width: 8),
            Expanded(child: _field(_fC, 'Fat (g)')),
          ]),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.lang.t('CANCEL'),
                style: const TextStyle(color: AppTheme.textSecondary))),
        TextButton(
            onPressed: () {
              if (_calC.text.isEmpty) return;
              widget.onConfirm(FoodEntry(
                id: widget.uuid.v4(),
                name: _nameC.text.isEmpty
                    ? widget.lang.t('Scanned Food')
                    : _nameC.text,
                calories: int.tryParse(_calC.text) ?? 0,
                protein: int.tryParse(_pC.text) ?? 0,
                carbs: int.tryParse(_cC.text) ?? 0,
                fat: int.tryParse(_fC.text) ?? 0,
              ));
              Navigator.pop(context);
            },
            child: Text(widget.lang.t('SAVE'),
                style: const TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.bold))),
      ],
    );
  }
}

// ─── Barcode Scanner ──────────────────────────────────────────────────────────

class AppBarcodeScanner extends StatefulWidget {
  const AppBarcodeScanner({super.key});
  @override
  State<AppBarcodeScanner> createState() => _AppBarcodeScannerState();
}

class _AppBarcodeScannerState extends State<AppBarcodeScanner> {
  final MobileScannerController ctrl = MobileScannerController();
  bool _scanned = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('SCAN BARCODE'),
        actions: [
          IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => ctrl.toggleTorch()),
          IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: () => ctrl.switchCamera()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: ctrl,
          onDetect: (capture) {
            if (_scanned) return;
            final b = capture.barcodes;
            if (b.isNotEmpty && b.first.rawValue != null) {
              _scanned = true;
              Navigator.pop(context, b.first.rawValue);
            }
          },
        ),
        Center(
          child: Container(
            width: 260,
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.6), width: 2.5),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ]),
    );
  }
}
