# PSA Visitor Logging System
### Philippine Statistics Authority — Marinduque Provincial Statistical Office

A tablet-based QR-powered visitor logging kiosk application built with Flutter.

---

## Features

| Feature | Details |
|---|---|
| **QR Scanner** | Scans PSA-MRNDQ-VISIT-001 to 010 codes |
| **Auto Check-In / Out** | Single scan determines entry or exit |
| **Guard Schedule** | Auto-detects guard per shift + 2-week rotation |
| **SQLite Storage** | Fully offline, on-device database |
| **Duplicate Blocking** | Only one active visit per visitor allowed |
| **Kiosk Mode** | Fullscreen immersive, no scrolling on home |
| **Camera Switch** | Front / rear camera toggle |
| **Visitor Logs** | Filterable history (All / Today / Active) |

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── utils/
│   └── constants.dart           # Colors, guard schedule, QR config
├── models/
│   └── visitor_model.dart       # VisitorRecord data model
├── services/
│   ├── database_service.dart    # SQLite operations
│   └── guard_service.dart       # Guard duty management
├── screens/
│   ├── home_screen.dart         # Kiosk home + QR scanner
│   ├── checkin_screen.dart      # Check-in form
│   ├── checkout_screen.dart     # Check-out screen
│   └── logs_screen.dart         # Visitor history
└── widgets/
    └── psa_dialogs.dart         # Reusable dialog components
```

---

## Guard Schedule Logic

- **Guard 1:** Michael Magcamit
- **Guard 2:** Christian Malapad
- **Day Shift:** 7:00 AM – 7:00 PM
- **Night Shift:** 7:00 PM – 7:00 AM
- **Rotation:** Every 2 weeks, swapping shifts
- **Anchor Date:** May 12, 2025 (Michael on Day, Christian on Night)
- **Override:** Admin can manually change guard if one is on leave

---

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / Xcode
- Physical tablet (recommended for camera)

### 1. Install Flutter
```bash
# Check installation
flutter doctor
```

### 2. Clone & Set Up
```bash
# Navigate to project
cd psa_visitor_app

# Install dependencies
flutter pub get
```

### 3. Add Logo Asset
Place your PSA logo at:
```
assets/images/psa_logo.png
```
(Already included in this build)

### 4. Run on Device
```bash
# List connected devices
flutter devices

# Run on specific device
flutter run -d <device_id>

# Build release APK
flutter build apk --release
```

### 5. Android Camera Permission
The app automatically requests camera permission on first launch.
Make sure the device grants it.

---

## Dependencies

```yaml
mobile_scanner: ^5.2.3     # QR/Barcode scanning
sqflite: ^2.3.3+1          # Local SQLite database
google_fonts: ^6.2.1       # Typography (Outfit font)
flutter_animate: ^4.5.0    # Animations
intl: ^0.19.0              # Date/time formatting
path: ^1.9.0               # File path utilities
```

---

## Configuration (white-label)

Everything below is editable at runtime in **Settings** (admin mode) and stored
under the SharedPreferences key `psa_app_config_v1`:

- Office identity (organization, office, app title, republic line, QR prefix)
- Units (name, short name, QR range, color)
- Special QR ranges (vendor / delivery)
- Delivery providers (couriers)
- Guards (names + rotation weeks)
- Visit purposes
- Admin password (salted SHA-256)

Defaults (first launch): units 001–040 across 4 units, vendor 041–043 & 046–048,
delivery 044–045 & 049–050, weekly guard rotation.

### Custom ID prefixes

The visitor QR/ID prefix is fully customizable — it is **not** limited to
`PSA-MRNDQ`. Edit it under **Settings → Office Info → QR code prefix** (default
`PSA-MRNDQ-VISIT-`). The prefix flows through both directions:

- **Card generation** — `ConfigService.codeFor(n)` builds each card as
  `<prefix><NNN>` (e.g. `NCR-QC-VISIT-001`).
- **Scan matching** — `unitForQR` / `specialTypeForQR` strip the configured
  prefix before resolving the number, so check-in and check-out follow whatever
  prefix is set.

> Changing the prefix invalidates any visitor cards already printed with the old
> prefix — only change it when you are reprinting all cards.

**Not yet prefix-aware (still hardcoded to `PSA_MRNDQ`):** the exported CSV
filename (`PSA_MRNDQ_<unit>_Visitors_<period>.csv`) and the export folder
(`PSA_Visitor_Logs`). The admin-QR token and password salt are intentionally
separate from the visitor prefix. For a fully white-label report filename,
update `consolidation_service.dart` to derive the prefix from `ConfigService`.
