// lib/screens/programs_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/storage_service.dart';
import '../services/app_theme.dart';
import '../services/lang_service.dart';
import '../widgets/anim.dart';

class ProgramsScreen extends StatefulWidget {
  const ProgramsScreen({super.key});

  @override
  State<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  final _store = StorageService();
  final _lang = LangService();
  final _uuid = const Uuid();
  List<Program> _programs = [];
  bool _loading = true;

  Set<String> _completedDates = {};
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_updateUI);
    _store.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _lang.removeListener(_updateUI);
    _store.removeListener(_onDataChanged);
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  void _onDataChanged() {
    _load();
  }

  Future<void> _load() async {
    final p = await _store.loadPrograms();
    await _loadActivity();
    if (mounted) {
      setState(() {
        _programs = p;
        _loading = false;
      });
    }
  }

  Future<void> _loadActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('log_'));
    final Set<String> dates = {};

    for (var k in keys) {
      final str = prefs.getString(k);
      if (str != null) {
        try {
          final l = WorkoutLog.fromJson(jsonDecode(str));
          if (l.isCompleted) dates.add(l.date);
        } catch (_) {}
      }
    }

    int streak = 0;
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final d = today.subtract(Duration(days: i));
      final dk = DateFormat('yyyy-MM-dd').format(d);
      if (dates.contains(dk)) {
        streak++;
      } else {
        if (i == 0) continue;
        break;
      }
    }

    _completedDates = dates;
    _streak = streak;
  }

  Future<void> _createProgram() async {
    final name =
        await _showNameDialog(_lang.t('NEW PROGRAM'), 'e.g. PPL, 5/3/1');
    if (name == null || name.isEmpty) return;
    final p = Program(
        id: _uuid.v4(),
        name: name,
        days: [],
        createdAt: DateTime.now(),
        isPreset: false);
    await _store.upsertProgram(p);
    if (mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => _ProgramEditor(programId: p.id)));
    }
  }

  Future<void> _deleteProgram(String id) async {
    await _store.deleteProgram(id);
  }

  Future<String?> _showNameDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _NameDialog(title: title, hint: hint, ctrl: ctrl),
    );
  }

  Widget _buildActivityHeatmap() {
    final today = DateTime.now();
    List<Widget> boxes = [];

    for (int i = 34; i >= 0; i--) {
      final d = today.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(d);
      final isDone = _completedDates.contains(dateKey);

      boxes.add(Container(
        decoration: BoxDecoration(
          color: isDone ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.5),
          ),
          boxShadow: isDone
              ? [
                  BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
      ));
    }

    return FadeIn(
      delay: const Duration(milliseconds: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: AppTheme.gold, size: 20),
                    const SizedBox(width: 8),
                    Text(_lang.t('ACTIVITY'),
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5)),
                  ],
                ),
                Text('$_streak ${_lang.t("DAYS")} ${_lang.t("STREAK")}',
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: 35,
              itemBuilder: (ctx, i) => boxes[i],
            ),
          ],
        ),
      ),
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
                letterSpacing: 1.5),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8)),
            child: Text('$count',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          children: children,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customPrograms = _programs.where((p) => !p.isPreset).toList();
    final presetPrograms = _programs.where((p) => p.isPreset).toList();

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.card,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _lang.t('PROGRAMS').toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2),
                      ),
                      // 移除匯入按鈕
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildActivityHeatmap(),
                  _buildExpansionBox(
                    title: _lang.t('CUSTOM PROGRAMS'),
                    icon: Icons.build_circle_outlined,
                    count: customPrograms.length,
                    initiallyExpanded: true,
                    children: customPrograms.isEmpty
                        ? [_buildEmpty()]
                        : customPrograms
                            .map((p) => _ProgramTile(
                                  program: p,
                                  onEdit: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              _ProgramEditor(programId: p.id))),
                                  onDelete: () => _deleteProgram(p.id),
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
                          .map((p) => _ProgramTile(
                                program: p,
                                onEdit: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            _ProgramEditor(programId: p.id))),
                                onDelete: () {},
                              ))
                          .toList(),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: Tap(
        onTap: _createProgram,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4))
            ],
          ),
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),
    );
  }

  Widget _buildEmpty() => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 12),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border)),
                child: const Icon(Icons.library_add_outlined,
                    color: AppTheme.border, size: 28),
              ),
              const SizedBox(height: 16),
              Text(_lang.t('NO CUSTOM PROGRAMS'),
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      letterSpacing: 2,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_lang.t('Tap + to create your own'),
                  style: const TextStyle(color: AppTheme.border, fontSize: 11)),
            ],
          ),
        ),
      );
}

