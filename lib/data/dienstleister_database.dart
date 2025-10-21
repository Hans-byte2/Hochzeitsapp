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

    // Demo-Daten einfügen
    await seedDienstleisterData(db);
  }

  // Demo-Daten
  static Future<void> seedDienstleisterData(Database db) async {
    final demoData = [
      {
        'id': 'dl1',
        'name': 'Seeblick Alm',
        'kategorie': 'location',
        'status': 'angebot',
        'kontakt_name': 'Maria Schmidt',
        'kontakt_email': 'info@seeblick-alm.de',
        'kontakt_telefon': '+49 170 1234567',
        'angebot_betrag': 4800.0,
        'option_bis': DateTime.now().add(Duration(days: 21)).toIso8601String(),
        'logistik_json': jsonEncode({
          'adresse': 'Bergstraße 42, 82467 Garmisch',
          'parken': 'Parkplatz P3',
          'strom': '3x 230V',
          'ankunftsfenster': '14:00-15:00',
          'zugangshinweise': 'Zufahrt über Nebenstraße',
        }),
        'tags_json': '["traumlocation"]',
        'dateien_json': '[]',
        'notizen': 'Traumhafte Bergkulisse, perfekt für Outdoor-Zeremonie',
        'bewertung': 5.0,
        'ist_favorit': 1,
      },
      {
        'id': 'dl2',
        'name': 'DJ Lumi',
        'kategorie': 'musik',
        'status': 'gebucht',
        'kontakt_name': 'Lukas Müller',
        'kontakt_email': 'kontakt@djlumi.de',
        'kontakt_telefon': '+49 171 9876543',
        'website': 'https://djlumi.de',
        'instagram': '@djlumi',
        'angebot_betrag': 1200.0,
        'logistik_json': jsonEncode({}),
        'tags_json': '["lieblingsanbieter"]',
        'dateien_json': '[]',
        'notizen': 'Sehr professionell, tolle Bewertungen, Setlist besprochen',
        'bewertung': 4.8,
        'ist_favorit': 1,
      },
      {
        'id': 'dl3',
        'name': 'Licht & Liebe Fotografie',
        'kategorie': 'fotografie',
        'status': 'shortlist',
        'kontakt_name': 'Anna Weber',
        'kontakt_email': 'hello@lichtundliebe.de',
        'kontakt_telefon': '+49 172 5555555',
        'website': 'https://lichtundliebe.de',
        'angebot_betrag': 1900.0,
        'logistik_json': jsonEncode({}),
        'tags_json': '[]',
        'dateien_json': '[]',
        'notizen': 'Lieferzeit 6 Wochen, Portfolio ist wunderschön',
        'bewertung': 4.5,
        'ist_favorit': 0,
      },
      {
        'id': 'dl4',
        'name': 'Rosarium Floristik',
        'kategorie': 'floristik',
        'status': 'angefragt',
        'kontakt_name': 'Sophie Bauer',
        'kontakt_email': 'info@rosarium-floristik.de',
        'kontakt_telefon': '+49 173 7777777',
        'angebot_betrag': 850.0,
        'ankunft': DateTime.now().add(Duration(days: 60)).toIso8601String(),
        'logistik_json': jsonEncode({
          'ankunftsfenster': '10:00',
          'zugangshinweise': 'Wasserversorgung benötigt',
        }),
        'tags_json': '[]',
        'dateien_json': '[]',
        'notizen': 'Spezialisiert auf Wildblumen und Vintage-Stil',
        'bewertung': 0.0,
        'ist_favorit': 0,
      },
      {
        'id': 'dl5',
        'name': 'SweetPeak Torten',
        'kategorie': 'torte',
        'status': 'gebucht',
        'kontakt_name': 'Julia Klein',
        'kontakt_email': 'orders@sweetpeak.de',
        'kontakt_telefon': '+49 174 8888888',
        'angebot_betrag': 520.0,
        'ankunft': DateTime.now().add(Duration(days: 60)).toIso8601String(),
        'logistik_json': jsonEncode({
          'ankunftsfenster': '17:30',
          'zugangshinweise': 'Kühlung vor Ort benötigt',
        }),
        'tags_json': '[]',
        'dateien_json': '[]',
        'notizen': 'Geschmacksprobe am 15.3., Naked Cake mit Beeren',
        'bewertung': 4.9,
        'ist_favorit': 0,
      },
    ];

    for (var data in demoData) {
      await db.insert('dienstleister', data);
    }

    // Demo-Zahlungen für DJ Lumi
    await db.insert('dienstleister_zahlungen', {
      'id': 'z1',
      'dienstleister_id': 'dl2',
      'bezeichnung': 'Anzahlung 25%',
      'betrag': 300.0,
      'faellig_am': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      'bezahlt': 0,
    });

    await db.insert('dienstleister_zahlungen', {
      'id': 'z2',
      'dienstleister_id': 'dl2',
      'bezeichnung': 'Restbetrag',
      'betrag': 900.0,
      'faellig_am': DateTime.now().add(Duration(days: 45)).toIso8601String(),
      'bezahlt': 0,
    });

    // Demo-Zahlung für Torte
    await db.insert('dienstleister_zahlungen', {
      'id': 'z3',
      'dienstleister_id': 'dl5',
      'bezeichnung': 'Volle Zahlung',
      'betrag': 520.0,
      'faellig_am': DateTime.now().add(Duration(days: 30)).toIso8601String(),
      'bezahlt': 1,
    });
  }

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
