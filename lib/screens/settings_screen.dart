// lib/screens/settings_screen.dart
//
// Admin-only Settings screen. Reachable from the admin mode bar (home_screen).
// Provides six editors, each backed by ConfigService:
//   1. Office Info        — organization, office, app title, republic, QR prefix
//   2. Units              — name/short/QR range/color  + special (vendor/delivery) ranges
//   3. Delivery Providers — courier list
//   4. Guards             — guard names + rotation weeks
//   5. Purposes           — visitor purpose list
//   6. Security           — change admin password
//
// All mutations persist immediately via ConfigService (SharedPreferences).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/config_service.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _config = ConfigService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Settings',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _menuCard(
            icon: Icons.business_rounded,
            title: 'Office Info',
            subtitle: 'Organization, office, titles, QR prefix',
            onTap: () => _open(const _OfficeInfoEditor()),
          ),
          _menuCard(
            icon: Icons.apartment_rounded,
            title: 'Units',
            subtitle: '${_config.units.length} units · QR ranges & colors',
            onTap: () => _open(const _UnitsEditor()),
          ),
          _menuCard(
            icon: Icons.local_shipping_rounded,
            title: 'Delivery Providers',
            subtitle: '${_config.couriers.length} couriers',
            onTap: () => _open(const _StringListEditor(
              kind: _ListKind.couriers,
              title: 'Delivery Providers',
            )),
          ),
          _menuCard(
            icon: Icons.security_rounded,
            title: 'Guards',
            subtitle: '${_config.guards.length} guards · '
                'rotates every ${_config.rotationWeeks} wk',
            onTap: () => _open(const _GuardsEditor()),
          ),
          _menuCard(
            icon: Icons.assignment_rounded,
            title: 'Purposes',
            subtitle: '${_config.purposes.length} visit purposes',
            onTap: () => _open(const _StringListEditor(
              kind: _ListKind.purposes,
              title: 'Visit Purposes',
            )),
          ),
          _menuCard(
            icon: Icons.lock_rounded,
            title: 'Security',
            subtitle: _config.passwordIsDefault
                ? 'Using DEFAULT password — change recommended'
                : 'Admin password set',
            danger: _config.passwordIsDefault,
            onTap: () => _open(const _SecurityEditor()),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _confirmReset,
            icon: const Icon(Icons.restart_alt_rounded,
                color: AppColors.danger),
            label: Text('Reset all settings to factory defaults',
                style: GoogleFonts.outfit(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Widget editor) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => editor));
    if (mounted) setState(() {}); // refresh subtitles after editing
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset everything?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          'This restores all units, providers, guards, purposes, office info '
              'and the admin password to their original defaults. Visitor records '
              'are not affected.',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _config.resetToDefaults();
      if (mounted) setState(() {});
    }
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: danger
                ? AppColors.danger.withValues(alpha: 0.4)
                : AppColors.divider),
      ),
      color: AppColors.cardBg,
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: (danger ? AppColors.danger : AppColors.psaBlue)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon,
              color: danger ? AppColors.danger : AppColors.psaBlue, size: 20),
        ),
        title: Text(title,
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Text(subtitle,
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded,
            color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

InputDecoration _fieldDeco(String label) => InputDecoration(
  labelText: label,
  labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary),
  filled: true,
  fillColor: AppColors.cardBg,
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.divider),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AppColors.psaBlue, width: 1.6),
  ),
);

Widget _saveBar(BuildContext context, VoidCallback onSave) => Padding(
  padding: const EdgeInsets.all(16),
  child: SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      onPressed: onSave,
      icon: const Icon(Icons.check_rounded),
      label: Text('Save',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
  ),
);

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.outfit()),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Office Info
// ─────────────────────────────────────────────────────────────────────────────

class _OfficeInfoEditor extends StatefulWidget {
  const _OfficeInfoEditor();
  @override
  State<_OfficeInfoEditor> createState() => _OfficeInfoEditorState();
}

class _OfficeInfoEditorState extends State<_OfficeInfoEditor> {
  final _config = ConfigService();
  late final TextEditingController _org;
  late final TextEditingController _office;
  late final TextEditingController _title;
  late final TextEditingController _republic;
  late final TextEditingController _prefix;

