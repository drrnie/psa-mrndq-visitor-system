// lib/services/consolidation_service.dart

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/visitor_model.dart';
import '../services/database_service.dart';
import '../services/config_service.dart';

class ConsolidationService {
  static final ConsolidationService _instance =
  ConsolidationService._internal();
  factory ConsolidationService() => _instance;
  ConsolidationService._internal();

  // ── Human-readable unit labels ────────────────────────────────────────────
  static String _unitLabel(String unitId) {
    switch (unitId) {
      case 'vendor':   return 'Vendor';
      case 'delivery': return 'Delivery';
      default:         return ConfigService().unitById(unitId)?.name ?? unitId;
    }
  }

  static String _unitShort(String? unitId) {
    if (unitId == null)        return 'AllUnits';
    if (unitId == 'vendor')    return 'Vendor';
    if (unitId == 'delivery')  return 'Delivery';
    return ConfigService().unitById(unitId)?.shortName ?? unitId;
  }

  // ── Export directory ──────────────────────────────────────────────────────
  //
  // Tries (in order):
  //   1. External storage → visible in the device's Files app under
  //      Android › data › [package] › files › PSA_Visitor_Logs
  //   2. Internal documents as fallback (not browsable without root)
  //
  Future<Directory> _getExportDir() async {
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.path, 'PSA_Visitor_Logs'));
        await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}

    // Fallback
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory(p.join(docs.path, 'PSA_Visitor_Logs'));
    await dir.create(recursive: true);
    return dir;
  }

  // ── Count ─────────────────────────────────────────────────────────────────
  Future<int> countForMonth(int year, int month, {String? unitId}) async {
    final records = await DatabaseService().getMonthRecords(year, month);
    if (unitId == null) return records.length;
    return records.where((r) => r.unitId == unitId).length;
  }

  Future<int> countForYear(int year, {String? unitId}) async {
    final records = await DatabaseService().getYearRecords(year);
    if (unitId == null) return records.length;
    return records.where((r) => r.unitId == unitId).length;
  }

  // ── Generate CSV (month) ──────────────────────────────────────────────────
  Future<String> generateMonthlyCSV({
    required int year,
    required int month,
    String? unitId,
  }) async {
    var records = await DatabaseService().getMonthRecords(year, month);
    if (unitId != null) records = records.where((r) => r.unitId == unitId).toList();
    records.sort((a, b) => a.checkInTime.compareTo(b.checkInTime));

    final label   = DateFormat('MMMM_yyyy').format(DateTime(year, month));
    final fileName = 'PSA_MRNDQ_${_unitShort(unitId)}_Visitors_$label.csv';
    return _writeCsv(records, fileName);
  }

  // ── Generate CSV (full year) ──────────────────────────────────────────────
  Future<String> generateYearlyCSV({
    required int year,
    String? unitId,
  }) async {
    var records = await DatabaseService().getYearRecords(year);
    if (unitId != null) records = records.where((r) => r.unitId == unitId).toList();
    records.sort((a, b) => a.checkInTime.compareTo(b.checkInTime));

    final fileName = 'PSA_MRNDQ_${_unitShort(unitId)}_Visitors_$year.csv';
    return _writeCsv(records, fileName);
  }

  // ── Shared write logic ────────────────────────────────────────────────────
  Future<String> _writeCsv(List<VisitorRecord> records, String fileName) async {
    final dir  = await _getExportDir();
    final file = File(p.join(dir.path, fileName));

    final buffer  = StringBuffer();
    final dateFmt = DateFormat('MMM dd, yyyy');
    final timeFmt = DateFormat('hh:mm a');

    buffer.writeln(
      '"#","Visitor ID","Visitor Name","Agency / Organization",'
          '"Purpose","Type","Group Count","Guard on Duty","Unit",'
          '"Check-In Date","Check-In Time","Check-Out Date","Check-Out Time","Duration (mins)"',
    );

    int row = 1;
    for (final r in records) {
      final checkOutDate = r.checkOutTime != null
          ? dateFmt.format(r.checkOutTime!) : '';
      final checkOutTime = r.checkOutTime != null
          ? timeFmt.format(r.checkOutTime!) : '';
      final duration = r.checkOutTime != null
          ? r.checkOutTime!.difference(r.checkInTime).inMinutes.toString()
          : '';

      buffer.writeln(
        '"$row",'
            '"${_e(r.visitorId)}",'
            '"${_e(r.visitorName)}",'
            '"${_e(r.agency)}",'
            '"${_e(r.purpose)}",'
            '"${r.isGroup ? 'Group' : 'Individual'}",'
            '"${r.groupCount ?? ''}",'
            '"${_e(r.guardOnDuty)}",'
            '"${_e(_unitLabel(r.unitId))}",'
            '"${dateFmt.format(r.checkInTime)}",'
            '"${timeFmt.format(r.checkInTime)}",'
            '"$checkOutDate",'
            '"$checkOutTime",'
            '"$duration"',
      );
      row++;
    }

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  String _e(String s) => s.replaceAll('"', '""');
}