class _ProgramTile extends StatelessWidget {
  final Program program;
  final VoidCallback onEdit, onDelete;
  const _ProgramTile(
      {required this.program, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: program.isPreset
                    ? AppTheme.surface
                    : AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  program.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                      color: program.isPreset
                          ? AppTheme.textSecondary
                          : AppTheme.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program.name.toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    program.days.isEmpty
                        ? 'No days yet'
                        : program.days.map((d) => d.name).join(' · '),
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!program.isPreset)
              Tap(
                onTap: onDelete,
                child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline,
                        color: AppTheme.danger, size: 18)),
              ),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ProgramEditor extends StatefulWidget {
  final String programId;
  const _ProgramEditor({required this.programId});
  @override
  State<_ProgramEditor> createState() => _ProgramEditorState();
}

class _ProgramEditorState extends State<_ProgramEditor> {
  final _store = StorageService();
  final _lang = LangService();
  final _uuid = const Uuid();
  Program? _program;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_updateUI);
    _store.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _lang.removeListener(_updateUI);
    _store.removeListener(_onDataChanged);
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  void _onDataChanged() {
    _load();
  }

  Future<void> _load() async {
    final programs = await _store.loadPrograms();
    if (mounted) {
      try {
        final prog = programs.firstWhere((p) => p.id == widget.programId);
        setState(() => _program = prog);
      } catch (e) {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _save() async {
    if (_program != null && !_program!.isPreset) {
      await _store.upsertProgram(_program!);
    }
  }

  Future<void> _addDay() async {
    if (_program!.isPreset) return;
    final name = await _showNameDialog(_lang.t('NEW DAY'), 'e.g. Push A, Legs');
    if (name == null || name.isEmpty) return;
    setState(() => _program!.days
        .add(ProgramDay(id: _uuid.v4(), name: name, exercises: [])));
    await _save();
  }

  Future<void> _editDay(ProgramDay day) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                _DayEditor(programId: _program!.id, dayId: day.id)));
  }

  Future<void> _deleteDay(String id) async {
    if (_program!.isPreset) return;
    setState(() => _program!.days.removeWhere((d) => d.id == id));
    await _save();
  }

  Future<void> _renameProgram() async {
    if (_program!.isPreset) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_lang.t('Preset programs cannot be renamed.')),
          backgroundColor: AppTheme.surface));
      return;
    }
    final ctrl = TextEditingController(text: _program!.name);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(
          title: _lang.t('RENAME PROGRAM'), hint: _program!.name, ctrl: ctrl),
    );
    if (name != null && name.isNotEmpty) {
      setState(() => _program!.name = name);
      await _save();
    }
  }

  Future<String?> _showNameDialog(String title, String hint) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _NameDialog(title: title, hint: hint, ctrl: ctrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      return const Scaffold(
          backgroundColor: AppTheme.bg,
          body:
              Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    }
    final isPreset = _program!.isPreset;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _renameProgram,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_program!.name.toUpperCase()),
              const SizedBox(width: 6),
              if (!isPreset)
                const Icon(Icons.edit, size: 14, color: AppTheme.textSecondary)
              else
                const Icon(Icons.lock_outline,
                    size: 14, color: AppTheme.textSecondary),
            ],
          ),
        ),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context)),
        // 移除 actions 裡的分享按鈕
      ),
      body: _program!.days.isEmpty
          ? Center(
              child: FadeIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today,
                        color: AppTheme.border, size: 48),
                    const SizedBox(height: 14),
                    Text(_lang.t('NO DAYS YET'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            letterSpacing: 2,
                            fontSize: 12)),
                  ],
                ),
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: isPreset
                  ? (oldIdx, newIdx) {}
                  : (old, newIdx) {
                      setState(() {
                        if (newIdx > old) newIdx--;
                        final d = _program!.days.removeAt(old);
                        _program!.days.insert(newIdx, d);
                      });
                      _save();
                    },
              children: _program!.days
                  .asMap()
                  .entries
                  .map(
                    (e) => FadeIn(
                      key: ValueKey(e.value.id),
                      delay: Duration(milliseconds: e.key * 50),
                      child: _DayTile(
                          day: e.value,
                          isPreset: isPreset,
                          onTap: () => _editDay(e.value),
                          onDelete: () => _deleteDay(e.value.id)),
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: isPreset
          ? null
          : Tap(
              onTap: _addDay,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 4))
                    ]),
                child: const Icon(Icons.add, color: Colors.black, size: 28),
              ),
            ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final ProgramDay day;
  final bool isPreset;
  final VoidCallback onTap, onDelete;
  const _DayTile(
      {required this.day,
      required this.isPreset,
      required this.onTap,
      required this.onDelete});
  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border)),
        child: Row(
          children: [
            if (!isPreset) ...[
              const Icon(Icons.drag_indicator,
                  color: AppTheme.border, size: 18),
              const SizedBox(width: 10),
            ],
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.wb_sunny_outlined,
                  color: AppTheme.accent, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(day.name.toUpperCase(),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1)),
                  Text(
                      day.exercises.isEmpty
                          ? 'No exercises'
                          : '${day.exercises.length} exercises',
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            if (!isPreset)
              Tap(
                  onTap: onDelete,
                  child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.delete_outline,
                          color: AppTheme.danger, size: 18))),
            const Icon(Icons.chevron_right,
                color: AppTheme.textSecondary, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DayEditor extends StatefulWidget {
  final String programId, dayId;
  const _DayEditor({required this.programId, required this.dayId});
  @override
  State<_DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<_DayEditor> {
  final _store = StorageService();
  final _lang = LangService();
  final _uuid = const Uuid();
  Program? _program;
  ProgramDay? _day;

  @override
  void initState() {
    super.initState();
    _lang.addListener(_updateUI);
    _store.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    _lang.removeListener(_updateUI);
    _store.removeListener(_onDataChanged);
    super.dispose();
  }

  void _updateUI() {
    if (mounted) setState(() {});
  }

  void _onDataChanged() {
    _load();
  }

  Future<void> _load() async {
    final programs = await _store.loadPrograms();
    if (mounted) {
      try {
        final prog = programs.firstWhere((p) => p.id == widget.programId);
        setState(() {
          _program = prog;
          _day = prog.days.firstWhere((d) => d.id == widget.dayId);
        });
      } catch (e) {
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _save() async {
    if (_program != null && !_program!.isPreset) {
      await _store.upsertProgram(_program!);
    }
  }

  void _openExerciseSheet({TemplateExercise? existingEx}) {
    if (_program!.isPreset && existingEx != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppTheme.bg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => _ExerciseConfigSheet(
            initialEx: existingEx,
            isReadOnly: true,
            onSave: (_, __, ___, ____) {}),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ExerciseConfigSheet(
        initialEx: existingEx,
        isReadOnly: false,
        onSave: (name, sets, scheme, tips) {
          setState(() {
            if (existingEx == null) {
              _day!.exercises.add(TemplateExercise(
                  id: _uuid.v4(),
                  name: name,
                  defaultSets: sets,
                  scheme: scheme,
                  tips: tips));
            } else {
              existingEx.name = name;
              existingEx.defaultSets = sets;
              existingEx.scheme = scheme;
              existingEx.tips = tips;
            }
          });
          _save();
        },
      ),
    );
  }

  void _removeExercise(String id) {
    if (_program!.isPreset) return;
    setState(() => _day!.exercises.removeWhere((e) => e.id == id));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    if (_day == null)
      return const Scaffold(
          backgroundColor: AppTheme.bg,
          body:
              Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    final isPreset = _program!.isPreset;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_day!.name.toUpperCase()),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => Navigator.pop(context)),
      ),
      body: _day!.exercises.isEmpty
          ? Center(
              child: FadeIn(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fitness_center,
                        color: AppTheme.border, size: 48),
                    const SizedBox(height: 14),
                    Text(_lang.t('NO EXERCISES'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            letterSpacing: 2,
                            fontSize: 12)),
                  ],
                ),
              ),
            )
          : ReorderableListView(
              padding: const EdgeInsets.all(16),
              onReorder: isPreset
                  ? (oldIdx, newIdx) {}
                  : (old, newIdx) {
                      setState(() {
                        if (newIdx > old) newIdx--;
                        final ex = _day!.exercises.removeAt(old);
                        _day!.exercises.insert(newIdx, ex);
                      });
                      _save();
                    },
              children: _day!.exercises
                  .asMap()
                  .entries
                  .map(
                    (e) => FadeIn(
                      key: ValueKey(e.value.id),
                      delay: Duration(milliseconds: e.key * 50),
                      child: _TemplateExRow(
                          ex: e.value,
                          isPreset: isPreset,
                          onTap: () => _openExerciseSheet(existingEx: e.value),
                          onRemove: () => _removeExercise(e.value.id)),
                    ),
                  )
                  .toList(),
            ),
      floatingActionButton: isPreset
          ? null
          : Tap(
              onTap: () => _openExerciseSheet(),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 4))
                    ]),
                child: const Icon(Icons.add, color: Colors.black, size: 28),
              ),
            ),
    );
  }
}

