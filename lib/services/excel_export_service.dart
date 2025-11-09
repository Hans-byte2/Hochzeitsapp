import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/wedding_models.dart';
import '../models/dienstleister_models.dart';
import '../models/budget_models.dart';
import '../models/table_models.dart';
import '../data/dienstleister_database.dart';

class ExcelExportService {
  /// 1. Gästeliste als Excel exportieren
  static Future<void> exportGuestListToExcel(List<Guest> guests) async {
    var excel = Excel.createExcel();

    // Lösche das Standard-Sheet
    excel.delete('Sheet1');

    // Erstelle Haupt-Sheet
    var sheet = excel['Gästeliste'];

    // Styling
    var headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#ff6fb5'),
      fontColorHex: ExcelColor.white,
    );

    // Header
    var headers = [
      'Vorname',
      'Nachname',
      'E-Mail',
      'Status',
      'Tischnummer',
      'Besonderheiten',
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Daten
    for (var i = 0; i < guests.length; i++) {
      var guest = guests[i];
      var row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        guest.firstName,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        guest.lastName,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(
        guest.email,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(
        _getStatusText(guest.confirmed),
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(
        guest.tableNumber?.toString() ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = TextCellValue(
        guest.dietaryRequirements,
      );
    }

    // Statistik-Sheet
    var statsSheet = excel['Statistik'];
    statsSheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('B1'),
    );
    var titleCell = statsSheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('Gäste-Statistik');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      backgroundColorHex: ExcelColor.fromHexString('#ffeef6'),
    );

    var confirmed = guests.where((g) => g.confirmed == 'yes').length;
    var pending = guests.where((g) => g.confirmed == 'pending').length;
    var declined = guests.where((g) => g.confirmed == 'no').length;

    _addStatRow(statsSheet, 3, 'Gesamt:', guests.length);
    _addStatRow(statsSheet, 4, 'Zugesagt:', confirmed);
    _addStatRow(statsSheet, 5, 'Ausstehend:', pending);
    _addStatRow(statsSheet, 6, 'Abgesagt:', declined);

    await _saveExcel(excel, 'Gaesteliste');
  }

  /// 2. Budget als Excel exportieren
  static Future<void> exportBudgetToExcel(List<BudgetItem> budgetItems) async {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');

    var sheet = excel['Budget'];

    // Header Styling
    var headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#ff6fb5'),
      fontColorHex: ExcelColor.white,
    );

    // Header
    var headers = [
      'Kategorie',
      'Name',
      'Geplant (€)',
      'Tatsächlich (€)',
      'Differenz (€)',
      'Bezahlt',
      'Notizen',
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Daten
    for (var i = 0; i < budgetItems.length; i++) {
      var item = budgetItems[i];
      var row = i + 1;
      var difference = item.planned - item.actual;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        item.category,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        item.name,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = DoubleCellValue(
        item.planned,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = DoubleCellValue(
        item.actual,
      );

      var diffCell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row),
      );
      diffCell.value = DoubleCellValue(difference);
      diffCell.cellStyle = CellStyle(
        fontColorHex: difference >= 0
            ? ExcelColor.fromHexString('#4CAF50')
            : ExcelColor.fromHexString('#F44336'),
      );

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = TextCellValue(
        item.paid ? 'Ja' : 'Nein',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = TextCellValue(
        item.notes ?? '',
      );
    }

    // Zusammenfassung unten
    var summaryRow = budgetItems.length + 2;
    var totalPlanned = budgetItems.fold<double>(
      0.0,
      (sum, item) => sum + item.planned,
    );
    var totalActual = budgetItems.fold<double>(
      0.0,
      (sum, item) => sum + item.actual,
    );
    var totalDiff = totalPlanned - totalActual;

    var summaryStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#ffeef6'),
    );

    var totalCell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: summaryRow),
    );
    totalCell.value = TextCellValue('GESAMT:');
    totalCell.cellStyle = summaryStyle;

    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: summaryRow))
        .value = DoubleCellValue(
      totalPlanned,
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: summaryRow))
        .value = DoubleCellValue(
      totalActual,
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: summaryRow))
        .value = DoubleCellValue(
      totalDiff,
    );

    // Kategorien-Übersicht Sheet
    var categoriesSheet = excel['Nach Kategorien'];
    var categories = <String, List<BudgetItem>>{};
    for (var item in budgetItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    categoriesSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Kategorie',
    );
    categoriesSheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
      'Geplant (€)',
    );
    categoriesSheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Tatsächlich (€)',
    );
    categoriesSheet.cell(CellIndex.indexByString('D1')).value = TextCellValue(
      'Differenz (€)',
    );

    var catRow = 1;
    categories.forEach((category, items) {
      var catPlanned = items.fold<double>(
        0.0,
        (sum, item) => sum + item.planned,
      );
      var catActual = items.fold<double>(0.0, (sum, item) => sum + item.actual);

      categoriesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: catRow))
          .value = TextCellValue(
        category,
      );
      categoriesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: catRow))
          .value = DoubleCellValue(
        catPlanned,
      );
      categoriesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: catRow))
          .value = DoubleCellValue(
        catActual,
      );
      categoriesSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: catRow))
          .value = DoubleCellValue(
        catPlanned - catActual,
      );

      catRow++;
    });

    await _saveExcel(excel, 'Budget');
  }

  /// 3. Dienstleister als Excel exportieren
  static Future<void> exportServiceProvidersToExcel(
    List<Dienstleister> providers,
  ) async {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');

    var sheet = excel['Dienstleister'];

    // Header
    var headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#ff6fb5'),
      fontColorHex: ExcelColor.white,
    );

    var headers = [
      'Name',
      'Kategorie',
      'Status',
      'Kontaktperson',
      'E-Mail',
      'Telefon',
      'Angebotssumme (€)',
      'Website',
      'Instagram',
      'Option bis',
      'Notizen',
      'Favorit',
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Daten
    for (var i = 0; i < providers.length; i++) {
      var provider = providers[i];
      var row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        provider.name,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        provider.kategorie.label,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(
        provider.status.label,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(
        provider.hauptkontakt.name,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(
        provider.hauptkontakt.email,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = TextCellValue(
        provider.hauptkontakt.telefon,
      );

      if (provider.angebotsSumme != null) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
            .value = DoubleCellValue(
          provider.angebotsSumme!.betrag,
        );
      }

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
          .value = TextCellValue(
        provider.website ?? '',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
          .value = TextCellValue(
        provider.instagram,
      );

      if (provider.optionBis != null) {
        sheet
            .cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
            .value = TextCellValue(
          '${provider.optionBis!.day}.${provider.optionBis!.month}.${provider.optionBis!.year}',
        );
      }

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row))
          .value = TextCellValue(
        provider.notizen,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: row))
          .value = TextCellValue(
        provider.istFavorit ? 'Ja' : 'Nein',
      );
    }

    // Statistik Sheet
    var statsSheet = excel['Übersicht'];
    statsSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Kategorie',
    );
    statsSheet.cell(CellIndex.indexByString('B1')).value = TextCellValue(
      'Anzahl',
    );
    statsSheet.cell(CellIndex.indexByString('C1')).value = TextCellValue(
      'Gesamtpreis (€)',
    );

    var categories = <DienstleisterKategorie, List<Dienstleister>>{};
    for (var provider in providers) {
      categories.putIfAbsent(provider.kategorie, () => []).add(provider);
    }

    var statsRow = 1;
    categories.forEach((category, categoryProviders) {
      var totalPrice = categoryProviders
          .where((p) => p.angebotsSumme != null)
          .fold<double>(0.0, (sum, p) => sum + p.angebotsSumme!.betrag);

      statsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: statsRow))
          .value = TextCellValue(
        category.label,
      );
      statsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: statsRow))
          .value = IntCellValue(
        categoryProviders.length,
      );
      statsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: statsRow))
          .value = DoubleCellValue(
        totalPrice,
      );

      statsRow++;
    });

    await _saveExcel(excel, 'Dienstleister');
  }

  /// NEU: Dienstleister aus Excel importieren
  static Future<Map<String, int>?> importServiceProvidersFromExcel() async {
    try {
      // Datei auswählen
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        dialogTitle: 'Excel-Datei zum Importieren auswählen',
      );

      if (result == null || result.files.single.path == null) {
        return null; // Benutzer hat abgebrochen
      }

      final filePath = result.files.single.path!;
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      int imported = 0;
      int skipped = 0;

      // Erste Tabelle verwenden
      final sheet = excel.tables.keys.first;
      final table = excel.tables[sheet];

      if (table == null) {
        throw Exception('Keine Daten in der Excel-Datei gefunden');
      }

      // Header-Zeile überspringen (Zeile 0)
      for (var rowIndex = 1; rowIndex < table.maxRows; rowIndex++) {
        try {
          final row = table.rows[rowIndex];

          // Name ist Pflichtfeld (Spalte 0)
          final name = _getCellValue(row, 0);
          if (name.isEmpty) {
            skipped++;
            continue;
          }

          // Kategorie parsen (Spalte 1)
          final kategorieStr = _getCellValue(row, 1);
          final kategorie = _parseKategorie(kategorieStr);

          // Status parsen (Spalte 2)
          final statusStr = _getCellValue(row, 2);
          final status = _parseStatus(statusStr);

          // Kontaktdaten (Spalten 3-5)
          final kontaktName = _getCellValue(row, 3);
          final email = _getCellValue(row, 4);
          final telefon = _getCellValue(row, 5);

          // Angebotssumme (Spalte 6)
          final angebotStr = _getCellValue(row, 6);
          final angebotsSumme = angebotStr.isNotEmpty
              ? Geld(
                  betrag:
                      double.tryParse(angebotStr.replaceAll(',', '.')) ?? 0.0,
                )
              : null;

          // Website & Instagram (Spalten 7-8)
          final website = _getCellValue(row, 7);
          final instagram = _getCellValue(row, 8);

          // Option bis Datum (Spalte 9)
          final optionBisStr = _getCellValue(row, 9);
          final optionBis = _parseDate(optionBisStr);

          // Notizen (Spalte 10)
          final notizen = _getCellValue(row, 10);

          // Favorit (Spalte 11)
          final istFavoritStr = _getCellValue(row, 11);
          final istFavorit =
              istFavoritStr.toLowerCase() == 'ja' ||
              istFavoritStr.toLowerCase() == 'true' ||
              istFavoritStr == '1';

          // Dienstleister erstellen
          final dienstleister = Dienstleister(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_$imported',
            name: name,
            kategorie: kategorie,
            status: status,
            website: website.isEmpty ? null : website,
            instagram: instagram,
            hauptkontakt: Kontakt(
              name: kontaktName,
              email: email,
              telefon: telefon,
            ),
            angebotsSumme: angebotsSumme,
            optionBis: optionBis,
            logistik: Logistik(),
            notizen: notizen,
            istFavorit: istFavorit,
          );

          // In Datenbank speichern
          await DienstleisterDatabase.instance.createDienstleister(
            dienstleister,
          );
          imported++;
        } catch (e) {
          print('Fehler beim Importieren von Zeile $rowIndex: $e');
          skipped++;
        }
      }

      return {'imported': imported, 'skipped': skipped};
    } catch (e) {
      throw Exception('Fehler beim Importieren: $e');
    }
  }

  /// 4. Aufgaben als Excel exportieren
  static Future<void> exportTasksToExcel(List<Task> tasks) async {
    var excel = Excel.createExcel();
    excel.delete('Sheet1');

    var sheet = excel['Aufgaben'];

    // Header
    var headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#ff6fb5'),
      fontColorHex: ExcelColor.white,
    );

    var headers = [
      'Titel',
      'Beschreibung',
      'Kategorie',
      'Fälligkeitsdatum',
      'Status',
      'Priorität',
      'Erstellt am',
    ];
    for (var i = 0; i < headers.length; i++) {
      var cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Daten
    for (var i = 0; i < tasks.length; i++) {
      var task = tasks[i];
      var row = i + 1;

      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
          .value = TextCellValue(
        task.title,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
          .value = TextCellValue(
        task.description,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
          .value = TextCellValue(
        task.category,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
          .value = TextCellValue(
        task.deadline?.toString().split(' ')[0] ?? '-',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
          .value = TextCellValue(
        task.completed ? 'Erledigt' : 'Offen',
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
          .value = TextCellValue(
        task.priority,
      );
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
          .value = TextCellValue(
        task.createdDate.toString().split(' ')[0],
      );
    }

    // Statistik
    var statsSheet = excel['Statistik'];
    var completed = tasks.where((t) => t.completed).length;
    var pending = tasks.where((t) => !t.completed).length;

    _addStatRow(statsSheet, 1, 'Gesamt:', tasks.length);
    _addStatRow(statsSheet, 2, 'Erledigt:', completed);
    _addStatRow(statsSheet, 3, 'Offen:', pending);

    await _saveExcel(excel, 'Aufgaben');
  }

  /// 5. Tischplanung als Excel exportieren
  static Future<void> exportSeatingPlanToExcel(
    List<Guest> guests,
    List<TableData> tables,
  ) async {
    final excel = Excel.createExcel();

    // Standardsheet entfernen
    excel.delete('Sheet1');

    // === ÜBERSICHT SHEET ===
    final overviewSheet = excel['Übersicht'];

    // Header
    overviewSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Tischplanung - Übersicht',
    );
    overviewSheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#1976D2'),
    );

    overviewSheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'Statistik',
    );
    overviewSheet.cell(CellIndex.indexByString('A3')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );

    final seatedGuests = guests
        .where(
          (g) =>
              g.tableNumber != null &&
              g.tableNumber != 0 &&
              tables.any((t) => t.tableNumber == g.tableNumber),
        )
        .length;

    overviewSheet.cell(CellIndex.indexByString('A4')).value = TextCellValue(
      'Gesamt Gäste:',
    );
    overviewSheet.cell(CellIndex.indexByString('B4')).value = IntCellValue(
      guests.length,
    );

    overviewSheet.cell(CellIndex.indexByString('A5')).value = TextCellValue(
      'Platzierte Gäste:',
    );
    overviewSheet.cell(CellIndex.indexByString('B5')).value = IntCellValue(
      seatedGuests,
    );

    overviewSheet.cell(CellIndex.indexByString('A6')).value = TextCellValue(
      'Freie Gäste:',
    );
    overviewSheet.cell(CellIndex.indexByString('B6')).value = IntCellValue(
      guests.length - seatedGuests,
    );

    overviewSheet.cell(CellIndex.indexByString('A7')).value = TextCellValue(
      'Anzahl Tische:',
    );
    overviewSheet.cell(CellIndex.indexByString('B7')).value = IntCellValue(
      tables.length,
    );

    // Tisch-Übersicht
    overviewSheet.cell(CellIndex.indexByString('A9')).value = TextCellValue(
      'Tisch-Übersicht',
    );
    overviewSheet.cell(CellIndex.indexByString('A9')).cellStyle = CellStyle(
      bold: true,
      fontSize: 14,
    );

    // Header für Tisch-Tabelle
    overviewSheet.cell(CellIndex.indexByString('A10')).value = TextCellValue(
      'Tischnummer',
    );
    overviewSheet.cell(CellIndex.indexByString('B10')).value = TextCellValue(
      'Tischname',
    );
    overviewSheet.cell(CellIndex.indexByString('C10')).value = TextCellValue(
      'Plätze',
    );
    overviewSheet.cell(CellIndex.indexByString('D10')).value = TextCellValue(
      'Belegt',
    );
    overviewSheet.cell(CellIndex.indexByString('E10')).value = TextCellValue(
      'Frei',
    );

    for (var col in ['A', 'B', 'C', 'D', 'E']) {
      overviewSheet
          .cell(CellIndex.indexByString('${col}10'))
          .cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
      );
    }

    int row = 11;
    for (final table in tables) {
      final tableGuests = guests
          .where((g) => g.tableNumber == table.tableNumber)
          .length;

      overviewSheet.cell(CellIndex.indexByString('A$row')).value = IntCellValue(
        table.tableNumber,
      );
      overviewSheet.cell(CellIndex.indexByString('B$row')).value =
          TextCellValue(table.tableName);
      overviewSheet.cell(CellIndex.indexByString('C$row')).value = IntCellValue(
        table.seats,
      );
      overviewSheet.cell(CellIndex.indexByString('D$row')).value = IntCellValue(
        tableGuests,
      );
      overviewSheet.cell(CellIndex.indexByString('E$row')).value = IntCellValue(
        table.seats - tableGuests,
      );

      row++;
    }

    // === DETAILLIERTE TISCHPLANUNG SHEET ===
    final detailSheet = excel['Tischplanung'];

    detailSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
      'Detaillierte Tischplanung',
    );
    detailSheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#1976D2'),
    );

    // Header
    detailSheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
      'Tischnummer',
    );
    detailSheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(
      'Tischname',
    );
    detailSheet.cell(CellIndex.indexByString('C3')).value = TextCellValue(
      'Vorname',
    );
    detailSheet.cell(CellIndex.indexByString('D3')).value = TextCellValue(
      'Nachname',
    );
    detailSheet.cell(CellIndex.indexByString('E3')).value = TextCellValue(
      'Status',
    );
    detailSheet.cell(CellIndex.indexByString('F3')).value = TextCellValue(
      'E-Mail',
    );
    detailSheet.cell(CellIndex.indexByString('G3')).value = TextCellValue(
      'Diätwünsche',
    );

    for (var col in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
      detailSheet
          .cell(CellIndex.indexByString('${col}3'))
          .cellStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
      );
    }

    row = 4;
    for (final table in tables) {
      final tableGuests = guests
          .where((g) => g.tableNumber == table.tableNumber)
          .toList();

      for (final guest in tableGuests) {
        detailSheet.cell(CellIndex.indexByString('A$row')).value = IntCellValue(
          table.tableNumber,
        );
        detailSheet.cell(CellIndex.indexByString('B$row')).value =
            TextCellValue(table.tableName);
        detailSheet.cell(CellIndex.indexByString('C$row')).value =
            TextCellValue(guest.firstName);
        detailSheet.cell(CellIndex.indexByString('D$row')).value =
            TextCellValue(guest.lastName);
        detailSheet.cell(CellIndex.indexByString('E$row')).value =
            TextCellValue(_getStatusText(guest.confirmed));
        detailSheet.cell(CellIndex.indexByString('F$row')).value =
            TextCellValue(guest.email);
        detailSheet
            .cell(CellIndex.indexByString('G$row'))
            .value = TextCellValue(
          guest.dietaryRequirements.isEmpty ? '-' : guest.dietaryRequirements,
        );

        row++;
      }
    }

    // === FREIE GÄSTE SHEET ===
    final unassignedGuests = guests
        .where(
          (g) =>
              g.tableNumber == null ||
              g.tableNumber == 0 ||
              !tables.any((t) => t.tableNumber == g.tableNumber),
        )
        .toList();

    if (unassignedGuests.isNotEmpty) {
      final freeSheet = excel['Freie Gäste'];

      freeSheet.cell(CellIndex.indexByString('A1')).value = TextCellValue(
        'Noch nicht zugewiesene Gäste',
      );
      freeSheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: ExcelColor.fromHexString('#FF9800'),
      );

      // Header
      freeSheet.cell(CellIndex.indexByString('A3')).value = TextCellValue(
        'Vorname',
      );
      freeSheet.cell(CellIndex.indexByString('B3')).value = TextCellValue(
        'Nachname',
      );
      freeSheet.cell(CellIndex.indexByString('C3')).value = TextCellValue(
        'Status',
      );
      freeSheet.cell(CellIndex.indexByString('D3')).value = TextCellValue(
        'E-Mail',
      );
      freeSheet.cell(CellIndex.indexByString('E3')).value = TextCellValue(
        'Diätwünsche',
      );

      for (var col in ['A', 'B', 'C', 'D', 'E']) {
        freeSheet
            .cell(CellIndex.indexByString('${col}3'))
            .cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.fromHexString('#FFF3E0'),
        );
      }

      row = 4;
      for (final guest in unassignedGuests) {
        freeSheet.cell(CellIndex.indexByString('A$row')).value = TextCellValue(
          guest.firstName,
        );
        freeSheet.cell(CellIndex.indexByString('B$row')).value = TextCellValue(
          guest.lastName,
        );
        freeSheet.cell(CellIndex.indexByString('C$row')).value = TextCellValue(
          _getStatusText(guest.confirmed),
        );
        freeSheet.cell(CellIndex.indexByString('D$row')).value = TextCellValue(
          guest.email,
        );
        freeSheet.cell(CellIndex.indexByString('E$row')).value = TextCellValue(
          guest.dietaryRequirements.isEmpty ? '-' : guest.dietaryRequirements,
        );

        row++;
      }
    }

    // Datei speichern
    await _saveExcel(excel, 'Tischplanung');
  }

  // === HELPER METHODEN ===

  static void _addStatRow(Sheet sheet, int row, String label, int value) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
        .value = TextCellValue(
      label,
    );
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
        .value = IntCellValue(
      value,
    );
  }

  static String _getStatusText(String status) {
    switch (status) {
      case 'yes':
        return 'Zugesagt';
      case 'pending':
        return 'Ausstehend';
      case 'no':
        return 'Abgesagt';
      default:
        return status;
    }
  }

  static String _getCellValue(List<Data?> row, int columnIndex) {
    if (columnIndex >= row.length) return '';
    final cell = row[columnIndex];
    if (cell == null || cell.value == null) return '';
    return cell.value.toString().trim();
  }

  static DienstleisterKategorie _parseKategorie(String value) {
    final lowerValue = value.toLowerCase();

    for (var kategorie in DienstleisterKategorie.values) {
      if (kategorie.label.toLowerCase() == lowerValue) {
        return kategorie;
      }
    }

    // Fallback auf Sonstiges
    return DienstleisterKategorie.sonstiges;
  }

  static DienstleisterStatus _parseStatus(String value) {
    final lowerValue = value.toLowerCase();

    for (var status in DienstleisterStatus.values) {
      if (status.label.toLowerCase() == lowerValue) {
        return status;
      }
    }

    // Fallback auf Recherche
    return DienstleisterStatus.recherche;
  }

  static DateTime? _parseDate(String value) {
    if (value.isEmpty) return null;

    try {
      // Versuche verschiedene Formate zu parsen
      // Format: DD.MM.YYYY
      if (value.contains('.')) {
        final parts = value.split('.');
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            return DateTime(year, month, day);
          }
        }
      }

      // Format: YYYY-MM-DD
      if (value.contains('-')) {
        return DateTime.parse(value);
      }

      return null;
    } catch (e) {
      print('Fehler beim Parsen des Datums "$value": $e');
      return null;
    }
  }

  static Future<void> _saveExcel(Excel excel, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/$filename-${DateTime.now().millisecondsSinceEpoch}.xlsx';

      final file = File(path);
      await file.writeAsBytes(excel.encode()!);

      // Teile die Datei
      await Share.shareXFiles([XFile(path)], text: '$filename Export');
    } catch (e) {
      print('Fehler beim Speichern der Excel-Datei: $e');
      rethrow;
    }
  }
}
