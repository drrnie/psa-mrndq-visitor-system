// lib/utils/admin_auth.dart
//
// Generates and validates the admin QR code payload.
//
// SECURITY MODEL (changed in the white-label refactor):
// The QR payload no longer encodes the admin password. Instead it encodes a
// fixed, build-time token. This means the admin QR is decoupled from the
// password entirely — changing the password no longer invalidates the QR, and
// the password never appears (even obfuscated) inside a printed QR image.
//
// XOR-cipher + Base64URL still obscures the token so the raw QR content isn't
// human-readable. This is obfuscation, not cryptographic security — sufficient
// for a local office kiosk.
//
// ⚠️ DEPLOYMENT NOTE: Any admin QR codes printed BEFORE this change encoded the
// old password and will NO LONGER WORK. After updating the app, reprint the
// admin QR from the in-app "Admin QR" dialog (admin mode bar).

import 'dart:convert';

// ── Internal constants ────────────────────────────────────────────────────────

// Changing this key invalidates any previously generated admin QR codes.
const String _secretKey = 'PSA_MRNDQ_ADMIN_K3Y_2025_MRNDQ';

// Fixed token carried by every admin QR. Decoupled from the password.
// Changing this value invalidates all previously printed admin QR codes.
const String _adminToken = 'PSA-MRNDQ-ADMIN-TOKEN-v1';

/// Prefix that uniquely identifies an admin QR payload so the scanner can
/// quickly skip visitor-range validation.
const String adminQRPrefix = 'PSA-ADMIN-QR:';

// ── Public API ────────────────────────────────────────────────────────────────

/// Returns the full QR payload string for the admin token.
/// Render this string as a QR code (e.g. with qr_flutter).
///
/// No longer takes the password — the payload is password-independent.
String generateAdminQRPayload() {
  final keyBytes   = _secretKey.codeUnits;
  final tokenBytes = utf8.encode(_adminToken);
  final encrypted  = List<int>.generate(
    tokenBytes.length,
        (i) => tokenBytes[i] ^ keyBytes[i % keyBytes.length],
  );
  return '$adminQRPrefix${base64Url.encode(encrypted)}';
}

/// Returns `true` if [qrData] is a valid admin QR (decrypts to the fixed token).
bool isAdminQR(String qrData) =>
    _decryptAdminQR(qrData.trim()) == _adminToken;

// ── Internal helper ───────────────────────────────────────────────────────────

String? _decryptAdminQR(String qrData) {
  if (!qrData.startsWith(adminQRPrefix)) return null;
  try {
    final encoded   = qrData.substring(adminQRPrefix.length);
    final encrypted = base64Url.decode(encoded);
    final keyBytes  = _secretKey.codeUnits;
    final decrypted = List<int>.generate(
      encrypted.length,
          (i) => encrypted[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(decrypted);
  } catch (_) {
    return null;
  }
}