class _TemplateExRow extends StatelessWidget {
  final TemplateExercise ex;
  final bool isPreset;
  final VoidCallback onTap, onRemove;
  const _TemplateExRow(
      {required this.ex,
      required this.isPreset,
      required this.onTap,
      required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final lang = LangService();
    final hasScheme = ex.scheme != null && ex.scheme!.trim().isNotEmpty;
    final hasTips = ex.tips != null && ex.tips!.trim().isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isPreset) ...[
            const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.drag_indicator,
                    color: AppTheme.border, size: 18)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(ex.name.toUpperCase(),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 1))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('${ex.defaultSets} ${lang.t('SETS')}',
                          style: const TextStyle(
                              color: AppTheme.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (hasScheme) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.5),
                        )),
                    child: Text(ex.scheme!.toUpperCase(),
                        style: const TextStyle(
                            color: AppTheme.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                  ),
                ],
                if (hasTips) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppTheme.gold, size: 12),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(ex.tips!,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                  height: 1.4))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Tap(
                  onTap: onTap,
                  child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                          isPreset ? Icons.info_outline : Icons.edit_outlined,
                          color: AppTheme.textSecondary,
                          size: 18))),
              if (!isPreset) ...[
                const SizedBox(height: 4),
                Tap(
                    onTap: onRemove,
                    child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.delete_outline,
                            color: AppTheme.danger, size: 18))),
              ]
            ],
          ),
        ],
      ),
    );
  }
}

