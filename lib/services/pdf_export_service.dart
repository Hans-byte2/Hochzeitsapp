import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/wedding_models.dart';
import '../models/dienstleister_models.dart';
import '../models/budget_models.dart'; // ← HINZUFÜGEN
import '../models/table_models.dart'; // ← HINZUFÜGEN

class PdfExportService {
  // Farben für PDF (konvertiert von AppColors)
  static final primaryColor = PdfColor.fromHex('#ff6fb5');
  static final secondaryColor = PdfColor.fromHex('#ffeef6');
  static final textColor = PdfColors.black;
  static final lightGrey = PdfColors.grey300;

  /// 1. Gästeliste als PDF exportieren
  static Future<void> exportGuestListToPdf(List<Guest> guests) async {
    final pdf = pw.Document();

    // Gruppiere Gäste nach Status
    final confirmed = guests.where((g) => g.confirmed == 'yes').length;
    final pending = guests.where((g) => g.confirmed == 'pending').length;
    final declined = guests.where((g) => g.confirmed == 'no').length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Gästeliste',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Hochzeitsplanung',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: primaryColor, thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Statistik-Boxen
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatBox('Gesamt', guests.length.toString(), PdfColors.blue),
              _buildStatBox('Zugesagt', confirmed.toString(), PdfColors.green),
              _buildStatBox('Ausstehend', pending.toString(), PdfColors.orange),
              _buildStatBox('Abgesagt', declined.toString(), PdfColors.red),
            ],
          ),

          pw.SizedBox(height: 30),

          // Gästetabelle
          pw.Text(
            'Alle Gäste',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: lightGrey, width: 1),
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: secondaryColor),
                children: [
                  _buildTableHeader('Name'),
                  _buildTableHeader('E-Mail'),
                  _buildTableHeader('Status'),
                  _buildTableHeader('Tisch'),
                  _buildTableHeader('Besonderheiten'),
                ],
              ),
              // Daten
              ...guests.map(
                (guest) => pw.TableRow(
                  children: [
                    _buildTableCell('${guest.firstName} ${guest.lastName}'),
                    _buildTableCell(guest.email),
                    _buildTableCell(_getStatusText(guest.confirmed)),
                    _buildTableCell(guest.tableNumber?.toString() ?? '-'),
                    _buildTableCell(
                      guest.dietaryRequirements.isEmpty
                          ? '-'
                          : guest.dietaryRequirements,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
      ),
    );

    await _savePdf(pdf, 'Gaesteliste');
  }

  /// 2. Budget-Übersicht als PDF
  static Future<void> exportBudgetToPdf(List<BudgetItem> budgetItems) async {
    final pdf = pw.Document();

    final totalPlanned = budgetItems.fold<double>(
      0.0,
      (sum, item) => sum + item.planned,
    );
    final totalActual = budgetItems.fold<double>(
      0.0,
      (sum, item) => sum + item.actual,
    );
    final difference = totalPlanned - totalActual;

    // Gruppiere nach Kategorie
    final categories = <String, List<BudgetItem>>{};
    for (var item in budgetItems) {
      categories.putIfAbsent(item.category, () => []).add(item);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Budget-Übersicht',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Hochzeitsplanung',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: primaryColor, thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Budget-Zusammenfassung
          pw.Container(
            padding: pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: secondaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                _buildBudgetRow('Geplantes Budget:', totalPlanned),
                pw.SizedBox(height: 8),
                _buildBudgetRow('Tatsächliche Kosten:', totalActual),
                pw.Divider(),
                _buildBudgetRow(
                  difference >= 0 ? 'Verbleibendes Budget:' : 'Überzogen um:',
                  difference.abs(),
                  isTotal: true,
                  color: difference >= 0 ? PdfColors.green : PdfColors.red,
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Kategorien
          ...categories.entries.map(
            (entry) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entry.key,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: lightGrey, width: 1),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: lightGrey),
                      children: [
                        _buildTableHeader('Beschreibung'),
                        _buildTableHeader('Geplant'),
                        _buildTableHeader('Tatsächlich'),
                        _buildTableHeader('Status'),
                      ],
                    ),
                    ...entry.value.map((item) {
                      return pw.TableRow(
                        children: [
                          _buildTableCell(item.name),
                          _buildTableCell(
                            '${item.planned.toStringAsFixed(2)} €',
                          ),
                          _buildTableCell(
                            '${item.actual.toStringAsFixed(2)} €',
                          ),
                          _buildTableCell(item.paid ? 'Bezahlt' : 'Offen'),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
      ),
    );

    await _savePdf(pdf, 'Budget-Uebersicht');
  }

  /// 3. Sitzplan als PDF
  static Future<void> exportTablePlanToPdf(
    List<TableData> tables,
    List<Guest> guests,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Sitzplan',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Tischplanung für die Hochzeit',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: primaryColor, thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Tische als Grid
          pw.Wrap(
            spacing: 20,
            runSpacing: 20,
            children: tables.map((table) {
              final tableGuests = guests
                  .where((g) => g.tableNumber == table.tableNumber)
                  .toList();

              return pw.Container(
                width: 250,
                padding: pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 2),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          table.tableName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        pw.Text(
                          '${tableGuests.length}/${table.seats}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Divider(),
                    if (tableGuests.isEmpty)
                      pw.Text(
                        'Keine Gäste zugewiesen',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey,
                          fontStyle: pw.FontStyle.italic,
                        ),
                      )
                    else
                      ...tableGuests.map(
                        (guest) => pw.Padding(
                          padding: pw.EdgeInsets.only(bottom: 4),
                          child: pw.Text(
                            '• ${guest.firstName} ${guest.lastName}',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
      ),
    );

    await _savePdf(pdf, 'Sitzplan');
  }

  /// 4. Dienstleister-Liste als PDF
  static Future<void> exportServiceProvidersToPdf(
    List<Dienstleister> providers,
  ) async {
    final pdf = pw.Document();

    // Gruppiere nach Kategorie
    final categories = <DienstleisterKategorie, List<Dienstleister>>{};
    for (var provider in providers) {
      categories.putIfAbsent(provider.kategorie, () => []).add(provider);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Dienstleister-Übersicht',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Alle Kontakte für die Hochzeit',
                  style: pw.TextStyle(fontSize: 16, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: primaryColor, thickness: 2),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Kategorien
          ...categories.entries.map(
            (entry) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  entry.key.label,
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                pw.SizedBox(height: 10),

                ...entry.value.map(
                  (provider) => pw.Container(
                    margin: pw.EdgeInsets.only(bottom: 16),
                    padding: pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: lightGrey),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              provider.name,
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            if (provider.angebotsSumme != null)
                              pw.Text(
                                '${provider.angebotsSumme!.betrag.toStringAsFixed(2)} ${provider.angebotsSumme!.waehrung}',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        if (provider.hauptkontakt.name.isNotEmpty)
                          _buildInfoRow('Kontakt:', provider.hauptkontakt.name),
                        if (provider.hauptkontakt.telefon.isNotEmpty)
                          _buildInfoRow(
                            'Telefon:',
                            provider.hauptkontakt.telefon,
                          ),
                        if (provider.hauptkontakt.email.isNotEmpty)
                          _buildInfoRow('E-Mail:', provider.hauptkontakt.email),
                        if (provider.logistik.adresse.isNotEmpty)
                          _buildInfoRow('Adresse:', provider.logistik.adresse),
                        _buildInfoRow('Status:', provider.status.label),
                        if (provider.notizen.isNotEmpty)
                          pw.Padding(
                            padding: pw.EdgeInsets.only(top: 8),
                            child: pw.Text(
                              'Notizen: ${provider.notizen}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: PdfColors.grey700,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
            ),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ),
      ),
    );

    await _savePdf(pdf, 'Dienstleister');
  }

  // Helper Methoden
  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Container(
      padding: pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color.shade(0.1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9)),
    );
  }

  static pw.Widget _buildBudgetRow(
    String label,
    double amount, {
    bool isTotal = false,
    PdfColor? color,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
        pw.Text(
          '${amount.toStringAsFixed(2)} €',
          style: pw.TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10))),
        ],
      ),
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

  static Future<void> _savePdf(pw.Document pdf, String filename) async {
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '$filename-${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }
}
