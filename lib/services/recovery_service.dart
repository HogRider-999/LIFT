// lib/services/recovery_service.dart
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'storage_service.dart';

class RecoveryService {
  static final RecoveryService _instance = RecoveryService._internal();
  factory RecoveryService() => _instance;
  RecoveryService._internal();

  final _store = StorageService();

  // ⭐️ 這裡不要再定義 class Muscles 或 class MuscleReadiness 了！
  // 它們都已經在 models.dart 裡面了。

  final Map<String, double> _muscleHalfLife = {
    Muscles.quads: 48.0,
    Muscles.hamstrings: 48.0,
    Muscles.glutes: 48.0,
    Muscles.lowerBack: 72.0,
    Muscles.lats: 48.0,
    Muscles.chest: 48.0,
    Muscles.upperChest: 48.0,
    Muscles.lowerChest: 48.0,
    Muscles.frontDelt: 24.0,
    Muscles.sideDelt: 24.0,
    Muscles.rearDelt: 24.0,
    Muscles.triceps: 24.0,
    Muscles.biceps: 24.0,
    Muscles.calves: 24.0,
    Muscles.core: 24.0,
  };

  Future<List<MuscleReadiness>> calculateGlobalReadiness() async {
    final now = DateTime.now();
    Map<String, double> fatigueMap = {};

    for (var m in _muscleHalfLife.keys) {
      fatigueMap[m] = 0.0;
    }

    for (int i = 0; i < 7; i++) {
      final d = now.subtract(Duration(days: i));
      final dateStr =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final log = await _store.getLog(dateStr);

      if (log != null && log.isCompleted) {
        for (var ex in log.exercises) {
          final vol = _calcVolume(ex.sets);
          if (vol > 0 && ex.targetMuscles != null) {
            ex.targetMuscles!.forEach((muscle, ratio) {
              double addedFatigue = (vol * ratio) / 100.0;
              double decayHours = i * 24.0;
              double halfLife = _muscleHalfLife[muscle] ?? 48.0;
              double currentFatigue =
                  addedFatigue * _getDecayFactor(decayHours, halfLife);
              fatigueMap[muscle] = (fatigueMap[muscle] ?? 0) + currentFatigue;
            });
          }
        }
      }
    }

    List<MuscleReadiness> res = [];
    fatigueMap.forEach((muscle, fatigue) {
      double readiness = 100.0 - fatigue;
      if (readiness < 0) readiness = 0;
      if (readiness > 100) readiness = 100;

      String status = 'READY';
      String color = '#4CAF50';

      if (readiness < 40) {
        status = 'FATIGUED';
        color = '#F44336';
      } else if (readiness < 70) {
        status = 'RECOVERING';
        color = '#FFC107';
      }

      res.add(MuscleReadiness(
        muscleName: muscle,
        readinessScore: readiness,
        status: status,
        colorHex: color,
      ));
    });

    res.sort((a, b) => a.readinessScore.compareTo(b.readinessScore));
    return res;
  }

  double _calcVolume(List<ExerciseSet> sets) {
    double v = 0;
    for (var s in sets) {
      if (s.completed) v += (s.weight * s.reps);
    }
    return v;
  }

  double _getDecayFactor(double hoursPassed, double halfLife) {
    // 簡單的線性衰減模擬
    if (hoursPassed >= halfLife * 2) return 0.0;
    if (hoursPassed >= halfLife) return 0.2;
    return 1.0 - (hoursPassed / (halfLife * 1.5));
  }
}
