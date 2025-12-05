import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as pathJoin;
import '../models/wedding_models.dart';
import 'dienstleister_database.dart';

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
      version: 5, // BUMPED: 4 → 5 (Triggers DB rebuild für Tester)
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

    // Guests Table - MIT TIMESTAMPS + SOFT DELETE
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

    // Tasks Table - MIT TIMESTAMPS + SOFT DELETE
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
        updated_at TEXT,
        deleted INTEGER DEFAULT 0,
        deleted_at TEXT
      )
    ''');

    // Budget Table - MIT TIMESTAMPS + SOFT DELETE
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

    // Tables Table - MIT TIMESTAMPS + SOFT DELETE
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

    // Dienstleister tables (external)
    await DienstleisterDatabase.createTables(db);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Für Tester: Einfach alles neu erstellen bei Version-Bump
    if (newVersion > oldVersion) {
      // Drop alte Tabellen
      await db.execute('DROP TABLE IF EXISTS guests');
      await db.execute('DROP TABLE IF EXISTS tasks');
      await db.execute('DROP TABLE IF EXISTS budget_items');
      await db.execute('DROP TABLE IF EXISTS tables');

      // Neu erstellen mit neuen Spalten
      await _createDB(db, newVersion);
    }
  }

  // ================================================================
  // GUESTS - Mit Timestamps + Soft Deletes
  // ================================================================

  Future<Guest> createGuest(Guest guest) async {
    final db = await database;

    // Setze updated_at automatisch
    final guestWithTimestamp = guest.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      deleted: 0,
    );

    final id = await db.insert('guests', guestWithTimestamp.toMap());
    return guestWithTimestamp.copyWith(id: id);
  }

  Future<void> updateGuest(Guest guest) async {
    final db = await database;

    // Aktualisiere updated_at
    final guestWithTimestamp = guest.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
    );

    await db.update(
      'guests',
      guestWithTimestamp.toMap(),
      where: 'id = ?',
      whereArgs: [guest.id],
    );
  }

  Future<void> deleteGuest(int id) async {
    final db = await database;

    // SOFT DELETE: Markiere als gelöscht
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
  }

  Future<List<Guest>> getAllGuests() async {
    final db = await database;

    // Nur aktive Gäste (deleted = 0)
    final List<Map<String, dynamic>> maps = await db.query(
      'guests',
      where: 'deleted = ?',
      whereArgs: [0],
      orderBy: 'last_name ASC, first_name ASC',
    );

    return List.generate(maps.length, (i) => Guest.fromMap(maps[i]));
  }

  // Für Sync: Alle Gäste inkl. gelöschte
  Future<List<Guest>> getAllGuestsIncludingDeleted() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'guests',
      orderBy: 'last_name ASC, first_name ASC',
    );

    return List.generate(maps.length, (i) => Guest.fromMap(maps[i]));
  }

  // RAW für Sync-Service
  Future<void> insertGuest(Map<String, dynamic> guestMap) async {
    final db = await database;
    await db.insert('guests', guestMap);
  }

  // ================================================================
  // TASKS - Mit Timestamps + Soft Deletes
  // ================================================================

  Future<Task> createTask(Task task) async {
    final db = await database;

    final taskWithTimestamp = task.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      deleted: 0,
    );

    final id = await db.insert('tasks', taskWithTimestamp.toMap());
    return taskWithTimestamp.copyWith(id: id);
  }

  Future<void> updateTask(Task task) async {
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
  }

  Future<void> deleteTask(int id) async {
    final db = await database;

    // SOFT DELETE
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
  }

  Future<List<Task>> getAllTasks() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'deleted = ?',
      whereArgs: [0],
      orderBy: 'deadline ASC',
    );

    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
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
  // BUDGET ITEMS - Mit Timestamps + Soft Deletes
  // ================================================================

  Future<BudgetItem> createBudgetItem(BudgetItem item) async {
    final db = await database;

    final itemWithTimestamp = item.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      deleted: 0,
    );

    final id = await db.insert('budget_items', itemWithTimestamp.toMap());
    return itemWithTimestamp.copyWith(id: id);
  }

  Future<void> updateBudgetItem(BudgetItem item) async {
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
  }

  Future<void> deleteBudgetItem(int id) async {
    final db = await database;

    // SOFT DELETE
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
  }

  Future<List<BudgetItem>> getAllBudgetItems() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'budget_items',
      where: 'deleted = ?',
      whereArgs: [0],
      orderBy: 'name ASC',
    );

    return List.generate(maps.length, (i) => BudgetItem.fromMap(maps[i]));
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
  // TABLES - Mit Timestamps + Soft Deletes
  // ================================================================

  Future<TableModel> createTable(TableModel table) async {
    final db = await database;

    final tableWithTimestamp = table.copyWith(
      updatedAt: DateTime.now().toIso8601String(),
      deleted: 0,
    );

    final id = await db.insert('tables', tableWithTimestamp.toMap());
    return tableWithTimestamp.copyWith(id: id);
  }

  Future<void> updateTable(TableModel table) async {
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
  }

  Future<void> deleteTable(int id) async {
    final db = await database;

    // SOFT DELETE
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
  }

  Future<List<TableModel>> getAllTables() async {
    final db = await database;

    final List<Map<String, dynamic>> maps = await db.query(
      'tables',
      where: 'deleted = ?',
      whereArgs: [0],
      orderBy: 'table_number ASC',
    );

    return List.generate(maps.length, (i) => TableModel.fromMap(maps[i]));
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
  // WEDDING DATA (unverändert, braucht keine Timestamps)
  // ================================================================

  Future<Map<String, dynamic>?> getWeddingData() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('wedding_data');
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<void> updateWeddingData(
    DateTime date,
    String brideName,
    String groomName,
  ) async {
    final db = await database;
    final existing = await getWeddingData();

    if (existing == null) {
      await db.insert('wedding_data', {
        'wedding_date': date.toIso8601String(),
        'bride_name': brideName,
        'groom_name': groomName,
      });
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
    }
  }
}
