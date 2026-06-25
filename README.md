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

## QR Code Format

Valid QR payload format:
```
PSA-MRNDQ-VISIT-001
PSA-MRNDQ-VISIT-002
...
PSA-MRNDQ-VISIT-010
```

Any other QR code will be rejected with an error dialog.

---

## Kiosk Deployment Tips

1. **Enable kiosk/pinned app mode** on Android (Settings → Security → Screen Pinning)
2. **Disable sleep/auto-lock** (Settings → Display → Screen Timeout → Never)
3. **Enable auto-boot** if tablet restarts (device-specific setting)
4. **Mount tablet** at reception desk at ergonomic scan height

---

## Database Schema

```sql
CREATE TABLE visitor_logs (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  visitor_id     TEXT NOT NULL,
  visitor_name   TEXT NOT NULL,
  purpose        TEXT NOT NULL,
  agency         TEXT NOT NULL,
  visitor_type   TEXT NOT NULL DEFAULT 'individual',
  group_count    INTEGER,
  guard_on_duty  TEXT NOT NULL,
  check_in_time  TEXT NOT NULL,
  check_out_time TEXT,
  is_active      INTEGER NOT NULL DEFAULT 1
);
```

Database location: Android internal storage → `psa_visitors.db`

---

## Customization

### Change guard names / schedule
Edit `lib/utils/constants.dart`:
```dart
static const String guard1Name = 'Michael Magcamit';
static const String guard2Name = 'Christian Malapad';
static final DateTime rotationAnchor = DateTime(2025, 5, 12);
```

### Change shift hours
```dart
static const TimeOfDay dayStart = TimeOfDay(hour: 7, minute: 0);
static const TimeOfDay nightStart = TimeOfDay(hour: 19, minute: 0);
```

### Add more QR codes
```dart
static final RegExp validPattern =
    RegExp(r'^PSA-MRNDQ-VISIT-0(0[1-9]|10)$');
```
Modify the regex to allow a wider range.

---

## Version History

| Version | Date | Notes |
|---|---|---|
| 1.0.0 | May 2025 | Initial release |

---

*Developed for PSA Marinduque Provincial Statistical Office*
*Visitor Management Kiosk System*
