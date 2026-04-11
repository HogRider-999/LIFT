// lib/services/unit_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UnitService extends ChangeNotifier {
  // ⭐️ 單例模式 (Singleton)：確保全 App 只會共用同一個 UnitService 大腦
  static final UnitService _instance = UnitService._internal();

  factory UnitService() {
    return _instance;
  }

  // 初始化時自動讀取記憶
  UnitService._internal() {
    load();
  }

  bool _useLbs = false;
  bool get useLbs => _useLbs;

  // 從瀏覽器或手機讀取上一次的單位設定
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _useLbs = prefs.getBool('useLbs_key') ?? false; // 如果沒存過，預設是 KG
    notifyListeners();
  }

  // 設定單位並存檔
  Future<void> setUnit(bool val) async {
    _useLbs = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useLbs_key', val);
    notifyListeners(); // 通知所有頁面同步更新
  }

  // 切換單位
  Future<void> toggleUnit() async {
    await setUnit(!_useLbs);
  }

  // ⭐️ 格式化數字（配合 PR 頁面）
  String fmt(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

  // ⭐️ 格式化數字（配合訓練頁面）
  String fmtNum(double v) => fmt(v);

  // --- 重量換算邏輯 ---
  double toKg(double v) => _useLbs ? v / 2.20462 : v;
  double toDisplay(double v) => _useLbs ? v * 2.20462 : v;
  String get unit => _useLbs ? 'LBS' : 'KG';
}
