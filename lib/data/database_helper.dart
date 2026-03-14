import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as pathJoin;
import '../models/wedding_models.dart';
import '../models/dienstleister_models.dart';
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
        version:
            19, // VERSION 19: kommunikations_log + angebot_vergleiche + vergleichs_tag
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );

      ErrorLogger.success('Datenbank v19 erfolgreich initialisiert');
      return db;
    } catch (e, stack) {
      ErrorLogger.error('Fehler bei DB-Initialisierung', e, stack);
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    try {
      ErrorLogger.info('Erstelle Datenbank-Tabellen (Version $version)...');

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

      await db.execute('''
        CREATE TABLE app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at TEXT
        )
      ''');

      await DienstleisterDatabase.createTables(db);

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

      await db.execute('''
        CREATE TABLE payment_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          vendor_name TEXT NOT NULL,
          amount REAL NOT NULL DEFAULT 0.0,
          due_date TEXT NOT NULL,
          payment_type TEXT NOT NULL DEFAULT 'pauschale',
          paid INTEGER NOT NULL DEFAULT 0,
          notes TEXT DEFAULT '',
          updated_at TEXT,
          deleted INTEGER DEFAULT 0,
          deleted_at TEXT,
          budget_item_id INTEGER
        )
      ''');

      // ── v19: Kommunikations-Log ──────────────────────────────────────────
      await db.execute('''
        CREATE TABLE kommunikations_log (
          id TEXT PRIMARY KEY,
          dienstleister_id TEXT NOT NULL,
          erstellt_am TEXT NOT NULL,
          typ TEXT NOT NULL DEFAULT 'notiz',
          text TEXT NOT NULL DEFAULT '',
          vorlage_key TEXT
        )
      ''');

      // ── v19: Angebots-Vergleich ──────────────────────────────────────────
      await db.execute('''
        CREATE TABLE angebot_vergleiche (
          id TEXT PRIMARY KEY,
          dienstleister_id TEXT NOT NULL,
          bezeichnung TEXT NOT NULL,
          preis REAL NOT NULL DEFAULT 0.0,
          leistungen TEXT DEFAULT '',
          notizen TEXT DEFAULT '',
          erstellt_am TEXT NOT NULL,
          ist_gewaehlt INTEGER DEFAULT 0
        )
      ''');

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

      if (oldVersion < 9) {
        try {
          for (final col in [
            ['tasks', 'location', 'TEXT DEFAULT ""'],
            ['tasks', 'updated_at', 'TEXT'],
            ['tasks', 'deleted', 'INTEGER DEFAULT 0'],
            ['tasks', 'deleted_at', 'TEXT'],
            ['guests', 'updated_at', 'TEXT'],
            ['guests', 'deleted', 'INTEGER DEFAULT 0'],
            ['guests', 'deleted_at', 'TEXT'],
            ['budget_items', 'updated_at', 'TEXT'],
            ['budget_items', 'deleted', 'INTEGER DEFAULT 0'],
            ['budget_items', 'deleted_at', 'TEXT'],
            ['tables', 'updated_at', 'TEXT'],
            ['tables', 'deleted', 'INTEGER DEFAULT 0'],
            ['tables', 'deleted_at', 'TEXT'],
          ]) {
            if (!await columnExists(col[0], col[1])) {
              await db.execute(
                'ALTER TABLE ${col[0]} ADD COLUMN ${col[1]} ${col[2]}',
              );
            }
          }
        } catch (e) {
          ErrorLogger.info('  ℹ️ v9 Migration: $e');
        }
      }

      if (oldVersion < 10) {
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
          ErrorLogger.info('  ℹ️ v10 Migration: $e');
        }
      }

      if (oldVersion < 11) {
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
          ErrorLogger.info('  ℹ️ v11 Migration: $e');
        }
      }

      if (oldVersion < 12) {
        try {
          if (!await columnExists('tables', 'categories')) {
            await db.execute('ALTER TABLE tables ADD COLUMN categories TEXT');
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v12 Migration: $e');
        }
      }

      if (oldVersion < 13) {
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

      if (oldVersion < 14) {
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

      if (oldVersion < 15) {
        try {
          await DienstleisterDatabase.migrateAddSyncColumns(db);
        } catch (e) {
          ErrorLogger.info('  ⚠️ v15 Migration: $e');
        }
      }

      if (oldVersion < 16) {
        try {
          if (!await tableExists('app_settings')) {
            await db.execute('''
              CREATE TABLE app_settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT
              )
            ''');
          }
          final now = DateTime.now().toIso8601String();
          final existingSettings = await db.query('app_settings');
          final keys = existingSettings.map((r) => r['key'] as String).toSet();
          if (!keys.contains('adult_menu_price')) {
            await db.insert('app_settings', {
              'key': 'adult_menu_price',
              'value': '65',
              'updated_at': now,
            });
          }
          if (!keys.contains('child_menu_price')) {
            await db.insert('app_settings', {
              'key': 'child_menu_price',
              'value': '28',
              'updated_at': now,
            });
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v16 Migration: $e');
        }
      }

      if (oldVersion < 17) {
        try {
          if (!await tableExists('payment_plans')) {
            await db.execute('''
              CREATE TABLE payment_plans (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                vendor_name TEXT NOT NULL,
                amount REAL NOT NULL DEFAULT 0.0,
                due_date TEXT NOT NULL,
                payment_type TEXT NOT NULL DEFAULT 'pauschale',
                paid INTEGER NOT NULL DEFAULT 0,
                notes TEXT DEFAULT '',
                updated_at TEXT,
                deleted INTEGER DEFAULT 0,
                deleted_at TEXT
              )
            ''');
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v17 Migration: $e');
        }
      }

      if (oldVersion < 18) {
        try {
          if (!await columnExists('payment_plans', 'budget_item_id')) {
            await db.execute(
              'ALTER TABLE payment_plans ADD COLUMN budget_item_id INTEGER',
            );
          }
        } catch (e) {
          ErrorLogger.info('  ⚠️ v18 Migration: $e');
        }
      }

      // ═══════════════════════════════════════════════════════════════════════
      // Migration zu v19: Kommunikations-Log + Angebots-Vergleich + VergleichsTag
      // ═══════════════════════════════════════════════════════════════════════
      if (oldVersion < 19) {
        ErrorLogger.info('🔧 v19: Kommunikations-Log + Angebots-Vergleich...');
        try {
          // kommunikations_log Tabelle
          if (!await tableExists('kommunikations_log')) {
            await db.execute('''
              CREATE TABLE kommunikations_log (
                id TEXT PRIMARY KEY,
                dienstleister_id TEXT NOT NULL,
                erstellt_am TEXT NOT NULL,
                typ TEXT NOT NULL DEFAULT 'notiz',
                text TEXT NOT NULL DEFAULT '',
                vorlage_key TEXT
              )
            ''');
            ErrorLogger.success('  ✅ kommunikations_log Tabelle erstellt');
          }

          // angebot_vergleiche Tabelle
          if (!await tableExists('angebot_vergleiche')) {
            await db.execute('''
              CREATE TABLE angebot_vergleiche (
                id TEXT PRIMARY KEY,
                dienstleister_id TEXT NOT NULL,
                bezeichnung TEXT NOT NULL,
                preis REAL NOT NULL DEFAULT 0.0,
                leistungen TEXT DEFAULT '',
                notizen TEXT DEFAULT '',
                erstellt_am TEXT NOT NULL,
                ist_gewaehlt INTEGER DEFAULT 0
              )
            ''');
            ErrorLogger.success('  ✅ angebot_vergleiche Tabelle erstellt');
          }

          // vergleichs_tag Spalte in dienstleister Tabelle
          // (DienstleisterDatabase verwaltet die Tabelle, aber wir fügen hier die Spalte hinzu)
          if (!await columnExists('dienstleister', 'vergleichs_tag')) {
            await db.execute(
              'ALTER TABLE dienstleister ADD COLUMN vergleichs_tag TEXT',
            );
            ErrorLogger.success('  ✅ dienstleister.vergleichs_tag hinzugefügt');
          }

          ErrorLogger.success('  ✅ v19 Migration erfolgreich');
        } catch (e) {
          ErrorLogger.info('  ⚠️ v19 Migration: $e');
        }
      }

      ErrorLogger.success('🎉 DB-Upgrade erfolgreich abgeschlossen');
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim DB-Upgrade', e, stack);
      rethrow;
    }
  }

  // ================================================================
  // APP SETTINGS
  // ================================================================

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

  Future<void> setSetting(String key, String value) async {
    try {
      final db = await database;
      await db.insert('app_settings', {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, stack) {
      ErrorLogger.error('❌ setSetting Fehler für key "$key"', e, stack);
      rethrow;
    }
  }

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
      final db = await database;
      final g = guest.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );
      final id = await db.insert('guests', g.toMap());
      return g.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Gastes', e, stack);
      rethrow;
    }
  }

  Future<void> updateGuest(Guest guest) async {
    try {
      final db = await database;
      final g = guest.copyWith(updatedAt: DateTime.now().toIso8601String());
      await db.update(
        'guests',
        g.toMap(),
        where: 'id = ?',
        whereArgs: [guest.id],
      );
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Aktualisieren des Gastes', e, stack);
      rethrow;
    }
  }

  Future<void> deleteGuest(int id) async {
    try {
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
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Gastes', e, stack);
      rethrow;
    }
  }

  Future<List<Guest>> getAllGuests() async {
    try {
      final db = await database;
      final maps = await db.query(
        'guests',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'last_name ASC, first_name ASC',
      );
      return maps.map(Guest.fromMap).toList();
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Gäste', e, stack);
      return [];
    }
  }

  Future<List<Guest>> getAllGuestsIncludingDeleted() async {
    final db = await database;
    final maps = await db.query(
      'guests',
      orderBy: 'last_name ASC, first_name ASC',
    );
    return maps.map(Guest.fromMap).toList();
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
      final db = await database;
      final t = task.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );
      final id = await db.insert('tasks', t.toMap());
      return t.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Tasks', e, stack);
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      final db = await database;
      final t = task.copyWith(updatedAt: DateTime.now().toIso8601String());
      await db.update(
        'tasks',
        t.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Aktualisieren des Tasks', e, stack);
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
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
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Tasks', e, stack);
      rethrow;
    }
  }

  Future<List<Task>> getAllTasks() async {
    try {
      final db = await database;
      final maps = await db.query(
        'tasks',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'deadline ASC',
      );
      return maps.map(Task.fromMap).toList();
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Tasks', e, stack);
      return [];
    }
  }

  Future<List<Task>> getAllTasksIncludingDeleted() async {
    final db = await database;
    final maps = await db.query('tasks', orderBy: 'deadline ASC');
    return maps.map(Task.fromMap).toList();
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
      final db = await database;
      final i = item.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );
      final id = await db.insert('budget_items', i.toMap());
      return i.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Budget-Items', e, stack);
      rethrow;
    }
  }

  Future<void> updateBudgetItem(BudgetItem item) async {
    try {
      final db = await database;
      final i = item.copyWith(updatedAt: DateTime.now().toIso8601String());
      await db.update(
        'budget_items',
        i.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
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
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Budget-Items', e, stack);
      rethrow;
    }
  }

  Future<List<BudgetItem>> getAllBudgetItems() async {
    try {
      final db = await database;
      final maps = await db.query(
        'budget_items',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'name ASC',
      );
      return maps.map(BudgetItem.fromMap).toList();
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Budget-Items', e, stack);
      return [];
    }
  }

  Future<List<BudgetItem>> getAllBudgetItemsIncludingDeleted() async {
    final db = await database;
    final maps = await db.query('budget_items', orderBy: 'name ASC');
    return maps.map(BudgetItem.fromMap).toList();
  }

  Future<void> insertBudgetItem(Map<String, dynamic> itemMap) async {
    final db = await database;
    await db.insert('budget_items', itemMap);
  }

  // ================================================================
  // BUDGET ITEM ↔ PAYMENT PLAN VERKNÜPFUNG
  // ================================================================

  Future<List<PaymentPlan>> getPaymentPlansForBudgetItem(
    int budgetItemId,
  ) async {
    final db = await database;
    final maps = await db.query(
      'payment_plans',
      where: 'budget_item_id = ? AND deleted = 0',
      whereArgs: [budgetItemId],
      orderBy: 'due_date ASC',
    );
    return maps.map(PaymentPlan.fromMap).toList();
  }

  Future<void> recalculateBudgetActual(int budgetItemId) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(amount), 0.0) as total FROM payment_plans WHERE budget_item_id = ? AND paid = 1 AND deleted = 0',
        [budgetItemId],
      );
      final total = (result.first['total'] as num?)?.toDouble() ?? 0.0;
      await db.update(
        'budget_items',
        {'actual': total, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ? AND deleted = 0',
        whereArgs: [budgetItemId],
      );
    } catch (e, stack) {
      ErrorLogger.error(
        '❌ Fehler bei recalculateBudgetActual($budgetItemId)',
        e,
        stack,
      );
    }
  }

  // ================================================================
  // TABLES
  // ================================================================

  Future<TableModel> createTable(TableModel table) async {
    try {
      final db = await database;
      final t = table.copyWith(
        updatedAt: DateTime.now().toIso8601String(),
        deleted: 0,
      );
      final id = await db.insert('tables', t.toMap());
      return t.copyWith(id: id);
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Erstellen des Tisches', e, stack);
      rethrow;
    }
  }

  Future<void> updateTable(TableModel table) async {
    try {
      final db = await database;
      final t = table.copyWith(updatedAt: DateTime.now().toIso8601String());
      await db.update(
        'tables',
        t.toMap(),
        where: 'id = ?',
        whereArgs: [table.id],
      );
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Aktualisieren des Tisches', e, stack);
      rethrow;
    }
  }

  Future<void> deleteTable(int id) async {
    try {
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
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Löschen des Tisches', e, stack);
      rethrow;
    }
  }

  Future<List<TableModel>> getAllTables() async {
    try {
      final db = await database;
      final maps = await db.query(
        'tables',
        where: 'deleted = ?',
        whereArgs: [0],
        orderBy: 'table_number ASC',
      );
      return maps.map(TableModel.fromMap).toList();
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Laden der Tische', e, stack);
      return [];
    }
  }

  Future<List<TableModel>> getAllTablesIncludingDeleted() async {
    final db = await database;
    final maps = await db.query('tables', orderBy: 'table_number ASC');
    return maps.map(TableModel.fromMap).toList();
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
      final maps = await db.query('wedding_data');
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
      final db = await database;
      final existing = await getWeddingData();
      final now = DateTime.now().toIso8601String();
      if (existing == null) {
        await db.insert('wedding_data', {
          'wedding_date': date.toIso8601String(),
          'bride_name': brideName,
          'groom_name': groomName,
          'updated_at': now,
        });
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
      }
    } catch (e, stack) {
      ErrorLogger.error('❌ Fehler beim Speichern der Hochzeitsdaten', e, stack);
      rethrow;
    }
  }

  // ================================================================
  // PAYMENT PLANS
  // ================================================================

  Future<List<PaymentPlan>> getAllPaymentPlans() async {
    final db = await database;
    final maps = await db.query(
      'payment_plans',
      where: 'deleted = 0',
      orderBy: 'due_date ASC',
    );
    return maps.map(PaymentPlan.fromMap).toList();
  }

  Future<List<PaymentPlan>> getAllPaymentPlansIncludingDeleted() async {
    final db = await database;
    final maps = await db.query('payment_plans', orderBy: 'due_date ASC');
    return maps.map(PaymentPlan.fromMap).toList();
  }

  Future<int> insertPaymentPlan(PaymentPlan plan) async {
    final db = await database;
    final p = plan.copyWith(updatedAt: DateTime.now().toIso8601String());
    return db.insert('payment_plans', p.toMap());
  }

  Future<void> updatePaymentPlan(PaymentPlan plan) async {
    final db = await database;
    final p = plan.copyWith(updatedAt: DateTime.now().toIso8601String());
    await db.update(
      'payment_plans',
      p.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<void> deletePaymentPlan(int id) async {
    final db = await database;
    await db.update(
      'payment_plans',
      {
        'deleted': 1,
        'deleted_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> togglePaymentPlanPaid(int id, bool paid) async {
    final db = await database;
    await db.update(
      'payment_plans',
      {'paid': paid ? 1 : 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    final result = await db.query(
      'payment_plans',
      columns: ['budget_item_id'],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      final budgetItemId = result.first['budget_item_id'] as int?;
      if (budgetItemId != null) await recalculateBudgetActual(budgetItemId);
    }
  }

  Future<void> insertPaymentPlanMap(Map<String, dynamic> planMap) async {
    final db = await database;
    await db.insert('payment_plans', planMap);
  }

  // ================================================================
  // KOMMUNIKATIONS-LOG  (NEU v19)
  // ================================================================

  Future<List<KommunikationsLogEintrag>> getKommunikationsLogFuer(
    String dienstleisterId,
  ) async {
    try {
      final db = await database;
      final maps = await db.query(
        'kommunikations_log',
        where: 'dienstleister_id = ?',
        whereArgs: [dienstleisterId],
        orderBy: 'erstellt_am DESC',
      );
      return maps.map(KommunikationsLogEintrag.fromMap).toList();
    } catch (e) {
      ErrorLogger.info('getKommunikationsLogFuer Fehler: $e');
      return [];
    }
  }

  Future<void> createKommunikationsLogEintrag(
    KommunikationsLogEintrag eintrag,
  ) async {
    final db = await database;
    await db.insert('kommunikations_log', eintrag.toMap());
  }

  Future<void> deleteKommunikationsLogEintrag(String id) async {
    final db = await database;
    await db.delete('kommunikations_log', where: 'id = ?', whereArgs: [id]);
  }

  // ================================================================
  // ANGEBOT VERGLEICH  (NEU v19)
  // ================================================================

  Future<List<AngebotVergleich>> getAngeboteVergleichFuer(
    String dienstleisterId,
  ) async {
    try {
      final db = await database;
      final maps = await db.query(
        'angebot_vergleiche',
        where: 'dienstleister_id = ?',
        whereArgs: [dienstleisterId],
        orderBy: 'ist_gewaehlt DESC, preis ASC',
      );
      return maps.map(AngebotVergleich.fromMap).toList();
    } catch (e) {
      ErrorLogger.info('getAngeboteVergleichFuer Fehler: $e');
      return [];
    }
  }

  Future<void> createAngebotVergleich(AngebotVergleich angebot) async {
    final db = await database;
    await db.insert('angebot_vergleiche', angebot.toMap());
  }

  Future<void> updateAngebotVergleich(AngebotVergleich angebot) async {
    final db = await database;
    await db.update(
      'angebot_vergleiche',
      angebot.toMap(),
      where: 'id = ?',
      whereArgs: [angebot.id],
    );
  }

  Future<void> deleteAngebotVergleich(String id) async {
    final db = await database;
    await db.delete('angebot_vergleiche', where: 'id = ?', whereArgs: [id]);
  }

  /// Setzt ein Angebot als gewählt und alle anderen als nicht-gewählt
  Future<void> waehleAngebot(String dienstleisterId, String angebotId) async {
    final db = await database;
    await db.update(
      'angebot_vergleiche',
      {'ist_gewaehlt': 0},
      where: 'dienstleister_id = ?',
      whereArgs: [dienstleisterId],
    );
    await db.update(
      'angebot_vergleiche',
      {'ist_gewaehlt': 1},
      where: 'id = ?',
      whereArgs: [angebotId],
    );
  }
}
