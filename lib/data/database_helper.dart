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
      version: 4,
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

    // Budget Table
    await db.execute('''
      CREATE TABLE budget_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        planned REAL DEFAULT 0.0,
        actual REAL DEFAULT 0.0,
        category TEXT DEFAULT 'other',
        notes TEXT DEFAULT '',
        paid INTEGER DEFAULT 0
      )
    ''');

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

    // KEINE Beispiel-Budget-Einträge mehr
    // await _insertSampleBudgetItems(db); // ← ENTFERNT

    // Insert default timeline milestones
    await _insertDefaultMilestones(db);

    // Insert default tables
    await _insertDefaultTables(db);
  }

  // Diese Funktion ist jetzt leer und wird nicht mehr aufgerufen
  Future _insertSampleBudgetItems(Database db) async {
    // Keine Beispiel-Einträge mehr - Budget startet leer
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

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
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
  // BUDGET CRUD
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

  Future<void> updateBudgetItem(
    int id,
    String name,
    double planned,
    double actual,
  ) async {
    final db = await instance.database;
    await db.update(
      'budget_items',
      {'name': name, 'planned': planned, 'actual': actual},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteBudgetItem(int id) async {
    final db = await instance.database;
    await db.delete('budget_items', where: 'id = ?', whereArgs: [id]);
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
}
