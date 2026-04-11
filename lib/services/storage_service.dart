// lib/services/storage_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class StorageService extends ChangeNotifier {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final _uuid = const Uuid();

  // ==========================================
  // 1. 課表管理 (Programs)
  // ==========================================

  Future<List<Program>> loadPrograms() async {
    final prefs = await SharedPreferences.getInstance();
    final String? programsJson = prefs.getString('programs');

    if (programsJson != null && programsJson.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(programsJson);
        List<Program> loaded = decoded.map((e) => Program.fromJson(e)).toList();

        final presetNames = [
          'Mass Building PPL',
          '5/3/1 Strength (Compound)',
          'Arnold Split (Dr. Swole)',
          'Minimalist Full Body (Jeff Nippard)'
        ];
        bool needsSave = false;
        for (var p in loaded) {
          if (presetNames.contains(p.name) && !p.isPreset) {
            p.isPreset = true;
            needsSave = true;
          }
        }
        if (needsSave) {
          prefs.setString(
              'programs', jsonEncode(loaded.map((e) => e.toJson()).toList()));
        }
        return loaded;
      } catch (e) {
        debugPrint('Error decoding programs: $e');
      }
    }

    final defaultPrograms = _generateDefaultPrograms();
    await savePrograms(defaultPrograms);
    return defaultPrograms;
  }

  Future<void> savePrograms(List<Program> programs) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(programs.map((e) => e.toJson()).toList());
    await prefs.setString('programs', encoded);
    notifyListeners();
  }

  Future<void> upsertProgram(Program program) async {
    final programs = await loadPrograms();
    final index = programs.indexWhere((p) => p.id == program.id);
    if (index >= 0) {
      programs[index] = program;
    } else {
      programs.insert(0, program);
    }
    await savePrograms(programs);
  }

  Future<void> deleteProgram(String id) async {
    final programs = await loadPrograms();
    programs.removeWhere((p) => p.id == id);
    await savePrograms(programs);
  }

  // ⭐️ 裝甲級匯入系統 (v2 極簡版)
  Future<bool> importProgramFromCode(String code) async {
    try {
      // 交給 Model 解析並由 Storage 提供 UUID 生成器
      final Program imported = Program.fromShareCode(code, () => _uuid.v4());
      await upsertProgram(imported);
      return true;
    } catch (e) {
      debugPrint('Import Error: $e');
      return false;
    }
  }

  // ==========================================
  // 2. 訓練紀錄管理 (Workout Logs)
  // ==========================================

  Future<WorkoutLog?> getLog(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final String? logJson = prefs.getString('log_$date');
    if (logJson != null && logJson.isNotEmpty) {
      try {
        return WorkoutLog.fromJson(jsonDecode(logJson));
      } catch (e) {
        debugPrint('Error decoding log for $date: $e');
      }
    }
    return null;
  }

  Future<void> saveLog(WorkoutLog log) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(log.toJson());
    await prefs.setString('log_${log.date}', encoded);
    notifyListeners();
  }

  Future<void> deleteLog(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('log_$date');
    notifyListeners();
  }

  Future<List<ExerciseSet>> getLastSetsFor(String exerciseName) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('log_')).toList()
      ..sort((a, b) => b.compareTo(a));
    for (String key in keys) {
      final logStr = prefs.getString(key);
      if (logStr != null) {
        final log = WorkoutLog.fromJson(jsonDecode(logStr));
        if (log.isCompleted) {
          for (var ex in log.exercises) {
            if (ex.name == exerciseName && ex.sets.isNotEmpty) return ex.sets;
          }
        }
      }
    }
    return [];
  }

  // ==========================================
  // 3. PR 紀錄
  // ==========================================

  Future<List<PersonalRecord>> loadPRs() async {
    final prefs = await SharedPreferences.getInstance();
    final prJson = prefs.getString('manual_prs');
    if (prJson != null && prJson.isNotEmpty) {
      try {
        return (jsonDecode(prJson) as List)
            .map((e) => PersonalRecord.fromJson(e))
            .toList();
      } catch (e) {
        debugPrint('Error decoding PRs: $e');
      }
    }
    return [];
  }

  Future<void> saveManualPR(PersonalRecord pr) async {
    final prs = await loadPRs();
    final index = prs.indexWhere((p) => p.id == pr.id);
    if (index >= 0)
      prs[index] = pr;
    else
      prs.add(pr);
    prs.sort((a, b) => b.weight.compareTo(a.weight));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'manual_prs', jsonEncode(prs.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> deletePR(String id) async {
    final prs = await loadPRs();
    prs.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'manual_prs', jsonEncode(prs.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  // ==========================================
  // 4. 預設資料生成 (Default Data) - 完整保留
  // ==========================================

  List<Program> _generateDefaultPrograms() {
    final now = DateTime.now();
    return [
      // 1. Mass Building PPL
      Program(
        id: 'preset_ppl',
        name: 'Mass Building PPL',
        createdAt: now,
        isPreset: true,
        days: [
          ProgramDay(
              id: _uuid.v4(),
              name: 'Push (Chest/Shoulders/Triceps)',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Barbell Bench Press',
                    defaultSets: 4,
                    scheme: 'Top Set + Backoffs',
                    tips: 'Control the eccentric, pause at chest.',
                    targetMuscles: {
                      'Chest': 1.0,
                      'Triceps': 0.4,
                      'FrontDelts': 0.3
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Overhead Press',
                    defaultSets: 3,
                    scheme: '3x8-10',
                    tips: 'Squeeze glutes, push head through at the top.',
                    targetMuscles: {
                      'FrontDelts': 1.0,
                      'Triceps': 0.6,
                      'UpperChest': 0.2
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Incline Dumbbell Press',
                    defaultSets: 3,
                    scheme: '3x10-12 Hypertrophy',
                    targetMuscles: {
                      'UpperChest': 1.0,
                      'FrontDelts': 0.5,
                      'Triceps': 0.3
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Lateral Raise',
                    defaultSets: 4,
                    scheme: 'Drop Set on Last Set',
                    tips: 'Slight lean forward, pour the water.',
                    targetMuscles: {'SideDelts': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Tricep Rope Pushdown',
                    defaultSets: 3,
                    scheme: '3x12-15',
                    targetMuscles: {'Triceps': 1.0}),
              ]),
          ProgramDay(id: _uuid.v4(), name: 'Pull (Back/Biceps)', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Deadlift',
                defaultSets: 3,
                scheme: '1x5 Heavy, 2x8 Backoffs',
                tips: 'Brace core, push the floor away.',
                targetMuscles: {
                  'Glutes': 1.0,
                  'Hamstrings': 0.8,
                  'LowerBack': 0.8,
                  'Lats': 0.4
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Lat Pulldown',
                defaultSets: 3,
                scheme: '3x10-12',
                tips: 'Pull with your elbows, chest up.',
                targetMuscles: {'Lats': 1.0, 'Biceps': 0.4, 'RearDelts': 0.2}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Barbell Row',
                defaultSets: 3,
                scheme: '3x8-10',
                tips: 'Keep torso angle fixed, squeeze lats.',
                targetMuscles: {'Lats': 0.8, 'Rhomboids': 1.0, 'Biceps': 0.5}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Face Pulls',
                defaultSets: 3,
                scheme: '3x15-20',
                tips: 'Focus on rear delts and external rotation.',
                targetMuscles: {'RearDelts': 1.0, 'Traps': 0.6}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'EZ Bar Curls',
                defaultSets: 3,
                scheme: '3x10-12',
                targetMuscles: {'Biceps': 1.0}),
          ]),
          ProgramDay(
              id: _uuid.v4(),
              name: 'Legs (Quads/Hams/Calves)',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Barbell Squat',
                    defaultSets: 4,
                    scheme: 'Top Set + Backoffs',
                    tips: 'Drive knees out, chest tall.',
                    targetMuscles: {
                      'Quads': 1.0,
                      'Glutes': 0.7,
                      'LowerBack': 0.4
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Romanian Deadlift (RDL)',
                    defaultSets: 3,
                    scheme: '3x8-10',
                    tips: 'Hinge at hips, feel the hamstring stretch.',
                    targetMuscles: {
                      'Hamstrings': 1.0,
                      'Glutes': 0.8,
                      'LowerBack': 0.5
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Leg Press',
                    defaultSets: 3,
                    scheme: '3x10-15',
                    tips: 'Don\'t lock out knees completely.',
                    targetMuscles: {'Quads': 1.0, 'Glutes': 0.5}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Lying Leg Curls',
                    defaultSets: 3,
                    scheme: '3x12-15',
                    tips: 'Slow eccentric, hold at contraction.',
                    targetMuscles: {'Hamstrings': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Standing Calf Raises',
                    defaultSets: 4,
                    scheme: '4x15-20',
                    tips: 'Full stretch at bottom, hold 1s at top.',
                    targetMuscles: {'Calves': 1.0}),
              ]),
        ],
      ),

      // 2. Upper / Lower Strength
      Program(
        id: 'preset_ul',
        name: 'Upper / Lower Strength',
        createdAt: now,
        isPreset: true,
        days: [
          ProgramDay(id: _uuid.v4(), name: 'Upper Body A', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Bench Press',
                defaultSets: 4,
                scheme: '5x5 Strength',
                targetMuscles: {'Chest': 1.0, 'Triceps': 0.5}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Pendlay Row',
                defaultSets: 4,
                scheme: '5x5 Strength',
                targetMuscles: {'Lats': 1.0, 'Rhomboids': 0.8}),
          ]),
          ProgramDay(id: _uuid.v4(), name: 'Lower Body A', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Squat',
                defaultSets: 4,
                scheme: '5x5 Strength',
                targetMuscles: {'Quads': 1.0, 'Glutes': 0.7}),
          ]),
        ],
      ),

      // 3. Arnold Split (Dr. Swole)
      Program(
        id: 'preset_arnold',
        name: 'Arnold Split (Dr. Swole)',
        createdAt: now,
        isPreset: true,
        days: [
          ProgramDay(id: _uuid.v4(), name: 'Day 1: Chest & Back 1', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'DB Bench Press',
                defaultSets: 3,
                scheme: 'Top Set + 2 Back-offs',
                tips: 'Top: 5-8 reps, Back-offs: -10% weight 5-8 reps.',
                targetMuscles: {
                  'Chest': 1.0,
                  'FrontDelts': 0.3,
                  'Triceps': 0.4
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'T-Bar Row',
                defaultSets: 3,
                scheme: 'Top Set + 2 Back-offs',
                tips: 'Top: 6-10 reps, Back-offs: -10% weight 6-10 reps.',
                targetMuscles: {'Lats': 0.8, 'Rhomboids': 1.0, 'Biceps': 0.5}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Lat Pulldown',
                defaultSets: 3,
                scheme: '3x10-15 Hypertrophy',
                targetMuscles: {'Lats': 1.0, 'RearDelts': 0.2}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Cable Upright Row',
                defaultSets: 3,
                scheme: '3x6-10',
                tips: 'Side delts focus with traps involvement.',
                targetMuscles: {'SideDelts': 1.0, 'Traps': 0.7}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Abs (Triset)',
                defaultSets: 3,
                scheme: '3x12-20',
                tips: 'Hanging leg raises, crunches, etc.',
                targetMuscles: {'Core': 1.0}),
          ]),
          ProgramDay(
              id: _uuid.v4(),
              name: 'Day 2: Shoulders & Arms 1',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'DB Overhead Press',
                    defaultSets: 3,
                    scheme: 'Top Set + 2 Back-offs',
                    tips: 'Top: 5-8 reps, Back-offs: -10% weight.',
                    targetMuscles: {
                      'FrontDelts': 1.0,
                      'Triceps': 0.6,
                      'SideDelts': 0.4
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Dumbbell Curls',
                    defaultSets: 3,
                    scheme: '3x6-10',
                    targetMuscles: {'Biceps': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'EZ Bar Skull Crushers',
                    defaultSets: 3,
                    scheme: '3x8-12',
                    targetMuscles: {'Triceps': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Lying Bicep Curls',
                    defaultSets: 3,
                    scheme: '3x8-12',
                    tips: 'Lying flat on bench.',
                    targetMuscles: {'Biceps': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Cable Lateral Raise',
                    defaultSets: 3,
                    scheme: '3x8-12',
                    targetMuscles: {'SideDelts': 1.0}),
              ]),
          ProgramDay(id: _uuid.v4(), name: 'Day 3: Legs 1', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Front Squat',
                defaultSets: 3,
                scheme: 'Top Set + 2 Back-offs',
                tips: 'Top: 5-8 reps.',
                targetMuscles: {'Quads': 1.0, 'Glutes': 0.6, 'Core': 0.4}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Dumbbell RDL',
                defaultSets: 3,
                scheme: '3x6-10',
                tips: 'Use straps if grip fails.',
                targetMuscles: {
                  'Hamstrings': 1.0,
                  'Glutes': 0.8,
                  'LowerBack': 0.5
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Leg Press',
                defaultSets: 3,
                scheme: '3x8-12',
                targetMuscles: {'Quads': 1.0, 'Glutes': 0.5}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Calf Raises',
                defaultSets: 3,
                scheme: '3x8-12',
                tips: 'Take to failure.',
                targetMuscles: {'Calves': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Leg Curl',
                defaultSets: 2,
                scheme: '2x10-15',
                targetMuscles: {'Hamstrings': 1.0}),
          ]),
          ProgramDay(id: _uuid.v4(), name: 'Day 4: Chest & Back 2', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Incline Bench Press',
                defaultSets: 3,
                scheme: '3x6-10',
                targetMuscles: {
                  'UpperChest': 1.0,
                  'FrontDelts': 0.5,
                  'Triceps': 0.3
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Lat Pulldown',
                defaultSets: 3,
                scheme: '3x6-10',
                targetMuscles: {'Lats': 1.0, 'RearDelts': 0.2}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Cable Row',
                defaultSets: 3,
                scheme: '3x8-12',
                targetMuscles: {'Lats': 0.8, 'Rhomboids': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Cable Upright Row',
                defaultSets: 3,
                scheme: '3x10-15',
                targetMuscles: {'SideDelts': 1.0, 'Traps': 0.7}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Abs (Triset)',
                defaultSets: 3,
                scheme: '3x12-20',
                targetMuscles: {'Core': 1.0}),
          ]),
          ProgramDay(
              id: _uuid.v4(),
              name: 'Day 5: Shoulders & Arms 2',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Weighted Dips',
                    defaultSets: 3,
                    scheme: '3x6-10',
                    tips: 'Lower chest & triceps focus.',
                    targetMuscles: {
                      'LowerChest': 1.0,
                      'Triceps': 0.8,
                      'FrontDelts': 0.4
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'EZ Bar Preacher Curls',
                    defaultSets: 3,
                    scheme: '3x6-10',
                    targetMuscles: {'Biceps': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Rope Pressdown',
                    defaultSets: 3,
                    scheme: '3x10-15',
                    targetMuscles: {'Triceps': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Rope Hammer Curls',
                    defaultSets: 3,
                    scheme: '3x10-15',
                    targetMuscles: {'Biceps': 0.8, 'Brachialis': 1.0}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'DB Lateral Raise',
                    defaultSets: 3,
                    scheme: '3x10-15',
                    targetMuscles: {'SideDelts': 1.0}),
              ]),
          ProgramDay(id: _uuid.v4(), name: 'Day 6: Legs 2', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Trap Bar Deadlift',
                defaultSets: 2,
                scheme: 'Top Set + 1 Back-off',
                tips: 'Top: 5-8 reps, Back-off: 5-8 reps.',
                targetMuscles: {
                  'Glutes': 1.0,
                  'Hamstrings': 0.8,
                  'Quads': 0.4
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Smith Machine Squat',
                defaultSets: 3,
                scheme: '3x6-10',
                targetMuscles: {'Quads': 1.0, 'Glutes': 0.7}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Lunges',
                defaultSets: 3,
                scheme: '3x8-12',
                targetMuscles: {
                  'Quads': 1.0,
                  'Glutes': 0.9,
                  'Hamstrings': 0.4
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Leg Extension',
                defaultSets: 3,
                scheme: '3x10-15',
                targetMuscles: {'Quads': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Machine Calf Raise',
                defaultSets: 3,
                scheme: '3x10-15',
                targetMuscles: {'Calves': 1.0}),
          ]),
        ],
      ),

      // 4. 5/3/1 Strength
      Program(
        id: 'preset_ul',
        name: '5/3/1 Strength (Compound)',
        createdAt: now,
        isPreset: true,
        days: [
          ProgramDay(
              id: _uuid.v4(),
              name: 'Session 1: Volume (Sets of 5)',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Barbell Bench Press',
                    defaultSets: 4,
                    scheme: '4x5 @ 75% 1RM',
                    tips: '累積訓練量以驅動肌肥大，這是提升長期力量的關鍵 [00:02:14]。',
                    targetMuscles: {'Chest': 1.0, 'Triceps': 0.4}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Barbell Row',
                    defaultSets: 4,
                    scheme: '4x8 Hypertrophy',
                    targetMuscles: {'Lats': 1.0, 'Rhomboids': 0.8}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Overhead Press',
                    defaultSets: 3,
                    scheme: '3x8-10',
                    targetMuscles: {'FrontDelts': 1.0, 'Triceps': 0.6}),
              ]),
          ProgramDay(
              id: _uuid.v4(),
              name: 'Session 2: Triples (Sets of 3)',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Barbell Squat',
                    defaultSets: 3,
                    scheme: '3x3 @ 85% 1RM',
                    tips: '力量訓練的甜蜜點，兼顧訓練量與中樞神經 (CNS) 適應 [00:08:16]。',
                    targetMuscles: {'Quads': 1.0, 'Glutes': 0.7}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Deadlift',
                    defaultSets: 3,
                    scheme: '3x3 @ 85% 1RM',
                    tips: '使用較重負荷挑戰 CNS，同時維持良好的操作效率 [00:07:46]。',
                    targetMuscles: {
                      'Glutes': 1.0,
                      'Hamstrings': 0.8,
                      'LowerBack': 0.8
                    }),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Pull Ups',
                    defaultSets: 3,
                    scheme: '3xAMRAP',
                    targetMuscles: {'Lats': 1.0, 'Biceps': 0.4}),
              ]),
          ProgramDay(
              id: _uuid.v4(),
              name: 'Session 3: Intensity (Singles)',
              exercises: [
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Heavy Bench Single',
                    defaultSets: 3,
                    scheme: '3x1 @ 90-95% 1RM',
                    tips: '最針對 1RM 表現的訓練，讓 CNS 適應極高重量 [00:05:13]。',
                    targetMuscles: {'Chest': 1.0, 'Triceps': 0.4}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Dumbbell Incline Press',
                    defaultSets: 3,
                    scheme: '3x10-12',
                    targetMuscles: {'UpperChest': 1.0, 'FrontDelts': 0.5}),
                TemplateExercise(
                    id: _uuid.v4(),
                    name: 'Face Pulls',
                    defaultSets: 3,
                    scheme: '3x15-20',
                    tips: '在大重量訓練間維持肩關節健康與恢復 [00:12:08]。',
                    targetMuscles: {'RearDelts': 1.0}),
              ]),
        ],
      ),

      // 5. Minimalist Full Body (Jeff Nippard)
      Program(
        id: 'preset_fb',
        name: 'Minimalist Full Body (Jeff Nippard)',
        createdAt: now,
        isPreset: true,
        days: [
          ProgramDay(id: _uuid.v4(), name: 'Day 1: Foundation', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Flat DB Bench Press',
                defaultSets: 2,
                scheme: '1x4-6 (Heavy), 1x8-10 (Back-off)',
                tips: '30-45 degree elbow tuck, flare as you press [00:01:32].',
                targetMuscles: {
                  'Chest': 1.0,
                  'FrontDelts': 0.4,
                  'Triceps': 0.3
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Dumbbell RDL',
                defaultSets: 2,
                scheme: '2x8-10',
                tips:
                    'Push hips back, reverse when hamstrings are fully stretched [00:02:06].',
                targetMuscles: {
                  'Hamstrings': 1.0,
                  'Glutes': 0.8,
                  'LowerBack': 0.6
                }),
            TemplateExercise(
                id: _uuid.v4(),
                name: '2-Grip Lat Pulldown',
                defaultSets: 2,
                scheme: '1xOverhand Wide, 1xUnderhand Close',
                tips:
                    'Set 1 for mid-back/lats, Set 2 for biceps/lower lats [00:02:33].',
                targetMuscles: {'Lats': 1.0, 'Biceps': 0.5}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Dumbbell Step-up',
                defaultSets: 1,
                scheme: '1x8-10 per leg',
                tips:
                    'Force front leg to carry all load, minimize back leg assistance [00:03:19].',
                targetMuscles: {'Quads': 1.0, 'Glutes': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Overhead Cable Tricep Extension',
                defaultSets: 1,
                scheme: '1x12-15 + 1xDrop Set',
                tips: '40% more hypertrophy than pressdowns [00:04:11].',
                targetMuscles: {'Triceps': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Machine Lateral Raise',
                defaultSets: 1,
                scheme: '1x12-15 + 1xDrop Set',
                tips: 'Strap in to isolate side delts [00:05:25].',
                targetMuscles: {'SideDelts': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Seated Calf Raise (on Leg Press)',
                defaultSets: 1,
                scheme: '1x12-15 + 1xDrop Set',
                tips: '1s pause at bottom, full squeeze at top [00:06:42].',
                targetMuscles: {'Calves': 1.0}),
          ]),
          ProgramDay(id: _uuid.v4(), name: 'Day 2: Performance', exercises: [
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Hack Squat',
                defaultSets: 2,
                scheme: '1x4-6 (RPE 9), 1x8-10 (Hypertrophy)',
                tips:
                    'Drive through heels, allow knees to travel forward [00:07:28].',
                targetMuscles: {'Quads': 1.0, 'Glutes': 0.6}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'High Incline Smith Press',
                defaultSets: 2,
                scheme: '2x10-12',
                tips:
                    '45-60 degree incline to hit upper chest and delts [00:08:26].',
                targetMuscles: {'UpperChest': 1.0, 'FrontDelts': 0.8}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'T-Bar Row',
                defaultSets: 2,
                scheme: '2x10-12',
                tips: 'Super-set with Incline Press to save time [00:08:50].',
                targetMuscles: {'Rhomboids': 1.0, 'Lats': 0.7}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Seated Hamstring Curl',
                defaultSets: 1,
                scheme: '1x10-12 + 1xDrop Set',
                tips: 'Lean forward for deeper hamstring stretch [00:10:02].',
                targetMuscles: {'Hamstrings': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'EZ Bar Bicep Curl',
                defaultSets: 1,
                scheme: '1x12-15 + Myo-reps',
                tips:
                    'Myo-reps: 3-4s rest, then 4 reps, repeat until you can\'t hit 4 [00:10:48].',
                targetMuscles: {'Biceps': 1.0}),
            TemplateExercise(
                id: _uuid.v4(),
                name: 'Cable Crunch',
                defaultSets: 1,
                scheme: '1x12-15 + Double Drop Set',
                tips: 'Round the entire back to fully contract abs [00:11:32].',
                targetMuscles: {'Core': 1.0}),
          ]),
        ],
      ),
    ];
  }
}
