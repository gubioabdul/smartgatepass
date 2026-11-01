# SmartGatePass: Mobile Vehicle Entry-Exit System

**SmartGatePass** is a final-year Software Engineering project developed at Al-Ansar University, Maiduguri. It is a standalone, offline-first Android application designed to assist security personnel in managing vehicle entry and exit at institutional gates. 

By integrating on-device Optical Character Recognition (OCR), QR code ticketing, local SQLite database management, and Bluetooth thermal printing, SmartGatePass replaces inefficient manual paper registers with a secure, digital audit trail.

## ✨ Key Features

*   **Offline-First Architecture:** Core operations (OCR, QR generation/scanning, database) work entirely without internet connectivity.
*   **On-Device OCR:** Utilizes Google ML Kit to capture and recognize vehicle license plates.
*   **Human Verification:** Security officers can review and correct OCR results before saving, ensuring accuracy.
*   **QR Ticketing:** Generates a unique ticket ID (e.g., `SGP-261031-120000`) and displays it as a QR code.
*   **Bluetooth Thermal Printing:** Connects to portable 58mm/80mm ESC/POS printers to issue physical gate passes.
*   **Audit Trail:** Automatically calculates the duration of stay and logs the exact entry/exit timestamps.
*   **Authentication:** Secure login portal for security officers.

## 🛠️ Technology Stack

*   **Framework:** Flutter & Dart
*   **OCR Engine:** Google ML Kit (Text Recognition)
*   **Local Database:** SQLite (`sqflite`)
*   **QR Handling:** `qr_flutter` (generation) & `mobile_scanner` (scanning)
*   **Printing:** `print_bluetooth_thermal` & `esc_pos_utils_plus`
*   **State Management:** Standard Flutter Stateful Widgets

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (3.13.0 or higher)
*   Android Studio / VS Code
*   A physical Android device (Recommended, due to camera and Bluetooth hardware requirements)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/gubioabdul/smartgatepass.git

Navigate to the project directory:
    ```bash
    cd smartgatepass
    Fetch dependencies:

    ```bash
    flutter pub get
    Run the application:

```bash
flutter run
🔐 Default Login Credentials
Username: admin
Password: 1234

👨‍🎓 Author
Abdullahi Babagana
B.Sc. Software Engineering
Al-Ansar University, Maiduguri