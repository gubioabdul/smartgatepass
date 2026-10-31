import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartgatepass/data/vehicle_repository.dart';
import 'package:smartgatepass/domain/vehicle_log.dart';
import 'package:smartgatepass/main.dart';
import 'package:smartgatepass/services/gate_hardware.dart';

class MemoryRepository implements VehicleRepository {
  final records = <VehicleLog>[];
  @override
  Future<List<VehicleLog>> activeRecords({String query = ''}) async => records
      .where(
        (r) =>
            r.isActive &&
            (r.plateNumber.contains(normalizePlate(query)) ||
                r.ticketId.contains(query)),
      )
      .toList();
  @override
  Future<VehicleLog?> byTicket(String id) async {
    for (final record in records) {
      if (record.ticketId == id) return record;
    }
    return null;
  }

  @override
  Future<VehicleLog> registerEntry(String plate) async {
    final normalized = normalizePlate(plate);
    if (records.any((r) => r.isActive && r.plateNumber == normalized))
      throw const GateException('Duplicate entry');
    final record = VehicleLog(
      ticketId: '98765432-1234-4123-8123-123456789012',
      plateNumber: normalized,
      entryTimestamp: DateTime(2026, 9, 25, 12),
    );
    records.add(record);
    return record;
  }

  @override
  Future<VehicleLog> recordExit(String id, String plate) async {
    final record = (await byTicket(id))!;
    if (!record.isActive || normalizePlate(plate) != record.plateNumber)
      throw const GateException('Invalid exit');
    final closed = VehicleLog(
      ticketId: id,
      plateNumber: record.plateNumber,
      entryTimestamp: record.entryTimestamp,
      exitTimestamp: DateTime(2026, 9, 25, 13),
    );
    records[records.indexOf(record)] = closed;
    return closed;
  }

  @override
  Future<void> close() async {}
}

class StubReader implements PlateReader {
  @override
  Future<String?> captureText() async => 'NIGERIA\nABC-123DE';
  @override
  Future<String?> recoverText() async => null;
}

class FailingPrinter implements PassPrinter {
  @override
  Future<List<PrinterDevice>> pairedDevices() async => [
    const PrinterDevice('Test printer', '00:11:22:33:44:55'),
  ];
  @override
  Future<void> printPass(
    VehicleLog record,
    PrinterDevice device, {
    required bool widePaper,
  }) async => throw const GateException(
    'Printer unavailable. Saved pass remains active.',
  );
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'manual entry, print failure, and verified exit preserve record lifecycle',
    (tester) async {
      final repository = MemoryRepository();
      await tester.pumpWidget(
        SmartGatePassApp(
          repository: repository,
          plateReader: StubReader(),
          printer: FailingPrinter(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SmartGatePass'), findsOneWidget);
      await tapVisible(tester, find.text('Vehicle Entry'));
      await tester.enterText(find.byType(TextFormField), 'abc-123de');
      await tapVisible(tester, find.text('Save entry & create pass'));
      expect(repository.records, isEmpty);
      expect(
        find.text('Verify the plate against the vehicle before saving.'),
        findsOneWidget,
      );
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('Save entry & create pass'));
      expect(repository.records, hasLength(1));
      expect(find.text('ABC123DE'), findsOneWidget);
      await tapVisible(tester, find.text('Print gate pass'));
      await tapVisible(tester, find.text('Test printer'));
      expect(
        find.text('Printer unavailable. Saved pass remains active.'),
        findsOneWidget,
      );
      expect(repository.records.single.isActive, isTrue);
      await tapVisible(tester, find.text('Verify vehicle exit'));
      await tester.enterText(find.byType(TextField), 'WRONG123');
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('Record exit & close pass'));
      expect(
        find.text('Plate does not match. Check the vehicle before proceeding.'),
        findsOneWidget,
      );
      expect(repository.records.single.isActive, isTrue);
      await tester.enterText(find.byType(TextField), 'ABC123DE');
      await tapVisible(tester, find.byType(CheckboxListTile));
      await tapVisible(tester, find.text('Record exit & close pass'));
      await tapVisible(tester, find.text('Cancel'));
      expect(repository.records.single.isActive, isTrue);
      await tapVisible(tester, find.text('Record exit & close pass'));
      await tapVisible(tester, find.text('Confirm exit'));
      expect(repository.records.single.isActive, isFalse);
      expect(find.text('SmartGatePass'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'OCR fills a suggestion but still requires officer verification',
    (tester) async {
      final repository = MemoryRepository();
      await tester.pumpWidget(
        SmartGatePassApp(
          repository: repository,
          plateReader: StubReader(),
          printer: FailingPrinter(),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Vehicle Entry'));
      await tapVisible(tester, find.text('Capture plate with camera'));
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'ABC123DE',
      );
      await tapVisible(tester, find.text('Save entry & create pass'));
      expect(repository.records, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('home works on a narrow phone with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      SmartGatePassApp(
        repository: MemoryRepository(),
        plateReader: StubReader(),
        printer: FailingPrinter(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
