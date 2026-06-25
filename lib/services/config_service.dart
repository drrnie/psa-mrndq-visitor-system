// lib/services/config_service.dart
//
// Central runtime configuration store for the entire app.
//
// Everything that used to be hard-coded in constants.dart now lives here,
// persisted as JSON in SharedPreferences and editable through the admin
// Settings screen. On first launch the store is seeded from DefaultConfig
// (which mirrors the original hard-coded values), so existing deployments
// behave identically until an administrator changes something.
//
// This service is a ChangeNotifier singleton: editors call the mutators,
// listeners (the scanner home, check-in forms, logs, etc.) rebuild
// automatically.

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data models (mutable, JSON-serializable versions of the old const classes)
// ─────────────────────────────────────────────────────────────────────────────

class UnitDef {
  String id;
  String name;
  String shortName;
  int    qrStart;
  int    qrEnd;
  int    colorValue; // ARGB int, e.g. 0xFF1A3A6B

  UnitDef({
    required this.id,
    required this.name,
    required this.shortName,
    required this.qrStart,
    required this.qrEnd,
    required this.colorValue,
  });

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'shortName': shortName,
        'qrStart': qrStart,
        'qrEnd': qrEnd,
        'colorValue': colorValue,
      };

  factory UnitDef.fromJson(Map<String, dynamic> j) => UnitDef(
        id: j['id'] as String,
        name: j['name'] as String,
        shortName: j['shortName'] as String,
        qrStart: j['qrStart'] as int,
        qrEnd: j['qrEnd'] as int,
        colorValue: j['colorValue'] as int,
      );

  UnitDef copy() => UnitDef(
        id: id,
        name: name,
        shortName: shortName,
        qrStart: qrStart,
        qrEnd: qrEnd,
        colorValue: colorValue,
      );
}

class SpecialRangeDef {
  // 'vendor' or 'delivery'
  String type;
  int    qrStart;
  int    qrEnd;

  SpecialRangeDef({
    required this.type,
    required this.qrStart,
    required this.qrEnd,
  });

  Map<String, dynamic> toJson() =>
      {'type': type, 'qrStart': qrStart, 'qrEnd': qrEnd};

  factory SpecialRangeDef.fromJson(Map<String, dynamic> j) => SpecialRangeDef(
        type: j['type'] as String,
        qrStart: j['qrStart'] as int,
        qrEnd: j['qrEnd'] as int,
      );

  SpecialRangeDef copy() =>
      SpecialRangeDef(type: type, qrStart: qrStart, qrEnd: qrEnd);
}

// ─────────────────────────────────────────────────────────────────────────────
// Default configuration — mirrors the original hard-coded values
// ─────────────────────────────────────────────────────────────────────────────

class DefaultConfig {
  static const String qrPrefix     = 'PSA-MRNDQ-VISIT-';
  static const String organization = 'Philippine Statistics Authority';
  static const String office       = 'Marinduque Provincial Statistical Office';
  static const String appTitle     = 'Visitor Logging System';
  static const String republic     = 'Republic of the Philippines';

  // Default admin password is "1740..p$A". We ship only its hash.
  // Salt is fixed per-build; rehashed if the admin changes the password.
  static const String passwordSalt = 'PSA_MRNDQ_SALT_v1';
  static String defaultPasswordHash() =>
      ConfigService.hashPassword(r'1740..p$A');

  static List<UnitDef> units() => [
        UnitDef(id: 'statistical',    name: 'Statistical Unit',
            shortName: 'Stat',  qrStart: 1,  qrEnd: 10, colorValue: 0xFF1A3A6B),
        UnitDef(id: 'administrative', name: 'Administrative Unit',
            shortName: 'Admin', qrStart: 11, qrEnd: 20, colorValue: 0xFF2E7D52),
        UnitDef(id: 'civil_registry', name: 'Civil Registry Unit',
            shortName: 'CRU',   qrStart: 21, qrEnd: 30, colorValue: 0xFF7B3F9E),
        UnitDef(id: 'national_id',    name: 'National ID Unit',
            shortName: 'NID',   qrStart: 31, qrEnd: 40, colorValue: 0xFFB45309),
      ];

  static List<SpecialRangeDef> specialRanges() => [
        SpecialRangeDef(type: 'vendor',   qrStart: 41, qrEnd: 43),
        SpecialRangeDef(type: 'delivery', qrStart: 44, qrEnd: 45),
        SpecialRangeDef(type: 'vendor',   qrStart: 46, qrEnd: 48),
        SpecialRangeDef(type: 'delivery', qrStart: 49, qrEnd: 50),
      ];

