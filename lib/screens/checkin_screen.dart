// lib/screens/checkin_screen.dart

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

// Purpose options are now admin-editable via ConfigService.purposes.

// ── Shared neumorphic shadows (const → allocated once) ───────────────────────
const List<BoxShadow> _neu = [
  BoxShadow(color: Colors.white,      offset: Offset(-5, -5), blurRadius: 14),
  BoxShadow(color: Color(0xFFC8CDD9), offset: Offset( 5,  5), blurRadius: 14),
];
const List<BoxShadow> _neuSm = [
  BoxShadow(color: Colors.white,      offset: Offset(-3, -3), blurRadius: 8),
  BoxShadow(color: Color(0xFFCDD1DC), offset: Offset( 3,  3), blurRadius: 8),
];

// ── Field height constants ────────────────────────────────────────────────────
const double _kFieldH  = 72.0;   // Name / Agency
const double _kShortH  = 64.0;   // Purpose / Others / Group Count

class CheckInScreen extends StatefulWidget {
  final String visitorId;
  final VoidCallback onComplete;
  final String unitId;

  const CheckInScreen({
    super.key,
    required this.visitorId,
    required this.onComplete,
    required this.unitId,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen>
    with SingleTickerProviderStateMixin {
  final _formKey              = GlobalKey<FormState>();
  final _nameCtrl             = TextEditingController();
  final _agencyCtrl           = TextEditingController();
  final _groupCountCtrl       = TextEditingController(text: '2');
  final _othersCtrl           = TextEditingController();

  String  _visitorType     = 'individual';
  String? _selectedPurpose;
  bool    _isLoading       = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  final _guardService = GuardService();
  final _dbService    = DatabaseService();

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
    _agencyCtrl.dispose();
    _groupCountCtrl.dispose();
    _othersCtrl.dispose();
    super.dispose();
  }

  bool   get _isOthers => _selectedPurpose == 'Others, please specify';
  String get _effectivePurpose {
    if (_isOthers && _othersCtrl.text.trim().isNotEmpty) {
      return 'Others: ${_othersCtrl.text.trim()}';
    }
    return _selectedPurpose ?? '';
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitCheckIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final record = VisitorRecord(
        visitorId:   widget.visitorId,
        visitorName: _nameCtrl.text.trim(),
        purpose:     _effectivePurpose,
        agency:      _agencyCtrl.text.trim(),
        visitorType: _visitorType,
        groupCount:  _visitorType == 'group'
            ? int.tryParse(_groupCountCtrl.text) : null,
        guardOnDuty: _guardService.currentGuardName,
        unitId:      widget.unitId,
        checkInTime: now,
        isActive:    true,
      );
      await _dbService.checkIn(record);
      if (!mounted) return;
      await showSuccessDialog(
        context,
        title:        'Check-In Successful!',
        message:      '${record.visitorName} has been logged in successfully.',
        confirmLabel: 'Done',
        onConfirm:    widget.onComplete,
        extraContent: _buildSuccessSummary(record, now),
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

  Widget _buildSuccessSummary(VisitorRecord record, DateTime time) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        _summaryRow(Icons.badge_outlined,      'ID',      record.visitorId),
        _summaryRow(Icons.assignment_outlined,  'Purpose', record.purpose),
        _summaryRow(Icons.access_time, 'Time',
            DateFormat('MMM dd, yyyy hh:mm a').format(time)),
        _summaryRow(Icons.security, 'Guard', record.guardOnDuty),
        if (record.isGroup)
          _summaryRow(Icons.group, 'Group Size', '${record.groupCount} persons'),
      ]),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
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
            style: GoogleFonts.outfit(
                fontSize: 12, color: AppColors.textPrimary))),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Build
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Vertical-centering pattern:
  //
  //   Expanded                       ← claim full remaining height
  //   └─ LayoutBuilder               ← know the available height
  //       └─ SingleChildScrollView   ← safety valve (kiosk: never actually scrolls)
  //           └─ ConstrainedBox(minHeight: available)
  //               └─ Center          ← center the content when it's shorter
  //                   └─ IntrinsicHeight
  //                       └─ Row(stretch)
  //                           ├─ left 60%  (fixed-height fields → Column)
  //                           └─ right 40% (guard fixed + Expanded confirm)
  //
  // IntrinsicHeight gives the Row a definite height = max(left, right).
  // The right Column's Expanded then fills guard-to-bottom of that height.
  // Center vertically positions the whole block when it's < available height.
  //
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
                    Expanded(flex: 6, child: _buildFormFields()),
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

