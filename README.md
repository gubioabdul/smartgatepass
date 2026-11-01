# SmartGatePass

**SmartGatePass** is an offline-first Android application developed as a final-year Software Engineering project at **Al-Ansar University, Maiduguri**. It assists security personnel with recording vehicle entry and exit at institutional gates.

The application combines on-device Optical Character Recognition (OCR), QR-code gate passes, a local SQLite database, and Bluetooth thermal printing. Its purpose is to make vehicle movement records easier to create, retrieve, verify, and maintain without depending on a continuous internet connection.

> **Project status:** Academic project / development prototype. Features should be tested on the target Android device and compatible printer before being used in a live gate environment.

## Features

- **Offline-first operation:** Core vehicle-record workflows use on-device processing and local storage, so normal entry and exit tasks do not require continuous internet access.
- **Vehicle plate capture and OCR:** Captures a vehicle registration plate using the phone camera and extracts text with Google ML Kit Text Recognition.
- **Officer verification:** Displays the recognised plate for review and correction. The officer must verify the plate before an entry record can be saved.
- **QR-coded gate pass:** Creates a unique ticket ID and generates a QR code containing that ID. The ID is used to locate the associated local vehicle record.
- **Bluetooth thermal printing:** Sends a gate-pass ticket to a paired, compatible Bluetooth ESC/POS thermal printer. The implementation provides 58 mm and 80 mm paper-width options.
- **Vehicle exit processing:** Scans the ticket QR code, retrieves the corresponding record, checks the vehicle registration, and records the exit.
- **Digital audit trail:** Stores entry and exit timestamps, tracks active and closed passes, and calculates the duration of a completed visit.
- **Record search:** Supports searching vehicle records using a registration number or ticket ID.
- **Duplicate-active-entry protection:** Prevents a vehicle from having more than one active entry record in the local database.
- **Officer login screen:** Provides a basic login screen for the current prototype.

## Technology stack

| Area | Technology |
|---|---|
| Mobile framework | Flutter |
| Programming language | Dart |
| Platform | Android |
| OCR | Google ML Kit Text Recognition |
| Local database | SQLite with `sqflite` |
| QR generation | `qr_flutter` |
| QR scanning | `mobile_scanner` |
| Bluetooth printing | `print_bluetooth_thermal` |
| ESC/POS ticket formatting | `esc_pos_utils_plus` |
| Permissions | `permission_handler` |
| Date formatting | `intl` |
| Identifiers | `uuid` (dependency available in the project) |
| State management | Flutter `StatefulWidget` / `setState` |

## How it works

### Vehicle entry

1. The security officer opens **Vehicle Entry**.
2. The officer captures the vehicle's registration plate with the Android camera.
3. Google ML Kit extracts text from the captured image on the device.
4. The officer checks the recognised registration number and corrects it when necessary.
5. After verification, SmartGatePass creates a unique ticket ID and saves an active vehicle record in SQLite.
6. The application generates a QR code containing the ticket ID.
7. The officer can print the gate pass using a paired Bluetooth thermal printer. A printer failure does not remove the saved entry record; the same active pass can be retrieved and printed again.

### Vehicle exit

1. The officer opens **Vehicle Exit** and scans the QR code on the gate pass.
2. SmartGatePass reads the ticket ID and retrieves the matching record from the local database.
3. The officer checks the displayed vehicle details against the vehicle at the gate.
4. After confirmation, the application records the exit timestamp and closes the active pass.
5. The application calculates the duration between the entry and exit timestamps.

If a ticket cannot be scanned, the officer can search for an active record by vehicle registration number.

## Database record

The current SQLite implementation uses a `Vehicle_Log` table with these fields:

| Field | Description |
|---|---|
| `Ticket_ID` | Unique identifier for the gate pass; primary key |
| `Plate_Number` | Normalised vehicle registration number |
| `Entry_Timestamp` | Date and time the entry was recorded |
| `Exit_Timestamp` | Date and time the exit was recorded; empty while active |
| `Status` | `ACTIVE` or `CLOSED` |