  static List<String> couriers() => [
        'J&T Express', 'Shopee Express', 'LBC', 'JRS Express', 'AP Cargo',
        'Flash Express', 'Dory Delivery', 'YNP Delivery', 'Goodchow',
        'Water Delivery', 'Others, please specify',
      ];

  static List<String> purposes() => [
        'Data Request',
        'Endorsement (for OJT, etc.)',
        'Receiving of Documents (letters, notices)',
        'Others, please specify',
      ];

  static List<String> guards() => [
        'Michael Magcamit', 'Christian Malapad', 'Civil Registry Unit',
      ];

  static int rotationWeeks() => 1;
}

// ─────────────────────────────────────────────────────────────────────────────
// ConfigService
// ─────────────────────────────────────────────────────────────────────────────

class ConfigService extends ChangeNotifier {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  static const _kKey = 'psa_app_config_v1';

  // ── Live state ────────────────────────────────────────────────────────────
  late String _qrPrefix;
  late String _organization;
  late String _office;
  late String _appTitle;
  late String _republic;
  late String _passwordHash;
  late bool   _passwordIsDefault;
  late List<UnitDef> _units;
  late List<SpecialRangeDef> _specialRanges;
  late List<String> _couriers;
  late List<String> _purposes;
  late List<String> _guards;
  late int _rotationWeeks;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  // ── Getters ───────────────────────────────────────────────────────────────
  String get qrPrefix     => _qrPrefix;
  String get organization => _organization;
  String get office       => _office;
  String get appTitle     => _appTitle;
  String get republic     => _republic;
  bool   get passwordIsDefault => _passwordIsDefault;
  List<UnitDef> get units => _units;
  List<SpecialRangeDef> get specialRanges => _specialRanges;
  List<String> get couriers => _couriers;
  List<String> get purposes => _purposes;
  List<String> get guards   => _guards;
  int get rotationWeeks     => _rotationWeeks;

  // ── Password hashing ───────────────────────────────────────────────────────
  static String hashPassword(String plain) {
    final bytes = utf8.encode('${DefaultConfig.passwordSalt}|$plain');
    return sha256.convert(bytes).toString();
  }

  bool verifyPassword(String plain) =>
      hashPassword(plain) == _passwordHash;

