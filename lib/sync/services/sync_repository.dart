// lib/sync/services/sync_repository.dart
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database_helper.dart';
import '../models/sync_models.dart';
import 'sync_logger.dart';

class SyncRepository {
  // ── WICHTIG: Getrennte Keys für "was ich gesendet habe" vs.
  //             "was ich empfangen habe". Vorher war es ein einziger
  //             Key – das führte dazu dass nach dem ersten Sync die
  //             eigenen Änderungen nicht mehr als "neu" erkannt wurden.
  static const String _lastSentKey = 'sync_last_sent_at';
  static const String _lastReceivedKey = 'sync_last_received_at';

  // ── Gesendet ─────────────────────────────────────────────────

  Future<String?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSentKey);
  }

  Future<void> setLastSyncedAt(String isoDateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSentKey, isoDateTime);
    SyncLogger.info('Letzte Sende-Zeit gespeichert: $isoDateTime');
  }

  // ── Empfangen ────────────────────────────────────────────────

  Future<String?> getLastReceivedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastReceivedKey);
  }

  Future<void> setLastReceivedAt(String isoDateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastReceivedKey, isoDateTime);
    SyncLogger.info('Letzte Empfangs-Zeit gespeichert: $isoDateTime');
  }

  /// Löscht beide Timestamps – wird beim Unpair aufgerufen damit
  /// nach einem neuen Pairing ein vollständiger Full-Sync stattfindet.
  Future<void> clearSyncTimestamps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSentKey);
    await prefs.remove(_lastReceivedKey);
    SyncLogger.info('Sync-Timestamps zurückgesetzt');
  }

  // ── Änderungen lesen ─────────────────────────────────────────

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

    // wedding_data hat kein deleted-Feld → einfach alle Rows
    if (table == SyncTable.weddingData) {
      rows = since == null
          ? await db.query(table.dbName)
          : await db.query(
              table.dbName,
              where: 'updated_at > ?',
              whereArgs: [since],
            );
      return rows.map((row) {
        final updatedAt =
            (row['updated_at'] as String?) ?? DateTime.now().toIso8601String();
        return SyncRecord(
          table: table,
          localId: row['id'] as int,
          data: Map<String, dynamic>.from(row),
          updatedAt: updatedAt,
          isDeleted: false,
        );
      }).toList();
    }

    if (since == null) {
      rows = await db.query(table.dbName);
    } else {
      rows = await db.query(
        table.dbName,
        where: 'updated_at > ?',
        whereArgs: [since],
      );
    }

    // ── Dienstleister haben String-IDs ───────────────────────────────────
    // Wir hashen den String zu einem stabilen Integer für localId,
    // da SyncRecord.localId ein int erwartet. Der echte String-ID
    // bleibt in data['id'] erhalten und wird beim applyRecord verwendet.
    if (table.hasStringId) {
      return rows.map((row) {
        final stringId = row['id'] as String;
        final updatedAt =
            (row['updated_at'] as String?) ?? DateTime.now().toIso8601String();
        final isDeleted = (row['is_deleted'] as int?) == 1;

        return SyncRecord(
          table: table,
          localId: stringId.hashCode, // stabiler Hash für Übertragung
          data: Map<String, dynamic>.from(row),
          updatedAt: updatedAt,
          isDeleted: isDeleted,
        );
      }).toList();
    }

    // ── Alle anderen Tabellen: Integer-ID ────────────────────────────────
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

  // ── Empfangene Records anwenden ──────────────────────────────

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

    // Empfangs-Timestamp separat speichern – NICHT den Sende-Timestamp!
    await setLastReceivedAt(DateTime.now().toIso8601String());

    SyncLogger.info(
      'Records angewendet: $applied übernommen, $skipped übersprungen, $errors Fehler',
    );
    return SyncApplyResult(applied: applied, skipped: skipped, errors: errors);
  }

  Future<bool> _applyRecord(Database db, SyncRecord record) async {
    final tableName = record.table.dbName;
    final incomingUpdatedAt = record.updatedAt;

    // ── Dienstleister: String-ID aus data['id'] verwenden ────────────────
    if (record.table.hasStringId) {
      return _applyStringIdRecord(db, record, tableName, incomingUpdatedAt);
    }

    // ── wedding_data: kein deleted-Feld, immer per id=1 upsert ──────────
    if (record.table == SyncTable.weddingData) {
      final existing = await db.query(tableName, limit: 1);
      if (existing.isEmpty) {
        await db.insert(
          tableName,
          Map<String, dynamic>.from(record.data),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return true;
      }
      final localUpdatedAt = existing.first['updated_at'] as String?;
      if (localUpdatedAt != null &&
          localUpdatedAt.compareTo(incomingUpdatedAt) >= 0) {
        return false;
      }
      await db.update(
        tableName,
        Map<String, dynamic>.from(record.data),
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return true;
    }

    // ── Standard: Integer-ID ────────────────────────────────────────────
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
        'Übersprungen (lokal neuer/gleich): $tableName #${record.localId}'
        '\n  lokal:     $localUpdatedAt'
        '\n  eingehend: $incomingUpdatedAt',
      );
      return false;
    }

    await db.update(
      tableName,
      Map<String, dynamic>.from(record.data),
      where: 'id = ?',
      whereArgs: [record.localId],
    );
    SyncLogger.debug(
      'Aktualisiert: $tableName #${record.localId}'
      '\n  lokal war: $localUpdatedAt'
      '\n  neu:       $incomingUpdatedAt',
    );
    return true;
  }

  /// Wie _applyRecord, aber mit String-ID aus data['id'].
  Future<bool> _applyStringIdRecord(
    Database db,
    SyncRecord record,
    String tableName,
    String incomingUpdatedAt,
  ) async {
    final stringId = record.data['id'] as String?;
    if (stringId == null) {
      SyncLogger.error('Dienstleister ohne id-Feld empfangen', null);
      return false;
    }

    final existing = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [stringId],
    );

    if (existing.isEmpty) {
      // Soft-Delete: nicht einfügen wenn is_deleted=1
      if ((record.data['is_deleted'] as int?) == 1) {
        SyncLogger.debug(
          'Soft-Delete ignoriert (existiert nicht lokal): $tableName $stringId',
        );
        return false;
      }
      await db.insert(
        tableName,
        Map<String, dynamic>.from(record.data),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      SyncLogger.debug('Neu eingefügt: $tableName $stringId');
      return true;
    }

    final localUpdatedAt = existing.first['updated_at'] as String?;

    if (localUpdatedAt != null &&
        localUpdatedAt.compareTo(incomingUpdatedAt) >= 0) {
      SyncLogger.debug(
        'Übersprungen (lokal neuer/gleich): $tableName $stringId',
      );
      return false;
    }

    await db.update(
      tableName,
      Map<String, dynamic>.from(record.data),
      where: 'id = ?',
      whereArgs: [stringId],
    );
    SyncLogger.debug('Aktualisiert: $tableName $stringId');
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
