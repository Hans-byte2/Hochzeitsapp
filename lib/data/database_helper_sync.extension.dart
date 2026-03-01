import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Extension für DatabaseHelper mit Sync-spezifischen Methoden
///
/// Diese Methoden werden vom SyncService benötigt.
/// Füge diesen Code in deine database_helper.dart Datei ein!

extension SyncHelpers on DatabaseHelper {
  // ============================================================================
  // WEDDING INFO
  // ============================================================================

  Future<Map<String, dynamic>?> getWeddingInfo() async {
    final db = await database;
    final results = await db.query('wedding_info', limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateWeddingInfo(Map<String, dynamic> info) async {
    final db = await database;

    final existing = await getWeddingInfo();
    if (existing == null) {
      await db.insert('wedding_info', info);
    } else {
      await db.update(
        'wedding_info',
        info,
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
    }
  }

  // ============================================================================
  // GUESTS - Get by ID & Update
  // ============================================================================

  Future<Map<String, dynamic>?> getGuestById(String id) async {
    final db = await database;
    final results = await db.query(
      'guests',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateGuest(Map<String, dynamic> guest) async {
    final db = await database;
    guest['updated_at'] = DateTime.now().toIso8601String();

    await db.update('guests', guest, where: 'id = ?', whereArgs: [guest['id']]);
  }

  // ============================================================================
  // BUDGET ITEMS - Get by ID & Update
  // ============================================================================

  Future<Map<String, dynamic>?> getBudgetItemById(String id) async {
    final db = await database;
    final results = await db.query(
      'budget',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateBudgetItem(Map<String, dynamic> item) async {
    final db = await database;
    item['updated_at'] = DateTime.now().toIso8601String();

    await db.update('budget', item, where: 'id = ?', whereArgs: [item.id]);
  }

  // ============================================================================
  // TASKS - Get by ID & Update
  // ============================================================================

  Future<Map<String, dynamic>?> getTaskById(String id) async {
    final db = await database;
    final results = await db.query(
      'tasks',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateTask(Map<String, dynamic> task) async {
    final db = await database;
    task['updated_at'] = DateTime.now().toIso8601String();

    await db.update('tasks', task, where: 'id = ?', whereArgs: [task['id']]);
  }

  // ============================================================================
  // TABLES - Get by ID & Update
  // ============================================================================

  Future<Map<String, dynamic>?> getTableById(String id) async {
    final db = await database;
    final results = await db.query(
      'tables',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateTable(Map<String, dynamic> table) async {
    final db = await database;
    table['updated_at'] = DateTime.now().toIso8601String();

    await db.update('tables', table, where: 'id = ?', whereArgs: [table['id']]);
  }

  // ============================================================================
  // SERVICE PROVIDERS - Get by ID & Update
  // ============================================================================

  Future<Map<String, dynamic>?> getServiceProviderById(String id) async {
    final db = await database;
    final results = await db.query(
      'service_providers',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> updateServiceProvider(Map<String, dynamic> provider) async {
    final db = await database;
    provider['updated_at'] = DateTime.now().toIso8601String();

    await db.update(
      'service_providers',
      provider,
      where: 'id = ?',
      whereArgs: [provider['id']],
    );
  }

  // ============================================================================
  // EXISTING METHODS (die du bereits haben solltest)
  // ============================================================================

  // Falls diese Methoden noch NICHT in deiner database_helper.dart existieren,
  // müssen sie noch hinzugefügt werden:

  /*
  Future<List<Map<String, dynamic>>> getAllGuests() async {
    final db = await database;
    return await db.query('guests', where: 'is_deleted = 0');
  }

  Future<List<Map<String, dynamic>>> getAllBudgetItems() async {
    final db = await database;
    return await db.query('budget', where: 'is_deleted = 0');
  }

  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await database;
    return await db.query('tasks', where: 'is_deleted = 0');
  }

  Future<List<Map<String, dynamic>>> getAllTables() async {
    final db = await database;
    return await db.query('tables', where: 'is_deleted = 0');
  }

  Future<List<Map<String, dynamic>>> getAllServiceProviders() async {
    final db = await database;
    return await db.query('service_providers', where: 'is_deleted = 0');
  }

  Future<void> insertGuest(Map<String, dynamic> guest) async {
    final db = await database;
    await db.insert('guests', guest);
  }

  Future<void> insertBudgetItem(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('budget', item);
  }

  Future<void> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    await db.insert('tasks', task);
  }

  Future<void> insertTable(Map<String, dynamic> table) async {
    final db = await database;
    await db.insert('tables', table);
  }

  Future<void> insertServiceProvider(Map<String, dynamic> provider) async {
    final db = await database;
    await db.insert('service_providers', provider);
  }
  */
}