  // ══════════════════════════════════════════════════════════════════════════
  // Header
  // ══════════════════════════════════════════════════════════════════════════
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
          child: Text('VISITOR CHECK-IN',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 30, fontWeight: FontWeight.w800,
                  color: AppColors.psaAccent, letterSpacing: 2.5)),
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

  // ══════════════════════════════════════════════════════════════════════════
  // Left column — form fields at natural fixed heights
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFormFields() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(
          ctrl: _nameCtrl,
          hint: 'Visitor Name',
          icon: Icons.person_outline_rounded,
          height: _kFieldH,
          validator: (v) =>
          v == null || v.trim().isEmpty ? 'Required' : null,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _textField(
          ctrl: _agencyCtrl,
          hint: 'Agency/Organization',
          icon: Icons.business_outlined,
          height: _kFieldH,
          validator: (v) =>
          v == null || v.trim().isEmpty ? 'Required' : null,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        _purposeField(),
        if (_isOthers) ...[
          const SizedBox(height: 12),
          _textField(
            ctrl: _othersCtrl,
            hint: 'Please specify purpose',
            icon: Icons.edit_note_rounded,
            height: _kShortH,
            validator: (v) =>
            (_isOthers && (v == null || v.trim().isEmpty))
                ? 'Please specify'
                : null,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
        const SizedBox(height: 12),
        _buildVisitorTypeCard(),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Field widgets — Row-based layout guarantees perfect vertical centering
  // ══════════════════════════════════════════════════════════════════════════
  //
  // Instead of relying on InputDecoration.prefixIcon (which uses Flutter's
  // internal InputDecorator layout and can misalign in tall containers),
  // we build each field as:
  //
  //   Container (neumorphic, fixed height)
  //   └─ Row (crossAxisAlignment: center)
  //       ├─ SizedBox(16)          ← left inset
  //       ├─ Icon                  ← vertically centered by Row
  //       ├─ SizedBox(10)
  //       ├─ Expanded              ← fills remaining width
  //       │   └─ TextField         ← text aligned center; no decoration chrome
  //       └─ SizedBox(16)          ← right inset
  //
  // Validation errors appear as a separate Text below the container,
  // rendered by a wrapping FormField<String>.
  //

  Widget _textField({
    required TextEditingController ctrl,
    required String hint,
    required IconData icon,
    required double height,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final radius = height / 2;
    return FormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) => validator?.call(ctrl.text),
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _neuContainer(
            height: height,
            radius: radius,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 16),
                Icon(icon, color: AppColors.textSecondary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    textCapitalization: textCapitalization,
                    textAlignVertical: TextAlignVertical.center,
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

  // ── Purpose dropdown ──────────────────────────────────────────────────────
  //
  // DropdownButtonFormField can't be placed raw inside a Row the same way,
  // so we keep it as-is but fix centering with isDense + zero vertical padding.
  //
  Widget _purposeField() {
    return _neuContainer(
      height: _kShortH,
      radius: _kShortH / 2,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          const Icon(Icons.assignment_outlined,
              color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedPurpose,
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
              hint: Text('Purpose of Visit',
                  style: GoogleFonts.outfit(
                      fontSize: 16, color: AppColors.textMuted)),
              validator: (v) =>
              v == null ? 'Please select a purpose' : null,
              onChanged: (val) => setState(() {
                _selectedPurpose = val;
                if (val != 'Others, please specify') _othersCtrl.clear();
              }),
              items: ConfigService().purposes.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Row(children: [
                    Icon(_purposeIcon(opt), size: 15, color: AppColors.psaBlue),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(opt,
                          style: GoogleFonts.outfit(
                              fontSize: 14, color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  IconData _purposeIcon(String p) {
    if (p.contains('Data'))        return Icons.storage_outlined;
    if (p.contains('Endorsement')) return Icons.school_outlined;
    if (p.contains('Receiving'))   return Icons.markunread_mailbox_outlined;
    if (p.contains('Vendor'))      return Icons.storefront_outlined;
    if (p.contains('Delivery'))    return Icons.local_shipping_outlined;
    return Icons.edit_outlined;
  }

  // ── Visitor Type card ─────────────────────────────────────────────────────
  Widget _buildVisitorTypeCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: _neu,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.group_outlined,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text('Visitor Type',
                style: GoogleFonts.outfit(
                    fontSize: 16, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _typeButton(
                'individual', Icons.person_rounded, 'Individual')),
            const SizedBox(width: 12),
            Expanded(child: _typeButton(
                'group', Icons.groups_rounded, 'Group')),
          ]),
          if (_visitorType == 'group') ...[
            const SizedBox(height: 12),
            _textField(
              ctrl: _groupCountCtrl,
              hint: 'Number of People',
              icon: Icons.tag_rounded,
              height: _kShortH,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (_visitorType != 'group') return null;
                final n = int.tryParse(v ?? '');
                if (n == null || n < 2) return 'Group must have at least 2 people';
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _typeButton(String type, IconData icon, String label) {
    final sel = _visitorType == type;
    return GestureDetector(
      onTap: () => setState(() => _visitorType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: sel ? AppColors.psaBlue : Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: sel ? null : _neuSm,
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: sel ? Colors.white : AppColors.textSecondary, size: 20),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Right panel
  // ══════════════════════════════════════════════════════════════════════════
  //
  // IntrinsicHeight (from parent Row) gives this Column a bounded height
  // equal to the left column's natural height. Expanded then fills the
  // remaining space below the guard card with the confirm button.
  //
  Widget _buildRightPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGuardCard(),                // 110 px
        const SizedBox(height: 14),
        SizedBox(
          height: 110,                    // same height as guard card
          child: _buildConfirmButton(),
        ),
      ],
    );
  }

  Widget _buildGuardCard() {
    return Container(
      height: 110,
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
    );
  }

  Widget _buildConfirmButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _submitCheckIn,
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
              width: 40, height: 40,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3))
              : LayoutBuilder(
            builder: (_, constraints) {
              final h    = constraints.maxHeight;
              final icon = (h * 0.18).clamp(32.0, 60.0);
              final font = (h * 0.12).clamp(18.0, 32.0);
              final gap  = (h * 0.05).clamp(8.0, 18.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login_rounded,
                      color: Colors.white, size: icon),
                  SizedBox(height: gap),
                  Text('CONFIRM',
                      style: GoogleFonts.outfit(
                          fontSize: font, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 2, height: 1.1)),
                  Text('CHECK-IN',
                      style: GoogleFonts.outfit(
                          fontSize: font, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 2, height: 1.1)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Shared neumorphic container ───────────────────────────────────────────
  Widget _neuContainer({
    required double height,
    required double radius,
    required Widget child,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _neu,
      ),
      child: child,
    );
  }
}