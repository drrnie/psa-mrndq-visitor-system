// lib/utils/constants.dart
//
// After the white-label refactor, all editable values (units, QR ranges,
// special ranges, couriers, purposes, guards, office identity, password) live
// in ConfigService. This file keeps only:
//   • AppColors        — the fixed brand palette (not admin-editable)
//   • SpecialVisitorType — enum used across the special check-in flow
//   • GuardInfo        — value object for the resolved current guard
//   • GuardSchedule    — rotation MATH (anchor + shift times); names/weeks
//                        now read from ConfigService
//   • AppStrings       — thin config-backed accessors for office identity
//
// Removed (migrated into ConfigService): PSAUnit, UnitConfig, UnitService,
// SpecialQRConfig, QRConfig.

import 'package:flutter/material.dart';
import '../services/config_service.dart';

class AppColors {
  static const Color psaBlue      = Color(0xFF1A3A6B);
  static const Color psaDarkBlue  = Color(0xFF0D2147);
  static const Color psaLightBlue = Color(0xFF2B5BA8);
  static const Color psaAccent    = Color(0xFFE8C44D);
  static const Color psaRed       = Color(0xFFCC2B2B);
  static const Color psaWhite     = Color(0xFFF8F9FC);

  static const Color success      = Color(0xFF2E7D52);
  static const Color successLight = Color(0xFFE8F5EE);
  static const Color warning      = Color(0xFFB45309);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger       = Color(0xFFCC2B2B);
  static const Color dangerLight  = Color(0xFFFEE2E2);

  static const Color cardBg       = Color(0xFFFFFFFF);
  static const Color scaffoldBg   = Color(0xFFEEF2F8);
  static const Color divider      = Color(0xFFDDE3EF);
  static const Color textPrimary  = Color(0xFF0D1B3E);
  static const Color textSecondary= Color(0xFF4A5A7A);
  static const Color textMuted    = Color(0xFF8A96B0);
}

// ── Special-purpose visitor type ─────────────────────────────────────────────
// The QR→type mapping now lives in ConfigService.specialTypeForQR (returns the
// string 'vendor'/'delivery'); home_screen bridges that string to this enum.

enum SpecialVisitorType { vendor, delivery }

// ── Guard schedule ───────────────────────────────────────────────────────────

class GuardInfo {
  final String name;
  final String shift;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const GuardInfo({
    required this.name,
    required this.shift,
    required this.startTime,
    required this.endTime,
  });
}

/// Rotation math stays here; the guard NAMES and rotationWeeks are read live
/// from ConfigService so admins can edit them in Settings without code changes.
class GuardSchedule {
  // Anchor = start of a "Guard 1 on day shift" week.
  // May 19 2025 — the Monday of the most recent week Guard 1 started day shift.
  // If the rotation pattern ever changes, update this date.
  static final DateTime rotationAnchor = DateTime(2025, 5, 19);

  static const TimeOfDay dayStart   = TimeOfDay(hour: 7,  minute: 0);
  static const TimeOfDay nightStart = TimeOfDay(hour: 19, minute: 0);

  // ── Config-backed names / weeks ──────────────────────────────────────────
  static List<String> get _guards => ConfigService().guards;

  static String get guard1Name =>
      _guards.isNotEmpty ? _guards[0] : 'Guard 1';
  static String get guard2Name =>
      _guards.length > 1 ? _guards[1] : guard1Name;

  static int get rotationWeeks {
    final w = ConfigService().rotationWeeks;
    return w < 1 ? 1 : w;
  }

  static int _currentCycle(DateTime now) {
    final daysSinceAnchor = now.difference(rotationAnchor).inDays;
    final cycleLength = rotationWeeks * 7;
    final adjusted = daysSinceAnchor < 0
        ? daysSinceAnchor - cycleLength + 1
        : daysSinceAnchor;
    return (adjusted / cycleLength).floor().abs() +
        (daysSinceAnchor < 0 ? 1 : 0);
  }

  static bool _isDayShift(DateTime now) =>
      now.hour >= 7 && now.hour < 19;

  static GuardInfo getCurrentGuard([DateTime? overrideNow]) {
    final now = overrideNow ?? DateTime.now();
    final cycle = _currentCycle(now);
    final dayShift = _isDayShift(now);
    final guard1OnDay = cycle.isEven;

    final name = dayShift
        ? (guard1OnDay ? guard1Name : guard2Name)
        : (guard1OnDay ? guard2Name : guard1Name);

    return GuardInfo(
      name: name,
      shift: dayShift ? 'Day Shift' : 'Night Shift',
      startTime: dayShift ? dayStart : nightStart,
      endTime: dayShift ? nightStart : dayStart,
    );
  }

  /// Full configured guard list (used to populate the override dropdown).
  static List<String> getAllGuardNames() => ConfigService().guards;
}

// ── App strings (config-backed office identity) ──────────────────────────────

class AppStrings {
  static String get appTitle     => ConfigService().appTitle;
  static String get organization => ConfigService().organization;
  static String get office       => ConfigService().office;
  static String get republic     => ConfigService().republic;
}