  @override
  void initState() {
    super.initState();
    _org = TextEditingController(text: _config.organization);
    _office = TextEditingController(text: _config.office);
    _title = TextEditingController(text: _config.appTitle);
    _republic = TextEditingController(text: _config.republic);
    _prefix = TextEditingController(text: _config.qrPrefix);
  }

  @override
  void dispose() {
    _org.dispose();
    _office.dispose();
    _title.dispose();
    _republic.dispose();
    _prefix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _config.setOfficeInfo(
      organization: _org.text.trim(),
      office: _office.text.trim(),
      appTitle: _title.text.trim(),
      republic: _republic.text.trim(),
      qrPrefix: _prefix.text.trim(),
    );
    if (!mounted) return;
    _toast(context, 'Office info saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Office Info',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _republic, decoration: _fieldDeco('Republic line')),
          const SizedBox(height: 14),
          TextField(controller: _org, decoration: _fieldDeco('Organization')),
          const SizedBox(height: 14),
          TextField(controller: _office, decoration: _fieldDeco('Office')),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: _fieldDeco('App title')),
          const SizedBox(height: 14),
          TextField(
            controller: _prefix,
            decoration: _fieldDeco('QR code prefix'),
          ),
          const SizedBox(height: 8),
          Text(
            'Changing the QR prefix means previously printed visitor QR codes '
                'will no longer be recognized. Only change this if you are '
                'reprinting all codes.',
            style: GoogleFonts.outfit(
                fontSize: 11.5, color: AppColors.warning),
          ),
        ],
      ),
      bottomNavigationBar: _saveBar(context, _save),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Units (+ special ranges)
// ─────────────────────────────────────────────────────────────────────────────

const List<int> _unitPalette = [
  0xFF1A3A6B, 0xFF2E7D52, 0xFF7B3F9E, 0xFFB45309,
  0xFF2B5BA8, 0xFFCC2B2B, 0xFF0D7377, 0xFF8E44AD,
];

class _UnitsEditor extends StatefulWidget {
  const _UnitsEditor();
  @override
  State<_UnitsEditor> createState() => _UnitsEditorState();
}

class _UnitsEditorState extends State<_UnitsEditor> {
  final _config = ConfigService();

  Future<void> _editUnit(UnitDef? existing) async {
    final draft = existing?.copy() ??
        UnitDef(
          id: '',
          name: '',
          shortName: '',
          qrStart: _config.maxCode + 1,
          qrEnd: _config.maxCode + 1,
          colorValue: _unitPalette[
          _config.units.length % _unitPalette.length],
        );
    final saved = await showDialog<UnitDef>(
      context: context,
      builder: (_) => _UnitDialog(unit: draft, isNew: existing == null),
    );
    if (saved != null) {
      await _config.upsertUnit(saved);
      if (mounted) setState(() {});
    }
  }

  Future<void> _delete(UnitDef u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${u.name}"?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        content: Text(
          'New scans in range ${u.qrStart}–${u.qrEnd} will no longer be '
              'recognized. Existing visitor records are kept.',
          style: GoogleFonts.outfit(fontSize: 13),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _config.deleteUnit(u.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Units',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editUnit(null),
        backgroundColor: AppColors.psaBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add Unit',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
        children: [
          ..._config.units.map((u) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.divider),
            ),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: u.color, radius: 12),
              title: Text(u.name,
                  style:
                  GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              subtitle: Text(
                  '${u.shortName} · QR ${u.qrStart}–${u.qrEnd}',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textSecondary)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.psaBlue, size: 20),
                      onPressed: () => _editUnit(u)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      onPressed: () => _delete(u)),
                ],
              ),
            ),
          )),
          const SizedBox(height: 8),
          _SpecialRangesCard(onChanged: () => setState(() {})),
        ],
      ),
    );
  }
}

class _UnitDialog extends StatefulWidget {
  final UnitDef unit;
  final bool isNew;
  const _UnitDialog({required this.unit, required this.isNew});
  @override
  State<_UnitDialog> createState() => _UnitDialogState();
}

