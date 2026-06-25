// lib/screens/checkout_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../widgets/psa_dialogs.dart';

class CheckOutScreen extends StatefulWidget {
  final VisitorRecord record;
  final VoidCallback onComplete;

  const CheckOutScreen({
    super.key,
    required this.record,
    required this.onComplete,
  });

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Duration get _visitDuration {
    return DateTime.now().difference(widget.record.checkInTime);
  }

  String get _durationString {
    final d = _visitDuration;
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  Future<void> _confirmCheckOut() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Confirm Check-Out',
      message:
      'Are you sure you want to check out ${widget.record.visitorName}?',
      confirmLabel: 'Check Out',
      cancelLabel: 'Cancel',
    );

    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      await _dbService.checkOut(widget.record.id!, now);

      if (!mounted) return;

      await showSuccessDialog(
        context,
        title: 'Check-Out Complete',
        message:
        '${widget.record.visitorName} has been checked out successfully.',
        confirmLabel: 'Done',
        onConfirm: widget.onComplete,
        extraContent: _buildSummary(now),
      );
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: 'Check-Out Failed',
        message: 'An error occurred: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSummary(DateTime checkoutTime) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _row(Icons.badge_outlined, 'Visitor ID', widget.record.visitorId),
          _row(Icons.login_rounded, 'Check-In',
              DateFormat('hh:mm a').format(widget.record.checkInTime)),
          _row(Icons.logout_rounded, 'Check-Out',
              DateFormat('hh:mm a').format(checkoutTime)),
          _row(Icons.timer_outlined, 'Duration', _durationString),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.success),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        color: AppColors.scaffoldBg,
        child: Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              decoration: BoxDecoration(
                color: AppColors.psaDarkBlue,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onComplete,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VISITOR CHECK-OUT',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.psaAccent,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          record.visitorId,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Active badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.greenAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ACTIVE',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.greenAccent,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        children: [
                          // Visitor Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Avatar
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.psaBlue.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.psaBlue
                                            .withValues(alpha: 0.3),
                                        width: 3),
                                  ),
                                  child: Center(
                                    child: Text(
                                      record.visitorName
                                          .split(' ')
                                          .map((e) => e.isNotEmpty
                                          ? e[0].toUpperCase()
                                          : '')
                                          .take(2)
                                          .join(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.psaBlue,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                Text(
                                  record.visitorName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  record.agency,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),

                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 20),

                                // Info grid
                                _infoGrid(record),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Duration indicator
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.psaBlue.withValues(alpha: 0.08),
                                  AppColors.psaLightBlue.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.psaBlue.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined,
                                    color: AppColors.psaBlue),
                                const SizedBox(width: 10),
                                Text(
                                  'Time inside: $_durationString',
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.psaBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Check Out Button
                          SizedBox(
                            width: double.infinity,
                            height: 64,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _confirmCheckOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                                shadowColor:
                                AppColors.danger.withValues(alpha: 0.4),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5),
                              )
                                  : Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.logout_rounded,
                                      size: 24),
                                  const SizedBox(width: 12),
                                  Text(
                                    'CHECK OUT ${record.visitorId}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: widget.onComplete,
                            child: Text(
                              'Cancel — Return to Scanner',
                              style: GoogleFonts.outfit(
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoGrid(VisitorRecord record) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _infoTile(Icons.assignment_outlined, 'Purpose',
                    record.purpose)),
            const SizedBox(width: 12),
            Expanded(
                child: _infoTile(
                    record.isGroup ? Icons.groups_rounded : Icons.person_rounded,
                    'Type',
                    record.isGroup
                        ? 'Group (${record.groupCount} pax)'
                        : 'Individual')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _infoTile(Icons.login_rounded, 'Check-In',
                    DateFormat('hh:mm a\nMMM dd, yyyy').format(record.checkInTime))),
            const SizedBox(width: 12),
            Expanded(
                child: _infoTile(
                    Icons.security_rounded, 'Guard on Duty', record.guardOnDuty)),
          ],
        ),
      ],
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.psaBlue),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}