The QR code stores the ticket ID rather than the complete vehicle record. The application uses that ID to retrieve the record from the device's SQLite database.

## Project structure

The Flutter source is organised into the following main areas:

```text
lib/
├── main.dart                 # App startup, repository setup and login flow
├── data/
│   └── vehicle_repository.dart  # SQLite access and vehicle record operations
├── domain/
│   └── vehicle_log.dart      # Vehicle record model and validation helpers
├── services/
│   └── gate_hardware.dart    # Camera/OCR and Bluetooth printer services
└── ui/
    ├── gate_app.dart         # Gate workflows and application screens
    └── login_screen.dart     # Officer login screen
```

## Requirements

- Flutter SDK with a bundled Dart SDK that satisfies the project's `pubspec.yaml` constraint (`^3.13.0`).
- Android development tools (Android Studio or Visual Studio Code with the Flutter and Dart extensions).
- Android SDK and a configured Android emulator or physical Android device.
- A physical Android phone is recommended for testing camera capture, QR scanning, Bluetooth permissions, and thermal printing.
- A Bluetooth thermal receipt printer that is compatible with the app's Bluetooth ESC/POS printing implementation. The current UI supports 58 mm and 80 mm paper-width settings.

Check your installed tools before building:

```bash
flutter --version
flutter doctor
```

## Getting started

### 1. Clone the repository

```bash
git clone https://github.com/gubioabdul/smartgatepass.git
cd smartgatepass
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Connect an Android device

Enable Developer options and USB debugging on a physical Android device, or start an Android emulator. Confirm that Flutter can see the device:

```bash
flutter devices
```

### 4. Run the application

```bash
flutter run
```

## Demo login

The current prototype login screen uses the following hard-coded demonstration credentials:

| Field | Demo value |
|---|---|
| Username | `admin` |
| Password | `1234` |

**Security note:** These are prototype credentials, not production authentication. The current login check is implemented in the client application and should not be treated as secure protection for real institutional records. Replace the hard-coded check with an appropriate authentication and credential-management design before any operational deployment. Do not reuse this password for other accounts or systems.

## Printer setup

1. Turn on the Bluetooth thermal printer and load the correct thermal paper.
2. Pair the printer with the Android phone through the phone's Bluetooth settings.
3. Open SmartGatePass and choose the print action for a saved active pass.
4. Select the paired printer and the matching paper width (58 mm or 80 mm).
5. Check that the printed ticket is legible and that its QR code can be scanned before handing it to the driver.

Printer compatibility depends on the printer's Bluetooth implementation and ESC/POS support. A printer that only works through a proprietary manufacturer's app may not be compatible. Test the exact printer model with the application before relying on it.

## Useful development commands

Run static analysis:

```bash
flutter analyze
```

Run the project's automated tests:

```bash
flutter test
```

Build a debug APK:

```bash
flutter build apk --debug
```

Build a release APK (release signing configuration must be prepared before distribution):

```bash
flutter build apk --release
```

## Scope and limitations

SmartGatePass is designed to assist the security officer; it does not replace the officer's responsibility to verify the vehicle and its registration number.

The current project scope does **not** include:

- Automatic opening or closing of a physical boom barrier.
- Facial recognition or biometric authentication.
- Queries to external vehicle-registration or law-enforcement databases.
- Mandatory cloud services or cloud-based multi-site synchronisation.
- Parking-space allocation or automated parking-fee collection.

Vehicle records are stored locally on the device. The current implementation does not provide a cloud backup or multi-device synchronisation service. Protect the device and arrange an appropriate data-backup process before using the application for real operations.

## Author

**Abdullahi Babagana**  
B.Sc. Software Engineering  
Al-Ansar University, Maiduguri

## Repository

[https://github.com/gubioabdul/smartgatepass](https://github.com/gubioabdul/smartgatepass)
