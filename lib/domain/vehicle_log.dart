class VehicleLog {
  const VehicleLog({
    required this.ticketId,
    required this.plateNumber,
    required this.entryTimestamp,
    this.exitTimestamp,
    this.category = 'Visitor',
    this.syncStatus = 'PENDING',
  });

  final String ticketId;
  final String plateNumber;
  final DateTime entryTimestamp;
  final DateTime? exitTimestamp;
  final String category;
  final String syncStatus;

  bool get isActive => exitTimestamp == null;
  bool get isSynced => syncStatus == 'SYNCED';

  String get durationString {
    if (exitTimestamp == null) return 'Ongoing';
    final diff = exitTimestamp!.difference(entryTimestamp);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  factory VehicleLog.fromMap(Map<String, Object?> row) => VehicleLog(
    ticketId: row['Ticket_ID'] as String,
    plateNumber: row['Plate_Number'] as String,
    entryTimestamp: DateTime.parse(row['Entry_Timestamp'] as String).toLocal(),
    exitTimestamp: row['Exit_Timestamp'] == null
        ? null
        : DateTime.parse(row['Exit_Timestamp'] as String).toLocal(),
    category: (row['Category'] as String?) ?? 'Visitor',
    syncStatus: (row['Sync_Status'] as String?) ?? 'PENDING',
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