class _ExerciseConfigSheet extends StatefulWidget {
  final TemplateExercise? initialEx;
  final bool isReadOnly;
  final Function(String name, int sets, String? scheme, String? tips) onSave;
  const _ExerciseConfigSheet(
      {this.initialEx, this.isReadOnly = false, required this.onSave});
  @override
  State<_ExerciseConfigSheet> createState() => _ExerciseConfigSheetState();
}

class _ExerciseConfigSheetState extends State<_ExerciseConfigSheet> {
  final _lang = LangService();
  late TextEditingController _nameCtrl, _schemeCtrl, _tipsCtrl;
  int _sets = 3;
  final List<String> _schemePresets = [
    '3x10 Hypertrophy',
    '5x5 Strength',
    '2 Sets to Failure',
    'Drop Set',
    'Top Set + Backoffs'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialEx?.name ?? '');
    _schemeCtrl = TextEditingController(text: widget.initialEx?.scheme ?? '');
    _tipsCtrl = TextEditingController(text: widget.initialEx?.tips ?? '');
    _sets = widget.initialEx?.defaultSets ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialEx != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  widget.isReadOnly
                      ? _lang.t('EXERCISE INFO')
                      : (isEditing
                          ? _lang.t('EDIT EXERCISE')
                          : _lang.t('TACTICAL CONFIG')),
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2)),
              GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close,
                      color: AppTheme.textSecondary, size: 20)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  flex: 2,
                  child: _buildInputField(_lang.t('EXERCISE NAME'),
                      'e.g. Barbell Squat', _nameCtrl, 1,
                      readOnly: widget.isReadOnly)),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_lang.t('SETS'),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.border)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Tap(
                              onTap: widget.isReadOnly
                                  ? () {}
                                  : () => setState(
                                      () => _sets = (_sets - 1).clamp(1, 20)),
                              child: Icon(Icons.remove,
                                  size: 16,
                                  color: widget.isReadOnly
                                      ? AppTheme.surface
                                      : AppTheme.textSecondary)),
                          Text('$_sets',
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Tap(
                              onTap: widget.isReadOnly
                                  ? () {}
                                  : () => setState(
                                      () => _sets = (_sets + 1).clamp(1, 20)),
                              child: Icon(Icons.add,
                                  size: 16,
                                  color: widget.isReadOnly
                                      ? AppTheme.surface
                                      : AppTheme.accent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(_lang.t('SCHEME / PROTOCOL (OPTIONAL)'),
              'e.g. 2 Sets to Failure', _schemeCtrl, 1,
              readOnly: widget.isReadOnly),
          if (!widget.isReadOnly) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _schemePresets
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Tap(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _schemeCtrl.text = s);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  border: Border.all(color: AppTheme.border),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(s,
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildInputField(_lang.t('TRAINER TIPS (OPTIONAL)'),
              'Focus points, tempo, or cues...', _tipsCtrl, 3,
              readOnly: widget.isReadOnly),
          const SizedBox(height: 24),
          if (!widget.isReadOnly)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  if (_nameCtrl.text.trim().isEmpty) return;
                  widget.onSave(
                      _nameCtrl.text.trim(),
                      _sets,
                      _schemeCtrl.text.trim().isNotEmpty
                          ? _schemeCtrl.text.trim()
                          : null,
                      _tipsCtrl.text.trim().isNotEmpty
                          ? _tipsCtrl.text.trim()
                          : null);
                  Navigator.pop(context);
                },
                child: Text(
                    isEditing
                        ? _lang.t('UPDATE CONFIG')
                        : _lang.t('DEPLOY EXERCISE'),
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5)),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildInputField(
          String label, String hint, TextEditingController ctrl, int lines,
          {bool readOnly = false}) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: lines,
            readOnly: readOnly,
            style: TextStyle(
                color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppTheme.border),
              filled: true,
              fillColor: AppTheme.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppTheme.accent, width: 1.5)),
            ),
          ),
        ],
      );
}

class _NameDialog extends StatelessWidget {
  final String title, hint;
  final TextEditingController ctrl;
  const _NameDialog(
      {required this.title, required this.hint, required this.ctrl});
  @override
  Widget build(BuildContext context) {
    final lang = LangService();
    return AlertDialog(
      backgroundColor: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(title,
          style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 13, letterSpacing: 1.5)),
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
            child: Text(lang.t('CANCEL'),
                style: const TextStyle(color: AppTheme.textSecondary))),
        TextButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty)
                Navigator.pop(context, ctrl.text.trim());
            },
            child: Text(lang.t('SAVE'),
                style: const TextStyle(
                    color: AppTheme.accent, fontWeight: FontWeight.bold))),
      ],
    );
  }
}
