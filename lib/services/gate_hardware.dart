import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../domain/vehicle_log.dart';

abstract class PlateReader {
  Future<String?> captureText();
  Future<String?> recoverText();
}

class CameraPlateReader implements PlateReader {
  final ImagePicker _picker = ImagePicker();
  Future<String> _read(XFile image) async {
    final reader = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      return (await reader.processImage(InputImage.fromFilePath(image.path)))
          .text;
    } finally {
      await reader.close();
    }
  }

  @override
  Future<String?> captureText() async {
    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      throw const GateException(
        'Camera access is disabled. Allow it in phone settings, or enter the plate manually.',
      );
    }
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      imageQuality: 90,
    );
    return photo == null ? null : _read(photo);
  }

  @override
  Future<String?> recoverText() async {
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) {
      throw const GateException(
        'Photo recovery failed. Capture the plate again or type it manually.',
      );
    }
    final photos = lost.files;
    return photos == null || photos.isEmpty ? null : _read(photos.first);
  }
}

class PrinterDevice {
  const PrinterDevice(this.name, this.address);
  final String name;
  final String address;
}

abstract class PassPrinter {
  Future<List<PrinterDevice>> pairedDevices();
  Future<void> printPass(
    VehicleLog record,
    PrinterDevice device, {
    required bool widePaper,
  });
}

class BluetoothPassPrinter implements PassPrinter {
  Future<void> _check() async {
    if (!await PrintBluetoothThermal.isPermissionBluetoothGranted) {
      if (!(await Permission.bluetoothConnect.request()).isGranted) {
        throw const GateException(
          'Allow Nearby devices access in phone settings to use the printer.',
        );
      }
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      throw const GateException(
        'Turn on Bluetooth, then pair the thermal printer in phone settings.',
      );
    }
  }

  @override
  Future<List<PrinterDevice>> pairedDevices() async {
    await _check();
    return (await PrintBluetoothThermal.pairedBluetooths)
        .map((d) => PrinterDevice(d.name, d.macAdress))
        .toList();
  }

  @override
  Future<void> printPass(
    VehicleLog record,
    PrinterDevice device, {
    required bool widePaper,
  }) async {
    if (!record.isActive) {
      throw const GateException('Closed passes cannot be printed.');
    }
    await _check();
    await PrintBluetoothThermal.disconnect;
    try {
      if (!await PrintBluetoothThermal.connect(
        macPrinterAddress: device.address,
      )) {
        throw const GateException(
          'Could not connect. Check printer power and Bluetooth pairing. The saved pass is still available.',
        );
      }
      final profile = await CapabilityProfile.load();
      final bytes = ticketBytes(
        record,
        Generator(widePaper ? PaperSize.mm80 : PaperSize.mm58, profile),
      );
      if (!await PrintBluetoothThermal.writeBytes(bytes)) {
        throw const GateException(
          'The printer did not accept the ticket. Check paper and connection, then retry this same pass.',
        );
      }
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }
}

List<int> ticketBytes(VehicleLog record, Generator generator) => [
  ...generator.reset(),
  ...generator.text(
    'SMARTGATEPASS',
    styles: const PosStyles(align: PosAlign.center, bold: true),
  ),
  ...generator.text(
    'VEHICLE ENTRY PASS',
    styles: const PosStyles(align: PosAlign.center),
  ),
  ...generator.hr(),
  ...generator.text(
    record.plateNumber,
    styles: const PosStyles(
      align: PosAlign.center,
      bold: true,
      height: PosTextSize.size2,
    ),
  ),
  ...generator.text('Entry: ${formatTimestamp(record.entryTimestamp)}'),
  ...generator.qrcode(record.ticketId, size: QRSize.size6),
  ...generator.text(
    'Ticket ID:',
    styles: const PosStyles(align: PosAlign.center),
  ),
  ...generator.text(
    record.ticketId,
    styles: const PosStyles(align: PosAlign.center),
  ),
  ...generator.hr(),
  ...generator.text(
    'Keep this pass for vehicle exit.',
    styles: const PosStyles(align: PosAlign.center),
  ),
  ...generator.feed(3),
];
