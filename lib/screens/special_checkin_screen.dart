// lib/screens/special_checkin_screen.dart
//
// Streamlined check-in form for Vendor (QR 041-043) and Delivery (QR 044-045).
// Purpose is pre-set from the QR code — no purpose dropdown needed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';
import '../services/database_service.dart';
import '../services/config_service.dart';
import '../services/guard_service.dart';
import '../utils/constants.dart';
import '../widgets/psa_dialogs.dart';

// ── Neumorphic shadow (matches CheckInScreen) ─────────────────────────────────
const List<BoxShadow> _neu = [
  BoxShadow(color: Colors.white,      offset: Offset(-5, -5), blurRadius: 14),
  BoxShadow(color: Color(0xFFC8CDD9), offset: Offset( 5,  5), blurRadius: 14),
];

const double _kFieldH = 72.0;
const double _kGuardH = 110.0;

class SpecialCheckInScreen extends StatefulWidget {
  final String             visitorId;
  final SpecialVisitorType type;
  final VoidCallback       onComplete;

  const SpecialCheckInScreen({
    super.key,
    required this.visitorId,
    required this.type,
    required this.onComplete,
  });

  @override
  State<SpecialCheckInScreen> createState() => _SpecialCheckInScreenState();
}

class _SpecialCheckInScreenState extends State<SpecialCheckInScreen>
    with SingleTickerProviderStateMixin {
  // Courier/provider options are now admin-editable via ConfigService.couriers.
  List<String> get _couriers => ConfigService().couriers;

  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _field3Ctrl        = TextEditingController(); // Items / Description
  final _otherCourierCtrl  = TextEditingController(); // "Others" courier name
  final _deliveryBoysCtrl  = TextEditingController(text: '1'); // Water Delivery headcount

  String? _selectedCourier;
  bool _isLoading = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  final _guardService = GuardService();
  final _dbService    = DatabaseService();

  bool get _isVendor        => widget.type == SpecialVisitorType.vendor;
  bool get _isWaterDelivery => _selectedCourier == 'Water Delivery';

  String get _title       => _isVendor ? 'VENDOR CHECK-IN'   : 'DELIVERY CHECK-IN';
  String get _unitId      => _isVendor ? 'vendor'            : 'delivery';
  Color  get _accentColor => _isVendor ? AppColors.psaAccent : AppColors.psaBlue;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _field3Ctrl.dispose();
    _otherCourierCtrl.dispose();
    _deliveryBoysCtrl.dispose();
    super.dispose();
  }

  String get _purposeString {
    final desc = _field3Ctrl.text.trim();
    if (_isVendor) {
      return desc.isEmpty ? 'Vendor' : 'Vendor — $desc';
    }
    if (_isWaterDelivery) {
      final count = int.tryParse(_deliveryBoysCtrl.text) ?? 1;
      final boys  = count == 1 ? '1 delivery boy' : '$count delivery boys';
      return desc.isEmpty ? 'Water Delivery ($boys)' : 'Water Delivery ($boys) — $desc';
    }
    return desc.isEmpty ? 'Delivery' : 'Delivery — $desc';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final record = VisitorRecord(
        visitorId:   widget.visitorId,
        visitorName: _nameCtrl.text.trim(),
        purpose:     _purposeString,
        agency: _isVendor
            ? 'Private'
            : (_selectedCourier == 'Others, please specify'
            ? _otherCourierCtrl.text.trim()
            : (_selectedCourier ?? '')),
        visitorType: _isWaterDelivery ? 'group' : 'individual',
        groupCount:  _isWaterDelivery
            ? int.tryParse(_deliveryBoysCtrl.text)
            : null,
        guardOnDuty: _guardService.currentGuardName,
        unitId:      _unitId,
        checkInTime: now,
        isActive:    true,
      );
      await _dbService.checkIn(record);
      if (!mounted) return;
      await showSuccessDialog(
        context,
        title:        'Check-In Successful!',
        message:      '${record.visitorName} has been logged in.',
        confirmLabel: 'Done',
        onConfirm:    widget.onComplete,
        extraContent: _buildSummary(record, now),
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context,
          title: 'Check-In Failed',
          message: 'An error occurred: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSummary(VisitorRecord r, DateTime t) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.successLight,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
    ),
    child: Column(children: [
      _row(Icons.badge_outlined,     'ID',      r.visitorId),
      _row(Icons.assignment_outlined, 'Purpose', r.purpose),
      _row(Icons.access_time, 'Time',
          DateFormat('MMM dd, yyyy hh:mm a').format(t)),
      _row(Icons.security, 'Guard', r.guardOnDuty),
    ]),
  );

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14, color: AppColors.success),
      const SizedBox(width: 8),
      Text('$label: ',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.textSecondary)),
      Expanded(child: Text(value,
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textPrimary))),
    ]),
  );

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: AppColors.scaffoldBg,
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Form(
                key: _formKey,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildFields()),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _buildRightPanel()),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.psaDarkBlue,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: widget.onComplete,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(width: 14),
        Image.asset(
          'assets/images/psa_header_logo.png',
          height: 56, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox(width: 4),
        ),
        Expanded(
          child: Text(_title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 28, fontWeight: FontWeight.w800,
                  color: _accentColor, letterSpacing: 2.5)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.psaBlue.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(DateFormat('hh:mm a').format(now).toUpperCase(),
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Text(
                '${DateFormat('EEE').format(now).toUpperCase()}  |  '
                    '${DateFormat('dd MMM yy').format(now).toUpperCase()}',
                style: GoogleFonts.outfit(
                    fontSize: 11, color: Colors.white60, letterSpacing: 0.5)),
          ]),
        ),
      ]),
    );
  }

  // ── Left column ───────────────────────────────────────────────────────────
  //
  // Vendor  → Name + Items (agency auto-set to "Private")
  // Delivery → Name + Courier dropdown + Item Description
  //
  Widget _buildFields() {
    if (_isVendor) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(
            ctrl: _nameCtrl,
            hint: 'Vendor / Representative Name',
            icon: Icons.person_outline_rounded,
            height: _kFieldH,
            required: true,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          _field(
            ctrl: _field3Ctrl,
            hint: 'Items / Transaction (optional)',
            icon: Icons.inventory_2_outlined,
            height: _kFieldH,
            required: false,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      );
    }

    // Delivery
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field(
          ctrl: _nameCtrl,
          hint: 'Delivery Person Name',
          icon: Icons.person_outline_rounded,
          height: _kFieldH,
          required: true,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _courierDropdown(),
        if (_selectedCourier == 'Others, please specify') ...[
          const SizedBox(height: 12),
          _field(
            ctrl: _otherCourierCtrl,
            hint: 'Please specify courier / company',
            icon: Icons.edit_note_rounded,
            height: _kFieldH,
            required: true,
            textCapitalization: TextCapitalization.words,
          ),
        ],
        if (_isWaterDelivery) ...[
          const SizedBox(height: 12),
          _field(
            ctrl: _deliveryBoysCtrl,
            hint: 'Number of Delivery Boys',
            icon: Icons.group_outlined,
            height: _kFieldH,
            required: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 1) return 'Enter at least 1';
              return null;
            },
          ),
        ],
        const SizedBox(height: 12),
        _field(
          ctrl: _field3Ctrl,
          hint: 'Item Description',
          icon: Icons.local_shipping_outlined,
          height: _kFieldH,
          required: true,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  // ── Courier dropdown (delivery only) ──────────────────────────────────────
  Widget _courierDropdown() {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.all(Radius.circular(50)),
        boxShadow: _neu,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.local_shipping_outlined,
              color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCourier,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary, size: 22),
              style: GoogleFonts.outfit(
                  fontSize: 16, color: AppColors.textPrimary),
              dropdownColor: AppColors.scaffoldBg,
              decoration: InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                errorStyle: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.danger),
              ),
              hint: Text('Courier / Delivery Company',
                  style: GoogleFonts.outfit(
                      fontSize: 16, color: AppColors.textMuted)),
              validator: (v) =>
              v == null ? 'Please select a courier' : null,
              onChanged: (val) => setState(() => _selectedCourier = val),
              items: _couriers
                  .map((c) => DropdownMenuItem<String>(
                value: c,
                child: Text(c,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: AppColors.textPrimary)),
              ))
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required double height,
    required bool required,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return FormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) {
        if (validator != null) return validator(ctrl.text);
        return required && ctrl.text.trim().isEmpty ? 'Required' : null;
      },
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: AppColors.scaffoldBg,
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: _neu,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 16),
                Icon(icon, color: AppColors.textSecondary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    textCapitalization: textCapitalization,
                    textAlignVertical: TextAlignVertical.center,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    style: GoogleFonts.outfit(
                        fontSize: 16, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: GoogleFonts.outfit(
                          fontSize: 16, color: AppColors.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 18),
              child: Text(state.errorText!,
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: AppColors.danger)),
            ),
        ],
      ),
    );
  }

  // ── Right panel: guard card + confirm ─────────────────────────────────────
  Widget _buildRightPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Guard card
        Container(
          height: _kGuardH,
          decoration: BoxDecoration(
            color: AppColors.psaAccent,
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(children: [
            Positioned(
              left: 20, top: 0, bottom: 0, right: 90,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _guardService.currentGuardName.toUpperCase(),
                      style: GoogleFonts.outfit(
                          fontSize: 17, fontWeight: FontWeight.w800,
                          color: AppColors.psaDarkBlue, height: 1.2),
                      overflow: TextOverflow.ellipsis, maxLines: 2),
                  const SizedBox(height: 4),
                  Text('Guard on Duty',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.psaDarkBlue.withValues(alpha: 0.65))),
                ],
              ),
            ),
            Positioned(
              right: -4, top: 0, bottom: 0,
              child: Image.asset(
                'assets/images/guard_illustration.png',
                fit: BoxFit.contain, width: 90,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.local_police_rounded,
                      size: 60,
                      color: AppColors.psaDarkBlue.withValues(alpha: 0.3)),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 14),

        // Confirm button — same height as guard card
        SizedBox(
          height: _kGuardH,
          child: GestureDetector(
            onTap: _isLoading ? null : _submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: _isLoading
                    ? AppColors.success.withValues(alpha: 0.75)
                    : AppColors.success,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.login_rounded,
                        color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text('CONFIRM',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 1.5)),
                    Text('CHECK-IN',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}