// services/muscle_service.dart
class MuscleService {
  static const Map<String, String> mapping = {
    'BENCH PRESS': 'Chest', 'INCLINE PRESS': 'Chest', 'CHEST FLY': 'Chest',
    'SQUAT': 'Legs', 'LEG PRESS': 'Legs', 'LEG EXTENSION': 'Legs',
    'DEADLIFT': 'Back/Legs',
    'PULL UP': 'Back', 'ROW': 'Back', 'LAT PULLDOWN': 'Back',
    'SHOULDER PRESS': 'Shoulders', 'LATERAL RAISE': 'Shoulders',
    'CURL': 'Arms', 'TRICEPS EXTENSION': 'Arms',
    // ... 可以持續增加
  };

  static String getGroup(String exerciseName) {
    final name = exerciseName.toUpperCase();
    for (var key in mapping.keys) {
      if (name.contains(key)) return mapping[key]!;
    }
    return 'Others';
  }
}