class _UnitDialogState extends State<_UnitDialog> {
  late final TextEditingController _name;
  late final TextEditingController _short;
  late final TextEditingController _start;
  late final TextEditingController _end;
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.unit.name);
    _short = TextEditingController(text: widget.unit.shortName);
    _start = TextEditingController(text: widget.unit.qrStart.toString());
    _end = TextEditingController(text: widget.unit.qrEnd.toString());
    _color = widget.unit.colorValue;
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  String _slug(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  void _submit() {
    final name = _name.text.trim();
    final short = _short.text.trim();
    final start = int.tryParse(_start.text.trim());
    final end = int.tryParse(_end.text.trim());
    if (name.isEmpty || short.isEmpty) {
      setState(() => _error = 'Name and short name are required.');
      return;
    }
    if (start == null || end == null || start < 1 || end < start) {
      setState(() => _error = 'Enter a valid QR range (start ≤ end, ≥ 1).');
      return;
    }
    final id = widget.isNew
        ? (_slug(name).isEmpty ? 'unit_${DateTime.now().millisecondsSinceEpoch}'
        : _slug(name))
        : widget.unit.id;
    Navigator.pop(
      context,
      UnitDef(
        id: id,
        name: name,
        shortName: short,
        qrStart: start,
        qrEnd: end,
        colorValue: _color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add Unit' : 'Edit Unit',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Text(_error!,
                  style: GoogleFonts.outfit(
                      color: AppColors.danger, fontSize: 12.5)),
              const SizedBox(height: 10),
            ],
            TextField(controller: _name, decoration: _fieldDeco('Unit name')),
            const SizedBox(height: 12),
            TextField(
                controller: _short, decoration: _fieldDeco('Short name')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _start,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDeco('QR start'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _end,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _fieldDeco('QR end'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Color',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _unitPalette.map((c) {
                final selected = c == _color;
                return GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check,
                        color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.psaBlue,
              foregroundColor: Colors.white),
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SpecialRangesCard extends StatefulWidget {
  final VoidCallback onChanged;
  const _SpecialRangesCard({required this.onChanged});
  @override
  State<_SpecialRangesCard> createState() => _SpecialRangesCardState();
}

class _SpecialRangesCardState extends State<_SpecialRangesCard> {
  final _config = ConfigService();
  late List<SpecialRangeDef> _ranges;

  @override
  void initState() {
    super.initState();
    _ranges = _config.specialRanges.map((r) => r.copy()).toList();
  }

  Future<void> _persist() async {
    await _config.setSpecialRanges(_ranges.map((r) => r.copy()).toList());
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Special QR Ranges (Vendor / Delivery)',
                style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'QR numbers in these ranges open the vendor or delivery flow '
                  'instead of a unit.',
              style: GoogleFonts.outfit(
                  fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            ..._ranges.asMap().entries.map((e) {
              final i = e.key;
              final r = e.value;
              return Padding(
                key: ValueKey(r),
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: r.type,
                        decoration: _fieldDeco('Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'vendor', child: Text('Vendor')),
                          DropdownMenuItem(
                              value: 'delivery', child: Text('Delivery')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => r.type = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: r.qrStart.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _fieldDeco('Start'),
                        onChanged: (v) =>
                        r.qrStart = int.tryParse(v) ?? r.qrStart,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: r.qrEnd.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _fieldDeco('End'),
                        onChanged: (v) =>
                        r.qrEnd = int.tryParse(v) ?? r.qrEnd,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: AppColors.danger),
                      onPressed: () => setState(() => _ranges.removeAt(i)),
                    ),
                  ],
                ),
              );
            }),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _ranges.add(
                      SpecialRangeDef(type: 'vendor', qrStart: 1, qrEnd: 1))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add range'),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.psaBlue,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await _persist();
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('Special ranges saved',
                            style: GoogleFonts.outfit()),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ));
                  },
                  child: const Text('Save ranges'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3 & 5. Generic string-list editor (couriers / purposes)
// ─────────────────────────────────────────────────────────────────────────────

enum _ListKind { couriers, purposes }

class _StringListEditor extends StatefulWidget {
  final _ListKind kind;
  final String title;
  const _StringListEditor({required this.kind, required this.title});
  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  final _config = ConfigService();
  late List<String> _items;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(
        widget.kind == _ListKind.couriers ? _config.couriers : _config.purposes);
  }

  Future<void> _save() async {
    final cleaned = _items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (widget.kind == _ListKind.couriers) {
      await _config.setCouriers(cleaned);
    } else {
      await _config.setPurposes(cleaned);
    }
    if (!mounted) return;
    _toast(context, '${widget.title} saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text(widget.title,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ..._items.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value,
                      decoration: _fieldDeco('Item ${i + 1}'),
                      onChanged: (v) => _items[i] = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.danger),
                    onPressed: () => setState(() => _items.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _items.add('')),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ],
      ),
      bottomNavigationBar: _saveBar(context, _save),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Guards
// ─────────────────────────────────────────────────────────────────────────────

class _GuardsEditor extends StatefulWidget {
  const _GuardsEditor();
  @override
  State<_GuardsEditor> createState() => _GuardsEditorState();
}

class _GuardsEditorState extends State<_GuardsEditor> {
  final _config = ConfigService();
  late List<String> _guards;
  late final TextEditingController _weeks;

  @override
  void initState() {
    super.initState();
    _guards = List<String>.from(_config.guards);
    _weeks = TextEditingController(text: _config.rotationWeeks.toString());
  }

  @override
  void dispose() {
    _weeks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cleaned =
    _guards.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final weeks = int.tryParse(_weeks.text.trim()) ?? 1;
    await _config.setGuards(cleaned);
    await _config.setRotationWeeks(weeks);
    if (!mounted) return;
    _toast(context, 'Guards saved');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Guards',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'The first two guards alternate on the day/night rotation. Any '
                'additional entries appear as manual override options only.',
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ..._guards.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: e.value,
                      decoration: _fieldDeco(i == 0
                          ? 'Guard 1 (rotates)'
                          : i == 1
                          ? 'Guard 2 (rotates)'
                          : 'Guard ${i + 1} (override only)'),
                      onChanged: (v) => _guards[i] = v,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: AppColors.danger),
                    onPressed: () => setState(() => _guards.removeAt(i)),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: () => setState(() => _guards.add('')),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add guard'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _weeks,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _fieldDeco('Rotation period (weeks)'),
          ),
        ],
      ),
      bottomNavigationBar: _saveBar(context, _save),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Security
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityEditor extends StatefulWidget {
  const _SecurityEditor();
  @override
  State<_SecurityEditor> createState() => _SecurityEditorState();
}

