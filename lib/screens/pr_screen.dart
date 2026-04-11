// lib/screens/pr_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../services/app_theme.dart';
import '../services/lang_service.dart';
import '../services/unit_service.dart';
import '../services/intelligence_service.dart';
import '../models/models.dart';
import '../widgets/anim.dart'; // 確保你有這個淡入動畫 widget

class RankedPR {
  final String exerciseName;
  final double maxWeight;
  final int maxReps;
  final double est1RM;
  final String date;
  final EquipmentType equipment;

  RankedPR({
    required this.exerciseName,
    required this.maxWeight,
    required this.maxReps,
    required this.est1RM,
    required this.date,
    required this.equipment,
  });
}

class PRScreen extends StatefulWidget {
  const PRScreen({super.key});

  @override
  State<PRScreen> createState() => _PRScreenState();
}

class _PRScreenState extends State<PRScreen> {
  final _lang = LangService();
  final _units = UnitService();

  bool _loading = true;
  List<RankedPR> _allPRs = [];

  @override
  void initState() {
    super.initState();
    _lang.addListener(_refresh);
    _units.addListener(_refresh);
    _loadAllPRs();
  }

  @override
  void dispose() {
    _lang.removeListener(_refresh);
    _units.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAllPRs() async {
    setState(() => _loading = true);

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('log_')).toList();

    Map<String, RankedPR> bestLifts = {};

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null) {
        try {
          final log = WorkoutLog.fromJson(jsonDecode(str));
          if (!log.isCompleted) continue;

          for (var ex in log.exercises) {
            for (var set in ex.sets) {
              if (set.completed && set.weight > 0 && set.reps > 0) {
                double current1RM = set.reps == 1
                    ? set.weight
                    : set.weight * (1 + (set.reps / 30.0));

                final existing = bestLifts[ex.name];

                if (existing == null || current1RM > existing.est1RM) {
                  final analysis =
                      IntelligenceService().analyzeExercise(ex.name);

                  bestLifts[ex.name] = RankedPR(
                    exerciseName: ex.name,
                    maxWeight: set.weight,
                    maxReps: set.reps,
                    est1RM: current1RM,
                    date: log.date,
                    equipment: analysis.equipment,
                  );
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing log for PRs: $e');
        }
      }
    }

    List<RankedPR> sortedPRs = bestLifts.values.toList();
    sortedPRs.sort((a, b) => b.est1RM.compareTo(a.est1RM));

    if (mounted) {
      setState(() {
        _allPRs = sortedPRs;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_lang.isEn ? 'PERSONAL RECORDS' : '個人最佳紀錄',
            style:
                const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh,
                color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadAllPRs();
            },
          )
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.card,
              onRefresh: _loadAllPRs,
              child: _allPRs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _allPRs.length,
                      itemBuilder: (context, index) {
                        return _buildPRCard(index, _allPRs[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events_outlined,
              color: AppTheme.border, size: 64),
          const SizedBox(height: 16),
          Text(
            _lang.t('Complete at least 1 record to unlock'),
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            _lang.isEn
                ? 'Finish a workout to see your rankings.'
                : '完成一次訓練結算後即可解鎖排行榜',
            style: const TextStyle(color: AppTheme.border, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildPRCard(int index, RankedPR pr) {
    Color rankColor;
    Color bgColor;
    bool isTop3 = index < 3;

    if (index == 0) {
      rankColor = AppTheme.gold;
      bgColor = AppTheme.gold.withOpacity(0.05);
    } else if (index == 1) {
      rankColor = Colors.grey[400]!;
      bgColor = Colors.grey[400]!.withOpacity(0.05);
    } else if (index == 2) {
      rankColor = const Color(0xFFCD7F32);
      bgColor = const Color(0xFFCD7F32).withOpacity(0.05);
    } else {
      rankColor = AppTheme.textSecondary;
      bgColor = AppTheme.card;
    }

    return FadeIn(
      delay: Duration(milliseconds: index * 50 > 500 ? 500 : index * 50),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTop3 ? rankColor.withOpacity(0.5) : AppTheme.border,
            width: isTop3 ? 1.5 : 1.0,
          ),
          boxShadow: isTop3
              ? [
                  BoxShadow(
                      color: rankColor.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 1)
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isTop3 ? rankColor.withOpacity(0.15) : AppTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: isTop3 ? rankColor : AppTheme.border),
              ),
              alignment: Alignment.center,
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  color: isTop3 ? rankColor : AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pr.exerciseName.toUpperCase(),
                    style: TextStyle(
                      color: isTop3 ? Colors.white : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 10, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy')
                            .format(DateTime.parse(pr.date)),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 10),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          pr.equipment.label,
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_units.fmtNum(_units.toDisplay(pr.maxWeight))} ${_units.unit}',
                  style: TextStyle(
                    color: isTop3 ? rankColor : AppTheme.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  'x ${pr.maxReps} REPS',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'EST. 1RM: ${_units.fmtNum(_units.toDisplay(pr.est1RM))} ${_units.unit}',
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.8),
                      fontSize: 9,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
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
