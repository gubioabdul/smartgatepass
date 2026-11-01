import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart'; // Added for unique ID generation

import '../domain/vehicle_log.dart';

abstract class VehicleRepository {
  Future<List<VehicleLog>> activeRecords({String query = ''});
  Future<List<VehicleLog>> allRecords({String query = ''});
  Future<VehicleLog?> byTicket(String ticketId);
  Future<VehicleLog> registerEntry(String plate);
  Future<VehicleLog> recordExit(String ticketId, String verifiedPlate);
  Future<Map<String, int>> getDashboardStats();
  Future<void> close();
}

class SqliteVehicleRepository implements VehicleRepository {
  SqliteVehicleRepository(this.db, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final Database db;
  final DateTime Function() _now;

  static Future<SqliteVehicleRepository> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final engine = factory ?? databaseFactory;
    final location =
        path ?? p.join(await engine.getDatabasesPath(), 'smartgatepass.db');
    final db = await engine.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''CREATE TABLE Vehicle_Log (
          Ticket_ID TEXT PRIMARY KEY NOT NULL,
          Plate_Number TEXT NOT NULL,
          Entry_Timestamp TEXT NOT NULL,
          Exit_Timestamp TEXT,
          Status TEXT NOT NULL CHECK (Status IN ('ACTIVE','CLOSED')),
          CHECK ((Status = 'ACTIVE' AND Exit_Timestamp IS NULL) OR
                 (Status = 'CLOSED' AND Exit_Timestamp IS NOT NULL))
        )''');
          await db.execute(
            "CREATE UNIQUE INDEX one_active_plate ON Vehicle_Log(Plate_Number) WHERE Status = 'ACTIVE'",
          );
          await db.execute(
            'CREATE INDEX record_status ON Vehicle_Log(Status, Entry_Timestamp)',
          );
        },
      ),
    );
    return SqliteVehicleRepository(db);
  }

  @override
  Future<List<VehicleLog>> activeRecords({String query = ''}) async {
    final rows = await db.query(
      'Vehicle_Log',
      where: "Status = 'ACTIVE' AND (instr(Plate_Number, ?) > 0 OR instr(upper(Ticket_ID), ?) > 0)",
      whereArgs: [normalizePlate(query), query.trim().toUpperCase()],
      orderBy: 'Entry_Timestamp DESC',
    );
    return rows.map(VehicleLog.fromMap).toList();
  }

  @override
  Future<List<VehicleLog>> allRecords({String query = ''}) async {
    final rows = await db.query(
      'Vehicle_Log',
      where: "(instr(Plate_Number, ?) > 0 OR instr(upper(Ticket_ID), ?) > 0)",
      whereArgs: [normalizePlate(query), query.trim().toUpperCase()],
      orderBy: 'Entry_Timestamp DESC',
    );
    return rows.map(VehicleLog.fromMap).toList();
  }

  @override
  Future<VehicleLog?> byTicket(String ticketId) async {
    final rows = await db.query(
      'Vehicle_Log',
      where: 'Ticket_ID = ?',
      whereArgs: [ticketId.trim()],
      limit: 1,
    );
    return rows.isEmpty ? null : VehicleLog.fromMap(rows.first);
  }

  @override
  Future<VehicleLog> registerEntry(String plate) async {
    final validation = validatePlate(plate);
    if (validation != null) throw GateException(validation);
    final normalized = normalizePlate(plate);
    return db.transaction((txn) async {
      final existing = await txn.query(
        'Vehicle_Log',
        where: "Plate_Number = ? AND Status = 'ACTIVE'",
        whereArgs: [normalized],
      );
      if (existing.isNotEmpty) {
        throw const GateException(
          'This vehicle already has an active pass. Search the record to reprint it.',
        );
      }
      final now = _now();
      // FIX: Appended 4 random UUID characters to guarantee uniqueness
      final formattedId = 'SGP-${DateFormat('yyMMdd').format(now)}-${DateFormat('HHmmss').format(now)}${const Uuid().v4().substring(0, 4).toUpperCase()}';
      
      final record = VehicleLog(
        ticketId: formattedId,
        plateNumber: normalized,
        entryTimestamp: now,
      );
      await txn.insert('Vehicle_Log', {
        'Ticket_ID': record.ticketId,
        'Plate_Number': record.plateNumber,
        'Entry_Timestamp': record.entryTimestamp.toUtc().toIso8601String(),
        'Exit_Timestamp': null,
        'Status': 'ACTIVE',
      });
      return record;
    });
  }

  @override
  Future<VehicleLog> recordExit(String ticketId, String verifiedPlate) async {
    return db.transaction((txn) async {
      final rows = await txn.query(
        'Vehicle_Log',
        where: 'Ticket_ID = ?',
        whereArgs: [ticketId],
      );
      if (rows.isEmpty) {
        throw const GateException('Ticket not found on this device.');
      }
      final record = VehicleLog.fromMap(rows.single);
      if (!record.isActive) {
        throw const GateException('This pass has already been closed.');
      }
      if (normalizePlate(verifiedPlate) != record.plateNumber) {
        throw const GateException(
          'Plate does not match. Do not authorize this exit.',
        );
      }
      final exit = _now();
      if (exit.isBefore(record.entryTimestamp)) {
        throw const GateException(
          'Device time is earlier than entry time. Correct the clock before recording exit.',
        );
      }
      final count = await txn.update(
        'Vehicle_Log',
        {'Exit_Timestamp': exit.toUtc().toIso8601String(), 'Status': 'CLOSED'},
        where: "Ticket_ID = ? AND Status = 'ACTIVE'",
        whereArgs: [ticketId],
      );
      if (count != 1) {
        throw const GateException(
          'This pass is no longer active. Refresh the record.',
        );
      }
      return VehicleLog(
        ticketId: record.ticketId,
        plateNumber: record.plateNumber,
        entryTimestamp: record.entryTimestamp,
        exitTimestamp: exit,
      );
    });
  }

  @override
  Future<Map<String, int>> getDashboardStats() async {
    final activeRes = await db.rawQuery("SELECT COUNT(*) FROM Vehicle_Log WHERE Status = 'ACTIVE'");
    final totalRes = await db.rawQuery("SELECT COUNT(*) FROM Vehicle_Log");
    
    return {
      'active': Sqflite.firstIntValue(activeRes) ?? 0,
      'total': Sqflite.firstIntValue(totalRes) ?? 0,
    };
  }

  @override
  Future<void> close() => db.close();
}