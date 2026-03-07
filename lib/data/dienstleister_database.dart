// lib/data/dienstleister_database.dart
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/dienstleister_models.dart';
import 'database_helper.dart';

class DienstleisterDatabase {
  static final DienstleisterDatabase instance = DienstleisterDatabase._init();
  DienstleisterDatabase._init();

  // ── Tabellen erstellen ────────────────────────────────────────────────────
  // Wird von DatabaseHelper beim DB-Upgrade aufgerufen.
  // updated_at und is_deleted sind für den Partner-Sync notwendig.

  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE dienstleister (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kategorie TEXT NOT NULL,
        status TEXT NOT NULL,
        website TEXT,
        instagram TEXT,
        kontakt_name TEXT NOT NULL,
        kontakt_email TEXT,
        kontakt_telefon TEXT,
        bewertung REAL DEFAULT 0.0,
        angebot_betrag REAL,
        angebot_waehrung TEXT DEFAULT 'EUR',
        option_bis TEXT,
        briefing_datum TEXT,
        ankunft TEXT,
        logistik_json TEXT,
        tags_json TEXT,
        dateien_json TEXT,
        notizen TEXT,
        ist_favorit INTEGER DEFAULT 0,
        updated_at TEXT,
        is_deleted INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE dienstleister_zahlungen (
        id TEXT PRIMARY KEY,
        dienstleister_id TEXT NOT NULL,
        bezeichnung TEXT NOT NULL,
        betrag REAL NOT NULL,
        waehrung TEXT DEFAULT 'EUR',
        faellig_am TEXT,
        bezahlt INTEGER DEFAULT 0,
        FOREIGN KEY (dienstleister_id) REFERENCES dienstleister (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE dienstleister_notizen (
        id TEXT PRIMARY KEY,
        dienstleister_id TEXT NOT NULL,
        erstellt_am TEXT NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (dienstleister_id) REFERENCES dienstleister (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE dienstleister_aufgaben (
        id TEXT PRIMARY KEY,
        dienstleister_id TEXT NOT NULL,
        titel TEXT NOT NULL,
        faellig_am TEXT,
        erledigt INTEGER DEFAULT 0,
        FOREIGN KEY (dienstleister_id) REFERENCES dienstleister (id) ON DELETE CASCADE
      )
    ''');
  }

  // ── Migration: updated_at + is_deleted nachrüsten ────────────────────────
  // Wird von DatabaseHelper.onUpgrade() aufgerufen wenn die Tabellen
  // bereits existieren aber die neuen Felder fehlen.
  static Future<void> migrateAddSyncColumns(Database db) async {
    // Prüfen ob updated_at bereits existiert
    final tableInfo = await db.rawQuery('PRAGMA table_info(dienstleister)');
    final columns = tableInfo.map((c) => c['name'] as String).toSet();

    if (!columns.contains('updated_at')) {
      await db.execute("ALTER TABLE dienstleister ADD COLUMN updated_at TEXT");
      // Bestehende Einträge mit aktuellem Timestamp befüllen
      final now = DateTime.now().toIso8601String();
      await db.execute(
        "UPDATE dienstleister SET updated_at = ? WHERE updated_at IS NULL",
        [now],
      );
    }

    if (!columns.contains('is_deleted')) {
      await db.execute(
        "ALTER TABLE dienstleister ADD COLUMN is_deleted INTEGER DEFAULT 0",
      );
    }
  }

  // ── Hilfsmethode: updated_at setzen ──────────────────────────────────────
  static String _nowIso() => DateTime.now().toIso8601String();

  // ── CRUD: Dienstleister ───────────────────────────────────────────────────

  Future<List<Dienstleister>> getAlleDienstleister() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'dienstleister',
      where: 'is_deleted = 0 OR is_deleted IS NULL',
    );
    return result.map((map) => Dienstleister.fromMap(map)).toList();
  }

  Future<Dienstleister?> getDienstleister(String id) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'dienstleister',
      where: 'id = ? AND (is_deleted = 0 OR is_deleted IS NULL)',
      whereArgs: [id],
    );
    return result.isNotEmpty ? Dienstleister.fromMap(result.first) : null;
  }

  Future<String> createDienstleister(Dienstleister dienstleister) async {
    final db = await DatabaseHelper.instance.database;
    final map = dienstleister.toMap();
    map['updated_at'] = _nowIso();
    map['is_deleted'] = 0;
    await db.insert('dienstleister', map);
    return dienstleister.id;
  }

  Future<void> updateDienstleister(Dienstleister dienstleister) async {
    final db = await DatabaseHelper.instance.database;
    final map = dienstleister.toMap();
    map['updated_at'] = _nowIso();
    await db.update(
      'dienstleister',
      map,
      where: 'id = ?',
      whereArgs: [dienstleister.id],
    );
  }

  /// Soft-Delete: setzt is_deleted=1 und updated_at, damit der Partner
  /// den Löschvorgang per Sync empfangen kann.
  Future<void> deleteDienstleister(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'dienstleister',
      {'is_deleted': 1, 'updated_at': _nowIso()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── CRUD: Zahlungen ───────────────────────────────────────────────────────

  Future<List<DienstleisterZahlung>> getZahlungenFuer(
    String dienstleisterId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'dienstleister_zahlungen',
      where: 'dienstleister_id = ?',
      whereArgs: [dienstleisterId],
      orderBy: 'faellig_am ASC',
    );
    return result.map((map) => DienstleisterZahlung.fromMap(map)).toList();
  }

  Future<List<DienstleisterZahlung>> getAlleZahlungen() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('dienstleister_zahlungen');
    return result.map((map) => DienstleisterZahlung.fromMap(map)).toList();
  }

  Future<void> createZahlung(DienstleisterZahlung zahlung) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('dienstleister_zahlungen', zahlung.toMap());
  }

  Future<void> updateZahlung(DienstleisterZahlung zahlung) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'dienstleister_zahlungen',
      zahlung.toMap(),
      where: 'id = ?',
      whereArgs: [zahlung.id],
    );
  }

  Future<void> deleteZahlung(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'dienstleister_zahlungen',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── CRUD: Notizen ─────────────────────────────────────────────────────────

  Future<List<DienstleisterNotiz>> getNotizenFuer(
    String dienstleisterId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'dienstleister_notizen',
      where: 'dienstleister_id = ?',
      whereArgs: [dienstleisterId],
      orderBy: 'erstellt_am DESC',
    );
    return result.map((map) => DienstleisterNotiz.fromMap(map)).toList();
  }

  Future<void> createNotiz(DienstleisterNotiz notiz) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('dienstleister_notizen', notiz.toMap());
  }

  Future<void> deleteNotiz(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('dienstleister_notizen', where: 'id = ?', whereArgs: [id]);
  }

  // ── CRUD: Aufgaben ────────────────────────────────────────────────────────

  Future<List<DienstleisterAufgabe>> getAufgabenFuer(
    String dienstleisterId,
  ) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'dienstleister_aufgaben',
      where: 'dienstleister_id = ?',
      whereArgs: [dienstleisterId],
      orderBy: 'faellig_am ASC',
    );
    return result.map((map) => DienstleisterAufgabe.fromMap(map)).toList();
  }

  Future<void> createAufgabe(DienstleisterAufgabe aufgabe) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('dienstleister_aufgaben', aufgabe.toMap());
  }

  Future<void> updateAufgabe(DienstleisterAufgabe aufgabe) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'dienstleister_aufgaben',
      aufgabe.toMap(),
      where: 'id = ?',
      whereArgs: [aufgabe.id],
    );
  }

  Future<void> deleteAufgabe(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('dienstleister_aufgaben', where: 'id = ?', whereArgs: [id]);
  }
}
