// lib/screens/training_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/unit_service.dart';
import '../services/lang_service.dart';
import '../services/app_theme.dart';
import '../services/intelligence_service.dart';
import '../widgets/anim.dart';

enum _ViewState { pickDay, logging, summary }

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _store = StorageService();
  final _units = UnitService();
  final _lang = LangService();
  final _uuid = const Uuid();

  DateTime _date = DateTime.now();
  _ViewState _view = _ViewState.pickDay;

  List<Program> _programs = [];
  WorkoutLog? _log;
  bool _loading = true;

  Map<String, Map<String, double>> _prevStats = {};
  Map<String, List<Map<String, double>>> _exHistory = {};

  late AnimationController _transCtrl;
  late Animation<double> _transFade;

  late ConfettiController _confettiCtrl;

  // ─── 時間戳記 Rest Timer ──────────────────────────────────────────────────
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _isResting = false;
  DateTime? _restEndTime; // 計時結束的絕對時間點

  static const String _restEndKey = 'rest_end_time'; // SharedPreferences key

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 監聽 App 生命週期

    _transCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _transFade = CurvedAnimation(parent: _transCtrl, curve: Curves.easeOut);

    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 2));

    _units.addListener(_updateUI);
    _lang.addListener(_updateUI);
    _load();

    // App 啟動時恢復未結束的計時
    _restoreTimerIfNeeded();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _transCtrl.dispose();
    _confettiCtrl.dispose();
    _units.removeListener(_updateUI);
    _lang.removeListener(_updateUI);
    _restTimer?.cancel();
    super.dispose();
  }

  // ─── App 生命週期監聽 ─────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前景：用時間戳記重新計算剩餘秒數
      _recalcTimerFromTimestamp();
    }
    // 進入背景時不需要做什麼，因為 _restEndTime 已經存好了
  }

  /// 啟動時檢查 SharedPreferences 是否有未完成的計時
  Future<void> _restoreTimerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final endTimeStr = prefs.getString(_restEndKey);
    if (endTimeStr == null) return;

    final endTime = DateTime.tryParse(endTimeStr);
    if (endTime == null) return;

    final now = DateTime.now();
    final remaining = endTime.difference(now).inSeconds;

    if (remaining > 0) {
      _restEndTime = endTime;
      setState(() {
        _restSeconds = remaining;
        _isResting = true;
      });
      _tickTimer();
    } else {
      // 已經結束，清掉
      await prefs.remove(_restEndKey);
    }
  }

  /// 從背景回來時重新計算剩餘秒數
  void _recalcTimerFromTimestamp() {
    if (_restEndTime == null) return;
    final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      _stopRestTimer();
    } else {
      setState(() => _restSeconds = remaining);
      // 如果 timer 被系統殺掉了，重新啟動
      if (_restTimer == null || !_restTimer!.isActive) {
        _tickTimer();
      }
    }
  }

  /// 實際的 tick loop，每秒從時間戳記計算剩餘秒，不會因為背景漂移
  void _tickTimer() {
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_restEndTime == null) {
        timer.cancel();
        return;
      }
      final remaining = _restEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        _stopRestTimer();
      } else {
        setState(() => _restSeconds = remaining);
      }
    });
  }

  void _startRestTimer() {
    _restTimer?.cancel();
    final endTime = DateTime.now().add(const Duration(seconds: 60));
    _restEndTime = endTime;
    _persistEndTime(endTime);

    setState(() {
      _restSeconds = 60;
      _isResting = true;
    });
    _tickTimer();
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _restTimer = null;
    _restEndTime = null;
    _clearPersistedEndTime();
    if (mounted) setState(() => _isResting = false);
  }

  void _addRestTime() {
    if (_restEndTime == null) return;
    final newEnd = _restEndTime!.add(const Duration(seconds: 30));
    _restEndTime = newEnd;
    _persistEndTime(newEnd);
    setState(() => _restSeconds = newEnd.difference(DateTime.now()).inSeconds);
  }

  Future<void> _persistEndTime(DateTime endTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_restEndKey, endTime.toIso8601String());
  }

  Future<void> _clearPersistedEndTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_restEndKey);
  }

  // ─── 以下與原本完全相同 ───────────────────────────────────────────────────

  void _updateUI() {
    if (mounted) setState(() {});
  }

  String get _dateKey => DateFormat('yyyy-MM-dd').format(_date);

  String get _dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sel = DateTime(_date.year, _date.month, _date.day);
    if (sel == today) return _lang.t('TODAY');
    if (sel == today.subtract(const Duration(days: 1))) {
      return _lang.t('YESTERDAY');
    }
    return DateFormat('MMM d').format(_date).toUpperCase();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final programs = await _store.loadPrograms();
    final log = await _store.getLog(_dateKey);

    if (mounted) {
      if (log != null && log.isCompleted) {
        await _loadPreviousStats(log);
        _view = _ViewState.summary;
      } else {
        _view = log != null ? _ViewState.logging : _ViewState.pickDay;
      }
      setState(() {
        _programs = programs;
        _log = log;
        _loading = false;
      });
      _transCtrl.forward(from: 0);
    }
  }

  Future<void> _loadPreviousStats(WorkoutLog currentLog) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('log_')).toList();
    final Map<String, WorkoutLog> allLogs = {};

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null) {
        try {
          final l = WorkoutLog.fromJson(jsonDecode(str));
          if (l.isCompleted && l.date.compareTo(currentLog.date) < 0) {
            allLogs[l.date] = l;
          }
        } catch (_) {}
      }
    }

    final sortedDates = allLogs.keys.toList()..sort((a, b) => a.compareTo(b));

    _prevStats.clear();
    _exHistory.clear();

    for (final ex in currentLog.exercises) {
      List<Map<String, double>> history = [];
      LoggedExercise? prevEx;

      for (final date in sortedDates) {
        final l = allLogs[date]!;
        final match = l.exercises.where((e) => e.name == ex.name).toList();
        if (match.isNotEmpty) {
          prevEx = match.first;

          double vol = 0;
          double maxW = 0;
          for (var s in prevEx.sets) {
            if (s.completed) {
              vol += (s.weight * s.reps);
              if (s.weight > maxW) maxW = s.weight;
            }
          }
          history.add({'volume': vol, 'maxWeight': maxW});
        }
      }

      if (history.length > 5) {
        history = history.sublist(history.length - 5);
      }
      _exHistory[ex.name] = history;

      if (history.isNotEmpty) {
        _prevStats[ex.name] = {
          'volume': history.last['volume']!,
          'maxWeight': history.last['maxWeight']!,
        };
      }
    }
  }

  Future<void> _changeDate(int delta) async {
    await _transCtrl.reverse();
    setState(() => _date = _date.add(Duration(days: delta)));
    await _load();
  }

  Future<void> _startFromDay(ProgramDay day, Program program) async {
    final exercises = <LoggedExercise>[];
    for (final te in day.exercises) {
      final lastSets = await _store.getLastSetsFor(te.name);
      List<ExerciseSet> sets;
      if (lastSets.isNotEmpty) {
        sets = lastSets
            .take(te.defaultSets)
            .map(
              (s) =>
                  ExerciseSet(id: _uuid.v4(), weight: s.weight, reps: s.reps),
            )
            .toList();
        while (sets.length < te.defaultSets) {
          sets.add(
            ExerciseSet(
              id: _uuid.v4(),
              weight: sets.last.weight,
              reps: sets.last.reps,
            ),
          );
        }
      } else {
        sets = List.generate(
          te.defaultSets,
          (_) => ExerciseSet(id: _uuid.v4(), weight: 0, reps: 0),
        );
      }
      exercises.add(LoggedExercise(
        id: _uuid.v4(),
        name: te.name,
        sets: sets,
        scheme: te.scheme,
        tips: te.tips,
        targetMuscles: te.targetMuscles,
      ));
    }
    final log = WorkoutLog(
      date: _dateKey,
      programDayId: day.id,
      programDayName: '${program.name} · ${day.name}',
      exercises: exercises,
    );
    await _store.saveLog(log);
    if (mounted) {
      setState(() {
        _log = log;
        _view = _ViewState.logging;
      });
      _transCtrl.forward(from: 0);
    }
  }

  Future<void> _startFree() async {
    final log = WorkoutLog(date: _dateKey, exercises: []);
    await _store.saveLog(log);
    if (mounted) {
      setState(() {
        _log = log;
        _view = _ViewState.logging;
      });
      _transCtrl.forward(from: 0);
    }
  }

  Future<void> _discard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: _lang.t('DISCARD WORKOUT?'),
        message: _lang.t("This will delete today's log."),
        danger: true,
      ),
    );
    if (confirm != true) return;
    await _store.deleteLog(_dateKey);
    if (mounted) {
      setState(() {
        _log = null;
        _view = _ViewState.pickDay;
      });
      _transCtrl.forward(from: 0);
    }
  }

  Future<void> _saveLog() async {
    if (_log != null) await _store.saveLog(_log!);
  }

  Future<void> _addExercise() async {
    final name = await _showNameDialog(
      _lang.t('ADD EXERCISE'),
      'e.g. Bench Press',
    );
    if (name == null || name.isEmpty) return;
    final lastSets = await _store.getLastSetsFor(name);
    List<ExerciseSet> sets = lastSets.isNotEmpty
        ? lastSets
            .map(
              (s) =>
                  ExerciseSet(id: _uuid.v4(), weight: s.weight, reps: s.reps),
            )
            .toList()
        : [ExerciseSet(id: _uuid.v4(), weight: 0, reps: 0)];
    setState(
      () => _log!.exercises.add(
        LoggedExercise(id: _uuid.v4(), name: name, sets: sets),
      ),
    );
    await _saveLog();
  }

  Future<void> _renameExercise(LoggedExercise ex) async {
    final newName = await _showNameDialog(
      _lang.t('RENAME EXERCISE'),
      ex.name,
      initialText: ex.name,
    );
    if (newName != null && newName.isNotEmpty) {
      setState(() {
        ex.name = newName;
      });
      await _saveLog();
    }
  }

  void _addSet(LoggedExercise ex) {
    final last = ex.sets.isNotEmpty ? ex.sets.last : null;
    setState(
      () => ex.sets.add(
        ExerciseSet(
          id: _uuid.v4(),
          weight: last?.weight ?? 0,
          reps: last?.reps ?? 0,
        ),
      ),
    );
    _saveLog();
  }

  void _removeSet(LoggedExercise ex, int idx) {
    setState(() {
      ex.sets.removeAt(idx);
      if (ex.sets.isEmpty) _log!.exercises.remove(ex);
    });
    _saveLog();
  }

  void _removeExercise(LoggedExercise ex) {
    setState(() => _log!.exercises.remove(ex));
    _saveLog();
  }

  Future<String?> _showNameDialog(String title, String hint,
      {String? initialText}) async {
    final ctrl = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _InputDialog(title: title, hint: hint, ctrl: ctrl),
    );
  }

  void _openPlateCalculator() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PlateCalculatorSheet(units: _units, lang: _lang),
    );
  }

  void _openShareCard() {
    if (_log == null) return;

    double totalVol = 0;
    for (var ex in _log!.exercises) {
      for (var s in ex.sets) {
        if (s.completed) totalVol += (s.weight * s.reps);
      }
    }

    showGeneralDialog(
      context: context,
      barrierColor: AppTheme.bg,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return _ShareCardOverlay(
          log: _log!,
          totalVol: totalVol,
          units: _units,
          lang: _lang,
        );
      },
    );
  }

  void _showExerciseHistory(String exerciseName) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('log_')).toList();
    List<Map<String, dynamic>> history = [];

    for (var key in keys) {
      final str = prefs.getString(key);
      if (str != null) {
        try {
          final l = WorkoutLog.fromJson(jsonDecode(str));
          if (l.isCompleted) {
            final match =
                l.exercises.where((e) => e.name == exerciseName).toList();
            if (match.isNotEmpty) {
              history.add({
                'date': l.date,
                'sets': match.first.sets.where((s) => s.completed).toList()
              });
            }
          }
        } catch (_) {}
      }
    }

    history.sort((a, b) => b['date'].compareTo(a['date']));

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.bg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ExerciseHistorySheet(
          exerciseName: exerciseName,
          history: history,
          units: _units,
          lang: _lang,
        ),
      );
    }
  }

  void _showWarmupGuide(String exerciseName, double targetWeight) async {
    final historySets = await _store.getLastSetsFor(exerciseName);
    final bool hasHistory = historySets.isNotEmpty;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _WarmupGuideSheet(
        exerciseName: exerciseName,
        targetWeight: targetWeight,
        hasHistory: hasHistory,
        units: _units,
        lang: _lang,
      ),
    );
  }

  Widget _buildFloatingTimerCapsule() {
    final mins = _restSeconds ~/ 60, secs = _restSeconds % 60;
    final timeStr = '$mins:${secs.toString().padLeft(2, '0')}';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, val, child) => Transform.translate(
        offset: Offset(0, -60 * (1 - val)),
        child: Opacity(opacity: val, child: child),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A).withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: AppTheme.accent.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, color: AppTheme.accent, size: 20),
                const SizedBox(width: 10),
                Text(
                  '${_lang.t("REST")}  $timeStr',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _addRestTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '+30s',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _stopRestTimer,
                  child: const Icon(
                    Icons.close,
                    color: AppTheme.textSecondary,
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProgramActive = _log?.programDayName != null;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildDateBar(),
              Expanded(
                child: _loading
                    ? _buildLoading()
                    : FadeTransition(
                        opacity: _transFade,
                        child: _view == _ViewState.summary
                            ? _buildSummary()
                            : _view == _ViewState.pickDay
                                ? _buildPickDay()
                                : _buildLogging(),
                      ),
              ),
            ],
          ),
          if (_isResting)
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: _buildFloatingTimerCapsule(),
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [AppTheme.accent, AppTheme.gold, Colors.white],
              gravity: 0.2,
            ),
          ),
        ],
      ),
      floatingActionButton:
          !_loading && _view == _ViewState.logging && !isProgramActive
              ? Tap(
                  onTap: _addExercise,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.black, size: 28),
                  ),
                )
              : null,
    );
  }

  Widget _buildDateBar() {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          Tap(
            onTap: () => _changeDate(-1),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.chevron_left,
                color: AppTheme.textPrimary,
                size: 26,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                  builder: (ctx, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                        primary: AppTheme.accent,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (p != null) {
                  await _transCtrl.reverse();
                  setState(() => _date = p);
                  await _load();
                }
              },
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _dateLabel,
                      key: ValueKey(_dateLabel),
                      style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat(
                      'EEEE · MMM d, yyyy',
                    ).format(_date).toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tap(
            onTap: () => _changeDate(1),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.chevron_right,
                color: AppTheme.textPrimary,
                size: 26,
              ),
            ),
          ),
          Tap(
            onTap: () {
              HapticFeedback.lightImpact();
              _load();
            },
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(
                Icons.refresh_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickDay() {
    final customPrograms = _programs.where((p) => !p.isPreset).toList();
    final presetPrograms = _programs.where((p) => p.isPreset).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_log != null && _log!.isCompleted) ...[
          FadeIn(
            delay: const Duration(milliseconds: 20),
            child: Tap(
              onTap: () => setState(() => _view = _ViewState.summary),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.analytics, color: Colors.black, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _lang.t('VIEW SUMMARY'),
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        FadeIn(
          delay: const Duration(milliseconds: 40),
          child: Tap(
            onTap: _startFree,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.accent.withOpacity(0.05),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _lang.t('FREE SESSION'),
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _lang.t('Start without a program'),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.accent,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildExpansionBox(
          title: _lang.t('CUSTOM PROGRAMS'),
          icon: Icons.build_circle_outlined,
          count: customPrograms.length,
          initiallyExpanded: true,
          children: customPrograms.isEmpty
              ? [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _lang.t('NO CUSTOM PROGRAMS'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ),
                  )
                ]
              : customPrograms
                  .map((p) => _ProgramCard(
                        program: p,
                        lang: _lang,
                        onSelectDay: (day) => _startFromDay(day, p),
                      ))
                  .toList(),
        ),
        const SizedBox(height: 16),
        if (presetPrograms.isNotEmpty)
          _buildExpansionBox(
            title: _lang.t('PRESET PROGRAMS'),
            icon: Icons.verified_outlined,
            count: presetPrograms.length,
            initiallyExpanded: false,
            children: presetPrograms
                .map((p) => _ProgramCard(
                      program: p,
                      lang: _lang,
                      onSelectDay: (day) => _startFromDay(day, p),
                    ))
                .toList(),
          ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildExpansionBox({
    required String title,
    required IconData icon,
    required int count,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          iconColor: AppTheme.accent,
          collapsedIconColor: AppTheme.textSecondary,
          leading: Icon(icon, color: AppTheme.accent, size: 22),
          title: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: children,
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_log == null) return const SizedBox();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 10),
        Center(
          child: Column(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.gold, size: 64),
              const SizedBox(height: 12),
              Text(
                _lang.t('GREAT JOB!'),
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(
                _lang.t('WORKOUT SUMMARY'),
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ..._log!.exercises.map((ex) {
          double currVol = 0;
          double currMaxW = 0;
          for (var s in ex.sets) {
            if (s.completed) {
              currVol += (s.weight * s.reps);
              if (s.weight > currMaxW) currMaxW = s.weight;
            }
          }

          final prev = _prevStats[ex.name];
          final hasPrev = prev != null;
          final diffVol = hasPrev ? currVol - prev['volume']! : 0.0;
          final diffMaxW = hasPrev ? currMaxW - prev['maxWeight']! : 0.0;

          final historyData = _exHistory[ex.name] ?? [];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.name.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildCompareStat(
                        _lang.t('VOLUME'), currVol, diffVol, hasPrev),
                    Container(
                        width: 1,
                        height: 30,
                        color: AppTheme.border,
                        margin: const EdgeInsets.symmetric(horizontal: 16)),
                    _buildCompareStat(
                        _lang.t('MAX WEIGHT'), currMaxW, diffMaxW, hasPrev),
                  ],
                ),
                if (historyData.isEmpty && !hasPrev) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.auto_graph,
                            color: AppTheme.border, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          _lang.t('Complete at least 1 record to unlock'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color:
                                  AppTheme.textSecondary.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ] else if (historyData.isNotEmpty || currMaxW > 0) ...[
                  const SizedBox(height: 20),
                  _buildChart(historyData, currMaxW),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: Tap(
                onTap: _openShareCard,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _lang.t('SHARE STORY'),
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Tap(
                onTap: () => setState(() => _view = _ViewState.pickDay),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _lang.t('BACK TO CALENDAR'),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildChart(List<Map<String, double>> history, double currMaxW) {
    final allData = [
      ...history,
      {'maxWeight': currMaxW}
    ];
    if (allData.length < 2) return const SizedBox();

    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = 0;

    for (int i = 0; i < allData.length; i++) {
      final w = allData[i]['maxWeight'] as double;
      spots.add(FlSpot(i.toDouble(), w));
      if (w < minY) minY = w;
      if (w > maxY) maxY = w;
    }

    if (minY == maxY) {
      minY -= 10;
      maxY += 10;
    } else {
      final diff = maxY - minY;
      minY -= diff * 0.2;
      maxY += diff * 0.2;
    }

    return SizedBox(
      height: 80,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (allData.length - 1).toDouble(),
          minY: minY < 0 ? 0 : minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.accent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: index == allData.length - 1
                        ? Colors.white
                        : AppTheme.accent,
                    strokeWidth: 2,
                    strokeColor: AppTheme.bg,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.accent.withOpacity(0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareStat(
      String label, double currVal, double diff, bool hasPrev) {
    Color diffColor = AppTheme.textSecondary;
    IconData? diffIcon;
    String diffText = '';

    if (hasPrev) {
      if (diff > 0) {
        diffColor = Colors.green;
        diffIcon = Icons.arrow_upward;
        diffText = '+${_units.fmt(diff)}';
      } else if (diff < 0) {
        diffColor = AppTheme.danger;
        diffIcon = Icons.arrow_downward;
        diffText = _units.fmt(diff);
      } else {
        diffText = '=';
      }
    } else {
      diffText = _lang.t('No previous data');
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9,
                  letterSpacing: 1)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_units.fmt(currVal),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              if (hasPrev && diff != 0)
                Row(
                  children: [
                    Icon(diffIcon, color: diffColor, size: 10),
                    Text(diffText,
                        style: TextStyle(
                            color: diffColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                )
              else
                Text(diffText,
                    style: TextStyle(color: diffColor, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogging() {
    final isProgramActive = _log!.programDayName != null;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          color: AppTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_log!.programDayName != null)
                      Text(
                        _log!.programDayName!.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                    Text(
                      _log!.programDayName != null
                          ? _lang.t('IN PROGRESS')
                          : _lang.t('FREE SESSION'),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openPlateCalculator,
                icon: const Icon(Icons.calculate_outlined,
                    color: AppTheme.gold, size: 22),
              ),
              Tap(
                onTap: _discard,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.danger.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _lang.t('DISCARD'),
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _log!.exercises.isEmpty
              ? _buildLogEmpty()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: _log!.exercises.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _log!.exercises.length) {
                      return FadeIn(
                        delay: Duration(milliseconds: i * 55),
                        child: _buildFinishButton(),
                      );
                    }
                    return FadeIn(
                      delay: Duration(milliseconds: i * 55),
                      child: _ExerciseCard(
                        exercise: _log!.exercises[i],
                        units: _units,
                        lang: _lang,
                        isProgram: isProgramActive,
                        onAddSet: () => _addSet(_log!.exercises[i]),
                        onRemoveSet: (idx) =>
                            _removeSet(_log!.exercises[i], idx),
                        onRemove: () => _removeExercise(_log!.exercises[i]),
                        onRename: () => _renameExercise(_log!.exercises[i]),
                        onChanged: _saveLog,
                        onSetCompleted: _startRestTimer,
                        onShowHistory: () =>
                            _showExerciseHistory(_log!.exercises[i].name),
                        onShowWarmup: (w) =>
                            _showWarmupGuide(_log!.exercises[i].name, w),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFinishButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 40),
      child: Tap(
        onTap: _finishWorkout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            _lang.t('FINISH WORKOUT'),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _finishWorkout() async {
    HapticFeedback.heavyImpact();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppTheme.accent, size: 28),
            const SizedBox(width: 10),
            Text(
              _lang.t('FINISH?'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        content: Text(
          _lang.t('Are you sure you want to finish this workout?'),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              _lang.t('CANCEL'),
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              bool brokePR = false;

              if (_log != null) {
                await _loadPreviousStats(_log!);

                for (final ex in _log!.exercises) {
                  double currVol = 0;
                  double currMaxW = 0;
                  for (var s in ex.sets) {
                    if (s.completed) {
                      currVol += (s.weight * s.reps);
                      if (s.weight > currMaxW) currMaxW = s.weight;
                    }
                  }

                  final prev = _prevStats[ex.name];
                  if (prev != null) {
                    if (currMaxW > prev['maxWeight']! ||
                        currVol > prev['volume']!) {
                      brokePR = true;
                    }
                  }
                }

                _log!.isCompleted = true;
                await _store.saveLog(_log!);
              }

              setState(() {
                _view = _ViewState.summary;
              });

              if (brokePR) {
                _confettiCtrl.play();
              }
            },
            child: Text(
              _lang.t('HELL YEAH'),
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center, color: AppTheme.border, size: 48),
            const SizedBox(height: 14),
            Text(
              _lang.t('NO EXERCISES'),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _lang.t('Tap + to add'),
              style: const TextStyle(color: AppTheme.border, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _buildLoading() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Shimmer(width: double.infinity, height: i == 0 ? 72 : 140),
            ),
          ),
        ),
      );
}

// ==========================================
// 圖卡分享
// ==========================================
class _ShareCardOverlay extends StatelessWidget {
  final WorkoutLog log;
  final double totalVol;
  final UnitService units;
  final LangService lang;

  const _ShareCardOverlay({
    required this.log,
    required this.totalVol,
    required this.units,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    DateTime dateObj = DateTime.parse(log.date);
    String dateFormatted = DateFormat('yyyy / MM / dd').format(dateObj);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              lang.t('TAKE A SCREENSHOT TO SHARE!'),
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.5),
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.accent.withOpacity(0.2),
                            blurRadius: 40,
                            spreadRadius: 5),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(22)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Icon(Icons.fitness_center,
                                      color: AppTheme.accent, size: 28),
                                  Text(dateFormatted,
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                log.programDayName != null
                                    ? log.programDayName!.toUpperCase()
                                    : 'FREE SESSION',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ListView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: log.exercises.length > 5
                                  ? 5
                                  : log.exercises.length,
                              itemBuilder: (ctx, i) {
                                final ex = log.exercises[i];
                                int setsDone =
                                    ex.sets.where((s) => s.completed).length;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('• ',
                                          style: TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(ex.name.toUpperCase(),
                                                style: const TextStyle(
                                                    color: AppTheme.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text('$setsDone ${lang.t('SETS')}',
                                                style: const TextStyle(
                                                    color:
                                                        AppTheme.textSecondary,
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(22)),
                          ),
                          child: Column(
                            children: [
                              Text(
                                lang.t('TOTAL VOLUME'),
                                style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${units.fmtNum(totalVol)} ${units.unit}',
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  lang.t('CLOSE'),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 計算機、歷史紀錄與熱身視窗
// ==========================================
class _PlateCalculatorSheet extends StatefulWidget {
  final UnitService units;
  final LangService lang;

  const _PlateCalculatorSheet({required this.units, required this.lang});

  @override
  State<_PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<_PlateCalculatorSheet> {
  late TextEditingController _targetCtrl;
  late TextEditingController _barCtrl;
  List<double> _resultPlates = [];

  @override
  void initState() {
    super.initState();
    _targetCtrl = TextEditingController();
    _barCtrl = TextEditingController(text: widget.units.useLbs ? '45' : '20');
  }

  void _calculate() {
    double target = double.tryParse(_targetCtrl.text) ?? 0;
    double bar =
        double.tryParse(_barCtrl.text) ?? (widget.units.useLbs ? 45 : 20);

    if (target <= bar) {
      setState(() => _resultPlates = []);
      return;
    }

    double weightPerSide = (target - bar) / 2;

    List<double> availablePlates = widget.units.useLbs
        ? [45, 35, 25, 10, 5, 2.5]
        : [25, 20, 15, 10, 5, 2.5, 1.25];

    List<double> result = [];

    for (double p in availablePlates) {
      while (weightPerSide >= p) {
        result.add(p);
        weightPerSide -= p;
      }
    }

    setState(() {
      _resultPlates = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lang;
    final u = widget.units;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate, color: AppTheme.gold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l.t('PLATE CALCULATOR'),
                    style: const TextStyle(
                        color: AppTheme.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close,
                    color: AppTheme.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('TARGET WEIGHT'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _targetCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      onChanged: (_) => _calculate(),
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: u.unit,
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.t('BAR WEIGHT'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _barCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      onChanged: (_) => _calculate(),
                      decoration: InputDecoration(
                        suffixText: u.unit,
                        filled: true,
                        fillColor: AppTheme.surface,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                Text(l.t('EACH SIDE'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        letterSpacing: 1.5)),
                const SizedBox(height: 16),
                if (_resultPlates.isEmpty && _targetCtrl.text.isNotEmpty)
                  Text(l.t('Too Light'),
                      style: const TextStyle(
                          color: AppTheme.danger, fontWeight: FontWeight.bold))
                else if (_resultPlates.isEmpty)
                  const Text('---',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 24))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _resultPlates.map((plate) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                  color: AppTheme.accent.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]),
                        child: Text(
                          u.fmtNum(plate),
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ExerciseHistorySheet extends StatelessWidget {
  final String exerciseName;
  final List<Map<String, dynamic>> history;
  final UnitService units;
  final LangService lang;

  const _ExerciseHistorySheet({
    required this.exerciseName,
    required this.history,
    required this.units,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7, minHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${exerciseName.toUpperCase()} ${lang.t('HISTORY')}',
                style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close,
                    color: AppTheme.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: history.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_toggle_off,
                            color: AppTheme.border, size: 40),
                        const SizedBox(height: 12),
                        Text(lang.t('Complete at least 1 record to unlock'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textSecondary
                                    .withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length,
                    itemBuilder: (ctx, i) {
                      final item = history[i];
                      final date = DateFormat('MMM d, yyyy')
                          .format(DateTime.parse(item['date']));
                      final sets = item['sets'] as List<ExerciseSet>;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(date,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const SizedBox(height: 8),
                            ...sets
                                .map((s) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.check,
                                              color: AppTheme.accent, size: 12),
                                          const SizedBox(width: 8),
                                          Text(
                                              '${units.fmtNum(units.toDisplay(s.weight))} ${units.unit}  x  ${s.reps}',
                                              style: const TextStyle(
                                                  color: AppTheme.textSecondary,
                                                  fontFamily: 'monospace',
                                                  fontSize: 13)),
                                        ],
                                      ),
                                    ))
                                .toList()
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _WarmupGuideSheet extends StatelessWidget {
  final String exerciseName;
  final double targetWeight;
  final bool hasHistory;
  final UnitService units;
  final LangService lang;

  const _WarmupGuideSheet({
    required this.exerciseName,
    required this.targetWeight,
    required this.hasHistory,
    required this.units,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasHistory) {
      return Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(minHeight: 200),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: AppTheme.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(lang.t('WARM UP'),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                  ],
                ),
                GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: AppTheme.textSecondary, size: 20)),
              ],
            ),
            const SizedBox(height: 40),
            const Icon(Icons.lock_outline, color: AppTheme.border, size: 40),
            const SizedBox(height: 12),
            Text(
              lang.t('Complete at least 1 record to unlock'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }

    final analysis = IntelligenceService().analyzeExercise(exerciseName);
    final double displayTarget = units.toDisplay(targetWeight);
    List<Map<String, dynamic>> warmupSets = [];

    final bool isBarbellOrCompound =
        (analysis.equipment == EquipmentType.barbell || analysis.isCompound);

    if (displayTarget <= 0) {
      warmupSets.add({'w': 0, 'r': '10', 'note': lang.t('Empty')});
    } else if (isBarbellOrCompound && displayTarget > 30) {
      double emptyBar = units.useLbs ? 45 : 20;
      double baseW =
          (displayTarget * 0.3 > emptyBar) ? displayTarget * 0.3 : emptyBar;

      warmupSets.add({'w': baseW, 'r': '8-10', 'note': lang.t('ACCLIMATION')});
      warmupSets.add({'w': displayTarget * 0.55, 'r': '5-8', 'note': '55%'});
      if (displayTarget > emptyBar * 2) {
        warmupSets.add({'w': displayTarget * 0.85, 'r': '1-3', 'note': '85%'});
      }
    } else {
      warmupSets.add({'w': displayTarget * 0.3, 'r': '10-15', 'note': '30%'});
      warmupSets.add({'w': displayTarget * 0.6, 'r': '5-8', 'note': '60%'});
      warmupSets.add({'w': displayTarget * 0.8, 'r': '2-3', 'note': '80%'});
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    lang.t('WARM UP'),
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close,
                    color: AppTheme.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Based on target: ${units.fmtNum(displayTarget)} ${units.unit}',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
          const SizedBox(height: 20),
          ...warmupSets
              .map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['note'],
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11)),
                        Text(
                            '${units.fmtNum(s['w'])} ${units.unit}  x  ${s['r']}',
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ))
              .toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatefulWidget {
  final Program program;
  final LangService lang;
  final Function(ProgramDay) onSelectDay;
  const _ProgramCard({
    required this.program,
    required this.lang,
    required this.onSelectDay,
  });
  @override
  State<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends State<_ProgramCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.program.isPreset
                ? AppTheme.border.withValues(alpha: 0.5)
                : AppTheme.border),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.program.isPreset
                          ? AppTheme.surface
                          : AppTheme.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.program.isPreset
                          ? Icons.verified_outlined
                          : Icons.build_circle_outlined,
                      color: widget.program.isPreset
                          ? AppTheme.textSecondary
                          : AppTheme.accent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.program.name.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '${widget.program.days.length} days',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            secondChild: const SizedBox.shrink(),
            firstChild: Column(
              children: [
                Container(height: 1, color: AppTheme.border),
                ...widget.program.days.map(
                  (day) => Tap(
                    onTap: () => widget.onSelectDay(day),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: widget.program.days.last == day
                                ? Colors.transparent
                                : AppTheme.border,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: AppTheme.accent,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  day.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  day.exercises.map((e) => e.name).join(' · '),
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: AppTheme.border,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final LoggedExercise exercise;
  final UnitService units;
  final LangService lang;
  final bool isProgram;
  final VoidCallback onAddSet,
      onRemove,
      onRename,
      onChanged,
      onSetCompleted,
      onShowHistory;
  final Function(double) onShowWarmup;
  final Function(int) onRemoveSet;
  const _ExerciseCard({
    required this.exercise,
    required this.units,
    required this.lang,
    required this.isProgram,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onRemove,
    required this.onRename,
    required this.onChanged,
    required this.onSetCompleted,
    required this.onShowHistory,
    required this.onShowWarmup,
  });

  @override
  Widget build(BuildContext context) {
    final done = exercise.sets.where((s) => s.completed).length,
        total = exercise.sets.length,
        pct = total > 0 ? done / total : 0.0;

    double maxWeight = 0;
    for (var s in exercise.sets) {
      if (s.weight > maxWeight) maxWeight = s.weight;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: pct),
                                duration: const Duration(milliseconds: 450),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 3,
                                  backgroundColor: AppTheme.border,
                                  color: AppTheme.accent,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$done/$total',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onShowWarmup(maxWeight),
                  icon: const Icon(Icons.local_fire_department,
                      color: AppTheme.textSecondary, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onShowHistory,
                  icon: const Icon(Icons.history,
                      color: AppTheme.textSecondary, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      color: AppTheme.textSecondary, size: 20),
                  color: AppTheme.surface,
                  padding: EdgeInsets.zero,
                  onSelected: (val) {
                    if (val == 'rename') onRename();
                    if (val == 'delete') onRemove();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'rename',
                        child: Text(lang.t('RENAME EXERCISE'),
                            style: const TextStyle(
                                color: AppTheme.gold, fontSize: 13))),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text(lang.t('DELETE'),
                            style: const TextStyle(
                                color: AppTheme.danger, fontSize: 13))),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: Row(
              children: [
                const SizedBox(width: 26),
                const SizedBox(width: 30),
                Expanded(
                  child: Text(
                    units.unit,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    lang.t('REPS'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ),
          ),
          ...exercise.sets.asMap().entries.map(
                (e) => _SetRow(
                  index: e.key,
                  set: e.value,
                  units: units,
                  isProgram: isProgram,
                  onRemove: () => onRemoveSet(e.key),
                  onChanged: onChanged,
                  onSetCompleted: onSetCompleted,
                ),
              ),
          if (!isProgram)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Tap(
                onTap: onAddSet,
                child: Container(
                  height: 34,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.border),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '+ ${lang.t('ADD SET')}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DropSetRow extends StatefulWidget {
  final DropSetRecord dropSet;
  final UnitService units;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _DropSetRow({
    required this.dropSet,
    required this.units,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_DropSetRow> createState() => _DropSetRowState();
}

class _DropSetRowState extends State<_DropSetRow> {
  late TextEditingController _dwCtrl, _drCtrl;

  @override
  void initState() {
    super.initState();
    _dwCtrl = TextEditingController(
        text: widget.dropSet.weight == 0
            ? ''
            : widget.units
                .fmtNum(widget.units.toDisplay(widget.dropSet.weight)));
    _drCtrl = TextEditingController(
        text: widget.dropSet.reps == 0 ? '' : widget.dropSet.reps.toString());
  }

  @override
  void dispose() {
    _dwCtrl.dispose();
    _drCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: 56),
          const Icon(Icons.subdirectory_arrow_right,
              color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: _NField(
              ctrl: _dwCtrl,
              hint: 'kg/lbs',
              isDropSetStyle: true,
              onChanged: (v) {
                widget.dropSet.weight =
                    widget.units.toKg(double.tryParse(v) ?? 0);
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _NField(
              ctrl: _drCtrl,
              hint: 'reps',
              isInt: true,
              isDropSetStyle: true,
              onChanged: (v) {
                widget.dropSet.reps = int.tryParse(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 14, color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final ExerciseSet set;
  final UnitService units;
  final bool isProgram;
  final VoidCallback onRemove, onChanged, onSetCompleted;
  const _SetRow({
    required this.index,
    required this.set,
    required this.units,
    required this.isProgram,
    required this.onRemove,
    required this.onChanged,
    required this.onSetCompleted,
  });
  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late TextEditingController _wCtrl, _rCtrl;
  bool _prevUseLbs = false;
  @override
  void initState() {
    super.initState();
    _prevUseLbs = widget.units.useLbs;
    _wCtrl = TextEditingController(text: _wText());
    _rCtrl = TextEditingController(
      text: widget.set.reps == 0 ? '' : '${widget.set.reps}',
    );
    widget.units.addListener(_onUnitChange);
  }

  String _wText() {
    if (widget.set.weight == 0) return '';
    return widget.units.fmtNum(widget.units.toDisplay(widget.set.weight));
  }

  void _onUnitChange() {
    if (_prevUseLbs != widget.units.useLbs) {
      _prevUseLbs = widget.units.useLbs;
      _wCtrl.text = _wText();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _rCtrl.dispose();
    widget.units.removeListener(_onUnitChange);
    super.dispose();
  }

  String _calc1RM() {
    if (widget.set.weight == 0 || widget.set.reps <= 0) return '';
    if (widget.set.reps == 1) {
      return widget.units.fmtNum(widget.units.toDisplay(widget.set.weight));
    }
    double rm = widget.set.weight * (36 / (37 - widget.set.reps));
    return widget.units.fmtNum(widget.units.toDisplay(rm));
  }

  @override
  Widget build(BuildContext context) {
    final done = widget.set.completed;
    final est1RM = _calc1RM();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              ElasticScale(
                trigger: done,
                child: GestureDetector(
                  onTap: () {
                    bool wasDone = widget.set.completed;
                    widget.set.completed = !wasDone;
                    widget.onChanged();
                    setState(() {});
                    if (!wasDone) widget.onSetCompleted();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: done ? AppTheme.accent : Colors.transparent,
                      border: Border.all(
                        color: done ? AppTheme.accent : AppTheme.border,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: done
                        ? const Icon(Icons.check, size: 14, color: Colors.black)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 22,
                child: Text(
                  '${widget.index + 1}',
                  style: TextStyle(
                    color: done ? AppTheme.accent : AppTheme.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: _NField(
                  ctrl: _wCtrl,
                  hint: '0',
                  onChanged: (v) {
                    widget.set.weight =
                        widget.units.toKg(double.tryParse(v) ?? 0);
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _NField(
                  ctrl: _rCtrl,
                  hint: '0',
                  isInt: true,
                  onChanged: (v) {
                    widget.set.reps = int.tryParse(v) ?? 0;
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 4),
              if (!widget.isProgram)
                GestureDetector(
                  onTap: widget.onRemove,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(width: 22),
            ],
          ),
          if (widget.set.isDropSet == true && widget.set.dropSets != null)
            ...widget.set.dropSets!.asMap().entries.map((e) => _DropSetRow(
                  dropSet: e.value,
                  units: widget.units,
                  onChanged: widget.onChanged,
                  onRemove: () {
                    setState(() => widget.set.dropSets!.removeAt(e.key));
                    widget.onChanged();
                  },
                )),
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 30),
                  child: Tap(
                    onTap: () {
                      setState(() {
                        widget.set.isDropSet = true;
                        widget.set.dropSets ??= [];
                        widget.set.dropSets!.add(DropSetRecord(
                            weight: widget.set.weight, reps: widget.set.reps));
                      });
                      widget.onChanged();
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_drop_down_circle_outlined,
                            size: 12, color: AppTheme.danger),
                        const SizedBox(width: 4),
                        const Text('DROP SET',
                            style: TextStyle(
                                color: AppTheme.danger,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (est1RM.isNotEmpty)
                  Text(
                    'EST. 1RM: $est1RM',
                    style: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                        fontSize: 9,
                        fontFamily: 'monospace'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool isInt;
  final bool isDropSetStyle;
  final Function(String) onChanged;

  const _NField({
    required this.ctrl,
    required this.hint,
    this.isInt = false,
    this.isDropSetStyle = false,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      textAlign: TextAlign.center,
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(
        color: isDropSetStyle ? AppTheme.danger : Colors.white,
        fontSize: isDropSetStyle ? 12 : 14,
        fontWeight: FontWeight.w900,
        fontFamily: 'monospace',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.border, fontSize: 13),
        contentPadding: EdgeInsets.symmetric(
            horizontal: 6, vertical: isDropSetStyle ? 4 : 8),
        isDense: true,
        filled: true,
        fillColor: isDropSetStyle ? AppTheme.bg : AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
              color: isDropSetStyle
                  ? AppTheme.danger.withOpacity(0.5)
                  : AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
              color: isDropSetStyle
                  ? AppTheme.danger.withOpacity(0.5)
                  : AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
              color: isDropSetStyle ? AppTheme.danger : AppTheme.accent,
              width: 1.5),
        ),
      ),
      onChanged: onChanged,
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String title, message;
  final bool danger;
  const _ConfirmDialog({
    required this.title,
    required this.message,
    this.danger = false,
  });
  @override
  Widget build(BuildContext context) {
    final lang = LangService();
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: TextStyle(
          color: danger ? AppTheme.danger : AppTheme.textPrimary,
          fontSize: 13,
          letterSpacing: 1.5,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            lang.t('CANCEL'),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            lang.t('CONFIRM'),
            style: TextStyle(
              color: danger ? AppTheme.danger : AppTheme.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputDialog extends StatelessWidget {
  final String title, hint;
  final TextEditingController ctrl;
  const _InputDialog({
    required this.title,
    required this.hint,
    required this.ctrl,
  });
  @override
  Widget build(BuildContext context) {
    final lang = LangService();
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          letterSpacing: 1.5,
        ),
      ),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            lang.t('CANCEL'),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              Navigator.pop(context, ctrl.text.trim());
            }
          },
          child: Text(
            lang.t('ADD'),
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