  // ── Load / seed ────────────────────────────────────────────────────────────
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null) {
        _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      } else {
        _seedDefaults();
        await _persist();
      }
    } catch (_) {
      _seedDefaults();
    }
    _loaded = true;
  }

  void _seedDefaults() {
    _qrPrefix          = DefaultConfig.qrPrefix;
    _organization      = DefaultConfig.organization;
    _office            = DefaultConfig.office;
    _appTitle          = DefaultConfig.appTitle;
    _republic          = DefaultConfig.republic;
    _passwordHash      = DefaultConfig.defaultPasswordHash();
    _passwordIsDefault = true;
    _units             = DefaultConfig.units();
    _specialRanges     = DefaultConfig.specialRanges();
    _couriers          = DefaultConfig.couriers();
    _purposes          = DefaultConfig.purposes();
    _guards            = DefaultConfig.guards();
    _rotationWeeks     = DefaultConfig.rotationWeeks();
  }

  void _applyJson(Map<String, dynamic> j) {
    _qrPrefix          = j['qrPrefix']     as String? ?? DefaultConfig.qrPrefix;
    _organization      = j['organization'] as String? ?? DefaultConfig.organization;
    _office            = j['office']       as String? ?? DefaultConfig.office;
    _appTitle          = j['appTitle']     as String? ?? DefaultConfig.appTitle;
    _republic          = j['republic']     as String? ?? DefaultConfig.republic;
    _passwordHash      = j['passwordHash'] as String? ?? DefaultConfig.defaultPasswordHash();
    _passwordIsDefault = j['passwordIsDefault'] as bool? ?? false;
    _units = (j['units'] as List? ?? [])
        .map((e) => UnitDef.fromJson(e as Map<String, dynamic>))
        .toList();
    if (_units.isEmpty) _units = DefaultConfig.units();
    _specialRanges = (j['specialRanges'] as List? ?? [])
        .map((e) => SpecialRangeDef.fromJson(e as Map<String, dynamic>))
        .toList();
    if (_specialRanges.isEmpty) _specialRanges = DefaultConfig.specialRanges();
    _couriers      = (j['couriers'] as List? ?? []).cast<String>();
    if (_couriers.isEmpty) _couriers = DefaultConfig.couriers();
    _purposes      = (j['purposes'] as List? ?? []).cast<String>();
    if (_purposes.isEmpty) _purposes = DefaultConfig.purposes();
    _guards        = (j['guards'] as List? ?? []).cast<String>();
    if (_guards.isEmpty) _guards = DefaultConfig.guards();
    _rotationWeeks = j['rotationWeeks'] as int? ?? DefaultConfig.rotationWeeks();
  }

  Map<String, dynamic> _toJson() => {
        'qrPrefix': _qrPrefix,
        'organization': _organization,
        'office': _office,
        'appTitle': _appTitle,
        'republic': _republic,
        'passwordHash': _passwordHash,
        'passwordIsDefault': _passwordIsDefault,
        'units': _units.map((u) => u.toJson()).toList(),
        'specialRanges': _specialRanges.map((s) => s.toJson()).toList(),
        'couriers': _couriers,
        'purposes': _purposes,
        'guards': _guards,
        'rotationWeeks': _rotationWeeks,
      };

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kKey, jsonEncode(_toJson()));
    } catch (_) {}
  }

  Future<void> _save() async {
    await _persist();
    notifyListeners();
  }

  // ── QR helpers (replace the old QRConfig / PSAUnit logic) ──────────────────

  String codeFor(int n) => '$_qrPrefix${n.toString().padLeft(3, '0')}';

  /// Highest QR number referenced by any unit or special range.
  int get maxCode {
    int m = 0;
    for (final u in _units) { if (u.qrEnd > m) m = u.qrEnd; }
    for (final s in _specialRanges) { if (s.qrEnd > m) m = s.qrEnd; }
    return m;
  }

  /// Returns the unit that owns [qrData], or null.
  UnitDef? unitForQR(String qrData) {
    final n = _numberFor(qrData);
    if (n == null) return null;
    for (final u in _units) {
      if (n >= u.qrStart && n <= u.qrEnd) return u;
    }
    return null;
  }

  UnitDef? unitById(String id) =>
      _units.where((u) => u.id == id).firstOrNull;

  /// Returns 'vendor', 'delivery', or null for the given QR code.
  String? specialTypeForQR(String qrData) {
    final n = _numberFor(qrData);
    if (n == null) return null;
    for (final s in _specialRanges) {
      if (n >= s.qrStart && n <= s.qrEnd) return s.type;
    }
    return null;
  }

  /// True if the code matches the configured prefix and falls in any
  /// configured unit or special range.
  bool isKnownCode(String qrData) {
    final n = _numberFor(qrData);
    if (n == null) return false;
    return unitForQR(qrData) != null || specialTypeForQR(qrData) != null;
  }

  int? _numberFor(String qrData) {
    final s = qrData.trim();
    if (!s.startsWith(_qrPrefix)) return null;
    final tail = s.substring(_qrPrefix.length);
    return int.tryParse(tail);
  }

  // ── Mutators ───────────────────────────────────────────────────────────────

  // Password
  Future<void> setPassword(String newPlain) async {
    _passwordHash = hashPassword(newPlain);
    _passwordIsDefault = false;
    await _save();
  }

  // Office info
  Future<void> setOfficeInfo({
    String? organization, String? office, String? appTitle,
    String? republic, String? qrPrefix,
  }) async {
    if (organization != null) _organization = organization;
    if (office != null)       _office = office;
    if (appTitle != null)     _appTitle = appTitle;
    if (republic != null)     _republic = republic;
    if (qrPrefix != null && qrPrefix.trim().isNotEmpty) {
      _qrPrefix = qrPrefix.trim();
    }
    await _save();
  }

  // Units
  Future<void> upsertUnit(UnitDef unit) async {
    final i = _units.indexWhere((u) => u.id == unit.id);
    if (i >= 0) {
      _units[i] = unit;
    } else {
      _units.add(unit);
    }
    await _save();
  }

  Future<void> deleteUnit(String id) async {
    _units.removeWhere((u) => u.id == id);
    await _save();
  }

  // Special ranges
  Future<void> setSpecialRanges(List<SpecialRangeDef> ranges) async {
    _specialRanges = ranges;
    await _save();
  }

  // Couriers
  Future<void> setCouriers(List<String> list) async {
    _couriers = list;
    await _save();
  }

  // Purposes
  Future<void> setPurposes(List<String> list) async {
    _purposes = list;
    await _save();
  }

  // Guards
  Future<void> setGuards(List<String> list) async {
    _guards = list;
    await _save();
  }

  Future<void> setRotationWeeks(int weeks) async {
    _rotationWeeks = weeks < 1 ? 1 : weeks;
    await _save();
  }

  // Reset everything to factory defaults
  Future<void> resetToDefaults() async {
    _seedDefaults();
    await _save();
  }
}
