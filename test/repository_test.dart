import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:smartgatepass/data/vehicle_repository.dart';
import 'package:smartgatepass/domain/vehicle_log.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory directory;
  late SqliteVehicleRepository repository;
  late String path;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smartgatepass_test_');
    path = '${directory.path}/records.db';
    repository = await SqliteVehicleRepository.open(
      factory: databaseFactoryFfi,
      path: path,
    );
  });
  tearDown(() async {
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'entry survives reopening and search ignores plate formatting',
    () async {
      final record = await repository.registerEntry('abc-123 de');
      await repository.close();
      repository = await SqliteVehicleRepository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      expect(
        (await repository.activeRecords(query: 'abc 123')).single.ticketId,
        record.ticketId,
      );
      expect(
        (await repository.byTicket(record.ticketId))!.plateNumber,
        'ABC123DE',
      );
      expect(await repository.activeRecords(query: "' OR 1=1 --"), isEmpty);
      expect(await repository.activeRecords(query: '%'), isEmpty);
    },
  );

  test(
    'duplicate active entry is rejected without creating a second pass',
    () async {
      await repository.registerEntry('ABC123DE');
      await expectLater(
        repository.registerEntry('abc-123 de'),
        throwsA(isA<GateException>()),
      );
      expect(await repository.activeRecords(), hasLength(1));
    },
  );

  test('concurrent duplicate entries produce one active pass', () async {
    final results = await Future.wait([
      repository
          .registerEntry('ABC123DE')
          .then<Object>((r) => r)
          .catchError((Object e) => e),
      repository
          .registerEntry('ABC123DE')
          .then<Object>((r) => r)
          .catchError((Object e) => e),
    ]);
    expect(results.whereType<VehicleLog>(), hasLength(1));
    expect(results.whereType<GateException>(), hasLength(1));
    expect(await repository.activeRecords(), hasLength(1));
  });

  test('wrong plate and unknown ticket cannot close a pass', () async {
    final record = await repository.registerEntry('ABC123DE');
    await expectLater(
      repository.recordExit(record.ticketId, 'XYZ999AA'),
      throwsA(isA<GateException>()),
    );
    await expectLater(
      repository.recordExit('unknown', 'ABC123DE'),
      throwsA(isA<GateException>()),
    );
    expect((await repository.byTicket(record.ticketId))!.isActive, isTrue);
  });

  test(
    'exit is permanent, repeat exit fails, and re-entry creates a new ticket',
    () async {
      final first = await repository.registerEntry('ABC123DE');
      final closed = await repository.recordExit(first.ticketId, 'abc-123 de');
      expect(closed.isActive, isFalse);
      expect(closed.exitTimestamp, isNotNull);
      expect(await repository.activeRecords(), isEmpty);
      await expectLater(
        repository.recordExit(first.ticketId, 'ABC123DE'),
        throwsA(isA<GateException>()),
      );
      final second = await repository.registerEntry('ABC123DE');
      expect(second.ticketId, isNot(first.ticketId));
      await repository.close();
      repository = await SqliteVehicleRepository.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      expect((await repository.byTicket(first.ticketId))!.isActive, isFalse);
      expect(
        (await repository.activeRecords()).single.ticketId,
        second.ticketId,
      );
    },
  );

  test('clock regression does not save an invalid exit time', () async {
    final futureRepository = SqliteVehicleRepository(
      repository.db,
      now: () => DateTime.now().add(const Duration(days: 1)),
    );
    final record = await futureRepository.registerEntry('ABC123DE');
    await expectLater(
      repository.recordExit(record.ticketId, 'ABC123DE'),
      throwsA(isA<GateException>()),
    );
    expect((await repository.byTicket(record.ticketId))!.isActive, isTrue);
  });

  test('invalid input cannot be stored and OCR is only a suggestion', () async {
    for (final invalid in ['', 'AB', 'ABC@123', 'A' * 16]) {
      await expectLater(
        repository.registerEntry(invalid),
        throwsA(isA<GateException>()),
      );
    }
    expect(plateCandidates('NIGERIA\nABC-123 DE\nABC 123DE\n123456'), [
      'ABC123DE',
    ]);
    expect(await repository.activeRecords(), isEmpty);
  });
}
