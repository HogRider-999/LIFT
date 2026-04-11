// lib/models/models.dart
import 'package:flutter/foundation.dart';
import 'dart:convert';

// ==========================================
// 1. 基礎肌肉群定義
// ==========================================
class Muscles {
  static const String chest = 'Chest';
  static const String upperChest = 'Upper Chest';
  static const String lowerChest = 'Lower Chest';
  static const String lats = 'Lats';
  static const String rhomboids = 'Rhomboids';
  static const String lowerBack = 'Lower Back';
  static const String frontDelt = 'Front Delts';
  static const String sideDelt = 'Side Delts';
  static const String rearDelt = 'Rear Delts';
  static const String biceps = 'Biceps';
  static const String triceps = 'Triceps';
  static const String quads = 'Quads';
  static const String hamstrings = 'Hamstrings';
  static const String glutes = 'Glutes';
  static const String calves = 'Calves';
  static const String core = 'Core';
}

// ==========================================
// 2. 課表範本 (Templates)
// ==========================================

class TemplateExercise {
  String id;
  String name;
  int defaultSets;
  String? scheme;
  String? tips;
  Map<String, double>? targetMuscles;

  TemplateExercise({
    required this.id,
    required this.name,
    required this.defaultSets,
    this.scheme,
    this.tips,
    this.targetMuscles,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'defaultSets': defaultSets,
    'scheme': scheme,
    'tips': tips,
    'targetMuscles': targetMuscles,
  };

  factory TemplateExercise.fromJson(Map<String, dynamic> json) =>
      TemplateExercise(
        id: json['id'] as String,
        name: json['name'] as String,
        defaultSets: json['defaultSets'] as int? ?? 3,
        scheme: json['scheme'] as String?,
        tips: json['tips'] as String?,
        targetMuscles: (json['targetMuscles'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
      );
}

class ProgramDay {
  String id;
  String name;
  List<TemplateExercise> exercises;

  ProgramDay({required this.id, required this.name, required this.exercises});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
    id: json['id'] as String,
    name: json['name'] as String,
    exercises:
        (json['exercises'] as List?)
            ?.map((e) => TemplateExercise.fromJson(e))
            .toList() ??
        [],
  );
}

class Program {
  String id;
  String name;
  DateTime createdAt;
  bool isPreset;
  List<ProgramDay> days;

  Program({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isPreset = false,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'isPreset': isPreset,
    'days': days.map((e) => e.toJson()).toList(),
  };

  factory Program.fromJson(Map<String, dynamic> json) => Program(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    isPreset: json['isPreset'] as bool? ?? false,
    days:
        (json['days'] as List?)?.map((e) => ProgramDay.fromJson(e)).toList() ??
        [],
  );

  // ⭐️ 戰術縮減版分享碼
  String toShareCode() {
    final Map<String, dynamic> minified = {
      'v': 2,
      'n': name,
      'd': days
          .map(
            (d) => {
              'n': d.name,
              'e': d.exercises
                  .map(
                    (e) => {
                      'n': e.name,
                      's': e.defaultSets,
                      'm': e.scheme,
                      't': e.tips,
                      'u': e.targetMuscles,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
    final jsonStr = jsonEncode(minified);
    return base64Encode(utf8.encode(jsonStr));
  }

  // ⭐️ 戰術解析版分享碼
  static Program fromShareCode(String code, String Function() uuidGen) {
    try {
      final bytes = base64Decode(code.trim());
      final Map<String, dynamic> data = jsonDecode(utf8.decode(bytes));

      return Program(
        id: uuidGen(),
        name: data['n'] ?? 'Imported Program',
        createdAt: DateTime.now(),
        isPreset: false,
        days: List<ProgramDay>.from(
          (data['d'] ?? []).map(
            (d) => ProgramDay(
              id: uuidGen(),
              name: d['n'] ?? 'New Day',
              exercises: List<TemplateExercise>.from(
                (d['e'] ?? []).map(
                  (e) => TemplateExercise(
                    id: uuidGen(),
                    name: e['n'] ?? 'Exercise',
                    defaultSets: e['s'] ?? 3,
                    scheme: e['m'],
                    tips: e['t'],
                    targetMuscles: e['u'] != null
                        ? Map<String, double>.from(e['u'])
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      throw const FormatException('Invalid share code format');
    }
  }
}

// ==========================================
// 3. 訓練執行與紀錄 (Workout Execution)
// ==========================================

class DropSetRecord {
  double weight;
  int reps;

  DropSetRecord({required this.weight, required this.reps});

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};

  factory DropSetRecord.fromJson(Map<String, dynamic> json) => DropSetRecord(
    weight: (json['weight'] as num).toDouble(),
    reps: json['reps'] as int,
  );
}

class ExerciseSet {
  String id;
  double weight;
  int reps;
  bool completed;
  bool isDropSet;
  List<DropSetRecord> dropSets;

  ExerciseSet({
    required this.id,
    this.weight = 0,
    this.reps = 0,
    this.completed = false,
    this.isDropSet = false,
    List<DropSetRecord>? dropSets,
  }) : dropSets = dropSets ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'reps': reps,
    'completed': completed,
    'isDropSet': isDropSet,
    'dropSets': dropSets.map((e) => e.toJson()).toList(),
  };

  factory ExerciseSet.fromJson(Map<String, dynamic> json) => ExerciseSet(
    id: json['id'] as String,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : 0,
    reps: json['reps'] as int? ?? 0,
    completed: json['completed'] as bool? ?? false,
    isDropSet: json['isDropSet'] as bool? ?? false,
    dropSets: (json['dropSets'] as List?)
        ?.map((e) => DropSetRecord.fromJson(e))
        .toList(),
  );
}

class LoggedExercise {
  String id;
  String name;
  List<ExerciseSet> sets;
  String? scheme;
  String? tips;
  Map<String, double>? targetMuscles;

  LoggedExercise({
    required this.id,
    required this.name,
    required this.sets,
    this.scheme,
    this.tips,
    this.targetMuscles,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sets': sets.map((e) => e.toJson()).toList(),
    'scheme': scheme,
    'tips': tips,
    'targetMuscles': targetMuscles,
  };

  factory LoggedExercise.fromJson(Map<String, dynamic> json) => LoggedExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    sets:
        (json['sets'] as List?)?.map((e) => ExerciseSet.fromJson(e)).toList() ??
        [],
    scheme: json['scheme'] as String?,
    tips: json['tips'] as String?,
    targetMuscles: (json['targetMuscles'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
  );
}

typedef WorkoutExercise = LoggedExercise;

class WorkoutLog {
  String id;
  String date;
  String? programDayId;
  String? programDayName;
  List<LoggedExercise> exercises;
  bool isCompleted;

  WorkoutLog({
    this.id = '',
    required this.date,
    this.programDayId,
    this.programDayName,
    required this.exercises,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'programDayId': programDayId,
    'programDayName': programDayName,
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isCompleted': isCompleted,
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String? ?? '',
    date: json['date'] as String,
    programDayId: json['programDayId'] as String?,
    programDayName: json['programDayName'] as String?,
    exercises:
        (json['exercises'] as List?)
            ?.map((e) => LoggedExercise.fromJson(e))
            .toList() ??
        [],
    isCompleted: json['isCompleted'] as bool? ?? false,
  );

  int get totalCalories =>
      exercises.fold(0, (sum, ex) => sum + (ex.sets.length * 10));
}

// ==========================================
// 4. 獨立 PR 紀錄 (Personal Records)
// ==========================================

class PersonalRecord {
  String id;
  String exerciseName;
  double weight;
  int reps;
  String date;

  PersonalRecord({
    required this.id,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'exerciseName': exerciseName,
    'weight': weight,
    'reps': reps,
    'date': date,
  };

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    id: json['id'] as String,
    exerciseName: json['exerciseName'] as String,
    weight: (json['weight'] as num).toDouble(),
    reps: json['reps'] as int,
    date: json['date'] as String,
  );
}

// ==========================================
// 5. 營養與體態追蹤 (Nutrition & Body)
// ==========================================

class FoodEntry {
  String id;
  String name;
  int calories;
  int protein;
  int carbs;
  int fat;

  FoodEntry({
    required this.id,
    required this.name,
    required this.calories,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory FoodEntry.fromJson(Map<String, dynamic> json) => FoodEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    calories: json['calories'] as int,
    protein: json['protein'] as int? ?? 0,
    carbs: json['carbs'] as int? ?? 0,
    fat: json['fat'] as int? ?? 0,
  );
}

class NutritionLog {
  String date;
  List<FoodEntry> entries;

  NutritionLog({required this.date, required this.entries});

  int get totalCalories => entries.fold(0, (sum, item) => sum + item.calories);
  int get totalProtein => entries.fold(0, (sum, item) => sum + item.protein);
  int get totalCarbs => entries.fold(0, (sum, item) => sum + item.carbs);
  int get totalFat => entries.fold(0, (sum, item) => sum + item.fat);

  Map<String, dynamic> toJson() => {
    'date': date,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory NutritionLog.fromJson(Map<String, dynamic> json) => NutritionLog(
    date: json['date'] as String,
    entries:
        (json['entries'] as List?)
            ?.map((e) => FoodEntry.fromJson(e))
            .toList() ??
        [],
  );
}

class ProgressPhoto {
  String id;
  String date;
  String path;

  ProgressPhoto({required this.id, required this.date, required this.path});

  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'path': path};

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) => ProgressPhoto(
    id: json['id'] as String,
    date: json['date'] as String,
    path: json['path'] as String,
  );
}

class BodyMetric {
  String date;
  double weight;
  double? bodyFat;

  BodyMetric({required this.date, required this.weight, this.bodyFat});

  Map<String, dynamic> toJson() => {
    'date': date,
    'weight': weight,
    'bodyFat': bodyFat,
  };

  factory BodyMetric.fromJson(Map<String, dynamic> json) => BodyMetric(
    date: json['date'] as String,
    weight: (json['weight'] as num).toDouble(),
    bodyFat: json['bodyFat'] != null
        ? (json['bodyFat'] as num).toDouble()
        : null,
  );
}

class MuscleReadiness {
  String muscleName;
  double readinessScore;
  String status;
  String colorHex;

  MuscleReadiness({
    required this.muscleName,
    required this.readinessScore,
    required this.status,
    required this.colorHex,
  });
}
