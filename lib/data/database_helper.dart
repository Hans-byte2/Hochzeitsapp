import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as pathJoin;
import '../models/wedding_models.dart';
import 'dienstleister_database.dart';
import '../models/budget.dart';
import '../models/budget_models.dart';
import 'package:uuid/uuid.dart';

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
    final dbPath = await getDatabasesPath();
    final pathString = pathJoin.join(dbPath, filePath);

    return await openDatabase(
      pathString,
      version: 6, // ✅ Version erhöht
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // Wedding Data Table
    await db.execute('''
      CREATE TABLE wedding_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        wedding_date TEXT,
        bride_name TEXT,
        groom_name TEXT
      )
    ''');

    // Guests Table
    await db.execute('''
      CREATE TABLE guests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        email TEXT,
        confirmed TEXT DEFAULT 'pending',
        dietary_requirements TEXT,
        table_number INTEGER
      )
    ''');

    // Tasks Table
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT DEFAULT 'other',
        priority TEXT DEFAULT 'medium',
        deadline TEXT,
        completed INTEGER DEFAULT 0,
        created_date TEXT NOT NULL
      )
    ''');

    // ✅ Budget Table mit NEUEN Spaltennamen
    await _createBudgetTable(db);

    // Tables Table (für Tischplanung)
    await db.execute('''
      CREATE TABLE tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_name TEXT NOT NULL,
        table_number INTEGER NOT NULL,
        seats INTEGER DEFAULT 8
      )
    ''');

    // Timeline Milestones Table
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

    // Dienstleister Tabellen
    await DienstleisterDatabase.createTables(db);

    // Insert default wedding data
    await db.insert('wedding_data', {
      'id': 1,
      'wedding_date': null,
      'bride_name': '',
      'groom_name': '',
    });

    // Insert default timeline milestones
    await _insertDefaultMilestones(db);

    // Insert default tables
    await _insertDefaultTables(db);
  }

  Future _insertDefaultMilestones(Database db) async {
    final milestones = [
      {
        'title': 'Standesamt, Kirche oder beides?',
        'description': 'Entscheidung über die Art der Trauung treffen',
        'months': 12,
        'order': 1,
      },
      {
        'title': 'Hochzeitsdatum fixieren',
        'description': 'Finales Datum für die Hochzeit festlegen',
        'months': 12,
        'order': 2,
      },
    ];

    for (final milestone in milestones) {
      await db.insert('timeline_milestones', {
        'title': milestone['title'],
        'description': milestone['description'],
        'months_before': milestone['months'],
        'order_index': milestone['order'],
        'is_completed': 0,
        'created_date': DateTime.now().toIso8601String(),
      });
    }
  }

  Future _insertDefaultTables(Database db) async {
    await db.insert('tables', {
      'table_name': 'Brautpaar',
      'table_number': 1,
      'seats': 8,
    });
    await db.insert('tables', {
      'table_name': 'Familie Braut',
      'table_number': 2,
      'seats': 6,
    });
    await db.insert('tables', {
      'table_name': 'Familie Bräutigam',
      'table_number': 3,
      'seats': 6,
    });
    await db.insert('tables', {
      'table_name': 'Freunde',
      'table_number': 4,
      'seats': 10,
    });
  }

  // ✅ KORRIGIERTE UPGRADE METHODE
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrade database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
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
      await _insertDefaultMilestones(db);
    }

    if (oldVersion < 3) {
      await DienstleisterDatabase.createTables(db);
    }

    if (oldVersion < 4) {
      // Add tables table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tables (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          table_name TEXT NOT NULL,
          table_number INTEGER NOT NULL,
          seats INTEGER DEFAULT 8
        )
      ''');
      await _insertDefaultTables(db);

      // Add category, notes, paid to budget_items
      await db
          .execute(
            'ALTER TABLE budget_items ADD COLUMN category TEXT DEFAULT "other"',
          )
          .catchError((e) {});
      await db
          .execute('ALTER TABLE budget_items ADD COLUMN notes TEXT DEFAULT ""')
          .catchError((e) {});
      await db
          .execute('ALTER TABLE budget_items ADD COLUMN paid INTEGER DEFAULT 0')
          .catchError((e) {});
    }

    // ✅ NEU: Budget-Migration zu v6
    if (oldVersion < 6) {
      await _migrateBudgetTableToV6(db);
    }
  }

  // ✅ BUDGET-TABELLE ERSTELLEN (mit neuen Spaltennamen)
  Future<void> _createBudgetTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budget_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        estimated_cost REAL NOT NULL,
        actual_cost REAL NOT NULL DEFAULT 0,
        is_paid INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // ✅ KORRIGIERTE MIGRATION (planned -> estimated_cost, etc.)
  Future<void> _migrateBudgetTableToV6(Database db) async {
    print('🔄 Starte Budget-Tabellen-Migration zu v6...');

    try {
      // Prüfen ob alte Tabelle existiert
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='budget_items'",
      );

      if (tables.isEmpty) {
        print('⚠️ budget_items Tabelle existiert nicht, erstelle neue...');
        await _createBudgetTable(db);
        return;
      }

      // Prüfen ob Migration notwendig ist (alte Spalte vorhanden?)
      final columns = await db.rawQuery('PRAGMA table_info(budget_items)');
      final hasOldColumns = columns.any((col) => col['name'] == 'planned');

      if (!hasOldColumns) {
        print('✅ Tabelle hat bereits neue Spalten, Migration nicht nötig');
        return;
      }

      print('📊 Migriere Daten von alten zu neuen Spalten...');

      // Alte Tabelle umbenennen
      await db.execute('ALTER TABLE budget_items RENAME TO budget_items_old');

      // Neue Tabelle mit korrekten Spalten erstellen
      await _createBudgetTable(db);

      // Daten kopieren und umwandeln
      final oldData = await db.query('budget_items_old');

      for (var row in oldData) {
        await db.insert('budget_items', {
          'id': (row['id'] as String?) ?? Uuid().v4(),
          'name': row['name'] ?? row['category'] ?? 'Unbenannt',
          'category': row['category'] ?? 'Sonstiges',
          'estimated_cost':
              row['planned'] ?? 0.0, // ✅ planned -> estimated_cost
          'actual_cost': row['actual'] ?? 0.0, // ✅ actual -> actual_cost
          'is_paid': row['paid'] ?? 0, // ✅ paid -> is_paid
          'notes': row['notes'] ?? '',
          'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Alte Tabelle löschen
      await db.execute('DROP TABLE budget_items_old');

      print('✅ Migration erfolgreich! ${oldData.length} Einträge migriert');
    } catch (e) {
      print('❌ Fehler bei Migration: $e');
      // Bei Fehler: Rollback versuchen
      try {
        await db.execute('DROP TABLE IF EXISTS budget_items');
        await db.execute('ALTER TABLE budget_items_old RENAME TO budget_items');
        print('↩️ Rollback durchgeführt');
      } catch (rollbackError) {
        print('❌ Rollback fehlgeschlagen: $rollbackError');
      }
      rethrow;
    }
  }

  // ================================
  // WEDDING DATA CRUD
  // ================================

  Future<Map<String, dynamic>?> getWeddingData() async {
    final db = await instance.database;
    final maps = await db.query('wedding_data', limit: 1);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> updateWeddingData(
    DateTime? date,
    String brideName,
    String groomName,
  ) async {
    final db = await instance.database;
    await db.update(
      'wedding_data',
      {
        'wedding_date': date?.toIso8601String(),
        'bride_name': brideName,
        'groom_name': groomName,
      },
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  // ================================
  // GUESTS CRUD
  // ================================

  Future<List<Guest>> getAllGuests() async {
    final db = await instance.database;
    final result = await db.query('guests');
    return result.map((json) => Guest.fromMap(json)).toList();
  }

  Future<Guest> createGuest(Guest guest) async {
    final db = await instance.database;
    final id = await db.insert('guests', guest.toMap());
    return guest.copyWith(id: id);
  }

  Future<void> updateGuest(Guest guest) async {
    final db = await instance.database;
    await db.update(
      'guests',
      guest.toMap(),
      where: 'id = ?',
      whereArgs: [guest.id],
    );
  }

  Future<void> deleteGuest(int id) async {
    final db = await instance.database;
    await db.delete('guests', where: 'id = ?', whereArgs: [id]);
  }

  // ================================
  // TASKS CRUD
  // ================================

  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<Task> createTask(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<void> updateTask(Task task) async {
    final db = await instance.database;
    await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await instance.database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // ================================
  // ALTE BUDGET CRUD (Legacy - für Abwärtskompatibilität)
  // ================================

  Future<List<Map<String, dynamic>>> getAllBudgetItems() async {
    final db = await instance.database;
    return await db.query('budget_items');
  }

  Future<void> createBudgetItem(
    String name,
    double planned,
    double actual,
  ) async {
    final db = await instance.database;
    await db.insert('budget_items', {
      'name': name,
      'planned': planned,
      'actual': actual,
    });
  }

  // ================================
  // TIMELINE MILESTONES CRUD
  // ================================

  Future<List<Map<String, dynamic>>> getAllTimelineMilestones() async {
    final db = await instance.database;
    return await db.query('timeline_milestones', orderBy: 'order_index ASC');
  }

  Future<int> createTimelineMilestone(Map<String, dynamic> milestone) async {
    final db = await instance.database;
    return await db.insert('timeline_milestones', milestone);
  }

  Future<void> updateTimelineMilestone(
    int id,
    Map<String, dynamic> milestone,
  ) async {
    final db = await instance.database;
    await db.update(
      'timeline_milestones',
      milestone,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTimelineMilestone(int id) async {
    final db = await instance.database;
    await db.delete('timeline_milestones', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleMilestoneComplete(int id, bool isCompleted) async {
    final db = await instance.database;
    await db.update(
      'timeline_milestones',
      {'is_completed': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================================
  // TABLES CRUD
  // ================================

  Future<List<Map<String, dynamic>>> getAllTables() async {
    final db = await instance.database;
    return await db.query('tables', orderBy: 'table_number ASC');
  }

  Future<int> createTable(Map<String, dynamic> table) async {
    final db = await instance.database;
    return await db.insert('tables', table);
  }

  Future<void> updateTable(int id, Map<String, dynamic> table) async {
    final db = await instance.database;
    await db.update('tables', table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteTable(int id) async {
    final db = await instance.database;
    await db.delete('tables', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }

  // ========================================
  // BUDGET CRUD OPERATIONEN (für Budget-Klasse)
  // ========================================

  // Budget erstellen
  Future<String> insertBudget(Budget budget) async {
    final db = await database;
    await db.insert('budget', budget.toMap());
    return budget.id;
  }

  // Budget aktualisieren
  Future<int> updateBudget(Budget budget) async {
    final db = await database;
    return await db.update(
      'budget',
      budget.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  // Budget löschen (Soft Delete)
  Future<int> deleteBudget(String id) async {
    final db = await database;
    return await db.update(
      'budget',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Budget endgültig löschen
  Future<int> deleteBudgetPermanently(String id) async {
    final db = await database;
    return await db.delete('budget', where: 'id = ?', whereArgs: [id]);
  }

  // Alle Budgets abrufen (ohne gelöschte)
  Future<List<Budget>> getAllBudgets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget',
      where: 'is_deleted = ?',
      whereArgs: [0],
      orderBy: 'category ASC',
    );
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  // Budget nach ID abrufen
  Future<Budget?> getBudgetById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget',
      where: 'id = ? AND is_deleted = ?',
      whereArgs: [id, 0],
    );
    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  // Budgets nach Kategorie abrufen
  Future<List<Budget>> getBudgetsByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'budget',
      where: 'category = ? AND is_deleted = ?',
      whereArgs: [category, 0],
    );
    return List.generate(maps.length, (i) => Budget.fromMap(maps[i]));
  }

  // Gesamt-Budget berechnen
  Future<Map<String, double>> getTotalBudget() async {
    final db = await database;
    final result = await db.rawQuery('''
    SELECT 
      SUM(planned_amount) as total_planned,
      SUM(actual_amount) as total_actual
    FROM budget
    WHERE is_deleted = 0
  ''');

    return {
      'planned': (result.first['total_planned'] as num?)?.toDouble() ?? 0.0,
      'actual': (result.first['total_actual'] as num?)?.toDouble() ?? 0.0,
    };
  }

  // ================================
  // NEUE BUDGET ITEM CRUD METHODEN
  // ================================

  // CREATE - Budget Item hinzufügen
  Future<int> insertBudgetItem(BudgetItem item) async {
    final db = await database;
    try {
      await db.insert(
        'budget_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return 1;
    } catch (e) {
      print('Fehler beim Einfügen des Budget Items: $e');
      rethrow;
    }
  }

  // READ - Alle Budget Items laden
  Future<List<BudgetItem>> getBudgetItems() async {
    final db = await database;
    try {
      final maps = await db.query(
        'budget_items',
        orderBy: 'category ASC, name ASC',
      );
      return maps.map((map) => BudgetItem.fromMap(map)).toList();
    } catch (e) {
      print('Fehler beim Laden der Budget Items: $e');
      return [];
    }
  }

  // READ - Einzelnes Budget Item
  Future<BudgetItem?> getBudgetItem(String id) async {
    final db = await database;
    try {
      final maps = await db.query(
        'budget_items',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return BudgetItem.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Fehler beim Laden des Budget Items: $e');
      return null;
    }
  }

  // READ - Budget Items nach Kategorie
  Future<List<BudgetItem>> getBudgetItemsByCategory(String category) async {
    final db = await database;
    try {
      final maps = await db.query(
        'budget_items',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'name ASC',
      );
      return maps.map((map) => BudgetItem.fromMap(map)).toList();
    } catch (e) {
      print('Fehler beim Laden der Budget Items nach Kategorie: $e');
      return [];
    }
  }

  // UPDATE - Budget Item aktualisieren
  Future<int> updateBudgetItem(BudgetItem item) async {
    final db = await database;
    try {
      final updatedItem = item.copyWith(updatedAt: DateTime.now());
      return await db.update(
        'budget_items',
        updatedItem.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
    } catch (e) {
      print('Fehler beim Aktualisieren des Budget Items: $e');
      rethrow;
    }
  }

  // DELETE - Budget Item löschen
  Future<int> deleteBudgetItem(String id) async {
    final db = await database;
    try {
      return await db.delete('budget_items', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Fehler beim Löschen des Budget Items: $e');
      rethrow;
    }
  }

  // DELETE - Budget Item permanent löschen
  Future<int> permanentlyDeleteBudgetItem(String id) async {
    final db = await database;
    try {
      return await db.delete('budget_items', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Fehler beim permanenten Löschen des Budget Items: $e');
      rethrow;
    }
  }

  // STATISTICS - Budget Statistiken
  Future<Map<String, double>> getBudgetStatistics() async {
    final items = await getBudgetItems();

    double totalEstimated = 0;
    double totalActual = 0;
    int paidCount = 0;

    for (var item in items) {
      totalEstimated += item.estimatedCost;
      totalActual += item.actualCost;
      if (item.isPaid) paidCount++;
    }

    return {
      'totalEstimated': totalEstimated,
      'totalActual': totalActual,
      'paidCount': paidCount.toDouble(),
      'unpaidCount': (items.length - paidCount).toDouble(),
      'totalItems': items.length.toDouble(),
    };
  }

  // EXPORT/IMPORT - Alle Budget Items für Export
  Future<List<Map<String, dynamic>>> exportBudgetItems() async {
    final items = await getBudgetItems();
    return items.map((item) => item.toJson()).toList();
  }

  // EXPORT/IMPORT - Budget Items importieren
  Future<void> importBudgetItems(List<Map<String, dynamic>> itemsJson) async {
    for (var json in itemsJson) {
      try {
        final item = BudgetItem.fromJson(json);
        await insertBudgetItem(item);
      } catch (e) {
        print('Fehler beim Importieren eines Budget Items: $e');
      }
    }
  }
}
