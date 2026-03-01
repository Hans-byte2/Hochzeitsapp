import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../models/dienstleister_models.dart';
import 'database_helper.dart';

class DienstleisterDatabase {
  // Singleton pattern
  static final DienstleisterDatabase instance = DienstleisterDatabase._init();
  DienstleisterDatabase._init();

  // Tabellen erstellen
  static Future<void> createTables(Database db) async {
    // Dienstleister Tabelle
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
        ist_favorit INTEGER DEFAULT 0
      )
    ''');

    // Zahlungen Tabelle
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

    // Notizen Tabelle
    await db.execute('''
      CREATE TABLE dienstleister_notizen (
        id TEXT PRIMARY KEY,
        dienstleister_id TEXT NOT NULL,
        erstellt_am TEXT NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (dienstleister_id) REFERENCES dienstleister (id) ON DELETE CASCADE
      )
    ''');

    // Aufgaben Tabelle
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

    // KEINE Demo-Daten mehr einfügen - Tabellen bleiben leer
    // await seedDienstleisterData(db);
  }

  // Demo-Daten Funktion auskommentiert oder entfernt
  /*
  static Future<void> seedDienstleisterData(Database db) async {
    // Keine Demo-Daten mehr
  }
  */

  // ==================== CRUD Operationen ====================
  // Nutzt DatabaseHelper.instance aus main.dart

  // Dienstleister
  Future<List<Dienstleister>> getAlleDienstleister() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('dienstleister');
    return result.map((map) => Dienstleister.fromMap(map)).toList();
  }

  Future<Dienstleister?> getDienstleister(String id) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'dienstleister',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? Dienstleister.fromMap(result.first) : null;
  }

  Future<String> createDienstleister(Dienstleister dienstleister) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('dienstleister', dienstleister.toMap());
    return dienstleister.id;
  }

  Future<void> updateDienstleister(Dienstleister dienstleister) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'dienstleister',
      dienstleister.toMap(),
      where: 'id = ?',
      whereArgs: [dienstleister.id],
    );
  }

  Future<void> deleteDienstleister(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('dienstleister', where: 'id = ?', whereArgs: [id]);
  }

  // Zahlungen
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

  // Notizen
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

  // Aufgaben
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
