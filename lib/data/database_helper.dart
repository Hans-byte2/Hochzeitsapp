import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as pathJoin;
import '../models/wedding_models.dart';
import 'dienstleister_database.dart';
import '../utils/error_logger.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('wedding_planner.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final pathString = pathJoin.join(dbPath, filePath);

      ErrorLogger.info('Initialisiere Datenbank: $pathString');

      final db = await openDatabase(
        pathString,
        version: 16, // VERSION 16: app_settings Tabelle für Menüpreise etc.
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );

      ErrorLogger.success('Datenbank v16 erfolgreich initialisiert');
      return db;
    } catch (e, stack) {
      ErrorLogger.error('Fehler bei DB-Initialisierung', e, stack);
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    try {
      ErrorLogger.info('Erstelle Datenbank-Tabellen (Version $version)...');

      // Wedding Data - MIT updated_at für Sync
      await db.execute('''
        CREATE TABLE wedding_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          wedding_date TEXT,
          bride_name TEXT,
          groom_name TEXT,
          total_budget REAL DEFAULT 0.0,
          updated_at TEXT
        )
      ''');
      ErrorLogger.info('✅ wedding_data Tabelle erstellt');

      // Guests - VOLLSTÄNDIG mit allen Spalten inkl. Kinder + Scoring
      await db.execute('''
        CREATE TABLE guests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          first_name TEXT NOT NULL,
          last_name TEXT NOT NULL,
          email TEXT,
          confirmed TEXT DEFAULT 'pending',
          dietary_requirements TEXT,
          table_number INTEGER,
          updated_at TEXT,
          deleted INTEGER DEFAULT 0,
          deleted_at TEXT,
          children_count INTEGER DEFAULT 0,
          children_names TEXT,
          relationship_type TEXT,
          is_vip INTEGER DEFAULT 0,
          distance_km INTEGER DEFAULT 0,
          priority_score REAL DEFAULT 0.0,
          score_updated_at TEXT,
          conflicts_json TEXT,
          knows_json TEXT,
          age_group TEXT,
          hobbies TEXT
        )
      ''');
      ErrorLogger.info('✅ guests Tabelle erstellt');

      // Tasks
      await db.execute('''
        CREATE TABLE tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          category TEXT DEFAULT 'other',
          priority TEXT DEFAULT 'medium',
          deadline TEXT,
          completed INTEGER DEFAULT 0,
          created_date TEXT NOT NULL,
          location TEXT DEFAULT '',
          updated_at TEXT,
          deleted INTEGER DEFAULT 0,
          deleted_at TEXT
        )
      ''');
      ErrorLogger.info('✅ tasks Tabelle erstellt');

      // Budget Items
      await db.execute('''
        CREATE TABLE budget_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          planned REAL DEFAULT 0.0,
          actual REAL DEFAULT 0.0,
          category TEXT DEFAULT 'other',
          notes TEXT DEFAULT '',
          paid INTEGER DEFAULT 0,
          updated_at TEXT,
          deleted INTEGER DEFAULT 0,
          deleted_at TEXT
        )
      ''');
      ErrorLogger.info('✅ budget_items Tabelle erstellt');

      // Tables
      await db.execute('''
        CREATE TABLE tables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          table_number INTEGER NOT NULL,
          seats INTEGER DEFAULT 8,
          categories TEXT,
          updated_at TEXT,
          deleted INTEGER DEFAULT 0,
          deleted_at TEXT
        )
      ''');
      ErrorLogger.info('✅ tables Tabelle erstellt');

      // Timeline Milestones
      await db.execute('''
        CREATE TABLE timeline_milestones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          months_before INTEGER NOT NULL,
          order_index INTEGER NOT NULL,
          is_completed INTEGER DEFAULT 0,
          created_date TEXT NOT NULL
        )
      ''');
      ErrorLogger.info('✅ timeline_milestones Tabelle erstellt');

      // ── NEU v16: App Settings ──────────────────────────────────────────
      await db.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT
        )
      ''');
      ErrorLogger.info('✅ app_settings Tabelle erstellt');

      await DienstleisterDatabase.createTables(db);
      ErrorLogger.info('✅ Dienstleister Tabellen erstellt');

      // Standardwerte für Menüpreise eintragen
      final now = DateTime.now().toIso8601String();
      await db.insert('app_settings', {
        'key': 'adult_menu_price',
        'value': '65',
        'updated_at': now,
      });
      await db.insert('app_settings', {
        'key': 'child_menu_price',
        'value': '28',
        'updated_at': now,
      });
      ErrorLogger.info('✅ Standard-Menüpreise eingetragen');

      ErrorLogger.success('🎉 Alle Tabellen erfolgreich erstellt!');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen der Tabellen', e, stack);
      rethrow;
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      ErrorLogger.info('🔄 Upgrade DB von v$oldVersion zu v$newVersion');

      Future<bool> columnExists(String table, String column) async {
        final result = await db.rawQuery('PRAGMA table_info($table)');
        return result.any((col) => col['name'] == column);
      }

      Future<bool> tableExists(String table) async {
        final result = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [table],
        );
        return result.isNotEmpty;
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v9: Soft Delete + Timestamps
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 9) {
        ErrorLogger.info(
          '🔧 Füge fehlende Spalten zu bestehenden Tabellen hinzu...',
        );

        try {
          if (!await columnExists('tasks', 'location')) {
            await db.execute(
              'ALTER TABLE tasks ADD COLUMN location TEXT DEFAULT ""',
            );
          }
          if (!await columnExists('tasks', 'updated_at')) {
            await db.execute('ALTER TABLE tasks ADD COLUMN updated_at TEXT');
          }
          if (!await columnExists('tasks', 'deleted')) {
            await db.execute(
              'ALTER TABLE tasks ADD COLUMN deleted INTEGER DEFAULT 0',
            );
          }
          if (!await columnExists('tasks', 'deleted_at')) {
            await db.execute('ALTER TABLE tasks ADD COLUMN deleted_at TEXT');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ tasks Migration: $e');
        }

        try {
          if (!await columnExists('guests', 'updated_at')) {
            await db.execute('ALTER TABLE guests ADD COLUMN updated_at TEXT');
          }
          if (!await columnExists('guests', 'deleted')) {
            await db.execute(
              'ALTER TABLE guests ADD COLUMN deleted INTEGER DEFAULT 0',
            );
          }
          if (!await columnExists('guests', 'deleted_at')) {
            await db.execute('ALTER TABLE guests ADD COLUMN deleted_at TEXT');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ guests Migration: $e');
        }

        try {
          if (!await columnExists('budget_items', 'updated_at')) {
            await db.execute(
              'ALTER TABLE budget_items ADD COLUMN updated_at TEXT',
            );
          }
          if (!await columnExists('budget_items', 'deleted')) {
            await db.execute(
              'ALTER TABLE budget_items ADD COLUMN deleted INTEGER DEFAULT 0',
            );
          }
          if (!await columnExists('budget_items', 'deleted_at')) {
            await db.execute(
              'ALTER TABLE budget_items ADD COLUMN deleted_at TEXT',
            );
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ budget_items Migration: $e');
        }

        try {
          if (!await columnExists('tables', 'updated_at')) {
            await db.execute('ALTER TABLE tables ADD COLUMN updated_at TEXT');
          }
          if (!await columnExists('tables', 'deleted')) {
            await db.execute(
              'ALTER TABLE tables ADD COLUMN deleted INTEGER DEFAULT 0',
            );
          }
          if (!await columnExists('tables', 'deleted_at')) {
            await db.execute('ALTER TABLE tables ADD COLUMN deleted_at TEXT');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ tables Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v10: Kinder + KI-Scoring
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 10) {
        ErrorLogger.info('🔧 v10: Füge Kinder + Scoring Spalten hinzu...');
        try {
          for (final col in [
            ['children_count', 'INTEGER DEFAULT 0'],
            ['children_names', 'TEXT'],
            ['relationship_type', 'TEXT'],
            ['is_vip', 'INTEGER DEFAULT 0'],
            ['distance_km', 'INTEGER DEFAULT 0'],
            ['priority_score', 'REAL DEFAULT 0.0'],
            ['score_updated_at', 'TEXT'],
          ]) {
            if (!await columnExists('guests', col[0])) {
              await db.execute(
                'ALTER TABLE guests ADD COLUMN ${col[0]} ${col[1]}',
              );
            }
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ guests v10 Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v11: Konflikte + Kennt + Altersgruppe + Hobbys
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 11) {
        ErrorLogger.info('🔧 v11: Füge Tischplanungs-Spalten hinzu...');
        try {
          for (final col in [
            'conflicts_json',
            'knows_json',
            'age_group',
            'hobbies',
          ]) {
            if (!await columnExists('guests', col)) {
              await db.execute('ALTER TABLE guests ADD COLUMN $col TEXT');
            }
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ guests v11 Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v12: tables.categories
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 12) {
        ErrorLogger.info('🔧 v12: Füge categories Spalte zu tables hinzu...');
        try {
          if (!await columnExists('tables', 'categories')) {
            await db.execute('ALTER TABLE tables ADD COLUMN categories TEXT');
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ tables.categories Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v13: wedding_data.total_budget
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 13) {
        ErrorLogger.info('🔧 v13: Füge total_budget zu wedding_data hinzu...');
        try {
          if (!await columnExists('wedding_data', 'total_budget')) {
            await db.execute(
              'ALTER TABLE wedding_data ADD COLUMN total_budget REAL DEFAULT 0.0',
            );
          }
          final existing = await db.query(
            'budget_items',
            where: "category = ? AND deleted = 0",
            whereArgs: ['total_budget'],
            orderBy: 'id DESC',
            limit: 1,
          );
          if (existing.isNotEmpty) {
            final val = existing.first['planned'] ?? 0.0;
            final wd = await db.query('wedding_data');
            if (wd.isNotEmpty) {
              await db.update(
                'wedding_data',
                {'total_budget': val},
                where: 'id = ?',
                whereArgs: [wd.first['id']],
              );
            }
            await db.update(
              'budget_items',
              {'deleted': 1, 'deleted_at': DateTime.now().toIso8601String()},
              where: "category = ?",
              whereArgs: ['total_budget'],
            );
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v13 Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v14: wedding_data.updated_at
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 14) {
        ErrorLogger.info('🔧 v14: Füge updated_at zu wedding_data hinzu...');
        try {
          if (!await columnExists('wedding_data', 'updated_at')) {
            await db.execute(
              'ALTER TABLE wedding_data ADD COLUMN updated_at TEXT',
            );
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v14 Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v15: dienstleister Sync-Spalten
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 15) {
        ErrorLogger.info('🔧 v15: Füge Sync-Spalten zu dienstleister hinzu...');
        try {
          await DienstleisterDatabase.migrateAddSyncColumns(db);
        } catch (e) {
          ErrorLogger.info('  ⚠️ v15 Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // Migration zu v16: app_settings Tabelle
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 16) {
        ErrorLogger.info('🔧 v16: Erstelle app_settings Tabelle...');
        try {
          if (!await tableExists('app_settings')) {
            await db.execute('''
              CREATE TABLE app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT
              )
            ''');
            ErrorLogger.success('  ✅ app_settings Tabelle erstellt');
          }

          // Standardwerte nur eintragen wenn noch nicht vorhanden
          final now = DateTime.now().toIso8601String();
          final existing = await db.query('app_settings');
          final keys = existing.map((r) => r['key'] as String).toSet();

          if (!keys.contains('adult_menu_price')) {
            await db.insert('app_settings', {
              'key': 'adult_menu_price',
              'value': '65',
              'updated_at': now,
            });
            ErrorLogger.success('  ✅ adult_menu_price Default eingetragen');
          }
          if (!keys.contains('child_menu_price')) {
            await db.insert('app_settings', {
              'key': 'child_menu_price',
              'value': '28',
              'updated_at': now,
            });
            ErrorLogger.success('  ✅ child_menu_price Default eingetragen');
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v16 Migration: $e');
        }
      }

      ErrorLogger.success('🎉 DB-Upgrade erfolgreich abgeschlossen');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim DB-Upgrade', e, stack);
      rethrow;
    }
  }

  // ================================================================
  // APP SETTINGS  (neu in v16)
  // ================================================================

  /// Liest einen Setting-Wert anhand des Keys.
  /// Gibt null zurück wenn der Key nicht existiert.
  Future<String?> getSetting(String key) async {
    try {
      final db = await database;
      final result = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (result.isEmpty) return null;
      return result.first['value'] as String?;
    } catch (e) {
      ErrorLogger.info('getSetting Fehler für key "$key": $e');
      return null;
    }
  }

  /// Speichert einen Setting-Wert (INSERT OR REPLACE).
  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert('app_settings', {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      ErrorLogger.success('✅ Setting gespeichert: $key = $value');
    } catch (e, stack) {
      ErrorLogger.error('❌ setSetting Fehler für key "$key"', e, stack);
      rethrow;
    }
  }

  /// Liest alle Settings als Map zurück.
  Future<Map<String, String>> getAllSettings() async {
    try {
      final db = await database;
      final result = await db.query('app_settings');
      return {
        for (final row in result) row['key'] as String: row['value'] as String,
      };
    } catch (e) {
      ErrorLogger.info('getAllSettings Fehler: $e');
      return {};
    }
  }

  // ================================================================
  // GUESTS
  // ================================================================

  Future<Guest> createGuest(Guest guest) async {
    try {
      ErrorLogger.info('Erstelle Gast: ${guest.firstName} ${guest.lastName}');

      final db = await database;
      final guestWithTimestamp = guest.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );

      final guestMap = guestWithTimestamp.toMap();
      final id = await db.insert('guests', guestMap);

      ErrorLogger.success('✅ Gast erstellt mit ID: $id');
      return guestWithTimestamp.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Gastes', e, stack);
      rethrow;
    }
  }

  Future<void> updateGuest(Guest guest) async {
    try {
      ErrorLogger.info('Aktualisiere Gast ID: ${guest.id}');

      final db = await database;
      final guestWithTimestamp = guest.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
      );

      await db.update(
        'guests',
        guestWithTimestamp.toMap(),
        where: 'id = ?',
        whereArgs: [guest.id],
      );

      ErrorLogger.success('✅ Gast aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Aktualisieren des Gastes', e, stack);
      rethrow;
    }
  }

  Future<void> deleteGuest(int id) async {
    try {
      ErrorLogger.info('Lösche Gast ID: $id');

      final db = await database;
      await db.update(
        'guests',
        {
          'deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      ErrorLogger.success('✅ Gast gelöscht (soft delete)');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Gastes', e, stack);
      rethrow;
    }
  }

  Future<List<Guest>> getAllGuests() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'guests',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'last_name ASC, first_name ASC',
      );

      final guests = List.generate(maps.length, (i) => Guest.fromMap(maps[i]));
      ErrorLogger.info('${guests.length} Gäste geladen');
      return guests;
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Gäste', e, stack);
      return [];
    }
  }

  Future<List<Guest>> getAllGuestsIncludingDeleted() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'guests',
      orderBy: 'last_name ASC, first_name ASC',
    );
    return List.generate(maps.length, (i) => Guest.fromMap(maps[i]));
  }

  Future<void> insertGuest(Map<String, dynamic> guestMap) async {
    final db = await database;
    await db.insert('guests', guestMap);
  }

  // ================================================================
  // TASKS
  // ================================================================

  Future<Task> createTask(Task task) async {
    try {
      ErrorLogger.info('Erstelle Task: ${task.title}');

      final db = await database;
      final taskWithTimestamp = task.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );

      final id = await db.insert('tasks', taskWithTimestamp.toMap());

      ErrorLogger.success('✅ Task erstellt mit ID: $id');
      return taskWithTimestamp.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Tasks', e, stack);
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      ErrorLogger.info('Aktualisiere Task ID: ${task.id}');

      final db = await database;
      final taskWithTimestamp = task.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
      );

      await db.update(
        'tasks',
        taskWithTimestamp.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );

      ErrorLogger.success('✅ Task aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Aktualisieren des Tasks', e, stack);
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      ErrorLogger.info('Lösche Task ID: $id');

      final db = await database;
      await db.update(
        'tasks',
        {
          'deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      ErrorLogger.success('✅ Task gelöscht (soft delete)');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Tasks', e, stack);
      rethrow;
    }
  }

  Future<List<Task>> getAllTasks() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tasks',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'deadline ASC',
      );

      final tasks = List.generate(maps.length, (i) => Task.fromMap(maps[i]));
      ErrorLogger.info('${tasks.length} Tasks geladen');
      return tasks;
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Tasks', e, stack);
      return [];
    }
  }

  Future<List<Task>> getAllTasksIncludingDeleted() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      orderBy: 'deadline ASC',
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  Future<void> insertTask(Map<String, dynamic> taskMap) async {
    final db = await database;
    await db.insert('tasks', taskMap);
  }

  // ================================================================
  // BUDGET ITEMS
  // ================================================================

  Future<BudgetItem> createBudgetItem(BudgetItem item) async {
    try {
      ErrorLogger.info('Erstelle Budget-Item: ${item.name}');

      final db = await database;
      final itemWithTimestamp = item.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );

      final id = await db.insert('budget_items', itemWithTimestamp.toMap());

      ErrorLogger.success('✅ Budget-Item erstellt mit ID: $id');
      return itemWithTimestamp.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Budget-Items', e, stack);
      rethrow;
    }
  }

  Future<void> updateBudgetItem(BudgetItem item) async {
    try {
      ErrorLogger.info('Aktualisiere Budget-Item ID: ${item.id}');

      final db = await database;
      final itemWithTimestamp = item.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
      );

      await db.update(
        'budget_items',
        itemWithTimestamp.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );

      ErrorLogger.success('✅ Budget-Item aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error(
        '❌ Fehler beim Aktualisieren des Budget-Items',
        e,
        stack,
      );
      rethrow;
    }
  }

  Future<void> deleteBudgetItem(int id) async {
    try {
      ErrorLogger.info('Lösche Budget-Item ID: $id');

      final db = await database;
      await db.update(
        'budget_items',
        {
          'deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      ErrorLogger.success('✅ Budget-Item gelöscht (soft delete)');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Budget-Items', e, stack);
      rethrow;
    }
  }

  Future<List<BudgetItem>> getAllBudgetItems() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'budget_items',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'name ASC',
      );

      final items = List.generate(
        maps.length,
        (i) => BudgetItem.fromMap(maps[i]),
      );
      ErrorLogger.info('${items.length} Budget-Items geladen');
      return items;
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Budget-Items', e, stack);
      return [];
    }
  }

  Future<List<BudgetItem>> getAllBudgetItemsIncludingDeleted() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget_items',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => BudgetItem.fromMap(maps[i]));
  }

  Future<void> insertBudgetItem(Map<String, dynamic> itemMap) async {
    final db = await database;
    await db.insert('budget_items', itemMap);
  }

  // ================================================================
  // TABLES
  // ================================================================

  Future<TableModel> createTable(TableModel table) async {
    try {
      ErrorLogger.info('Erstelle Tisch: ${table.tableName}');

      final db = await database;
      final tableWithTimestamp = table.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );

      final id = await db.insert('tables', tableWithTimestamp.toMap());

      ErrorLogger.success('✅ Tisch erstellt mit ID: $id');
      return tableWithTimestamp.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Tisches', e, stack);
      rethrow;
    }
  }

  Future<void> updateTable(TableModel table) async {
    try {
      ErrorLogger.info('Aktualisiere Tisch ID: ${table.id}');

      final db = await database;
      final tableWithTimestamp = table.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
      );

      await db.update(
        'tables',
        tableWithTimestamp.toMap(),
        where: 'id = ?',
        whereArgs: [table.id],
      );

      ErrorLogger.success('✅ Tisch aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Aktualisieren des Tisches', e, stack);
      rethrow;
    }
  }

  Future<void> deleteTable(int id) async {
    try {
      ErrorLogger.info('Lösche Tisch ID: $id');

      final db = await database;
      await db.update(
        'tables',
        {
          'deleted': 1,
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      ErrorLogger.success('✅ Tisch gelöscht (soft delete)');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Tisches', e, stack);
      rethrow;
    }
  }

  Future<List<TableModel>> getAllTables() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'tables',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'table_number ASC',
      );

      final tables = List.generate(
        maps.length,
        (i) => TableModel.fromMap(maps[i]),
      );
      ErrorLogger.info('${tables.length} Tische geladen');
      return tables;
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Tische', e, stack);
      return [];
    }
  }

  Future<List<TableModel>> getAllTablesIncludingDeleted() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      orderBy: 'table_number ASC',
    );
    return List.generate(maps.length, (i) => TableModel.fromMap(maps[i]));
  }

  Future<void> insertTable(Map<String, dynamic> tableMap) async {
    final db = await database;
    await db.insert('tables', tableMap);
  }

  // ================================================================
  // WEDDING DATA
  // ================================================================

  Future<Map<String, dynamic>?> getWeddingData() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('wedding_data');
      return maps.isNotEmpty ? maps.first : null;
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Hochzeitsdaten', e, stack);
      return null;
    }
  }

  Future<double> getTotalBudget() async {
    try {
      final data = await getWeddingData();
      return (data?['total_budget'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<void> setTotalBudget(double amount) async {
    try {
      final db = await database;
      final existing = await getWeddingData();
      final now = DateTime.now().toIso8601String();
      if (existing == null) {
        await db.insert('wedding_data', {
          'total_budget': amount,
          'updated_at': now,
        });
      } else {
        await db.update(
          'wedding_data',
          {'total_budget': amount, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
      ErrorLogger.success('✅ Gesamtbudget gespeichert: $amount');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Speichern des Gesamtbudgets', e, stack);
      rethrow;
    }
  }

  Future<void> updateWeddingData(
    DateTime date,
    String brideName,
    String groomName,
  ) async {
    try {
      ErrorLogger.info('Speichere Hochzeitsdaten: $brideName & $groomName');

      final db = await database;
      final existing = await getWeddingData();
      final now = DateTime.now().toIso8601String();

      if (existing == null) {
        final id = await db.insert('wedding_data', {
          'wedding_date': date.toIso8601String(),
          'bride_name': brideName,
          'groom_name': groomName,
          'updated_at': now,
        });
        ErrorLogger.success('✅ Hochzeitsdaten erstellt mit ID: $id');
      } else {
        await db.update(
          'wedding_data',
          {
            'wedding_date': date.toIso8601String(),
            'bride_name': brideName,
            'groom_name': groomName,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
        ErrorLogger.success('✅ Hochzeitsdaten aktualisiert');
      }
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Speichern der Hochzeitsdaten', e, stack);
      rethrow;
    }
  }
}
