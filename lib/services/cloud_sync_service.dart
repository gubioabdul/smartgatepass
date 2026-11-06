import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../data/vehicle_repository.dart';
import '../domain/vehicle_log.dart';

class SyncResult {
  final int uploadedCount;
  final int failedCount;
  final String? errorMessage;

  const SyncResult({
    required this.uploadedCount,
    required this.failedCount,
    this.errorMessage,
  });

  bool get isSuccess => failedCount == 0 && errorMessage == null;
  bool get isNoOp => uploadedCount == 0 && failedCount == 0;

  @override
  String toString() =>
      'SyncResult(uploaded: $uploadedCount, failed: $failedCount, error: $errorMessage)';
}

class CloudSyncService {
  CloudSyncService({required this.repository});

  final VehicleRepository repository;

  static const String _collection = 'vehicle_logs';

  /// Upload all PENDING local records to Firestore.
  Future<SyncResult> syncPending() async {
    if (Firebase.apps.isEmpty) {
      return const SyncResult(
        uploadedCount: 0,
        failedCount: 0,
        errorMessage:
            'Firebase is not initialized. Check your internet connection.',
      );
    }

    final pending = await repository.pendingRecords();
    if (pending.isEmpty) {
      return const SyncResult(uploadedCount: 0, failedCount: 0);
    }

    final firestore = FirebaseFirestore.instance;
    int uploaded = 0;
    int failed = 0;
    String? lastError;

    for (final record in pending) {
      try {
        await firestore.collection(_collection).doc(record.ticketId).set({
          'ticketId': record.ticketId,
          'plateNumber': record.plateNumber,
          'entryTimestamp':
              record.entryTimestamp.toUtc().toIso8601String(),
          'exitTimestamp':
              record.exitTimestamp?.toUtc().toIso8601String(),
          'status': record.isActive ? 'ACTIVE' : 'CLOSED',
          'category': record.category,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await repository.markAsSynced(record.ticketId);
        uploaded++;
      } catch (e) {
        failed++;
        lastError = e.toString();
        if (kDebugMode) {
          debugPrint('Sync failed for ${record.ticketId}: $e');
        }
      }
    }

    return SyncResult(
      uploadedCount: uploaded,
      failedCount: failed,
      errorMessage: failed > 0 ? '$failed record(s) failed. $lastError' : null,
    );
  }

  /// Fetch records from Firestore for the Admin Dashboard.
  Future<List<VehicleLog>> fetchAllFromCloud({int limit = 100}) async {
    if (Firebase.apps.isEmpty) {
      throw Exception('Firebase is not initialized.');
    }

    final snapshot = await FirebaseFirestore.instance
        .collection(_collection)
        .orderBy('entryTimestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return VehicleLog(
        ticketId: data['ticketId'] as String,
        plateNumber: data['plateNumber'] as String,
        entryTimestamp:
            DateTime.parse(data['entryTimestamp'] as String).toLocal(),
        exitTimestamp: data['exitTimestamp'] == null
            ? null
            : DateTime.parse(data['exitTimestamp'] as String).toLocal(),
        category: (data['category'] as String?) ?? 'Visitor',
        syncStatus: 'SYNCED',
      );
    }).toList();
  }
}