// lib/widgets/psa_dialogs.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/constants.dart';

enum DialogType { success, warning, error, info }

class PSADialog extends StatelessWidget {
  final DialogType type;
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final Widget? extraContent;

  const PSADialog({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.onConfirm,
    this.onCancel,
    this.extraContent,
  });

  Color get _accentColor => switch (type) {
    DialogType.success => AppColors.success,
    DialogType.warning => AppColors.warning,
    DialogType.error => AppColors.danger,
    DialogType.info => AppColors.psaBlue,
  };

  Color get _bgColor => switch (type) {
    DialogType.success => AppColors.successLight,
    DialogType.warning => AppColors.warningLight,
    DialogType.error => AppColors.dangerLight,
    DialogType.info => const Color(0xFFEBF2FF),
  };

  IconData get _icon => switch (type) {
    DialogType.success => Icons.check_circle_rounded,
    DialogType.warning => Icons.warning_amber_rounded,
    DialogType.error => Icons.cancel_rounded,
    DialogType.info => Icons.info_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.15),
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
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_icon, color: _accentColor, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _accentColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  if (extraContent != null) ...[
                    const SizedBox(height: 16),
                    extraContent!,
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (cancelLabel != null)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            onCancel?.call();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          child: Text(
                            cancelLabel!,
                            style: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (cancelLabel != null) const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onConfirm?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmLabel ?? 'OK',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
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
    );
  }
}

// Convenience functions
Future<void> showSuccessDialog(
    BuildContext context, {
      required String title,
      required String message,
      String? confirmLabel,
      VoidCallback? onConfirm,
      Widget? extraContent,
    }) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PSADialog(
      type: DialogType.success,
      title: title,
      message: message,
      confirmLabel: confirmLabel ?? 'Done',
      onConfirm: onConfirm,
      extraContent: extraContent,
    ),
  );
}

Future<void> showErrorDialog(
    BuildContext context, {
      required String title,
      required String message,
    }) async {
  return showDialog(
    context: context,
    builder: (_) => PSADialog(
      type: DialogType.error,
      title: title,
      message: message,
      confirmLabel: 'Close',
    ),
  );
}

Future<bool> showConfirmDialog(
    BuildContext context, {
      required String title,
      required String message,
      String? confirmLabel,
      String? cancelLabel,
      Widget? extraContent,
    }) async {
  bool confirmed = false;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PSADialog(
      type: DialogType.warning,
      title: title,
      message: message,
      confirmLabel: confirmLabel ?? 'Confirm',
      cancelLabel: cancelLabel ?? 'Cancel',
      onConfirm: () => confirmed = true,
      extraContent: extraContent,
    ),
  );
  return confirmed;
}