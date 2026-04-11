// lib/services/lang_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LangService extends ChangeNotifier {
  static final LangService _instance = LangService._internal();
  factory LangService() => _instance;
  LangService._internal();

  bool _isZh = false;
  bool get isZh => _isZh;
  bool get isEn => !_isZh;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isZh = prefs.getBool('is_zh') ?? false;
    notifyListeners();
  }

  Future<void> load() => init();

  Future<void> toggle() async {
    _isZh = !_isZh;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_zh', _isZh);
    notifyListeners();
  }

  Future<void> toggleLang() => toggle();

  String t(String key) {
    final langMap = _isZh ? _zh : _en;
    return langMap[key] ?? key;
  }

  static const Map<String, String> _en = {
    'CANCEL': 'CANCEL', 'SAVE': 'SAVE', 'ADD': 'ADD', 'DELETE': 'DELETE',
    'EDIT': 'EDIT', 'DONE': 'DONE', 'CLOSE': 'CLOSE', 'CONFIRM': 'CONFIRM',
    'PROGRAMS': 'PROGRAMS', 'CUSTOM PROGRAMS': 'CUSTOM PROGRAMS',
    'PRESET PROGRAMS': 'PRESET PROGRAMS',
    'NO CUSTOM PROGRAMS': 'NO CUSTOM PROGRAMS',
    'Tap + to create your own': 'Tap + to create your own',
    'IMPORT PROGRAM': 'IMPORT PROGRAM',
    'Paste code here...': 'Paste code here...', 'IMPORT': 'IMPORT',
    'Import Successful!': 'Import Successful!', 'Invalid Code': 'Invalid Code',
    'NEW PROGRAM': 'NEW PROGRAM',
    'RENAME PROGRAM': 'RENAME PROGRAM',
    'Preset programs cannot be renamed.': 'Preset programs cannot be renamed.',
    'SHARE CODE': 'SHARE CODE',
    'Copy this code to share:': 'Copy this code to share:',
    'Copied to clipboard!': 'Copied to clipboard!',
    'COPY': 'COPY', 'NEW DAY': 'NEW DAY', 'NO DAYS YET': 'NO DAYS YET',
    'NO EXERCISES': 'NO EXERCISES',
    'EXERCISE INFO': 'EXERCISE INFO', 'EDIT EXERCISE': 'EDIT EXERCISE',
    'TACTICAL CONFIG': 'TACTICAL CONFIG',
    'EXERCISE NAME': 'EXERCISE NAME', 'SETS': 'SETS',
    'SCHEME / PROTOCOL (OPTIONAL)': 'SCHEME / PROTOCOL (OPTIONAL)',
    'TRAINER TIPS (OPTIONAL)': 'TRAINER TIPS (OPTIONAL)',
    'UPDATE CONFIG': 'UPDATE CONFIG', 'DEPLOY EXERCISE': 'DEPLOY EXERCISE',
    'ACTIVITY': 'ACTIVITY', 'DAYS': 'DAYS', 'STREAK': 'STREAK',
    'TODAY': 'TODAY', 'YESTERDAY': 'YESTERDAY', 'VIEW SUMMARY': 'VIEW SUMMARY',
    'FREE SESSION': 'FREE SESSION',
    'Start without a program': 'Start without a program',
    'NO PROGRAMS YET': 'NO PROGRAMS YET',
    'Create one in the Programs tab': 'Create one in the Programs tab',
    'DISCARD': 'DISCARD', 'DISCARD WORKOUT?': 'DISCARD WORKOUT?',
    "This will delete today's log.": "This will delete today's log.",
    'IN PROGRESS': 'IN PROGRESS', 'FINISH WORKOUT': 'FINISH WORKOUT',
    'FINISH?': 'FINISH?',
    'Are you sure you want to finish this workout?':
        'Are you sure you want to finish this workout?',
    'HELL YEAH': 'HELL YEAH',
    'REPS': 'REPS', 'ADD SET': 'ADD SET', 'REST': 'REST',
    'ADD EXERCISE': 'ADD EXERCISE', 'RENAME EXERCISE': 'RENAME EXERCISE',
    'PLATE CALCULATOR': 'PLATE CALCULATOR', 'TARGET WEIGHT': 'TARGET WEIGHT',
    'BAR WEIGHT': 'BAR WEIGHT', 'EACH SIDE': 'EACH SIDE',
    'Too Light': 'Too Light', 'HISTORY': 'HISTORY', 'WARM UP': 'WARM UP',
    'Empty': 'Empty Bar', 'ACCLIMATION': 'Acclimation',
    'GREAT JOB!': 'GREAT JOB!', 'WORKOUT SUMMARY': 'WORKOUT SUMMARY',
    'VOLUME': 'VOLUME', 'MAX WEIGHT': 'MAX WEIGHT',
    'No previous data': 'No previous data', 'SHARE STORY': 'SHARE STORY',
    'BACK TO CALENDAR': 'BACK TO CALENDAR',
    'TAKE A SCREENSHOT TO SHARE!': 'TAKE A SCREENSHOT TO SHARE!',
    'TOTAL VOLUME': 'TOTAL VOLUME',
    'Complete at least 1 record to unlock':
        'Complete at least 1 record to unlock',
    'MUSCLE RECOVERY': 'MUSCLE RECOVERY',
    'Ready (可挑戰 PR)': 'Ready (PR Attempt)',
    'Recovering (恢復中)': 'Recovering', 'Exhausted (強烈建議休息)': 'Exhausted (Rest)',
    'CNS FATIGUE': 'CNS FATIGUE',

    // ⭐️ Analytics UI
    'BIO-RECOVERY SCANNER': 'BIO-RECOVERY SCANNER',
    'SYSTEM STATUS': 'SYSTEM STATUS',
    'SELECT ZONE': 'SELECT ZONE',
    'AWAITING ZONE SELECTION': 'AWAITING ZONE SELECTION',
    'TACTICAL ANALYSIS': 'TACTICAL ANALYSIS',
    'NO DATA OR FULLY RECOVERED': 'NO DATA OR FULLY RECOVERED',
    'BODY WEIGHT': 'BODY WEIGHT',
    'WEIGHT': 'WEIGHT',
    'FAT %': 'FAT %',
    'No weight recorded': 'No weight recorded',
    'NUTRITION': 'NUTRITION',
    'CALORIE TARGET': 'CALORIE TARGET',
    'kcal left': 'kcal left',
    'kcal OVER': 'kcal OVER',
    'PRO': 'PRO', 'CHO': 'CHO', 'FAT': 'FAT',
    'SCAN BARCODE': 'SCAN BARCODE',
    'SCAN LABEL': 'SCAN LABEL',
    'MANUAL LOG': 'MANUAL LOG',
    'TODAY\'S LOG': 'TODAY\'S LOG',
    'No food logged today.': 'No food logged today.',
    'PHOTOS': 'PHOTOS',
    'No photos yet.': 'No photos yet.',
    'Delete Photo?': 'Delete Photo?',
    'ANALYTICS': 'ANALYTICS',

    // ⭐️ Muscles
    'Chest': 'Chest', 'Upper Chest': 'Upper Chest',
    'Lower Chest': 'Lower Chest', 'Lats': 'Lats',
    'Rhomboids': 'Rhomboids', 'Lower Back': 'Lower Back',
    'Front Delts': 'Front Delts',
    'Side Delts': 'Side Delts', 'Rear Delts': 'Rear Delts',
    'Triceps': 'Triceps',
    'Biceps': 'Biceps', 'Quads': 'Quads', 'Hamstrings': 'Hamstrings',
    'Glutes': 'Glutes', 'Calves': 'Calves', 'Core': 'Core',
    'CHEST': 'CHEST', 'BACK': 'BACK', 'SHOULDERS': 'SHOULDERS', 'ARMS': 'ARMS',
    'CORE': 'CORE', 'LEGS': 'LEGS',
  };

  static const Map<String, String> _zh = {
    'CANCEL': '取消', 'SAVE': '儲存', 'ADD': '新增', 'DELETE': '刪除', 'EDIT': '編輯',
    'DONE': '完成', 'CLOSE': '關閉', 'CONFIRM': '確認',
    'PROGRAMS': '課表庫', 'CUSTOM PROGRAMS': '我的自訂課表', 'PRESET PROGRAMS': '官方推薦課表',
    'NO CUSTOM PROGRAMS': '目前沒有自訂課表',
    'Tap + to create your own': '點擊右下角 + 建立新課表',
    'IMPORT PROGRAM': '匯入課表', 'Paste code here...': '請貼上課表代碼...',
    'IMPORT': '匯入',
    'Import Successful!': '匯入成功！', 'Invalid Code': '無效的代碼',
    'NEW PROGRAM': '建立新課表',
    'RENAME PROGRAM': '重新命名課表',
    'Preset programs cannot be renamed.': '官方預設課表無法重新命名',
    'SHARE CODE': '分享課表代碼', 'Copy this code to share:': '複製以下代碼分享給訓練夥伴：',
    'Copied to clipboard!': '已複製到剪貼簿！',
    'COPY': '複製', 'NEW DAY': '新增訓練日', 'NO DAYS YET': '尚無訓練日',
    'NO EXERCISES': '尚無訓練動作',
    'EXERCISE INFO': '動作資訊', 'EDIT EXERCISE': '編輯動作', 'TACTICAL CONFIG': '戰術配置',
    'EXERCISE NAME': '動作名稱', 'SETS': '組數',
    'SCHEME / PROTOCOL (OPTIONAL)': '次數與戰術策略 (選填)',
    'TRAINER TIPS (OPTIONAL)': '教練提示與重點 (選填)', 'UPDATE CONFIG': '更新配置',
    'DEPLOY EXERCISE': '部署動作',
    'ACTIVITY': '活動熱度', 'DAYS': '天', 'STREAK': '連續訓練',
    'TODAY': '今天', 'YESTERDAY': '昨天', 'VIEW SUMMARY': '查看訓練總結',
    'FREE SESSION': '自由訓練',
    'Start without a program': '不使用預設課表，直接開始紀錄', 'NO PROGRAMS YET': '尚無任何課表',
    'Create one in the Programs tab': '請先至 Programs 頁面建立課表',
    'DISCARD': '放棄紀錄', 'DISCARD WORKOUT?': '放棄今日訓練？',
    "This will delete today's log.": "這將會刪除今天的訓練紀錄。",
    'IN PROGRESS': '訓練進行中', 'FINISH WORKOUT': '結束訓練', 'FINISH?': '確認結束？',
    'Are you sure you want to finish this workout?': '你確定要結束今天的訓練並產生報表嗎？',
    'HELL YEAH': '結束並結算',
    'REPS': '次數', 'ADD SET': '新增一組', 'REST': '休息', 'ADD EXERCISE': '新增動作',
    'RENAME EXERCISE': '重新命名',
    'PLATE CALCULATOR': '槓片計算機', 'TARGET WEIGHT': '目標重量', 'BAR WEIGHT': '空槓重量',
    'EACH SIDE': '單邊需要裝上',
    'Too Light': '重量過輕', 'HISTORY': '歷史紀錄', 'WARM UP': '智慧熱身', 'Empty': '空槓熱身',
    'ACCLIMATION': '神經適應組',
    'GREAT JOB!': '幹得好，巨巨！', 'WORKOUT SUMMARY': '訓練總結', 'VOLUME': '總容量',
    'MAX WEIGHT': '最大重量',
    'No previous data': '尚無歷史數據', 'SHARE STORY': '分享至限時動態',
    'BACK TO CALENDAR': '返回行事曆',
    'TAKE A SCREENSHOT TO SHARE!': '截圖並分享至你的社群！', 'TOTAL VOLUME': '今日總容量',
    'Complete at least 1 record to unlock': '請至少完成一次相關紀錄以解鎖',
    'MUSCLE RECOVERY': '肌肉恢復狀態',
    'Ready (可挑戰 PR)': '已恢復 (可挑戰 PR)',
    'Recovering (恢復中)': '恢復中 (可輕量訓練)', 'Exhausted (強烈建議休息)': '嚴重疲勞 (建議休息)',
    'CNS FATIGUE': '中樞神經疲勞',

    // ⭐️ Analytics UI (Chinese)
    'BIO-RECOVERY SCANNER': '生物恢復掃描儀',
    'SYSTEM STATUS': '系統狀態',
    'SELECT ZONE': '選擇部位',
    'AWAITING ZONE SELECTION': '等待選擇掃描部位...',
    'TACTICAL ANALYSIS': '戰術分析',
    'NO DATA OR FULLY RECOVERED': '尚無數據或已完全恢復',
    'BODY WEIGHT': '體重紀錄',
    'WEIGHT': '體重',
    'FAT %': '體脂率',
    'No weight recorded': '尚無體重紀錄',
    'NUTRITION': '營養紀錄',
    'CALORIE TARGET': '目標熱量',
    'kcal left': '大卡 剩餘',
    'kcal OVER': '大卡 超標',
    'PRO': '蛋白質', 'CHO': '碳水', 'FAT': '脂肪',
    'SCAN BARCODE': '掃描條碼',
    'SCAN LABEL': '掃描標籤',
    'MANUAL LOG': '手動紀錄',
    'TODAY\'S LOG': '今日飲食紀錄',
    'No food logged today.': '今日尚未紀錄任何飲食。',
    'PHOTOS': '體態相簿',
    'No photos yet.': '尚無照片紀錄',
    'Delete Photo?': '刪除照片？',
    'ANALYTICS': '數據分析',

    // ⭐️ Muscles
    'Chest': '胸部', 'Upper Chest': '上胸', 'Lower Chest': '下胸', 'Lats': '背闊肌',
    'Rhomboids': '中背/菱形肌', 'Lower Back': '下背', 'Front Delts': '前三角',
    'Side Delts': '側三角', 'Rear Delts': '後三角', 'Triceps': '三頭肌',
    'Biceps': '二頭肌', 'Quads': '股四頭', 'Hamstrings': '腿後側',
    'Glutes': '臀部', 'Calves': '小腿', 'Core': '核心',
    'CHEST': '胸部', 'BACK': '背部', 'SHOULDERS': '肩部', 'ARMS': '手臂', 'CORE': '核心',
    'LEGS': '腿部',
  };
}