class _SecurityEditorState extends State<_SecurityEditor> {
  final _config = ConfigService();
  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new1.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // If the password isn't the default, require the current one first.
    if (!_config.passwordIsDefault &&
        !_config.verifyPassword(_current.text)) {
      setState(() => _error = 'Current password is incorrect.');
      return;
    }
    if (_new1.text.length < 4) {
      setState(() => _error = 'New password must be at least 4 characters.');
      return;
    }
    if (_new1.text != _new2.text) {
      setState(() => _error = 'New passwords do not match.');
      return;
    }
    await _config.setPassword(_new1.text);
    if (!mounted) return;
    _toast(context, 'Password updated');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDefault = _config.passwordIsDefault;
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: Text('Security',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.psaBlue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isDefault)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Text(
                'This device is using the default password. Set a new one now.',
                style: GoogleFonts.outfit(
                    fontSize: 12.5, color: AppColors.warning),
              ),
            ),
          if (_error != null) ...[
            Text(_error!,
                style: GoogleFonts.outfit(
                    color: AppColors.danger, fontSize: 12.5)),
            const SizedBox(height: 10),
          ],
          if (!isDefault) ...[
            TextField(
              controller: _current,
              obscureText: _obscure,
              decoration: _fieldDeco('Current password'),
            ),
            const SizedBox(height: 14),
          ],
          TextField(
            controller: _new1,
            obscureText: _obscure,
            decoration: _fieldDeco('New password'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _new2,
            obscureText: _obscure,
            decoration: _fieldDeco('Confirm new password'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: !_obscure,
                onChanged: (v) => setState(() => _obscure = !(v ?? false)),
              ),
              Text('Show passwords', style: GoogleFonts.outfit(fontSize: 13)),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _saveBar(context, _save),
    );
  }
}