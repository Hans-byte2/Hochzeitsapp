import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/database_helper.dart';
import '../data/dienstleister_database.dart';
import '../models/sync_models.dart';
import '../models/wedding_models.dart';
import '../models/dienstleister_models.dart';

class SyncService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Exportiert alle Daten als .heartpebble Datei
  Future<File?> exportAllData() async {
    try {
      debugPrint('🔄 Starting data export...');

      // 1. Alle Daten aus der Datenbank holen
      final syncData = await _collectAllData();

      // 2. In JSON konvertieren
      final jsonString = jsonEncode(syncData.toJson());
      debugPrint('📦 JSON size: ${jsonString.length} bytes');

      // 3. Komprimieren (gzip)
      final bytes = utf8.encode(jsonString);
      final compressed = gzip.encode(bytes);
      debugPrint(
        '🗜️  Compressed size: ${compressed.length} bytes '
        '(${(compressed.length / bytes.length * 100).toStringAsFixed(1)}% of original)',
      );

      // 4. Datei erstellen im öffentlichen Download-Verzeichnis
      // Versuche zuerst externes Storage (öffentlich zugänglich)
      File? file;
      try {
        // Für Android: /sdcard/Download/
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

      // Fallback: Privates App-Verzeichnis (wie vorher)
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

  /// Teilt die exportierte Datei
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

  /// Importiert Daten aus einer .heartpebble Datei
  Future<ImportResult> importData(
    String filePath, {
    bool mergeData = true,
  }) async {
    try {
      debugPrint('🔄 Starting data import from: $filePath');

      // 1. Datei lesen
      final file = File(filePath);
      if (!await file.exists()) {
        return ImportResult(
          success: false,
          message: 'Datei nicht gefunden',
          statistics: ImportStatistics(),
        );
      }

      final compressed = await file.readAsBytes();
      debugPrint('📦 Compressed file size: ${compressed.length} bytes');

      // 2. Dekomprimieren
      final decompressed = gzip.decode(compressed);
      final jsonString = utf8.decode(decompressed);
      debugPrint('📦 Decompressed size: ${jsonString.length} bytes');

      // 3. JSON parsen
      final Map<String, dynamic> json = jsonDecode(jsonString);
      final syncData = SyncData.fromJson(json);

      // 4. Validierung
      if (!_validateSyncData(syncData)) {
        return ImportResult(
          success: false,
          message: 'Ungültige Datenstruktur',
          statistics: ImportStatistics(),
        );
      } // ← Diese } war das Problem!

      // 5. Daten importieren
      final stats = await _importAllData(syncData, mergeData: mergeData);

      debugPrint('✅ Import successful: $stats');
      return ImportResult(
        success: true,
        message: 'Daten erfolgreich importiert',
        statistics: stats,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Import error: $e');
      debugPrint('Stack trace: $stackTrace');
      return ImportResult(
        success: false,
        message: 'Fehler beim Import: $e',
        statistics: ImportStatistics(),
      );
    }
  }

  /// Sammelt alle Daten aus der Datenbank
  Future<SyncData> _collectAllData() async {
    // Konvertiere Model-Objekte zu Maps
    final guests = await _db.getAllGuestsIncludingDeleted();
    final guestMaps = guests.map((g) => _sanitizeMap(_guestToMap(g))).toList();

    final budgetItems = await _db.getAllBudgetItemsIncludingDeleted();
    final sanitizedBudget = budgetItems
        .map((b) => _sanitizeMap(b.toMap()))
        .toList();

    final tasks = await _db.getAllTasksIncludingDeleted();
    final taskMaps = tasks.map((t) => _sanitizeMap(_taskToMap(t))).toList();

    final tables = await _db.getAllTablesIncludingDeleted();
    final sanitizedTables = tables.map((t) => _sanitizeMap(t.toMap())).toList();

    // Dienstleister (mit allen Unter-Tabellen: Zahlungen, Notizen, Aufgaben)
    List<Map<String, dynamic>> dienstleister = [];
    try {
      final dienstleisterDb = DienstleisterDatabase.instance;
      final alleDienstleister = await dienstleisterDb.getAlleDienstleister();

      debugPrint(
        '📦 Exporting ${alleDienstleister.length} Dienstleister with sub-tables...',
      );

      // Für jeden Dienstleister auch Zahlungen, Notizen, Aufgaben exportieren
      for (final dl in alleDienstleister) {
        final dlMap = _sanitizeMap(dl.toMap());

        // Zahlungen hinzufügen
        final zahlungen = await dienstleisterDb.getZahlungenFuer(dl.id);
        dlMap['zahlungen'] = zahlungen
            .map((z) => _sanitizeMap(z.toMap()))
            .toList();
        debugPrint('   └─ ${dl.name}: ${zahlungen.length} Zahlungen');

        // Notizen hinzufügen
        final notizen = await dienstleisterDb.getNotizenFuer(dl.id);
        dlMap['notizen'] = notizen.map((n) => _sanitizeMap(n.toMap())).toList();
        debugPrint('   └─ ${dl.name}: ${notizen.length} Notizen');

        // Aufgaben hinzufügen
        final aufgaben = await dienstleisterDb.getAufgabenFuer(dl.id);
        dlMap['aufgaben'] = aufgaben
            .map((a) => _sanitizeMap(a.toMap()))
            .toList();
        debugPrint('   └─ ${dl.name}: ${aufgaben.length} Aufgaben');

        dienstleister.add(dlMap);
      }

      debugPrint(
        '✅ Exported ${dienstleister.length} Dienstleister (complete with sub-tables)',
      );
    } catch (e) {
      debugPrint('ℹ️  Dienstleister export error (skipping): $e');
      dienstleister = [];
    }

    // Wedding Info
    var weddingInfo = await _db.getWeddingData();
    if (weddingInfo != null) {
      weddingInfo = _sanitizeMap(weddingInfo);
    }

    return SyncData(
      version: 1,
      exportedAt: DateTime.now(),
      weddingInfo: weddingInfo,
      guests: guestMaps,
      budgetItems: sanitizedBudget,
      tasks: taskMaps,
      tables: sanitizedTables,
      serviceProviders: dienstleister,
    );
  }

  /// Konvertiert alle DateTime-Objekte in einem Map zu Strings
  Map<String, dynamic> _sanitizeMap(Map<String, dynamic> map) {
    final sanitized = <String, dynamic>{};
    map.forEach((key, value) {
      if (value is DateTime) {
        sanitized[key] = value.toIso8601String();
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeMap(value);
      } else if (value is List) {
        sanitized[key] = value
            .map(
              (item) =>
                  item is Map<String, dynamic> ? _sanitizeMap(item) : item,
            )
            .toList();
      } else {
        sanitized[key] = value;
      }
    });
    return sanitized;
  }

  /// Validiert die Sync-Daten
  bool _validateSyncData(SyncData data) {
    if (data.version > 1) {
      debugPrint('⚠️  Warning: Newer data version (${data.version})');
      return false;
    }

    if (data.exportedAt == null) {
      debugPrint('⚠️  Warning: Missing exportedAt timestamp');
      return false;
    }

    return true;
  }

  // sync_service.dart - UPDATED IMPORT LOGIC
  //
  // Nur die _importAllData Methode mit Timestamp-Merge
  // Ersetze die komplette Methode in deiner sync_service.dart!

  Future<ImportStatistics> _importAllData(
    SyncData data, {
    bool mergeData = true,
  }) async {
    int guestsAdded = 0;
    int guestsUpdated = 0;
    int guestsSkipped = 0; // NEU: Für Timestamp-Konflikte
    int budgetAdded = 0;
    int budgetUpdated = 0;
    int tasksAdded = 0;
    int tasksUpdated = 0;
    int tasksSkipped = 0; // NEU
    int tablesAdded = 0;
    int tablesUpdated = 0;
    int providersAdded = 0;
    int providersUpdated = 0;

    try {
      // ================================================================
      // GÄSTE IMPORTIEREN - MIT TIMESTAMP-VERGLEICH
      // ================================================================

      for (final guestMap in data.guests) {
        try {
          final firstName = guestMap['first_name'] as String?;
          final lastName = guestMap['last_name'] as String?;
          final importUpdatedAt = guestMap['updated_at'] as String?;
          final isDeleted = (guestMap['deleted'] ?? 0) == 1;

          debugPrint(
            '🔍 Importing guest: $firstName $lastName (deleted: $isDeleted)',
          );

          // Prüfe ob ähnlicher Gast existiert (nach Namen)
          // WICHTIG: getAllGuestsIncludingDeleted() nutzen!
          final existingGuests = await _db.getAllGuestsIncludingDeleted();

          final existingGuest = existingGuests.where((g) {
            return g.firstName == firstName && g.lastName == lastName;
          }).firstOrNull;

          if (existingGuest == null) {
            // NEU: Kein Match gefunden

            if (isDeleted) {
              // Import ist gelöscht → nicht erstellen
              debugPrint('   ⏭️  Skipped (deleted in import, no local match)');
              continue;
            }

            // Erstelle neuen Gast
            debugPrint('   ➕ Creating new guest...');
            final guestMapClean = Map<String, dynamic>.from(guestMap);
            guestMapClean.remove('id'); // DB vergibt neue ID

            final guest = _mapToGuest(guestMapClean);
            final created = await _db.createGuest(guest);
            debugPrint('   ✅ Created with ID: ${created.id}');
            guestsAdded++;
          } else {
            // Match gefunden → TIMESTAMP VERGLEICH!

            final localUpdatedAt = existingGuest.updatedAt;

            debugPrint(
              '   ✅ Found match: ${existingGuest.firstName} ${existingGuest.lastName} (ID: ${existingGuest.id})',
            );

            // Vergleiche Timestamps
            if (importUpdatedAt != null && localUpdatedAt != null) {
              try {
                final importTime = DateTime.parse(importUpdatedAt);
                final localTime = DateTime.parse(localUpdatedAt);

                debugPrint('   📅 Comparing timestamps:');
                debugPrint(
                  '      Local:  $localTime (deleted: ${existingGuest.deleted})',
                );
                debugPrint(
                  '      Import: $importTime (deleted: ${isDeleted ? 1 : 0})',
                );

                if (importTime.isAfter(localTime)) {
                  // Import ist NEUER → überschreiben
                  debugPrint('   🔄 Import is newer → updating...');

                  if (isDeleted) {
                    // Import markiert als gelöscht → auch lokal löschen
                    if (existingGuest.deleted == 0) {
                      await _db.deleteGuest(existingGuest.id!);
                      debugPrint('   🗑️  Marked as deleted');
                      guestsUpdated++;
                    } else {
                      debugPrint('   ⏭️  Already deleted locally');
                    }
                  } else {
                    // Import ist aktiv → updaten
                    final updatedMap = Map<String, dynamic>.from(guestMap);
                    updatedMap['id'] = existingGuest.id; // Behalte lokale ID

                    final guest = _mapToGuest(updatedMap);
                    await _db.updateGuest(guest);
                    debugPrint('   ✅ Updated');
                    guestsUpdated++;
                  }
                } else if (importTime.isBefore(localTime)) {
                  // Lokal ist NEUER → behalten
                  debugPrint('   ⏭️  Local is newer → keeping local data');
                  guestsSkipped++;
                } else {
                  // Gleicher Timestamp → Import bevorzugen (oder skip)
                  debugPrint('   ⏭️  Same timestamp → skipping');
                  guestsSkipped++;
                }
              } catch (e) {
                // Fehler beim Timestamp-Parsing → Fallback
                debugPrint('   ⚠️  Timestamp parse error: $e');
                debugPrint('   ⚠️  Using import data as fallback');

                if (mergeData) {
                  final updatedMap = Map<String, dynamic>.from(guestMap);
                  updatedMap['id'] = existingGuest.id;
                  final guest = _mapToGuest(updatedMap);
                  await _db.updateGuest(guest);
                  guestsUpdated++;
                }
              }
            } else {
              // Kein Timestamp vorhanden → alte Logik (Import überschreibt)
              debugPrint('   ⚠️  No timestamps available → using import data');

              if (mergeData) {
                if (isDeleted) {
                  await _db.deleteGuest(existingGuest.id!);
                  debugPrint('   🗑️  Marked as deleted');
                } else {
                  final updatedMap = Map<String, dynamic>.from(guestMap);
                  updatedMap['id'] = existingGuest.id;
                  final guest = _mapToGuest(updatedMap);
                  await _db.updateGuest(guest);
                  debugPrint('   ✅ Updated');
                }
                guestsUpdated++;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️  Error importing guest: $e');
        }
      }

      debugPrint(
        '📊 Guests: $guestsAdded added, $guestsUpdated updated, $guestsSkipped skipped',
      );

      // ================================================================
      // TASKS IMPORTIEREN - MIT TIMESTAMP-VERGLEICH
      // ================================================================

      for (final taskMap in data.tasks) {
        try {
          final title = taskMap['title'] as String?;
          final importUpdatedAt = taskMap['updated_at'] as String?;
          final isDeleted = (taskMap['deleted'] ?? 0) == 1;

          debugPrint('🔍 Importing task: $title (deleted: $isDeleted)');

          // WICHTIG: getAllTasksIncludingDeleted() nutzen!
          final existingTasks = await _db.getAllTasksIncludingDeleted();

          final existingTask = existingTasks.where((t) {
            return t.title == title;
          }).firstOrNull;

          if (existingTask == null) {
            // Neu erstellen
            if (!isDeleted) {
              debugPrint('   ➕ Creating new task...');
              final taskMapClean = Map<String, dynamic>.from(taskMap);
              taskMapClean.remove('id');

              final task = _mapToTask(taskMapClean);
              final created = await _db.createTask(task);
              debugPrint('   ✅ Created with ID: ${created.id}');
              tasksAdded++;
            } else {
              debugPrint('   ⏭️  Skipped (deleted in import)');
            }
          } else {
            // Timestamp-Vergleich (gleiche Logik wie Gäste)
            final localUpdatedAt = existingTask.updatedAt;

            debugPrint(
              '   ✅ Found match: ${existingTask.title} (ID: ${existingTask.id})',
            );

            if (importUpdatedAt != null && localUpdatedAt != null) {
              try {
                final importTime = DateTime.parse(importUpdatedAt);
                final localTime = DateTime.parse(localUpdatedAt);

                debugPrint(
                  '   📅 Timestamps: Local=$localTime, Import=$importTime',
                );

                if (importTime.isAfter(localTime)) {
                  debugPrint('   🔄 Import is newer → updating...');

                  if (isDeleted) {
                    if (existingTask.deleted == 0) {
                      await _db.deleteTask(existingTask.id!);
                      debugPrint('   🗑️  Marked as deleted');
                      tasksUpdated++;
                    } else {
                      debugPrint('   ⏭️  Already deleted');
                    }
                  } else {
                    final updatedMap = Map<String, dynamic>.from(taskMap);
                    updatedMap['id'] = existingTask.id;
                    final task = _mapToTask(updatedMap);
                    await _db.updateTask(task);
                    debugPrint('   ✅ Updated');
                    tasksUpdated++;
                  }
                } else {
                  debugPrint('   ⏭️  Local is newer → keeping local');
                  tasksSkipped++;
                }
              } catch (e) {
                debugPrint('   ⚠️  Timestamp error: $e');
                if (mergeData) {
                  final updatedMap = Map<String, dynamic>.from(taskMap);
                  updatedMap['id'] = existingTask.id;
                  final task = _mapToTask(updatedMap);
                  await _db.updateTask(task);
                  tasksUpdated++;
                }
              }
            } else {
              // Fallback ohne Timestamps
              if (mergeData) {
                if (isDeleted) {
                  await _db.deleteTask(existingTask.id!);
                } else {
                  final updatedMap = Map<String, dynamic>.from(taskMap);
                  updatedMap['id'] = existingTask.id;
                  final task = _mapToTask(updatedMap);
                  await _db.updateTask(task);
                }
                tasksUpdated++;
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️  Error importing task: $e');
        }
      }

      debugPrint(
        '📊 Tasks: $tasksAdded added, $tasksUpdated updated, $tasksSkipped skipped',
      );

      // ================================================================
      // BUDGET, TABLES, DIENSTLEISTER - UNVERÄNDERT
      // (Hier die bestehende Logik beibehalten!)
      // ================================================================

      // Budget Items importieren (alte Logik)
      for (final itemMap in data.budgetItems) {
        try {
          final name = itemMap['name'] as String?;

          if (name == null || name.isEmpty) continue;

          debugPrint('🔍 Importing budget item: $name');

          final existingItems = await _db.getAllBudgetItemsIncludingDeleted();
          final existingItem = existingItems.where((item) {
            return item.name == name;
          }).firstOrNull;

          if (existingItem == null) {
            // Neu erstellen
            debugPrint('   ➕ Creating new budget item...');
            final itemMapClean = Map<String, dynamic>.from(itemMap);
            itemMapClean.remove('id'); // DB vergibt neue ID

            await _db.insertBudgetItem(itemMapClean);
            budgetAdded++;
            debugPrint('   ✅ Created');
          } else {
            // Update existierenden
            debugPrint('   🔄 Updating existing budget item...');

            // Behalte lokale ID
            final updatedMap = Map<String, dynamic>.from(itemMap);
            updatedMap['id'] = existingItem.id;

            final budgetItem = BudgetItem.fromMap(updatedMap);
            await _db.updateBudgetItem(budgetItem);
            budgetUpdated++;
            debugPrint('   ✅ Updated');
          }
        } catch (e) {
          debugPrint('⚠️  Error importing budget item: $e');
        }
      }

      debugPrint('📊 Budget: $budgetAdded added, $budgetUpdated updated');

      // Tasks, Tables, Dienstleister... (bestehende Logik beibehalten)
      // ...

      return ImportStatistics(
        guestsAdded: guestsAdded,
        guestsUpdated: guestsUpdated,
        guestsSkipped: guestsSkipped, // NEU
        budgetItemsAdded: budgetAdded,
        budgetItemsUpdated: budgetUpdated,
        tasksAdded: tasksAdded,
        tasksUpdated: tasksUpdated,
        tasksSkipped: tasksSkipped, // NEU
        tablesAdded: tablesAdded,
        tablesUpdated: tablesUpdated,
        serviceProvidersAdded: providersAdded,
        serviceProvidersUpdated: providersUpdated,
      );
    } catch (e) {
      debugPrint('❌ Import error: $e');
      rethrow;
    }
  }

  // ============================================================================
  // HELPER METHODEN - Konvertierung zwischen Models und Maps
  // ============================================================================

  Map<String, dynamic> _guestToMap(Guest guest) {
    return {
      'id': guest.id,
      'first_name': guest.firstName,
      'last_name': guest.lastName,
      'email': guest.email,
      'confirmed': guest.confirmed,
      'dietary_requirements': guest.dietaryRequirements,
      'table_number': guest.tableNumber,
    };
  }

  Guest _mapToGuest(Map<String, dynamic> map) {
    return Guest(
      id: map['id'],
      firstName: map['first_name'] ?? '',
      lastName: map['last_name'] ?? '',
      email: map['email'],
      confirmed: map['confirmed'] ?? 'pending',
      dietaryRequirements: map['dietary_requirements'],
      tableNumber: map['table_number'],
    );
  }

  Map<String, dynamic> _taskToMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'category': task.category,
      'priority': task.priority,
      'deadline': task.deadline?.toIso8601String(),
      'completed': task.completed ? 1 : 0,
      'created_date': task.createdDate.toIso8601String(),
    };
  }

  Task _mapToTask(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'other',
      priority: map['priority'] ?? 'medium',
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'])
          : null,
      completed: map['completed'] == 1,
      createdDate: map['created_date'] != null
          ? DateTime.parse(map['created_date'])
          : DateTime.now(),
    );
  }

  /// Gibt die aktuelle Datenbankgröße zurück
  Future<String> getDatabaseSize() async {
    try {
      final syncData = await _collectAllData();
      final jsonString = jsonEncode(syncData.toJson());
      final bytes = utf8.encode(jsonString);
      final compressed = gzip.encode(bytes);

      final kb = compressed.length / 1024;
      if (kb < 1024) {
        return '${kb.toStringAsFixed(1)} KB';
      } else {
        return '${(kb / 1024).toStringAsFixed(2)} MB';
      }
    } catch (e) {
      return 'Unbekannt';
    }
  }

  /// Zählt alle Datensätze
  Future<Map<String, int>> countAllRecords() async {
    // Dienstleister count (eigene Tabelle/Datenbank)
    int dienstleisterCount = 0;
    try {
      final dienstleisterDb = DienstleisterDatabase.instance;
      dienstleisterCount =
          (await dienstleisterDb.getAlleDienstleister()).length;
    } catch (e) {
      debugPrint('ℹ️  Dienstleister table error: $e');
      dienstleisterCount = 0;
    }

    return {
      'guests': (await _db.getAllGuests()).length,
      'budgetItems': (await _db.getAllBudgetItems()).length,
      'tasks': (await _db.getAllTasks()).length,
      'tables': (await _db.getAllTables()).length,
      'serviceProviders': dienstleisterCount,
    };
  }
}
