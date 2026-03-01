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
        version: 9, // VERSION 9: Kompletter Fix mit allen Spalten
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );

      ErrorLogger.success('Datenbank v9 erfolgreich initialisiert');
      return db;
    } catch (e, stack) {
      ErrorLogger.error('Fehler bei DB-Initialisierung', e, stack);
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    try {
      ErrorLogger.info('Erstelle Datenbank-Tabellen (Version $version)...');

      // Wedding Data
      await db.execute('''
        CREATE TABLE wedding_data (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          wedding_date TEXT,
          bride_name TEXT,
          groom_name TEXT
        )
      ''');
      ErrorLogger.info('✅ wedding_data Tabelle erstellt');

      // Guests - VOLLSTÄNDIG mit allen Spalten
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
          deleted_at TEXT
        )
      ''');
      ErrorLogger.info('✅ guests Tabelle erstellt');

      // Tasks - VOLLSTÄNDIG mit allen Spalten
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

      // Budget Items - VOLLSTÄNDIG mit allen Spalten
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

      // Tables - VOLLSTÄNDIG mit allen Spalten
      await db.execute('''
        CREATE TABLE tables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          table_number INTEGER NOT NULL,
          seats INTEGER DEFAULT 8,
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

      await DienstleisterDatabase.createTables(db);
      ErrorLogger.info('✅ Dienstleister Tabellen erstellt');

      ErrorLogger.success('🎉 Alle Tabellen erfolgreich erstellt!');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen der Tabellen', e, stack);
      rethrow;
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      ErrorLogger.info('🔄 Upgrade DB von v$oldVersion zu v$newVersion');

      // ═══════════════════════════════════════════════════════════
      // Migration zu v9: Füge fehlende Spalten hinzu
      // ═══════════════════════════════════════════════════════════
      if (oldVersion < 9) {
        ErrorLogger.info(
          '🔧 Füge fehlende Spalten zu bestehenden Tabellen hinzu...',
        );

        // Hilfsfunktion zum Prüfen ob Spalte existiert
        Future<bool> columnExists(String table, String column) async {
          final result = await db.rawQuery('PRAGMA table_info($table)');
          return result.any((col) => col['name'] == column);
        }

        // TASKS: Füge fehlende Spalten hinzu
        try {
          if (!await columnExists('tasks', 'location')) {
            await db.execute(
              'ALTER TABLE tasks ADD COLUMN location TEXT DEFAULT ""',
            );
            ErrorLogger.success('  ✅ tasks.location hinzugefügt');
          }
          if (!await columnExists('tasks', 'updated_at')) {
            await db.execute('ALTER TABLE tasks ADD COLUMN updated_at TEXT');
            ErrorLogger.success('  ✅ tasks.updated_at hinzugefügt');
          }
          if (!await columnExists('tasks', 'deleted')) {
            await db.execute(
              'ALTER TABLE tasks ADD COLUMN deleted INTEGER DEFAULT 0',
            );
            ErrorLogger.success('  ✅ tasks.deleted hinzugefügt');
          }
          if (!await columnExists('tasks', 'deleted_at')) {
            await db.execute('ALTER TABLE tasks ADD COLUMN deleted_at TEXT');
            ErrorLogger.success('  ✅ tasks.deleted_at hinzugefügt');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ tasks Migration: $e');
        }

        // GUESTS: Füge fehlende Spalten hinzu
        try {
          if (!await columnExists('guests', 'updated_at')) {
            await db.execute('ALTER TABLE guests ADD COLUMN updated_at TEXT');
            ErrorLogger.success('  ✅ guests.updated_at hinzugefügt');
          }
          if (!await columnExists('guests', 'deleted')) {
            await db.execute(
              'ALTER TABLE guests ADD COLUMN deleted INTEGER DEFAULT 0',
            );
            ErrorLogger.success('  ✅ guests.deleted hinzugefügt');
          }
          if (!await columnExists('guests', 'deleted_at')) {
            await db.execute('ALTER TABLE guests ADD COLUMN deleted_at TEXT');
            ErrorLogger.success('  ✅ guests.deleted_at hinzugefügt');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ guests Migration: $e');
        }

        // BUDGET_ITEMS: Füge fehlende Spalten hinzu
        try {
          if (!await columnExists('budget_items', 'updated_at')) {
            await db.execute(
              'ALTER TABLE budget_items ADD COLUMN updated_at TEXT',
            );
            ErrorLogger.success('  ✅ budget_items.updated_at hinzugefügt');
          }
          if (!await columnExists('budget_items', 'deleted')) {
            await db.execute(
              'ALTER TABLE budget_items ADD COLUMN deleted INTEGER DEFAULT 0',
            );
            ErrorLogger.success('  ✅ budget_items.deleted hinzugefügt');
          }
          if (!await columnExists('budget_items', 'deleted_at')) {
            await db.execute(
              'ALTER TABLE budget_items ADD COLUMN deleted_at TEXT',
            );
            ErrorLogger.success('  ✅ budget_items.deleted_at hinzugefügt');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ budget_items Migration: $e');
        }

        // TABLES: Füge fehlende Spalten hinzu
        try {
          if (!await columnExists('tables', 'updated_at')) {
            await db.execute('ALTER TABLE tables ADD COLUMN updated_at TEXT');
            ErrorLogger.success('  ✅ tables.updated_at hinzugefügt');
          }
          if (!await columnExists('tables', 'deleted')) {
            await db.execute(
              'ALTER TABLE tables ADD COLUMN deleted INTEGER DEFAULT 0',
            );
            ErrorLogger.success('  ✅ tables.deleted hinzugefügt');
          }
          if (!await columnExists('tables', 'deleted_at')) {
            await db.execute('ALTER TABLE tables ADD COLUMN deleted_at TEXT');
            ErrorLogger.success('  ✅ tables.deleted_at hinzugefügt');
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ tables Migration: $e');
        }
      }

      ErrorLogger.success('🎉 DB-Upgrade erfolgreich abgeschlossen');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim DB-Upgrade', e, stack);
      rethrow;
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
      ErrorLogger.info('Gast-Daten: $guestMap');

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

      final taskMap = taskWithTimestamp.toMap();
      ErrorLogger.info('Task-Daten: $taskMap');

      final id = await db.insert('tasks', taskMap);

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

      if (maps.isNotEmpty) {
        ErrorLogger.info('Hochzeitsdaten geladen');
      } else {
        ErrorLogger.info('Keine Hochzeitsdaten vorhanden');
      }

      return maps.isNotEmpty ? maps.first : null;
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Hochzeitsdaten', e, stack);
      return null;
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

      if (existing == null) {
        final id = await db.insert('wedding_data', {
          'wedding_date': date.toIso8601String(),
          'bride_name': brideName,
          'groom_name': groomName,
        });
        ErrorLogger.success('✅ Hochzeitsdaten erstellt mit ID: $id');
      } else {
        await db.update(
          'wedding_data',
          {
            'wedding_date': date.toIso8601String(),
            'bride_name': brideName,
            'groom_name': groomName,
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
