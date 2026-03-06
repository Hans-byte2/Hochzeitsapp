// lib/sync/services/sync_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database_helper.dart';
import '../models/sync_models.dart';
import 'sync_logger.dart';

class SyncRepository {
  static const String _lastSyncKey = 'sync_last_synced_at';

  Future<String?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  Future<void> setLastSyncedAt(String isoDateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, isoDateTime);
    SyncLogger.info('Letzte Sync-Zeit gespeichert: $isoDateTime');
  }

  Future<List<SyncRecord>> getChangedRecords({String? since}) async {
    final db = await DatabaseHelper.instance.database;
    final records = <SyncRecord>[];

    for (final table in SyncTable.values) {
      final tableRecords = await _getChangedFromTable(db, table, since: since);
      records.addAll(tableRecords);
    }

    SyncLogger.info(
      'Änderungen gelesen: ${records.length} Datensätze'
      '${since != null ? " seit $since" : " (Full-Sync)"}',
    );
    return records;
  }

  Future<List<SyncRecord>> _getChangedFromTable(
    Database db,
    SyncTable table, {
    String? since,
  }) async {
    List<Map<String, dynamic>> rows;

    if (since == null) {
      rows = await db.query(table.dbName);
    } else {
      rows = await db.query(
        table.dbName,
        where: 'updated_at > ?',
        whereArgs: [since],
      );
    }

    return rows.map((row) {
      final id = row['id'] as int;
      final updatedAt =
          (row['updated_at'] as String?) ?? DateTime.now().toIso8601String();
      final isDeleted = (row['deleted'] as int?) == 1;

      return SyncRecord(
        table: table,
        localId: id,
        data: Map<String, dynamic>.from(row),
        updatedAt: updatedAt,
        isDeleted: isDeleted,
      );
    }).toList();
  }

  Future<SyncApplyResult> applyRecords(List<SyncRecord> records) async {
    final db = await DatabaseHelper.instance.database;
    int applied = 0;
    int skipped = 0;
    int errors = 0;

    for (final record in records) {
      try {
        final wasApplied = await _applyRecord(db, record);
        if (wasApplied) {
          applied++;
        } else {
          skipped++;
        }
      } catch (e) {
        SyncLogger.error(
          'Fehler beim Anwenden von Record ${record.localId}',
          e,
        );
        errors++;
      }
    }

    SyncLogger.info(
      'Records angewendet: $applied übernommen, $skipped übersprungen, $errors Fehler',
    );
    return SyncApplyResult(applied: applied, skipped: skipped, errors: errors);
  }

  Future<bool> _applyRecord(Database db, SyncRecord record) async {
    final tableName = record.table.dbName;
    final incomingUpdatedAt = record.updatedAt;

    final existing = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [record.localId],
    );

    if (existing.isEmpty) {
      await db.insert(
        tableName,
        Map<String, dynamic>.from(record.data),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      SyncLogger.debug('Neu eingefügt: $tableName #${record.localId}');
      return true;
    }

    final localUpdatedAt = existing.first['updated_at'] as String?;

    if (localUpdatedAt != null &&
        localUpdatedAt.compareTo(incomingUpdatedAt) >= 0) {
      SyncLogger.debug(
        'Übersprungen (lokal neuer): $tableName #${record.localId}',
      );
      return false;
    }

    await db.update(
      tableName,
      Map<String, dynamic>.from(record.data),
      where: 'id = ?',
      whereArgs: [record.localId],
    );
    SyncLogger.debug('Aktualisiert: $tableName #${record.localId}');
    return true;
  }

  Future<int> countPendingChanges(String? lastSyncedAt) async {
    if (lastSyncedAt == null) return -1;
    final records = await getChangedRecords(since: lastSyncedAt);
    return records.length;
  }
}

class SyncApplyResult {
  final int applied;
  final int skipped;
  final int errors;

  const SyncApplyResult({
    required this.applied,
    required this.skipped,
    required this.errors,
  });

  bool get hasErrors => errors > 0;

  @override
  String toString() =>
      'SyncApplyResult(applied: $applied, skipped: $skipped, errors: $errors)';
}
