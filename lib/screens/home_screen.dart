// lib/screens/home_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:intl/intl.dart';
import '../models/visitor_model.dart';
import '../services/database_service.dart';
import '../services/config_service.dart';
import '../services/guard_service.dart';
import '../utils/constants.dart';
import '../services/audio_service.dart';
import '../utils/admin_auth.dart';
import '../widgets/psa_dialogs.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'checkin_screen.dart';
import 'checkout_screen.dart';
import 'logs_screen.dart';
import 'special_checkin_screen.dart';
import 'settings_screen.dart';

enum HomeView { scanner, checkIn, checkOut, logs, specialCheckIn }


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  HomeView _currentView = HomeView.scanner;
  String?  _scannedVisitorId;
  String?  _scannedUnitId;
  SpecialVisitorType? _scannedSpecialType;
  VisitorRecord? _activeRecord;
  bool _isAdminLoggedIn = false;
  int _consecutiveInvalidScans = 0; // easter egg: 5 in a row triggers the gag
  int  _versionTapCount = 0;

  // ── Easter eggs ───────────────────────────────────────────────────────────
  // Option 6: hold clock → show uptime
  late DateTime _appStartTime;

  // Option 5: tap PSA logo 3× → cycle scanner overlay color
  static const _overlayColors = [
    AppColors.psaBlue,   // default
    AppColors.psaAccent, // gold
    AppColors.danger,    // red
  ];
  int  _overlayColorIndex = 0;
  int  _logoTapCount      = 0;

  // Option 3: shake → dialog
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool _shakeDialogShowing = false;
  DateTime _lastShake = DateTime(2000);

  final _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  bool _isProcessing   = false;
  bool _useBackCamera  = true;

  final _dbService    = DatabaseService();
  final _guardService = GuardService();
  final _config       = ConfigService();

  late DateTime _now;
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  // Option: barrel roll — triple-tap the guard name
  late AnimationController _barrelRollController;
  late Animation<double>   _barrelRollAnim;
  int    _guardTapCount    = 0;
  Timer? _guardTapResetTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _appStartTime = DateTime.now(); // Option 6: uptime

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _barrelRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _barrelRollAnim = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _barrelRollController, curve: Curves.easeInOut),
    );
    _barrelRollController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _barrelRollController.reset();
      }
    });

    Stream.periodic(const Duration(seconds: 1))
        .listen((_) { if (mounted) setState(() => _now = DateTime.now()); });

    // Option 3: shake detector
    _accelSub = accelerometerEventStream().listen((AccelerometerEvent e) {
      final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      final now = DateTime.now();
      if (mag > 25 &&
          !_shakeDialogShowing &&
          now.difference(_lastShake).inSeconds > 3) {
        _lastShake = now;
        _showShakeDialog();
      }
    });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _pulseController.dispose();
    _barrelRollController.dispose();
    _guardTapResetTimer?.cancel();
    _accelSub?.cancel();
    super.dispose();
  }

  // ── Barrel roll — triple-tap guard name ──────────────────────────────────
  void _doBarrelRoll() {
    if (_barrelRollController.isAnimating) return;
    HapticFeedback.mediumImpact();
    _barrelRollController.forward();
  }

  void _onGuardNameTap() {
    _guardTapResetTimer?.cancel();
    _guardTapCount++;
    if (_guardTapCount >= 3) {
      _guardTapCount = 0;
      _doBarrelRoll();
      return;
    }
    // Reset counter if next tap doesn't come within 600 ms
    _guardTapResetTimer = Timer(
      const Duration(milliseconds: 600),
          () => _guardTapCount = 0,
    );
  }

  // ── Option 3: Shake dialog ────────────────────────────────────────────────
  void _showShakeDialog() {
    if (!mounted) return;
    setState(() => _shakeDialogShowing = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📳', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text('Did you just shake\na government kiosk?',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary, height: 1.3)),
                const SizedBox(height: 8),
                Text('Please handle with care.',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.psaBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('I will not do it again',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _shakeDialogShowing = false);
    });
  }

  // ── Option 6: Uptime snackbar ─────────────────────────────────────────────
  void _showUptimeSnackBar() {
    final d = DateTime.now().difference(_appStartTime);
    String uptime;
    if (d.inDays > 0) {
      uptime = '${d.inDays}d ${d.inHours % 24}h ${d.inMinutes % 60}m';
    } else if (d.inHours > 0) {
      uptime = '${d.inHours}h ${d.inMinutes % 60}m';
    } else {
      uptime = '${d.inMinutes}m ${d.inSeconds % 60}s';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('App running for $uptime',
            style: GoogleFonts.outfit(fontSize: 13)),
        backgroundColor: AppColors.psaDarkBlue,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  // ── About dialog (easter egg — tap version 5×) ────────────────────────────
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          decoration: BoxDecoration(
            color: AppColors.psaDarkBlue,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header band ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.psaBlue.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.badge_rounded,
                        color: AppColors.psaAccent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PSA Visitor Management System',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          )),
                      Text('Version 1.1.0',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: AppColors.psaAccent,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ]),
              ),

              // ── Two-column body ───────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left — system info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _aboutRow(Icons.location_on_outlined,
                                'Agency',
                                'Philippine Statistics Authority'),
                            const SizedBox(height: 6),
                            _aboutRow(Icons.apartment_outlined,
                                'Office',
                                'Marinduque Provincial Statistical Office'),
                            const SizedBox(height: 14),
                            _aboutRow(Icons.calendar_today_outlined,
                                'Deployed', '2025'),
                            const SizedBox(height: 14),
                            _aboutRow(Icons.qr_code_scanner_rounded,
                                'QR Codes', '50 active (001 – 050)'),
                            const SizedBox(height: 14),
                            _aboutRow(Icons.devices_rounded,
                                'Deployment', '2 tablet kiosks'),
                            const SizedBox(height: 20),
                            Text('Built with Flutter  ·  Powered by SQLite',
                                style: GoogleFonts.outfit(
                                    fontSize: 10, color: Colors.white24)),
                          ],
                        ),
                      ),
                    ),

                    // Divider
                    VerticalDivider(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                        thickness: 1),

                    // Right — message from developer
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Message from the Developer',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.psaAccent,
                                  letterSpacing: 0.5,
                                )),
                            const SizedBox(height: 10),
                            Text(
                              'Developed by fx_trt, ISA I of PSO Marinduque.  03 Jun 26',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Originally conceptualized in the 4th quarter of 2025, what started as a simple web interface powered by Google Apps Script has now turned into a full blown mobile application for Android.',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.white54,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text('Special thanks to:',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                )),
                            const SizedBox(height: 6),
                            ...[
                              '_axellexious_',
                              'Sonya Blade',
                              'PSO MRNDQ ICT Team',
                              'Claude.ai',
                            ].map((name) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: 4, left: 4),
                              child: Row(children: [
                                const Icon(Icons.favorite_rounded,
                                    size: 9,
                                    color: AppColors.psaAccent),
                                const SizedBox(width: 8),
                                Text(name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    )),
                              ]),
                            )),
                            const SizedBox(height: 10),
                            Text('For making this project come to life.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white38,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Close button ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.psaAccent,
                      foregroundColor: AppColors.psaDarkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Close',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 15, color: AppColors.psaAccent),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 10, color: Colors.white38, letterSpacing: 0.5)),
          Text(value,
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ]),
      ),
    ]);
  }

  // ── Admin login ────────────────────────────────────────────────────────────
  Future<bool> _showAdminLogin(String actionLabel) async {
    // If already in admin mode, grant immediately without a prompt.
    if (_isAdminLoggedIn) return true;

    final passCtrl = TextEditingController();
    bool obscure = true;
    bool failed  = false;
    bool granted = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.psaBlue.withValues(alpha: 0.15),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: AppColors.psaBlue,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin Access Required',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                )),
                            Text(actionLabel,
                                style: GoogleFonts.outfit(
                                    fontSize: 12, color: Colors.white60)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      if (failed)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.danger, size: 15),
                              const SizedBox(width: 8),
                              Text('Incorrect password.',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12, color: AppColors.danger)),
                            ],
                          ),
                        ),
                      StatefulBuilder(
                        builder: (_, setSO) => _loginField(
                          passCtrl,
                          'Password',
                          Icons.lock_outline_rounded,
                          obscure,
                              () => setSO(() => obscure = !obscure),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tip: you can also scan the admin QR code instead.',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('Cancel',
                                  style: GoogleFonts.outfit(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (_config.verifyPassword(passCtrl.text)) {
                                  granted = true;
                                  Navigator.of(ctx).pop();
                                } else {
                                  setS(() => failed = true);
                                  passCtrl.clear();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.psaBlue,
                                foregroundColor: Colors.white,
                                padding:
                                const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: Text('Login',
                                  style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (granted) {
      setState(() => _isAdminLoggedIn = true);
      await _enforcePasswordChangeIfDefault();
    }
    return granted;
  }

  // ── Admin QR dialog ────────────────────────────────────────────────────────
  void _showAdminQRDialog() {
    final payload = generateAdminQRPayload();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.psaBlue.withValues(alpha: 0.15),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.psaDarkBlue,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Admin QR Code',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              )),
                          Text('Scan to log in as administrator',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: Colors.white60)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Print or save this QR code as a backup login method. Scanning it with the app grants admin access without typing the password.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.divider, width: 1.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: QrImageView(
                        data: payload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppColors.psaDarkBlue,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.psaBlue,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.warningLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.warning, size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Keep this QR code confidential — it grants full admin access.',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: AppColors.warning),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.psaBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Done',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Admin logout ───────────────────────────────────────────────────────────
  Future<void> _adminLogout() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log Out Admin',
      message:
      'This ends admin mode. Future admin actions will require the password or admin QR code again.',
      confirmLabel: 'Log Out',
      cancelLabel: 'Cancel',
    );
    if (confirmed && mounted) {
      setState(() => _isAdminLoggedIn = false);
    }
  }

  Widget _loginField(
      TextEditingController ctrl,
      String label,
      IconData icon,
      bool obscure,
      VoidCallback? onToggle,
      ) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: GoogleFonts.outfit(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.psaBlue, size: 20),
        suffixIcon: onToggle != null
            ? IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textMuted, size: 20,
          ),
          onPressed: onToggle,
        )
            : null,
        labelStyle:
        GoogleFonts.outfit(fontSize: 13, color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.psaBlue, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  // ── Unit selector (admin gated) ────────────────────────────────────────────
  // ── Config bridges / admin helpers ─────────────────────────────────────────

  /// Bridges ConfigService's string special-type ('vendor'/'delivery') to the
  /// SpecialVisitorType enum the special check-in flow expects.
  SpecialVisitorType? _specialTypeEnum(String? t) {
    switch (t) {
      case 'vendor':   return SpecialVisitorType.vendor;
      case 'delivery': return SpecialVisitorType.delivery;
      default:         return null;
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() {}); // reflect any config changes immediately
  }

  /// On first admin entry while the password is still the shipped default,
  /// force the admin to set a new one before continuing.
  Future<void> _enforcePasswordChangeIfDefault() async {
    if (!_config.passwordIsDefault) return;
    final p1 = TextEditingController();
    final p2 = TextEditingController();
    bool obscure = true;
    String? error;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: AppColors.warning,
                    borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Text('Set a New Admin Password',
                      style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Text(
                        'This device is still using the default password. '
                            'For security, please set a new one to continue.',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      if (error != null) ...[
                        Text(error!,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.danger)),
                        const SizedBox(height: 10),
                      ],
                      _loginField(p1, 'New password',
                          Icons.lock_outline_rounded, obscure,
                              () => setS(() => obscure = !obscure)),
                      const SizedBox(height: 10),
                      _loginField(p2, 'Confirm password',
                          Icons.lock_outline_rounded, obscure,
                              () => setS(() => obscure = !obscure)),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final a = p1.text, b = p2.text;
                            if (a.length < 4) {
                              setS(() => error = 'Use at least 4 characters.');
                              return;
                            }
                            if (a != b) {
                              setS(() => error = 'Passwords do not match.');
                              return;
                            }
                            await _config.setPassword(a);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.psaBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Save Password',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ),
                      ),
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

  // ── QR Detection ───────────────────────────────────────────────────────────
  /// Easter egg dialog shown after 5 consecutive invalid QR scans.
  Future<void> _showFakeQrGtfoDialog() async {
    HapticFeedback.heavyImpact();
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 26),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: const Center(
                  child: Text('\u{1F940}\u{1F62D}',
                      style: TextStyle(fontSize: 56)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text(
                      'gtfo hiyeah wit yo fake QR code gng \u{1F940}\u{1F62D}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '(5 invalid scans in a row, fr?)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('my bad \u{1F64F}',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onQRDetected(BarcodeCapture capture) async {
    if (_isProcessing || _currentView != HomeView.scanner) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final qrData = barcode!.rawValue!.trim();

    // ── Admin QR: highest priority, no unit required ─────────────────────────
    if (isAdminQR(qrData)) {
      _consecutiveInvalidScans = 0;
      if (_isAdminLoggedIn) return; // already in admin mode, ignore silently
      HapticFeedback.mediumImpact();
      setState(() => _isAdminLoggedIn = true);
      await showSuccessDialog(
        context,
        title: 'Admin Access Granted',
        message:
        'You are now in admin mode. You can switch units, view logs, and manage guards without re-entering the password.',
        confirmLabel: 'Continue',
      );
      await _enforcePasswordChangeIfDefault();
      return;
    }

    // ── Special-purpose QRs (Vendor 041-043 · Delivery 044-045) ──────────────
    final specialType = _specialTypeEnum(_config.specialTypeForQR(qrData));
    if (specialType != null) {
      _consecutiveInvalidScans = 0;
      setState(() => _isProcessing = true);
      HapticFeedback.mediumImpact();
      try {
        final activeVisit = await _dbService.getActiveVisit(qrData);
        if (!mounted) return;
        if (activeVisit != null) {
          setState(() {
            _scannedVisitorId   = qrData;
            _activeRecord       = activeVisit;
            _currentView        = HomeView.checkOut;
          });
          AudioService().playDong();
        } else {
          setState(() {
            _scannedVisitorId   = qrData;
            _scannedSpecialType = specialType;
            _currentView        = HomeView.specialCheckIn;
          });
          AudioService().playDing();
        }
      } catch (e) {
        if (!mounted) return;
        await showErrorDialog(context,
            title: 'System Error',
            message: 'Failed to check visitor status: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
      return;
    }

    // ── Auto-detect unit from QR code ─────────────────────────────────────────
    // Each QR code encodes which unit the visitor belongs to. No need to
    // pre-configure the tablet to a specific unit — the scanner reads it.
    final detectedUnit = _config.unitForQR(qrData);
    if (detectedUnit == null) {
      if (_isProcessing) return;
      setState(() => _isProcessing = true);
      HapticFeedback.heavyImpact();
      _consecutiveInvalidScans++;
      if (_consecutiveInvalidScans >= 5) {
        _consecutiveInvalidScans = 0;
        AudioService().playFahhh();
        await _showFakeQrGtfoDialog();
      } else {
        await showErrorDialog(
          context,
          title: 'Invalid QR Code',
          message: 'This QR code is not recognized by the PSA Visitor System.',
        );
      }
      if (mounted) setState(() => _isProcessing = false);
      return;
    }

    // Valid, recognized unit code — reset the invalid-scan streak.
    _consecutiveInvalidScans = 0;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final activeVisit = await _dbService.getActiveVisit(qrData);
      if (!mounted) return;

      if (activeVisit != null) {
        setState(() {
          _scannedVisitorId = qrData;
          _activeRecord     = activeVisit;
          _currentView      = HomeView.checkOut;
        });
        AudioService().playDong();
      } else {
        setState(() {
          _scannedVisitorId = qrData;
          _scannedUnitId    = detectedUnit.id;
          _currentView      = HomeView.checkIn;
        });
        AudioService().playDing();
      }
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(
        context,
        title: 'System Error',
        message: 'Failed to check visitor status: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _switchCamera() {
    setState(() => _useBackCamera = !_useBackCamera);
    _scannerController.switchCamera();
  }

  void _returnToScanner() {
    setState(() {
      _currentView        = HomeView.scanner;
      _scannedVisitorId   = null;
      _scannedUnitId      = null;
      _scannedSpecialType = null;
      _activeRecord       = null;
    });
  }

  Future<void> _onViewLogsPressed() async {
    final granted = await _showAdminLogin('View Visitor Logs');
    if (granted && mounted) setState(() => _currentView = HomeView.logs);
  }

  Future<void> _onChangeGuardPressed() async {
    final granted = await _showAdminLogin('Change Guard on Duty');
    if (!granted || !mounted) return;
    _showGuardOverrideDialog();
  }

  void _showGuardOverrideDialog() {
    String? tempGuard = _guardService.hasOverride
        ? _guardService.overrideName
        : _guardService.getScheduledGuard().name;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => PSADialog(
          type: DialogType.info,
          title: 'Change Guard on Duty',
          message:
          'Only change this if a guard is on leave. The system auto-detects based on the shift schedule.',
          confirmLabel: 'Apply',
          cancelLabel: 'Use Auto-Detect',
          onConfirm: () {
            if (tempGuard != null) _guardService.setOverrideGuard(tempGuard!);
            setState(() {});
          },
          onCancel: () {
            _guardService.clearOverride();
            setState(() {});
          },
          extraContent: RadioGroup<String>(
            groupValue: tempGuard,
            onChanged: (v) => setS(() => tempGuard = v),
            child: Column(
              children: GuardSchedule.getAllGuardNames().map((name) {
                return RadioListTile<String>(
                  value: name,
                  title: Text(name,
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  activeColor: AppColors.psaBlue,
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    return AnimatedBuilder(
      animation: _barrelRollAnim,
      builder: (context, child) => Transform.rotate(
        angle: _barrelRollAnim.value,
        child: child,
      ),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        body: SafeArea(child: _buildView()),
      ),
    );
  }

  Widget _buildView() {
    switch (_currentView) {
      case HomeView.specialCheckIn:
        return SpecialCheckInScreen(
          visitorId:  _scannedVisitorId!,
          type:       _scannedSpecialType!,
          onComplete: _returnToScanner,
        );
      case HomeView.checkIn:
        return CheckInScreen(
          visitorId: _scannedVisitorId!,
          unitId: _scannedUnitId ?? 'unknown',
          onComplete: _returnToScanner,
        );
      case HomeView.checkOut:
        return CheckOutScreen(
          record: _activeRecord!,
          onComplete: _returnToScanner,
        );
      case HomeView.logs:
        return LogsScreen(onBack: _returnToScanner);
      case HomeView.scanner:
        return _buildScannerHome();
    }
  }

  Widget _buildScannerHome() {
    final size   = MediaQuery.of(context).size;
    final isWide = size.width > 700;

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.psaDarkBlue,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  _logoTapCount++;
                  if (_logoTapCount >= 3) {
                    _logoTapCount = 0;
                    setState(() =>
                    _overlayColorIndex =
                        (_overlayColorIndex + 1) % _overlayColors.length);
                  }
                },
                child: Image.asset(
                  'assets/images/psa_logo.png',
                  height: 48,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 48, width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance,
                        color: Colors.white, size: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.republic,
                        style: GoogleFonts.outfit(
                            fontSize: 9, color: Colors.white60)),
                    Text(AppStrings.organization,
                        style: GoogleFonts.outfit(
                          fontSize: isWide ? 14 : 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    Text(AppStrings.office,
                        style: GoogleFonts.outfit(
                          fontSize: isWide ? 11 : 9,
                          color: AppColors.psaAccent,
                        )),
                  ],
                ),
              ),
              GestureDetector(
                onLongPress: _showUptimeSnackBar,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(DateFormat('hh:mm').format(_now),
                        style: GoogleFonts.outfit(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        )),
                    Text(DateFormat('a • EEE, MMM d').format(_now),
                        style: GoogleFonts.outfit(
                            fontSize: 10, color: Colors.white60)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Guard Bar ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.psaBlue,
          child: Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: Colors.white70, size: 13),
              const SizedBox(width: 5),
              GestureDetector(
                onTap: _onGuardNameTap,
                child: Text(_guardService.currentGuardName,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    )),
              ),
              const SizedBox(width: 5),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_guardService.currentShift,
                    style: GoogleFonts.outfit(
                        fontSize: 9, color: Colors.white70)),
              ),
              if (_guardService.hasOverride) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.psaAccent.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('MANUAL',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.psaAccent,
                      )),
                ),
              ],
              const Spacer(),
              GestureDetector(
                onTap: _onChangeGuardPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isAdminLoggedIn
                            ? Icons.shield_rounded
                            : Icons.lock_outline_rounded,
                        color: Colors.white60,
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text('Guard',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Admin Mode Bar (visible only when logged in as admin) ────────────
        if (_isAdminLoggedIn)
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            color: AppColors.psaAccent.withValues(alpha: 0.18),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Admin Mode Active',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const Spacer(),
                // Show Admin QR
                GestureDetector(
                  onTap: _showAdminQRDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_rounded,
                            color: AppColors.warning, size: 12),
                        const SizedBox(width: 5),
                        Text('Admin QR',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Settings
                GestureDetector(
                  onTap: _openSettings,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.settings_rounded,
                            color: AppColors.warning, size: 12),
                        const SizedBox(width: 5),
                        Text('Settings',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.warning,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Log Out
                GestureDetector(
                  onTap: _adminLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded,
                            color: AppColors.danger, size: 12),
                        const SizedBox(width: 5),
                        Text('Log Out',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Main Content ─────────────────────────────────────────────────
        Expanded(
          child: isWide
              ? _buildWideLayout(size)
              : _buildNarrowLayout(size),
        ),

        // ── Bottom Bar ───────────────────────────────────────────────────
        _buildBottomBar(),
      ],
    );
  }

  Widget _buildWideLayout(Size size) {
    return Row(
      children: [
        // ── Balance spacer ────────────────────────────────────────────
        // Mirrors the side panel width so the scanner box sits exactly
        // in the horizontal centre of the full tablet screen — important
        // for a kiosk where visitors point their QR code at the screen.
        const SizedBox(width: 260),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildScannerBox(size),
          ),
        ),
        SizedBox(width: 260, child: _buildSidePanel()),
      ],
    );
  }

  Widget _buildNarrowLayout(Size size) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _buildScannerBox(size),
          ),
        ),
        _buildStatsRow(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildScannerBox(Size size) {
    final isWide = size.width > 700;

    return LayoutBuilder(
      builder: (context, constraints) {
        const reservedHeight = 30.0 + 12.0 + 44.0 + 10.0 + 20.0 + 10.0;
        final availableForBox = constraints.maxHeight - reservedHeight;
        final maxBoxFromWidth = isWide
            ? constraints.maxWidth * 0.85
            : constraints.maxWidth * 0.9;
        final boxSize = availableForBox.clamp(
            180.0, maxBoxFromWidth.clamp(180.0, 480.0));

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    color: AppColors.psaBlue, size: 16),
                const SizedBox(width: 8),
                Text(
                  'SCAN VISITOR QR CODE',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.psaBlue,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: boxSize,
                height: boxSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _overlayColors[_overlayColorIndex]
                          .withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Transform.rotate(
                        angle: _isLandscape(size) ? -1.5708 : 0,
                        child: MobileScanner(
                          controller: _scannerController,
                          onDetect: _onQRDetected,
                          fit: BoxFit.cover,
                        ),
                      ),
                      _buildScannerOverlay(boxSize, _overlayColors[_overlayColorIndex]),
                      if (_isProcessing)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: boxSize,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _switchCamera,
                icon: Icon(
                  _useBackCamera
                      ? Icons.camera_front_rounded
                      : Icons.camera_rear_rounded,
                  size: 18,
                ),
                label: Text(
                  _useBackCamera
                      ? 'Switch to Front Camera'
                      : 'Switch to Rear Camera',
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.psaBlue,
                  elevation: 2,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: AppColors.psaBlue.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: boxSize,
              child: Text(
                'Point the camera at a visitor\'s QR code',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _isLandscape(Size size) => size.width > size.height;

  Widget _buildScannerOverlay(double size, Color? unitColor) {
    const cornerSize  = 28.0;
    const cornerWidth = 3.5;
    final color       = unitColor ?? Colors.white;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
        ),
        Positioned(top: 10, left: 10,
            child: _corner(top: true,  left: true,  size: cornerSize, width: cornerWidth, color: color)),
        Positioned(top: 10, right: 10,
            child: _corner(top: true,  left: false, size: cornerSize, width: cornerWidth, color: color)),
        Positioned(bottom: 10, left: 10,
            child: _corner(top: false, left: true,  size: cornerSize, width: cornerWidth, color: color)),
        Positioned(bottom: 10, right: 10,
            child: _corner(top: false, left: false, size: cornerSize, width: cornerWidth, color: color)),
      ],
    );
  }

  Widget _corner({
    required bool top,
    required bool left,
    required double size,
    required double width,
    required Color color,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
          painter: _CornerPainter(
              top: top, left: left, width: width, color: color)),
    );
  }

  Widget _buildSidePanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("TODAY'S SUMMARY",
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                )),
            const SizedBox(height: 12),
            _statCard(Icons.people_rounded, 'Total Visitors',
                AppColors.psaBlue, _dbService.getTodayCount()),
            const SizedBox(height: 10),
            _statCard(Icons.login_rounded, 'Active Inside',
                AppColors.success, _dbService.getActiveCount()),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, Color color,
      Future<int> futureCount) {
    return FutureBuilder<int>(
      future: futureCount,
      builder: (_, snap) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary))),
            Text('${snap.data ?? 0}',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: color,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: _miniStat(Icons.people_rounded, 'Today',
                AppColors.psaBlue, _dbService.getTodayCount()),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _miniStat(Icons.person_rounded, 'Active',
                AppColors.success, _dbService.getActiveCount()),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color,
      Future<int> futureCount) {
    return FutureBuilder<int>(
      future: futureCount,
      builder: (_, snap) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${snap.data ?? 0}',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color,
                    )),
                Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _versionTapCount++);
              if (_versionTapCount >= 5) {
                setState(() => _versionTapCount = 0);
                _showAboutDialog();
              }
            },
            child: Text('PSA Visitor Management System v1.1',
                style: GoogleFonts.outfit(
                    fontSize: 10, color: AppColors.textMuted)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _onViewLogsPressed,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.psaBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: AppColors.psaBlue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  if (!_isAdminLoggedIn) ...[
                    const Icon(Icons.lock_outline_rounded,
                        color: AppColors.psaBlue, size: 12),
                    const SizedBox(width: 5),
                  ],
                  const Icon(Icons.list_alt_rounded,
                      color: AppColors.psaBlue, size: 14),
                  const SizedBox(width: 5),
                  Text('View Logs',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.psaBlue,
                      )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Corner painter ────────────────────────────────────────────────────────────
class _CornerPainter extends CustomPainter {
  final bool top, left;
  final double width;
  final Color color;

  _CornerPainter(
      {required this.top,
        required this.left,
        required this.width,
        required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height); path.lineTo(0, 0); path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}