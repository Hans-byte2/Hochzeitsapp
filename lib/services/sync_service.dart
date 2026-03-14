import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../data/database_helper.dart';
import '../data/dienstleister_database.dart';
import '../models/sync_models.dart';
import '../models/wedding_models.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final DienstleisterDatabase _dlDb = DienstleisterDatabase.instance;

  // ================================================================
  // EXPORT
  // ================================================================

  Future<File?> exportAllData() async {
    try {
      debugPrint('🔄 Starting data export...');

      final syncData = await _collectAllData();
      final jsonString = jsonEncode(syncData.toJson());
      debugPrint('📦 JSON size: ${jsonString.length} bytes');

      final bytes = utf8.encode(jsonString);
      final compressed = gzip.encode(bytes);
      debugPrint(
        '🗜️  Compressed size: ${compressed.length} bytes '
        '(${(compressed.length / bytes.length * 100).toStringAsFixed(1)}% of original)',
      );

      File? file;
      try {
        final downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final timestamp = DateTime.now()
              .toIso8601String()
              .replaceAll(':', '-')
              .split('.')[0];
          final filePath =
              '${downloadsDir.path}/wedding_backup_$timestamp.heartpebble';
          file = File(filePath);
          await file.writeAsBytes(compressed);
          debugPrint('✅ Export successful (public): $filePath');
        }
      } catch (e) {
        debugPrint('⚠️  Public storage not accessible: $e');
      }

      if (file == null) {
        final directory = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now()
            .toIso8601String()
            .replaceAll(':', '-')
            .split('.')[0];
        final filePath =
            '${directory.path}/wedding_backup_$timestamp.heartpebble';
        file = File(filePath);
        await file.writeAsBytes(compressed);
        debugPrint('✅ Export successful (private): $filePath');
      }

      return file;
    } catch (e, stackTrace) {
      debugPrint('❌ Export error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<bool> shareExportedData() async {
    try {
      final file = await exportAllData();
      if (file == null) return false;

      final result = await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'HeartPebble Hochzeitsdaten',
        text: 'Hier sind unsere Hochzeitsplanungsdaten! 💍✨',
      );

      debugPrint('📤 Share result: ${result.status}');
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('❌ Share error: $e');
      return false;
    }
  }

  // ================================================================
  // IMPORT
  // ================================================================

  Future<ImportResult> importData(
    String filePath, {
    bool mergeData = true,
  }) async {
    try {
      debugPrint('🔄 Starting data import from: $filePath');

      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          success: false,
          message: 'Datei nicht gefunden',
          statistics: ImportStatistics(),
        );
      }

      final compressed = await file.readAsBytes();
      final decompressed = gzip.decode(compressed);
      final jsonString = utf8.decode(decompressed);
      debugPrint('📦 Decompressed size: ${jsonString.length} bytes');

      final Map<String, dynamic> json = jsonDecode(jsonString);
      final syncData = SyncData.fromJson(json);

      if (!_validateSyncData(syncData)) {
        return ImportResult(
          success: false,
          message: 'Ungültige Datenstruktur',
          statistics: ImportStatistics(),
        );
      }

      final stats = await _importAllData(syncData, mergeData: mergeData);

      return ImportResult(
        success: true,
        message: 'Daten erfolgreich importiert',
        statistics: stats,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Import error: $e\n$stackTrace');
      return ImportResult(
        success: false,
        message: 'Fehler beim Import: $e',
        statistics: ImportStatistics(),
      );
    }
  }

  // ================================================================
  // DATEN SAMMELN (Export)
  // ================================================================

  Future<SyncData> _collectAllData() async {
    // Gäste
    final guests = await _db.getAllGuestsIncludingDeleted();
    final guestMaps = guests.map((g) => _sanitizeMap(g.toMap())).toList();

    // Budget
    final budgetItems = await _db.getAllBudgetItemsIncludingDeleted();
    final budgetMaps = budgetItems.map((b) => _sanitizeMap(b.toMap())).toList();

    // Tasks
    final tasks = await _db.getAllTasksIncludingDeleted();
    final taskMaps = tasks.map((t) => _sanitizeMap(t.toMap())).toList();

    // Tische
    final tables = await _db.getAllTablesIncludingDeleted();
    final tableMaps = tables.map((t) => _sanitizeMap(t.toMap())).toList();

    // Payment Plans
    List<Map<String, dynamic>> paymentPlanMaps = [];
    try {
      final plans = await _db.getAllPaymentPlansIncludingDeleted();
      paymentPlanMaps = plans.map((p) => _sanitizeMap(p.toMap())).toList();
      debugPrint('📦 Exporting ${paymentPlanMaps.length} PaymentPlans');
    } catch (e) {
      debugPrint('ℹ️  PaymentPlans export error (skipping): $e');
    }

    // Dienstleister inkl. soft-deleted + Sub-Tabellen
    List<Map<String, dynamic>> dienstleister = [];
    try {
      final db = await DatabaseHelper.instance.database;
      // Alle inkl. is_deleted=1 exportieren damit Partner-Löschungen ankommen
      final allRows = await db.query('dienstleister');
      debugPrint('📦 Exporting ${allRows.length} Dienstleister...');

      for (final row in allRows) {
        final dlMap = _sanitizeMap(Map<String, dynamic>.from(row));
        final dlId = row['id'] as String;

        final zahlungen = await _dlDb.getZahlungenFuer(dlId);
        dlMap['zahlungen'] = zahlungen
            .map((z) => _sanitizeMap(z.toMap()))
            .toList();

        final notizen = await _dlDb.getNotizenFuer(dlId);
        dlMap['notizen'] = notizen.map((n) => _sanitizeMap(n.toMap())).toList();

        final aufgaben = await _dlDb.getAufgabenFuer(dlId);
        dlMap['aufgaben'] = aufgaben
            .map((a) => _sanitizeMap(a.toMap()))
            .toList();

        dienstleister.add(dlMap);
      }
      debugPrint('✅ Exported ${dienstleister.length} Dienstleister');
    } catch (e) {
      debugPrint('ℹ️  Dienstleister export error (skipping): $e');
    }

    var weddingInfo = await _db.getWeddingData();
    if (weddingInfo != null) {
      weddingInfo = _sanitizeMap(weddingInfo);
    }

    return SyncData(
      version: 1,
      exportedAt: DateTime.now(),
      weddingInfo: weddingInfo,
      guests: guestMaps,
      budgetItems: budgetMaps,
      tasks: taskMaps,
      tables: tableMaps,
      serviceProviders: dienstleister,
      paymentPlans: paymentPlanMaps,
    );
  }

  // ================================================================
  // DATEN IMPORTIEREN
  // ================================================================

  Future<ImportStatistics> _importAllData(
    SyncData data, {
    bool mergeData = true,
  }) async {
    int guestsAdded = 0,
        guestsUpdated = 0,
        guestsDeleted = 0,
        guestsSkipped = 0;
    int budgetAdded = 0,
        budgetUpdated = 0,
        budgetDeleted = 0,
        budgetSkipped = 0;
    int tasksAdded = 0, tasksUpdated = 0, tasksDeleted = 0, tasksSkipped = 0;
    int tablesAdded = 0,
        tablesUpdated = 0,
        tablesDeleted = 0,
        tablesSkipped = 0;
    int providersAdded = 0,
        providersUpdated = 0,
        providersDeleted = 0,
        providersSkipped = 0;
    int plansAdded = 0, plansUpdated = 0, plansDeleted = 0, plansSkipped = 0;

    // ── GÄSTE ────────────────────────────────────────────────────────────
    debugPrint('🔄 Importing ${data.guests.length} Guests...');
    final existingGuests = await _db.getAllGuestsIncludingDeleted();

    for (final map in data.guests) {
      try {
        final firstName = map['first_name'] as String?;
        final lastName = map['last_name'] as String?;
        final isDeleted = (map['deleted'] ?? 0) == 1;

        final existing = existingGuests
            .where((g) => g.firstName == firstName && g.lastName == lastName)
            .firstOrNull;

        if (existing == null) {
          if (isDeleted) continue;
          final clean = Map<String, dynamic>.from(map)..remove('id');
          await _db.createGuest(Guest.fromMap(clean));
          guestsAdded++;
        } else {
          final r = _resolveConflict(
            map['updated_at'] as String?,
            existing.updatedAt,
          );
          if (r == _ConflictResult.skip) {
            guestsSkipped++;
            continue;
          }

          if (isDeleted) {
            if (existing.deleted == 0) {
              await _db.deleteGuest(existing.id!);
              guestsDeleted++;
            }
          } else {
            final updated = Map<String, dynamic>.from(map)
              ..['id'] = existing.id;
            await _db.updateGuest(Guest.fromMap(updated));
            guestsUpdated++;
          }
        }
      } catch (e) {
        debugPrint('⚠️  Guest import error: $e');
      }
    }
    debugPrint(
      '📊 Guests: +$guestsAdded ~$guestsUpdated 🗑$guestsDeleted ⏭$guestsSkipped',
    );

    // ── TASKS ─────────────────────────────────────────────────────────────
    debugPrint('🔄 Importing ${data.tasks.length} Tasks...');
    final existingTasks = await _db.getAllTasksIncludingDeleted();

    for (final map in data.tasks) {
      try {
        final title = map['title'] as String?;
        final isDeleted = (map['deleted'] ?? 0) == 1;

        final existing = existingTasks
            .where((t) => t.title == title)
            .firstOrNull;

        if (existing == null) {
          if (isDeleted) continue;
          final clean = Map<String, dynamic>.from(map)
            ..remove('id')
            ..putIfAbsent(
              'created_date',
              () => DateTime.now().toIso8601String(),
            );
          await _db.createTask(Task.fromMap(clean));
          tasksAdded++;
        } else {
          final r = _resolveConflict(
            map['updated_at'] as String?,
            existing.updatedAt,
          );
          if (r == _ConflictResult.skip) {
            tasksSkipped++;
            continue;
          }

          if (isDeleted) {
            if (existing.deleted == 0) {
              await _db.deleteTask(existing.id!);
              tasksDeleted++;
            }
          } else {
            final updated = Map<String, dynamic>.from(map)
              ..['id'] = existing.id;
            await _db.updateTask(Task.fromMap(updated));
            tasksUpdated++;
          }
        }
      } catch (e) {
        debugPrint('⚠️  Task import error: $e');
      }
    }
    debugPrint(
      '📊 Tasks: +$tasksAdded ~$tasksUpdated 🗑$tasksDeleted ⏭$tasksSkipped',
    );

    // ── BUDGET ITEMS ──────────────────────────────────────────────────────
    debugPrint('🔄 Importing ${data.budgetItems.length} BudgetItems...');
    final existingBudget = await _db.getAllBudgetItemsIncludingDeleted();

    for (final map in data.budgetItems) {
      try {
        final name = map['name'] as String?;
        if (name == null || name.isEmpty) continue;
        final isDeleted = (map['deleted'] ?? 0) == 1;

        final existing = existingBudget
            .where((b) => b.name == name)
            .firstOrNull;

        if (existing == null) {
          if (isDeleted) continue;
          final clean = Map<String, dynamic>.from(map)..remove('id');
          await _db.insertBudgetItem(clean);
          budgetAdded++;
        } else {
          final r = _resolveConflict(
            map['updated_at'] as String?,
            existing.updatedAt,
          );
          if (r == _ConflictResult.skip) {
            budgetSkipped++;
            continue;
          }

          if (isDeleted) {
            if (existing.deleted == 0) {
              await _db.deleteBudgetItem(existing.id!);
              budgetDeleted++;
            }
          } else {
            final updated = Map<String, dynamic>.from(map)
              ..['id'] = existing.id;
            await _db.updateBudgetItem(BudgetItem.fromMap(updated));
            budgetUpdated++;
          }
        }
      } catch (e) {
        debugPrint('⚠️  BudgetItem import error: $e');
      }
    }
    debugPrint(
      '📊 Budget: +$budgetAdded ~$budgetUpdated 🗑$budgetDeleted ⏭$budgetSkipped',
    );

    // ── TISCHE ────────────────────────────────────────────────────────────
    debugPrint('🔄 Importing ${data.tables.length} Tables...');
    final existingTables = await _db.getAllTablesIncludingDeleted();

    for (final map in data.tables) {
      try {
        final tableName = map['table_name'] as String?;
        final tableNumber = map['table_number'];
        if (tableName == null) continue;
        final isDeleted = (map['deleted'] ?? 0) == 1;

        // Match: gleicher Name ODER gleiche Nummer
        final existing = existingTables.where((t) {
          return t.tableName == tableName || t.tableNumber == tableNumber;
        }).firstOrNull;

        if (existing == null) {
          if (isDeleted) continue;
          final clean = Map<String, dynamic>.from(map)..remove('id');
          await _db.insertTable(clean);
          tablesAdded++;
        } else {
          final r = _resolveConflict(
            map['updated_at'] as String?,
            existing.updatedAt,
          );
          if (r == _ConflictResult.skip) {
            tablesSkipped++;
            continue;
          }

          if (isDeleted) {
            if (existing.deleted == 0) {
              await _db.deleteTable(existing.id!);
              tablesDeleted++;
            }
          } else {
            final updated = Map<String, dynamic>.from(map)
              ..['id'] = existing.id;
            await _db.updateTable(TableModel.fromMap(updated));
            tablesUpdated++;
          }
        }
      } catch (e) {
        debugPrint('⚠️  Table import error: $e');
      }
    }
    debugPrint(
      '📊 Tables: +$tablesAdded ~$tablesUpdated 🗑$tablesDeleted ⏭$tablesSkipped',
    );

    // ── DIENSTLEISTER ─────────────────────────────────────────────────────
    debugPrint('🔄 Importing ${data.serviceProviders.length} Dienstleister...');
    final db = await DatabaseHelper.instance.database;

    for (final map in data.serviceProviders) {
      try {
        final id = map['id'] as String?;
        final name = map['name'] as String?;
        if (id == null || name == null) continue;

        final isDeleted = (map['is_deleted'] ?? 0) == 1;
        final importTs = map['updated_at'] as String?;

        // Sub-Tabellen extrahieren
        final zahlungenData = List<Map<String, dynamic>>.from(
          map['zahlungen'] ?? [],
        );
        final notizenData = List<Map<String, dynamic>>.from(
          map['notizen'] ?? [],
        );
        final aufgabenData = List<Map<String, dynamic>>.from(
          map['aufgaben'] ?? [],
        );

        // Haupteintrag ohne Sub-Tabellen
        final dlMap = Map<String, dynamic>.from(map)
          ..remove('zahlungen')
          ..remove('notizen')
          ..remove('aufgaben');

        final existingRows = await db.query(
          'dienstleister',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (existingRows.isEmpty) {
          if (isDeleted) continue;
          await db.insert('dienstleister', dlMap);
          await _importDienstleisterSubtables(
            id,
            zahlungenData,
            notizenData,
            aufgabenData,
          );
          providersAdded++;
          debugPrint('   ➕ $name');
        } else {
          final localTs = existingRows.first['updated_at'] as String?;
          final r = _resolveConflict(importTs, localTs);
          if (r == _ConflictResult.skip) {
            providersSkipped++;
            continue;
          }

          if (isDeleted) {
            if ((existingRows.first['is_deleted'] ?? 0) == 0) {
              await db.update(
                'dienstleister',
                {
                  'is_deleted': 1,
                  'updated_at': importTs ?? DateTime.now().toIso8601String(),
                },
                where: 'id = ?',
                whereArgs: [id],
              );
              providersDeleted++;
              debugPrint('   🗑️  $name');
            }
          } else {
            await db.update(
              'dienstleister',
              dlMap,
              where: 'id = ?',
              whereArgs: [id],
            );
            // Sub-Tabellen: löschen + neu einfügen (Import gewinnt wenn neuer)
            await db.delete(
              'dienstleister_zahlungen',
              where: 'dienstleister_id = ?',
              whereArgs: [id],
            );
            await db.delete(
              'dienstleister_notizen',
              where: 'dienstleister_id = ?',
              whereArgs: [id],
            );
            await db.delete(
              'dienstleister_aufgaben',
              where: 'dienstleister_id = ?',
              whereArgs: [id],
            );
            await _importDienstleisterSubtables(
              id,
              zahlungenData,
              notizenData,
              aufgabenData,
            );
            providersUpdated++;
            debugPrint('   🔄 $name');
          }
        }
      } catch (e) {
        debugPrint('⚠️  Dienstleister import error: $e');
      }
    }
    debugPrint(
      '📊 Dienstleister: +$providersAdded ~$providersUpdated '
      '🗑$providersDeleted ⏭$providersSkipped',
    );

    // ── PAYMENT PLANS ─────────────────────────────────────────────────────
    debugPrint('🔄 Importing ${data.paymentPlans.length} PaymentPlans...');
    final existingPlans = await _db.getAllPaymentPlansIncludingDeleted();

    for (final map in data.paymentPlans) {
      try {
        final vendorName = map['vendor_name'] as String?;
        final dueDate = map['due_date'] as String?;
        final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
        if (vendorName == null || dueDate == null) continue;

        final isDeleted = (map['deleted'] ?? 0) == 1;

        // Match: vendor_name + due_date (Datum-Teil) + amount
        final dueDateNorm = _normalizeIsoDate(dueDate);
        final existing = existingPlans.where((p) {
          return p.vendorName == vendorName &&
              _normalizeIsoDate(p.dueDate.toIso8601String()) == dueDateNorm &&
              p.amount == amount;
        }).firstOrNull;

        if (existing == null) {
          if (isDeleted) continue;
          final clean = Map<String, dynamic>.from(map)..remove('id');
          await _db.insertPaymentPlanMap(clean);
          plansAdded++;
          debugPrint('   ➕ $vendorName ($dueDate)');
        } else {
          final r = _resolveConflict(
            map['updated_at'] as String?,
            existing.updatedAt,
          );
          if (r == _ConflictResult.skip) {
            plansSkipped++;
            continue;
          }

          if (isDeleted) {
            if (existing.deleted == 0) {
              await _db.deletePaymentPlan(existing.id!);
              plansDeleted++;
              debugPrint('   🗑️  $vendorName');
            }
          } else {
            final updated = Map<String, dynamic>.from(map)
              ..['id'] = existing.id;
            await _db.updatePaymentPlan(PaymentPlan.fromMap(updated));
            plansUpdated++;
            debugPrint('   🔄 $vendorName');
          }
        }
      } catch (e) {
        debugPrint('⚠️  PaymentPlan import error: $e');
      }
    }
    debugPrint(
      '📊 PaymentPlans: +$plansAdded ~$plansUpdated 🗑$plansDeleted ⏭$plansSkipped',
    );

    return ImportStatistics(
      guestsAdded: guestsAdded,
      guestsUpdated: guestsUpdated,
      guestsDeleted: guestsDeleted,
      guestsSkipped: guestsSkipped,
      budgetItemsAdded: budgetAdded,
      budgetItemsUpdated: budgetUpdated,
      budgetItemsDeleted: budgetDeleted,
      budgetItemsSkipped: budgetSkipped,
      tasksAdded: tasksAdded,
      tasksUpdated: tasksUpdated,
      tasksDeleted: tasksDeleted,
      tasksSkipped: tasksSkipped,
      tablesAdded: tablesAdded,
      tablesUpdated: tablesUpdated,
      tablesDeleted: tablesDeleted,
      tablesSkipped: tablesSkipped,
      serviceProvidersAdded: providersAdded,
      serviceProvidersUpdated: providersUpdated,
      serviceProvidersDeleted: providersDeleted,
      serviceProvidersSkipped: providersSkipped,
      paymentPlansAdded: plansAdded,
      paymentPlansUpdated: plansUpdated,
      paymentPlansDeleted: plansDeleted,
      paymentPlansSkipped: plansSkipped,
    );
  }

  // ================================================================
  // DIENSTLEISTER SUB-TABELLEN EINFÜGEN
  // ================================================================

  Future<void> _importDienstleisterSubtables(
    String dienstleisterId,
    List<Map<String, dynamic>> zahlungen,
    List<Map<String, dynamic>> notizen,
    List<Map<String, dynamic>> aufgaben,
  ) async {
    final db = await DatabaseHelper.instance.database;

    for (final z in zahlungen) {
      try {
        await db.insert('dienstleister_zahlungen', {
          ...z,
          'dienstleister_id': dienstleisterId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('   ⚠️  Zahlung insert: $e');
      }
    }
    for (final n in notizen) {
      try {
        await db.insert('dienstleister_notizen', {
          ...n,
          'dienstleister_id': dienstleisterId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('   ⚠️  Notiz insert: $e');
      }
    }
    for (final a in aufgaben) {
      try {
        await db.insert('dienstleister_aufgaben', {
          ...a,
          'dienstleister_id': dienstleisterId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } catch (e) {
        debugPrint('   ⚠️  Aufgabe insert: $e');
      }
    }
  }

  // ================================================================
  // HILFSMETHODEN
  // ================================================================

  /// Zentrale CRDT-Konfliktauflösung für alle Entitäten.
  /// Gibt [_ConflictResult.useImport] zurück wenn Import neuer oder kein Timestamp.
  /// Gibt [_ConflictResult.skip] zurück wenn lokal neuer oder gleich.
  _ConflictResult _resolveConflict(String? importTs, String? localTs) {
    if (importTs == null || localTs == null) return _ConflictResult.useImport;
    try {
      final importTime = DateTime.parse(importTs);
      final localTime = DateTime.parse(localTs);
      return importTime.isAfter(localTime)
          ? _ConflictResult.useImport
          : _ConflictResult.skip;
    } catch (_) {
      return _ConflictResult.useImport;
    }
  }

  /// Normalisiert ISO8601 auf Datums-Teil "YYYY-MM-DD" für due_date Vergleiche
  String _normalizeIsoDate(String isoDate) =>
      isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;

  /// Konvertiert DateTime-Objekte in Maps rekursiv zu Strings
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is DateTime) {
        result[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        result[key] = _sanitizeMap(value);
      } else if (value is List) {
        result[key] = value
            .map(
              (item) =>
                  item is Map<String, dynamic> ? _sanitizeMap(item) : item,
            )
            .toList();
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  bool _validateSyncData(SyncData data) {
    if (data.version > 1) {
      debugPrint('⚠️  Warning: Newer data version (${data.version})');
      return false;
    }
    return true;
  }

  // ================================================================
  // STATISTIK
  // ================================================================

  Future<String> getDatabaseSize() async {
    try {
      final syncData = await _collectAllData();
      final jsonString = jsonEncode(syncData.toJson());
      final bytes = utf8.encode(jsonString);
      final compressed = gzip.encode(bytes);
      final kb = compressed.length / 1024;
      return kb < 1024
          ? '${kb.toStringAsFixed(1)} KB'
          : '${(kb / 1024).toStringAsFixed(2)} MB';
    } catch (e) {
      return 'Unbekannt';
    }
  }

  Future<Map<String, int>> countAllRecords() async {
    int dienstleisterCount = 0;
    try {
      dienstleisterCount = (await _dlDb.getAlleDienstleister()).length;
    } catch (e) {
      debugPrint('ℹ️  Dienstleister count error: $e');
    }

    return {
      'guests': (await _db.getAllGuests()).length,
      'budgetItems': (await _db.getAllBudgetItems()).length,
      'tasks': (await _db.getAllTasks()).length,
      'tables': (await _db.getAllTables()).length,
      'serviceProviders': dienstleisterCount,
      'paymentPlans': (await _db.getAllPaymentPlans()).length,
    };
  }
}

// Interne Enum für Timestamp-basierte Konfliktauflösung
enum _ConflictResult { useImport, skip }
