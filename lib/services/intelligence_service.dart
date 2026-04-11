// lib/services/intelligence_service.dart
import 'package:flutter/foundation.dart';
import '../models/models.dart'; // ⭐️ 引入統一的 Muscles 定義

/// 1. 定義器械類型與其神經疲勞權重
enum EquipmentType {
  barbell('BB', 1.15), // 槓鈴：中樞神經(CNS)負荷最大
  dumbbell('DB', 1.05), // 啞鈴：需要高穩定性
  machine('MC', 0.85), // 器械：固定軌跡，神經負荷低
  cable('CB', 0.90), // 滑輪：持續張力
  bodyweight('BW', 0.80), // 徒手：關節自然軌跡
  unknown('N/A', 1.0); // 未知預設

  final String label;
  final double fatigueModifier;
  const EquipmentType(this.label, this.fatigueModifier);
}

/// 2. 動作解析結果模型
class ExerciseAnalysis {
  final EquipmentType equipment;
  final Map<String, double> targetMuscles;
  final double fatigueIndex; // 單下(Rep)的基礎疲勞指數
  final bool isCompound; // 是否為多關節複合動作

  ExerciseAnalysis({
    required this.equipment,
    required this.targetMuscles,
    required this.fatigueIndex,
    required this.isCompound,
  });
}

/// 3. 智慧感知引擎本體
class IntelligenceService {
  static final IntelligenceService _instance = IntelligenceService._internal();
  factory IntelligenceService() => _instance;
  IntelligenceService._internal();

  // ==========================================
  // 核心演算法：解析動作名稱
  // ==========================================
  ExerciseAnalysis analyzeExercise(String rawName) {
    final name = rawName.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    // 1. 偵測器械類型
    final equipment = _detectEquipment(name);

    // 2. 偵測動作圖譜 (肌肉映射與動作屬性)
    final mapping = _detectMuscleMapping(name);

    // 3. 計算基礎疲勞指數 (Base FI)
    // 複合動作基礎分為 1.2，孤立動作為 0.8
    final baseFatigue = mapping['isCompound'] == true ? 1.2 : 0.8;

    // 總疲勞係數 = 基礎動作係數 * 器械係數
    final finalFatigue = baseFatigue * equipment.fatigueModifier;

    return ExerciseAnalysis(
      equipment: equipment,
      targetMuscles: mapping['muscles'] as Map<String, double>,
      fatigueIndex: finalFatigue,
      isCompound: mapping['isCompound'] as bool,
    );
  }

  // --- 內部：器械偵測邏輯 ---
  EquipmentType _detectEquipment(String name) {
    if (RegExp(r'(barbell|bb\b|槓鈴|史密斯|smith)').hasMatch(name))
      return EquipmentType.barbell;
    if (RegExp(r'(dumbbell|db\b|啞鈴)').hasMatch(name))
      return EquipmentType.dumbbell;
    if (RegExp(r'(machine|mc\b|器械|蹬腿|固定)').hasMatch(name))
      return EquipmentType.machine;
    if (RegExp(r'(cable|cb\b|pulley|滑輪|繩索)').hasMatch(name))
      return EquipmentType.cable;
    if (RegExp(
            r'(bodyweight|bw\b|徒手|自體|push(-|\s)?up|pull(-|\s)?up|chin(-|\s)?up|dip)')
        .hasMatch(name)) return EquipmentType.bodyweight;
    return EquipmentType.unknown;
  }

