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
        return ImportResult(success: false, message: 'Datei nicht gefunden');
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
        return ImportResult(success: false, message: 'Ungültige Datenstruktur');
      }

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
      return ImportResult(success: false, message: 'Fehler beim Import: $e');
    }
  }

  /// Sammelt alle Daten aus der Datenbank
  Future<SyncData> _collectAllData() async {
    // Konvertiere Model-Objekte zu Maps
    final guests = await _db.getAllGuests();
    final guestMaps = guests.map((g) => _sanitizeMap(_guestToMap(g))).toList();

    final budgetItems = await _db.getAllBudgetItems();
    final sanitizedBudget = budgetItems.map((b) => _sanitizeMap(b)).toList();

    final tasks = await _db.getAllTasks();
    final taskMaps = tasks.map((t) => _sanitizeMap(_taskToMap(t))).toList();

    final tables = await _db.getAllTables();
    final sanitizedTables = tables.map((t) => _sanitizeMap(t)).toList();

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

  /// Importiert alle Daten in die Datenbank
  Future<ImportStatistics> _importAllData(
    SyncData data, {
    bool mergeData = true,
  }) async {
    int guestsAdded = 0;
    int guestsUpdated = 0;
    int budgetAdded = 0;
    int budgetUpdated = 0;
    int tasksAdded = 0;
    int tasksUpdated = 0;
    int tablesAdded = 0;
    int tablesUpdated = 0;
    int providersAdded = 0;
    int providersUpdated = 0;

    try {
      // WICHTIG: Bei INTEGER IDs können wir nicht einfach importieren,
      // da IDs zwischen Geräten unterschiedlich sind!
      // Wir importieren alles als NEU (ohne ID), damit die DB neue IDs vergibt.

      // Gäste importieren
      for (final guestMap in data.guests) {
        try {
          // Entferne ID, damit DB neue vergibt
          final guestMapWithoutId = Map<String, dynamic>.from(guestMap);
          guestMapWithoutId.remove('id');

          debugPrint(
            '🔍 Importing guest: ${guestMapWithoutId['first_name']} ${guestMapWithoutId['last_name']}',
          );

          // Prüfe ob ähnlicher Gast existiert (nach Namen)
          final existingGuests = await _db.getAllGuests();
          final firstName = guestMapWithoutId['first_name'] as String?;
          final lastName = guestMapWithoutId['last_name'] as String?;

          debugPrint(
            '   Checking against ${existingGuests.length} existing guests...',
          );

          final existingGuest = existingGuests.where((g) {
            final match = g.firstName == firstName && g.lastName == lastName;
            if (match) {
              debugPrint(
                '   ✅ Found match: ${g.firstName} ${g.lastName} (ID: ${g.id})',
              );
            }
            return match;
          }).firstOrNull;

          if (existingGuest == null) {
            // Neu erstellen
            debugPrint('   ➕ Creating new guest...');
            final guest = _mapToGuest(guestMapWithoutId);
            final created = await _db.createGuest(guest);
            debugPrint('   ✅ Created with ID: ${created.id}');
            guestsAdded++;
          } else if (mergeData) {
            // Aktualisieren
            debugPrint(
              '   🔄 Updating existing guest ID: ${existingGuest.id}...',
            );
            final updatedGuest = _mapToGuest(
              guestMapWithoutId,
            ).copyWith(id: existingGuest.id);
            await _db.updateGuest(updatedGuest);
            debugPrint('   ✅ Updated guest ID: ${existingGuest.id}');
            guestsUpdated++;
          }
        } catch (e) {
          debugPrint('⚠️  Error importing guest: $e');
        }
      }

      debugPrint('📊 Guests: $guestsAdded added, $guestsUpdated updated');

      // Budget Items importieren
      for (final itemMap in data.budgetItems) {
        try {
          final itemMapWithoutId = Map<String, dynamic>.from(itemMap);
          itemMapWithoutId.remove('id');

          debugPrint('🔍 Importing budget: ${itemMapWithoutId['name']}');

          // Prüfe ob ähnlicher Eintrag existiert (nach Namen)
          final existingItems = await _db.getAllBudgetItems();
          final name = itemMapWithoutId['name'] as String?;

          debugPrint(
            '   Checking against ${existingItems.length} existing items...',
          );

          final existingItem = existingItems.where((item) {
            final match = item['name'] == name;
            if (match) {
              debugPrint(
                '   ✅ Found match: ${item['name']} (ID: ${item['id']})',
              );
            }
            return match;
          }).firstOrNull;

          if (existingItem == null) {
            debugPrint('   ➕ Creating new budget item...');
            await _db.insertBudgetItem(itemMapWithoutId);
            debugPrint('   ✅ Created');
            budgetAdded++;
          } else if (mergeData) {
            debugPrint(
              '   🔄 Updating existing budget ID: ${existingItem['id']}...',
            );
            await _db.updateBudgetItem(
              existingItem['id'] as int,
              itemMapWithoutId['name'] as String,
              (itemMapWithoutId['planned'] as num?)?.toDouble() ?? 0.0,
              (itemMapWithoutId['actual'] as num?)?.toDouble() ?? 0.0,
            );
            debugPrint('   ✅ Updated budget ID: ${existingItem['id']}');
            budgetUpdated++;
          }
        } catch (e) {
          debugPrint('⚠️  Error importing budget item: $e');
        }
      }

      debugPrint('📊 Budget: $budgetAdded added, $budgetUpdated updated');

      // Tasks importieren
      for (final taskMap in data.tasks) {
        try {
          final taskMapWithoutId = Map<String, dynamic>.from(taskMap);
          taskMapWithoutId.remove('id');

          // Prüfe ob ähnlicher Task existiert (nach Titel)
          final existingTasks = await _db.getAllTasks();
          final title = taskMapWithoutId['title'] as String?;

          final existingTask = existingTasks.where((t) {
            return t.title == title;
          }).firstOrNull;

          if (existingTask == null) {
            final task = _mapToTask(taskMapWithoutId);
            await _db.createTask(task);
            tasksAdded++;
          } else if (mergeData) {
            final updatedTask = _mapToTask(
              taskMapWithoutId,
            ).copyWith(id: existingTask.id);
            await _db.updateTask(updatedTask);
            tasksUpdated++;
          }
        } catch (e) {
          debugPrint('⚠️  Error importing task: $e');
        }
      }

      // Tables importieren
      for (final tableMap in data.tables) {
        try {
          final tableMapWithoutId = Map<String, dynamic>.from(tableMap);
          tableMapWithoutId.remove('id');

          // Prüfe ob ähnlicher Tisch existiert (nach Nummer)
          final existingTables = await _db.getAllTables();
          final tableNumber = tableMapWithoutId['table_number'] as int?;

          final existingTable = existingTables.where((t) {
            return t['table_number'] == tableNumber;
          }).firstOrNull;

          if (existingTable == null) {
            await _db.insertTable(tableMapWithoutId);
            tablesAdded++;
          } else if (mergeData) {
            await _db.updateTable(
              existingTable['id'] as int,
              tableMapWithoutId,
            );
            tablesUpdated++;
          }
        } catch (e) {
          debugPrint('⚠️  Error importing table: $e');
        }
      }

      // Dienstleister importieren (mit UUID-IDs und Unter-Tabellen)
      final dienstleisterDb = DienstleisterDatabase.instance;
      for (final dlMap in data.serviceProviders) {
        try {
          debugPrint('🔍 Importing Dienstleister: ${dlMap['name']}');

          // Prüfe ob ähnlicher Dienstleister existiert (nach Namen)
          final existingDl = await dienstleisterDb.getAlleDienstleister();
          final name = dlMap['name'] as String?;

          debugPrint(
            '   Checking against ${existingDl.length} existing Dienstleister...',
          );

          final existing = existingDl.where((d) {
            final match = d.name == name;
            if (match) {
              debugPrint('   ✅ Found match: ${d.name} (ID: ${d.id})');
            }
            return match;
          }).firstOrNull;

          String dienstleisterId;

          if (existing == null) {
            // Neu erstellen - UUID aus Import übernehmen
            debugPrint('   ➕ Creating new Dienstleister...');
            final dienstleisterMapClean = Map<String, dynamic>.from(dlMap);
            // Entferne Unter-Tabellen für Haupt-Insert
            dienstleisterMapClean.remove('zahlungen');
            dienstleisterMapClean.remove('notizen');
            dienstleisterMapClean.remove('aufgaben');

            final dienstleister = Dienstleister.fromMap(dienstleisterMapClean);
            await dienstleisterDb.createDienstleister(dienstleister);
            dienstleisterId = dienstleister.id;
            debugPrint('   ✅ Created with ID: $dienstleisterId');
            providersAdded++;
          } else {
            // Aktualisieren - bestehende UUID beibehalten
            debugPrint(
              '   🔄 Updating existing Dienstleister ID: ${existing.id}...',
            );
            final updatedMap = Map<String, dynamic>.from(dlMap);
            updatedMap['id'] = existing.id; // Behalte bestehende UUID
            // Entferne Unter-Tabellen für Haupt-Update
            updatedMap.remove('zahlungen');
            updatedMap.remove('notizen');
            updatedMap.remove('aufgaben');

            final dienstleister = Dienstleister.fromMap(updatedMap);
            await dienstleisterDb.updateDienstleister(dienstleister);
            dienstleisterId = existing.id;
            debugPrint('   ✅ Updated Dienstleister ID: $dienstleisterId');
            providersUpdated++;
          }

          // Zahlungen importieren
          if (dlMap['zahlungen'] != null) {
            final zahlungenList = dlMap['zahlungen'] as List;
            debugPrint('   💰 Importing ${zahlungenList.length} Zahlungen...');

            // Lösche alte Zahlungen für diesen Dienstleister
            final oldZahlungen = await dienstleisterDb.getZahlungenFuer(
              dienstleisterId,
            );
            for (final z in oldZahlungen) {
              await dienstleisterDb.deleteZahlung(z.id);
            }

            // Erstelle neue Zahlungen
            for (final zahlungMap in zahlungenList) {
              try {
                final zahlung = DienstleisterZahlung.fromMap({
                  ...zahlungMap,
                  'dienstleister_id':
                      dienstleisterId, // Verbinde mit Dienstleister
                });
                await dienstleisterDb.createZahlung(zahlung);
              } catch (e) {
                debugPrint('   ⚠️  Error importing Zahlung: $e');
              }
            }
            debugPrint('   ✅ Imported ${zahlungenList.length} Zahlungen');
          }

          // Notizen importieren
          if (dlMap['notizen'] != null) {
            final notizenList = dlMap['notizen'] as List;
            debugPrint('   📝 Importing ${notizenList.length} Notizen...');

            // Lösche alte Notizen
            final oldNotizen = await dienstleisterDb.getNotizenFuer(
              dienstleisterId,
            );
            for (final n in oldNotizen) {
              await dienstleisterDb.deleteNotiz(n.id);
            }

            // Erstelle neue Notizen
            for (final notizMap in notizenList) {
              try {
                final notiz = DienstleisterNotiz.fromMap({
                  ...notizMap,
                  'dienstleister_id': dienstleisterId,
                });
                await dienstleisterDb.createNotiz(notiz);
              } catch (e) {
                debugPrint('   ⚠️  Error importing Notiz: $e');
              }
            }
            debugPrint('   ✅ Imported ${notizenList.length} Notizen');
          }

          // Aufgaben importieren
          if (dlMap['aufgaben'] != null) {
            final aufgabenList = dlMap['aufgaben'] as List;
            debugPrint('   ✅ Importing ${aufgabenList.length} Aufgaben...');

            // Lösche alte Aufgaben
            final oldAufgaben = await dienstleisterDb.getAufgabenFuer(
              dienstleisterId,
            );
            for (final a in oldAufgaben) {
              await dienstleisterDb.deleteAufgabe(a.id);
            }

            // Erstelle neue Aufgaben
            for (final aufgabeMap in aufgabenList) {
              try {
                final aufgabe = DienstleisterAufgabe.fromMap({
                  ...aufgabeMap,
                  'dienstleister_id': dienstleisterId,
                });
                await dienstleisterDb.createAufgabe(aufgabe);
              } catch (e) {
                debugPrint('   ⚠️  Error importing Aufgabe: $e');
              }
            }
            debugPrint('   ✅ Imported ${aufgabenList.length} Aufgaben');
          }
        } catch (e) {
          debugPrint('⚠️  Error importing Dienstleister: $e');
        }
      }

      debugPrint(
        '📊 Dienstleister: $providersAdded added, $providersUpdated updated (with sub-tables)',
      );

      return ImportStatistics(
        guestsAdded: guestsAdded,
        guestsUpdated: guestsUpdated,
        budgetItemsAdded: budgetAdded,
        budgetItemsUpdated: budgetUpdated,
        tasksAdded: tasksAdded,
        tasksUpdated: tasksUpdated,
        tablesAdded: tablesAdded,
        tablesUpdated: tablesUpdated,
        serviceProvidersAdded: providersAdded,
        serviceProvidersUpdated: providersUpdated,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Import data error: $e');
      debugPrint('Stack trace: $stackTrace');
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
