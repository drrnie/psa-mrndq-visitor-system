// lib/services/guard_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class GuardService extends ChangeNotifier {
  static final GuardService _instance = GuardService._internal();
  factory GuardService() => _instance;
  GuardService._internal();

  static const _kOverrideKey = 'psa_guard_override';

  String? _overrideGuard;

  String  get currentGuardName =>
      _overrideGuard ?? GuardSchedule.getCurrentGuard().name;
  String  get currentShift     => GuardSchedule.getCurrentGuard().shift;
  bool    get hasOverride      => _overrideGuard != null;
  String? get overrideName     => _overrideGuard;

  // ── Called once in main() before runApp ──────────────────────────────────
  Future<void> loadPersistedOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _overrideGuard = prefs.getString(_kOverrideKey);
      // No notifyListeners() — called before the widget tree exists.
    } catch (_) {}
  }

  void setOverrideGuard(String name) {
    _overrideGuard = name;
    _persist(name);
    notifyListeners();
  }

  void clearOverride() {
    _overrideGuard = null;
    _persist(null);
    notifyListeners();
  }

  Future<void> _persist(String? name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (name == null) {
        await prefs.remove(_kOverrideKey);
      } else {
        await prefs.setString(_kOverrideKey, name);
      }
    } catch (_) {}
  }

  List<String>  getGuardOptions()   => GuardSchedule.getAllGuardNames();
  GuardInfo     getScheduledGuard() => GuardSchedule.getCurrentGuard();
}