  // --- 內部：動作映射圖譜 (生物力學權重) ---
  // 注意：這裡採用「優先權排列」，越具體、越特別的動作放越前面
  Map<String, dynamic> _detectMuscleMapping(String name) {
    // -------------------------
    // 1. 臀腿部 (Bret Contreras 體系)
    // -------------------------
    if (RegExp(r'(hip thrust|glute bridge|臀推|臀橋)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {Muscles.glutes: 1.0, Muscles.hamstrings: 0.3}
      };
    }
    if (RegExp(r'(bulgarian|split squat|保加利亞|分腿蹲)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {Muscles.quads: 0.9, Muscles.glutes: 0.8}
      };
    }
    if (RegExp(r'(rdl|romanian|stiff leg|羅馬尼亞|直腿硬舉)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.hamstrings: 1.0,
          Muscles.glutes: 0.7,
          Muscles.lowerBack: 0.6
        }
      };
    }
    if (RegExp(r'(deadlift|硬舉)').hasMatch(name)) {
      // 傳統硬舉 (CNS怪獸)
      return {
        'isCompound': true,
        'muscles': {
          Muscles.glutes: 1.0,
          Muscles.hamstrings: 0.8,
          Muscles.lowerBack: 0.8,
          Muscles.lats: 0.4,
          Muscles.core: 0.5
        }
      };
    }
    if (RegExp(r'(leg press|腿推)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {Muscles.quads: 1.0, Muscles.glutes: 0.5}
      };
    }
    if (RegExp(r'(squat|深蹲)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.quads: 1.0,
          Muscles.glutes: 0.7,
          Muscles.lowerBack: 0.4,
          Muscles.core: 0.3
        }
      };
    }
    if (RegExp(r'(leg extension|腿伸伸|腿屈伸|踢腿)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.quads: 1.0}
      };
    }
    if (RegExp(r'(leg curl|腿彎舉|勾腿)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.hamstrings: 1.0}
      };
    }
    if (RegExp(r'(calf|提踵|小腿)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.calves: 1.0}
      };
    }

    // -------------------------
    // 2. 胸背部 (Delavier 體系)
    // -------------------------
    // 胸部特化
    if (RegExp(r'(incline.*bench|incline.*press|上斜.*臥推|上斜.*推)')
        .hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.upperChest: 1.0,
          Muscles.frontDelt: 0.6,
          Muscles.triceps: 0.4
        }
      };
    }
    if (RegExp(r'(decline.*bench|下斜.*臥推)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {Muscles.lowerChest: 1.0, Muscles.triceps: 0.5}
      };
    }
    if (RegExp(r'(bench press|chest press|臥推|胸推)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.chest: 1.0,
          Muscles.frontDelt: 0.4,
          Muscles.triceps: 0.5
        }
      };
    }
    if (RegExp(r'(chest fly|pec deck|夾胸|胸.*飛鳥)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.chest: 1.0, Muscles.frontDelt: 0.2}
      };
    }
    if (RegExp(r'(push(-|\s)?up|伏地挺身)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {Muscles.chest: 1.0, Muscles.triceps: 0.6, Muscles.core: 0.4}
      };
    }
    if (RegExp(r'(dip|雙槓)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.lowerChest: 0.8,
          Muscles.triceps: 1.0,
          Muscles.frontDelt: 0.5
        }
      };
    }

    // 背部特化
    if (RegExp(r'(pull(-|\s)?up|chin(-|\s)?up|引體向上)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.lats: 1.0,
          Muscles.biceps: 0.6,
          Muscles.rhomboids: 0.4
        }
      };
    }
    if (RegExp(r'(pulldown|下拉)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.lats: 1.0,
          Muscles.biceps: 0.5,
          Muscles.rearDelt: 0.2
        }
      };
    }
    if (RegExp(r'(pendlay|t-bar|barbell row|槓鈴划船|t形划船)').hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.lats: 0.8,
          Muscles.rhomboids: 1.0,
          Muscles.lowerBack: 0.5,
          Muscles.biceps: 0.4
        }
      };
    }
    if (RegExp(r'(row|划船)').hasMatch(name)) {
      // 一般划船
      return {
        'isCompound': true,
        'muscles': {
          Muscles.lats: 0.9,
          Muscles.rhomboids: 0.8,
          Muscles.biceps: 0.5
        }
      };
    }
    if (RegExp(r'(pullover|直臂下拉|仰臥上拉)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.lats: 1.0, Muscles.chest: 0.3}
      };
    }

    // -------------------------
    // 3. 肩部與手臂 (細節孤立)
    // -------------------------
    // 肩膀防呆判斷
    if (RegExp(r'(rear delt.*fly|reverse pec|face pull|後束.*飛鳥|面拉|反向夾胸)')
        .hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.rearDelt: 1.0, Muscles.rhomboids: 0.5}
      };
    }
    if (RegExp(r'(shoulder fly|肩.*飛鳥)').hasMatch(name)) {
      // 防呆：把 Shoulder Fly 歸類給肩膀側/後束
      return {
        'isCompound': false,
        'muscles': {Muscles.sideDelt: 0.8, Muscles.rearDelt: 0.5}
      };
    }
    if (RegExp(r'(lateral raise|side raise|側平舉)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.sideDelt: 1.0}
      };
    }
    if (RegExp(r'(front raise|前平舉)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.frontDelt: 1.0}
      };
    }
    if (RegExp(r'(shoulder press|overhead press|military press|肩推|推舉)')
        .hasMatch(name)) {
      return {
        'isCompound': true,
        'muscles': {
          Muscles.frontDelt: 1.0,
          Muscles.sideDelt: 0.4,
          Muscles.triceps: 0.6
        }
      };
    }
    if (RegExp(r'(shrug|聳肩)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.rhomboids: 0.5}
      }; // 這裡以斜方肌為主，歸類在廣義中背
    }

    // 手臂
    if (RegExp(r'(hammer curl|錘式)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.biceps: 0.8}
      }; // 包含肱橈肌
    }
    if (RegExp(r'(curl|彎舉)').hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.biceps: 1.0}
      };
    }
    if (RegExp(r'(skullcrusher|pushdown|kickback|extension|碎顱|下壓|臂屈伸)')
        .hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.triceps: 1.0}
      };
    }

    // -------------------------
    // 4. 核心 (Core)
    // -------------------------
    if (RegExp(r'(plank|crunch|sit(-|\s)?up|leg raise|棒式|捲腹|仰臥起坐|舉腿)')
        .hasMatch(name)) {
      return {
        'isCompound': false,
        'muscles': {Muscles.core: 1.0}
      };
    }

    // =========================
    // 5. 終極防呆 (Fallback)
    // =========================
    // 如果上面都沒匹配到，但有提到部位名稱
    if (RegExp(r'(chest|pec|胸)').hasMatch(name))
      return {
        'isCompound': false,
        'muscles': {Muscles.chest: 1.0}
      };
    if (RegExp(r'(back|lat|背)').hasMatch(name))
      return {
        'isCompound': false,
        'muscles': {Muscles.lats: 1.0}
      };
    if (RegExp(r'(shoulder|delt|肩)').hasMatch(name))
      return {
        'isCompound': false,
        'muscles': {Muscles.sideDelt: 1.0}
      };
    if (RegExp(r'(leg|quad|ham|腿|臀)').hasMatch(name))
      return {
        'isCompound': false,
        'muscles': {Muscles.quads: 1.0}
      };

    // 完全未知
    return {
      'isCompound': false,
      'muscles': <String, double>{},
    };
  }
}
