// lib/screens/logs_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/visitor_model.dart';
import '../services/database_service.dart';
import '../services/consolidation_service.dart';
import '../services/config_service.dart';
import '../utils/constants.dart';
import '../widgets/psa_dialogs.dart';

class LogsScreen extends StatefulWidget {
  final VoidCallback onBack;

  const LogsScreen({super.key, required this.onBack});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _dbService      = DatabaseService();
  final _consolidation  = ConsolidationService();

  List<VisitorRecord> _allRecords = []; // unfiltered
  List<VisitorRecord> _records    = []; // after filtering
  bool _loading       = false;
  bool _consolidating = false;

  // ── Filters ─────────────────────────────────────────────────────────────
  String  _timeFilter = 'all';   // all | today | active
  String? _unitFilter;           // null = All Units; otherwise unitId string

  // Unit chip definitions — standard units + vendor/delivery
  // Filter chips are derived from ConfigService so admin edits to units
  // (name / color / add / remove) are reflected here automatically. The two
  // special-type chips (vendor / delivery) are always appended.
  List<({String id, String label, Color color})> get _unitChips => [
    for (final u in ConfigService().units)
      (id: u.id, label: u.name.replaceAll(' Unit', ''), color: u.color),
    (id: 'vendor',   label: 'Vendor',   color: AppColors.psaAccent),
    (id: 'delivery', label: 'Delivery', color: AppColors.psaLightBlue),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // ── Data ─────────────────────────────────────────────────────────────────
  Future<void> _loadRecords() async {
    setState(() => _loading = true);
    try {
      final raw = _timeFilter == 'today'
          ? await _dbService.getTodayRecords()
          : await _dbService.getAllRecords();

      _allRecords = raw;
      _applyFilters();
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var filtered = _allRecords;

    // Time filter
    if (_timeFilter == 'active') {
      filtered = filtered.where((r) => r.isActive).toList();
    }

    // Unit filter
    if (_unitFilter != null) {
      filtered = filtered.where((r) => r.unitId == _unitFilter).toList();
    }

    setState(() {
      _records = filtered;
      _loading = false;
    });
  }

  // ── Consolidation ─────────────────────────────────────────────────────────
  Future<void> _showConsolidateDialog() async {
    final now = DateTime.now();
    int selectedYear   = now.year;
    int selectedMonth  = now.month;
    String? selectedUnit = _unitFilter;
    bool fullYear = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: AppColors.psaBlue.withValues(alpha: 0.15),
                  blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: AppColors.psaBlue,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.summarize_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Monthly Consolidation',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('Select unit, month, and year to export',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.white60)),
                      ],
                    )),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Unit selector
                      Text('Unit', style: GoogleFonts.outfit(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: [
                          _dialogChip('All Units', null, selectedUnit, (v) => setS(() => selectedUnit = v)),
                          ..._unitChips.map((u) => _dialogChip(
                              u.label, u.id, selectedUnit,
                                  (v) => setS(() => selectedUnit = v))),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Export period toggle
                      Text('Export Period', style: GoogleFonts.outfit(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        _dialogChip('Monthly', false, fullYear,
                                (v) => setS(() => fullYear = v as bool)),
                        const SizedBox(width: 8),
                        _dialogChip('Full Year', true, fullYear,
                                (v) => setS(() => fullYear = v as bool)),
                      ]),
                      const SizedBox(height: 16),

                      // Month + Year pickers
                      Row(children: [
                        if (!fullYear)
                          Expanded(flex: 3, child: _picker(
                            label: 'Month',
                            child: DropdownButton<int>(
                              value: selectedMonth,
                              isExpanded: true,
                              underline: const SizedBox(),
                              onChanged: (v) => setS(() => selectedMonth = v!),
                              items: List.generate(12, (i) => i + 1).map((m) =>
                                  DropdownMenuItem(
                                    value: m,
                                    child: Text(DateFormat('MMMM')
                                        .format(DateTime(2000, m)),
                                        style: GoogleFonts.outfit(fontSize: 14)),
                                  )).toList(),
                            ),
                          )),
                        if (!fullYear) const SizedBox(width: 12),
                        Expanded(flex: 2, child: _picker(
                          label: 'Year',
                          child: DropdownButton<int>(
                            value: selectedYear,
                            isExpanded: true,
                            underline: const SizedBox(),
                            onChanged: (v) => setS(() => selectedYear = v!),
                            items: List.generate(3, (i) => now.year - i).map((y) =>
                                DropdownMenuItem(
                                  value: y,
                                  child: Text('$y', style: GoogleFonts.outfit(fontSize: 14)),
                                )).toList(),
                          ),
                        )),
                      ]),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              size: 15, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                              'Only records from this tablet\'s local database are included.',
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppColors.warning))),
                        ]),
                      ),
                      const SizedBox(height: 24),

                      Row(children: [
                        Expanded(child: TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Cancel', style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600)),
                        )),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _doConsolidate(
                                selectedYear, selectedMonth,
                                selectedUnit, fullYear);
                          },
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text('Generate CSV',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.psaBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        )),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogChip(String label, dynamic value, dynamic selected,
      void Function(dynamic) onTap) {
    final isSelected = selected == value;
    Color color = AppColors.psaBlue;
    if (value is String?) {
      color = value == null
          ? AppColors.psaBlue
          : _unitChips
          .where((u) => u.id == value)
          .map((u) => u.color)
          .firstOrNull ?? AppColors.psaBlue;
    }
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? color : AppColors.divider),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            )),
      ),
    );
  }

  Future<void> _doConsolidate(
      int year, int month, String? unitId, bool fullYear) async {
    setState(() => _consolidating = true);
    try {
      final count = fullYear
          ? await _consolidation.countForYear(year, unitId: unitId)
          : await _consolidation.countForMonth(year, month, unitId: unitId);

      if (count == 0) {
        if (!mounted) return;
        final period = fullYear
            ? '$year'
            : DateFormat('MMMM yyyy').format(DateTime(year, month));
        await showErrorDialog(context,
            title: 'No Records Found',
            message: 'No visitor records found for $period'
                '${unitId != null ? ' in the selected unit' : ''}.');
        return;
      }

      final filePath = fullYear
          ? await _consolidation.generateYearlyCSV(
          year: year, unitId: unitId)
          : await _consolidation.generateMonthlyCSV(
          year: year, month: month, unitId: unitId);

      if (!mounted) return;

      final unitLabel = unitId == null
          ? 'All Units'
          : _unitChips
          .where((u) => u.id == unitId)
          .map((u) => u.label)
          .firstOrNull ?? unitId;

      final periodLabel = fullYear
          ? '$year (Full Year)'
          : DateFormat('MMMM yyyy').format(DateTime(year, month));

      final fileName = filePath.split('/').last;

      // Show where the file was saved with an option to also share it
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: AppColors.psaBlue.withValues(alpha: 0.15),
                  blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CSV Saved',
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        Text('$count records exported',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: Colors.white70)),
                      ],
                    )),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('File saved to:',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.scaffoldBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Files app → Android → data → [app] → files → PSA_Visitor_Logs',
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.5)),
                            const SizedBox(height: 4),
                            Text(fileName,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: AppColors.psaBlue)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await Share.shareXFiles(
                                [XFile(filePath)],
                                subject: 'PSA Visitor Log — $unitLabel — $periodLabel',
                              );
                            },
                            icon: const Icon(Icons.share_rounded, size: 16),
                            label: Text('Share',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.psaBlue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.psaBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: Text('Done',
                                style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context,
          title: 'Export Failed',
          message: 'Could not generate the report: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _consolidating = false);
    }
  }

  Widget _picker({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: AppColors.textMuted)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeChip = _unitFilter == null
        ? null
        : _unitChips.where((u) => u.id == _unitFilter).firstOrNull;

    return Container(
      color: AppColors.scaffoldBg,
      child: Column(children: [
        // ── Header ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          color: AppColors.psaBlue,
          child: Row(children: [
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VISITOR LOGS',
                    style: GoogleFonts.outfit(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: AppColors.psaAccent, letterSpacing: 1.5)),
                Text(
                    activeChip != null ? '${activeChip.label} Unit' : 'All Units',
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            )),

            if (_consolidating)
              const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
            else
              GestureDetector(
                onTap: _showConsolidateDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.psaAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.psaAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.summarize_rounded,
                        color: AppColors.psaAccent, size: 16),
                    const SizedBox(width: 6),
                    Text('Export CSV',
                        style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.psaAccent)),
                  ]),
                ),
              ),

            const SizedBox(width: 8),
            IconButton(
                onPressed: _loadRecords,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white)),
          ]),
        ),

        // ── Filter Bar ────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: time filters
              Row(children: [
                _timeChip('All Records', 'all'),
                const SizedBox(width: 8),
                _timeChip('Today', 'today'),
                const SizedBox(width: 8),
                _timeChip('Active Now', 'active'),
              ]),
              const SizedBox(height: 8),
              // Row 2: unit filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _unitChipWidget('All Units', null),
                  const SizedBox(width: 8),
                  ..._unitChips.map((u) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _unitChipWidget(u.label, u.id, color: u.color),
                  )),
                ]),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),

        // ── Record Count ──────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(children: [
            Text('${_records.length} record${_records.length == 1 ? '' : 's'}',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.textMuted)),
          ]),
        ),

        const Divider(height: 1, color: Color(0xFFE5E9F2)),

        // ── Record List ───────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _records.isEmpty
              ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open_rounded,
                  size: 56, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text('No records found',
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: AppColors.textMuted)),
            ],
          ))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _records.length,
            itemBuilder: (_, i) => _recordCard(_records[i]),
          ),
        ),
      ]),
    );
  }

  // ── Filter chips ──────────────────────────────────────────────────────────
  Widget _timeChip(String label, String value) {
    final selected = _timeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _timeFilter = value);
        _loadRecords();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.psaBlue : AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.psaBlue : AppColors.divider),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _unitChipWidget(String label, String? unitId,
      {Color color = AppColors.psaBlue}) {
    final selected = _unitFilter == unitId;
    return GestureDetector(
      onTap: () {
        setState(() => _unitFilter = unitId);
        _applyFilters();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : AppColors.divider),
        ),
        child: Text(label,
            style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  // ── Record card ───────────────────────────────────────────────────────────
  Widget _recordCard(VisitorRecord record) {
    final isActive   = record.isActive;
    final chipData   = _unitChips
        .where((u) => u.id == record.unitId)
        .firstOrNull;
    final unitColor  = chipData?.color ?? AppColors.psaBlue;
    final unitLabel  = chipData?.label ?? record.unitId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.divider,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
              color: isActive ? AppColors.success : AppColors.textMuted,
              shape: BoxShape.circle),
        ),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(record.visitorId,
                  style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: unitColor, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              _badge(unitLabel, unitColor),
              if (record.isGroup) ...[
                const SizedBox(width: 6),
                _badge('Group ×${record.groupCount}', AppColors.psaBlue),
              ],
              const Spacer(),
              _badge(
                isActive ? 'Active' : 'Checked Out',
                isActive ? AppColors.success : AppColors.textMuted,
                bg: isActive ? AppColors.successLight : AppColors.scaffoldBg,
              ),
            ]),
            const SizedBox(height: 3),
            Text(record.visitorName,
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            Text(record.agency,
                style: GoogleFonts.outfit(
                    fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.login_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(DateFormat('MMM dd, hh:mm a').format(record.checkInTime),
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.textMuted)),
              if (record.checkOutTime != null) ...[
                const SizedBox(width: 10),
                const Icon(Icons.logout_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(DateFormat('hh:mm a').format(record.checkOutTime!),
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.textMuted)),
              ],
              const Spacer(),
              const Icon(Icons.security_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 3),
              Text(record.guardOnDuty.split(' ').first,
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.textMuted)),
            ]),
          ],
        )),
      ]),
    );
  }

  Widget _badge(String label, Color color, {Color? bg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: bg ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5)),
    child: Text(label,
        style: GoogleFonts.outfit(
            fontSize: 10, fontWeight: FontWeight.w600, color: color)),
  );
}