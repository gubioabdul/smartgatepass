class VehicleLog {
  const VehicleLog({
    required this.ticketId,
    required this.plateNumber,
    required this.entryTimestamp,
    this.exitTimestamp,
  });

  final String ticketId;
  final String plateNumber;
  final DateTime entryTimestamp;
  final DateTime? exitTimestamp;
  bool get isActive => exitTimestamp == null;

  factory VehicleLog.fromMap(Map<String, Object?> row) => VehicleLog(
    ticketId: row['Ticket_ID'] as String,
    plateNumber: row['Plate_Number'] as String,
    entryTimestamp: DateTime.parse(row['Entry_Timestamp'] as String).toLocal(),
    exitTimestamp: row['Exit_Timestamp'] == null
        ? null
        : DateTime.parse(row['Exit_Timestamp'] as String).toLocal(),
  );
}

String normalizePlate(String value) =>
    value.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

String? validatePlate(String? value) {
  final plate = normalizePlate(value ?? '');
  if (!RegExp(r'^[A-Z0-9]{3,15}$').hasMatch(plate)) {
    return 'Enter 3–15 letters or numbers (spaces and hyphens are allowed).';
  }
  return null;
}

// Suggestions only: OCR never authorizes entry or exit.
List<String> plateCandidates(String text) {
  final candidates = <String>{};
  for (final line in text.split('\n')) {
    final plate = normalizePlate(line);
    if (validatePlate(plate) == null &&
        RegExp(r'[A-Z]').hasMatch(plate) &&
        RegExp(r'[0-9]').hasMatch(plate)) {
      candidates.add(plate);
    }
  }
  return candidates.toList();
}

String formatTimestamp(DateTime time) {
  final local = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class GateException implements Exception {
  const GateException(this.message);
  final String message;
  @override
  String toString() => message;
}
