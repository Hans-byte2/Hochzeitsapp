import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/wedding_models.dart';
import '../services/budget_ai_service.dart';

// ============================================================================
// BUDGET REPORT PDF SERVICE
// Erstellt einen vollständigen Budget-Bericht als PDF:
//  1. Gesamtübersicht (Budget, Ausgegeben, Verbleibend)
//  2. Richtwert-Ampeln pro Kategorie
//  3. Alle Budgetposten (tabellarisch)
//  4. Catering-Aufschlüsselung
//  5. Zahlungsplan
// ============================================================================

class BudgetReportPdfService {
  static final _currencyFormat = NumberFormat('#,##0', 'de_DE');
  static final _dateFormat = DateFormat('dd.MM.yyyy');

  static String _fmt(double v) => _currencyFormat.format(v);

  // ── Hauptmethode ──────────────────────────────────────────────────────────
  static Future<void> exportBudgetReport({
    required List<BudgetItem> budgetItems,
    required List<PaymentPlan> paymentPlans,
    required double totalBudget,
    required int guestCount,
    required int childCount,
    required double adultMenuPrice,
    required double childMenuPrice,
    required Map<String, String> categoryLabels,
    String? coupleNames,
    DateTime? weddingDate,
  }) async {
    // Analyse berechnen (offline)
    final analysis = BudgetAiService.analyze(
      budgetItems: budgetItems,
      totalBudget: totalBudget,
      guestCount: guestCount,
      childCount: childCount,
      childMenuPrice: childMenuPrice,
      adultMenuPrice: adultMenuPrice,
      categoryLabels: categoryLabels,
    );

    final pdf = pw.Document();

    // ── Farben ────────────────────────────────────────────────────────────
    const primaryColor = PdfColor.fromInt(0xFF6d3050);
    const accentColor = PdfColor.fromInt(0xFFa05070);
    const lightPink = PdfColor.fromInt(0xFFfaf5f8);
    const borderColor = PdfColor.fromInt(0xFFe0d0d8);
    const successColor = PdfColor.fromInt(0xFF2e7d32);
    const successBg = PdfColor.fromInt(0xFFe8f5e9);
    const warningColor = PdfColor.fromInt(0xFFe65100);
    const warningBg = PdfColor.fromInt(0xFFfff3e0);
    const errorColor = PdfColor.fromInt(0xFFc62828);
    const errorBg = PdfColor.fromInt(0xFFffebee);
    const greyText = PdfColor.fromInt(0xFF757575);
    const darkText = PdfColor.fromInt(0xFF212121);

    final totalActual = budgetItems.fold(0.0, (s, i) => s + i.actual);
    final totalPlanned = budgetItems.fold(0.0, (s, i) => s + i.planned);
    final diff = totalActual - totalBudget;
    final isOverBudget = diff > 0;

    // ── Seite 1: Übersicht + Kategorie-Ampeln ─────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── Titel-Header ─────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Budget-Bericht',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (coupleNames != null)
                      pw.Text(
                        coupleNames,
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 13,
                        ),
                      ),
                    if (weddingDate != null)
                      pw.Text(
                        _dateFormat.format(weddingDate),
                        style: const pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      '${analysis.score}/100',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Budget-Score',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 10,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Erstellt: ${_dateFormat.format(DateTime.now())}',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── 1. Gesamtübersicht ────────────────────────────────────────────
          _sectionTitle('1. Gesamtübersicht', primaryColor),
          pw.SizedBox(height: 8),

          // Ampel-Status
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            decoration: pw.BoxDecoration(
              color: isOverBudget ? errorBg : successBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(
                color: isOverBudget ? errorColor : successColor,
                width: 0.5,
              ),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  analysis.statusLabel,
                  style: pw.TextStyle(
                    color: isOverBudget ? errorColor : successColor,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 10),

          // Zahlen-Grid
          pw.Row(
            children: [
              _summaryBox(
                'Gesamtbudget',
                '€ ${_fmt(totalBudget)}',
                lightPink,
                borderColor,
                darkText,
              ),
              pw.SizedBox(width: 8),
              _summaryBox(
                'Verplant',
                '€ ${_fmt(totalPlanned)}',
                lightPink,
                borderColor,
                darkText,
              ),
              pw.SizedBox(width: 8),
              _summaryBox(
                'Ausgegeben',
                '€ ${_fmt(totalActual)}',
                isOverBudget ? errorBg : lightPink,
                isOverBudget ? errorColor : borderColor,
                isOverBudget ? errorColor : darkText,
              ),
              pw.SizedBox(width: 8),
              _summaryBox(
                isOverBudget ? 'Überzogen' : 'Verfügbar',
                '${isOverBudget ? '+' : ''}€ ${_fmt(diff.abs())}',
                isOverBudget ? errorBg : successBg,
                isOverBudget ? errorColor : successColor,
                isOverBudget ? errorColor : successColor,
              ),
            ],
          ),
          pw.SizedBox(height: 10),

          // Fortschrittsbalken (manuell, da FractionallySizedBox nicht im pdf Package)
          pw.LayoutBuilder(
            builder: (ctx, constraints) {
              final totalWidth = constraints?.maxWidth ?? 500.0;
              final fillPct = totalBudget > 0
                  ? (totalActual / totalBudget).clamp(0.0, 1.0)
                  : 0.0;
              final fillWidth = totalWidth * fillPct;
              return pw.Stack(
                children: [
                  pw.Container(
                    height: 10,
                    width: totalWidth,
                    decoration: pw.BoxDecoration(
                      color: borderColor,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                  ),
                  pw.Container(
                    height: 10,
                    width: fillWidth,
                    decoration: pw.BoxDecoration(
                      color: isOverBudget ? errorColor : accentColor,
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                  ),
                ],
              );
            },
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            '${totalBudget > 0 ? ((totalActual / totalBudget) * 100).toStringAsFixed(1) : 0}% des Budgets verwendet  ·  '
            '${guestCount + childCount} Gäste ($guestCount Erw. + $childCount Kinder)',
            style: const pw.TextStyle(color: greyText, fontSize: 9),
          ),
          pw.SizedBox(height: 10),

          // KI-Zusammenfassung
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: lightPink,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: borderColor, width: 0.5),
            ),
            child: pw.Text(
              analysis.summary,
              style: const pw.TextStyle(fontSize: 10, color: darkText),
            ),
          ),
          pw.SizedBox(height: 20),

          // ── 2. Richtwert-Ampeln ───────────────────────────────────────────
          _sectionTitle('2. Richtwert-Vergleich pro Kategorie', primaryColor),
          pw.SizedBox(height: 8),

          // Tabellen-Header
          _tableHeader([
            'Kategorie',
            'Ausgegeben',
            'Richtwert (min–max)',
            'Abweichung',
            'Status',
          ], primaryColor),

          // Benchmark-Zeilen
          ...analysis.benchmarks.map((b) {
            final statusText = b.status == BenchmarkStatus.ok
                ? 'OK'
                : b.status == BenchmarkStatus.warning
                ? 'Achtung'
                : 'Überzogen';
            final statusColor = b.status == BenchmarkStatus.ok
                ? successColor
                : b.status == BenchmarkStatus.warning
                ? warningColor
                : errorColor;
            final rowBg = b.status == BenchmarkStatus.ok
                ? PdfColors.white
                : b.status == BenchmarkStatus.warning
                ? warningBg
                : errorBg;

            return _tableRow(
              [
                b.categoryLabel,
                '€ ${_fmt(b.actualAmount)}',
                '€ ${_fmt(b.benchmarkMin)} – ${_fmt(b.benchmarkMax)}',
                '${b.deviation > 0 ? '+' : ''}€ ${_fmt(b.deviation.abs())}',
                statusText,
              ],
              bg: rowBg,
              lastColColor: statusColor,
            );
          }),
          pw.SizedBox(height: 20),

          // ── 3. Catering-Aufschlüsselung ───────────────────────────────────
          _sectionTitle('3. Catering-Aufschlüsselung', primaryColor),
          pw.SizedBox(height: 8),

          _tableHeader(['Posten', 'Berechnung', 'Betrag'], primaryColor),
          _tableRow([
            'Raummiete / Location',
            'Pauschale',
            '€ ${_fmt(analysis.cateringBreakdown.roomRent)}',
          ]),
          _tableRow([
            'Erwachsenen-Menü',
            '$guestCount × € ${_fmt(adultMenuPrice)}',
            '€ ${_fmt(analysis.cateringBreakdown.adultCatering)}',
          ]),
          if (childCount > 0)
            _tableRow([
              'Kinderteller',
              '$childCount × € ${_fmt(childMenuPrice)}',
              '€ ${_fmt(analysis.cateringBreakdown.childCatering)}',
            ]),
          _tableRow(
            [
              'Catering gesamt',
              '',
              '€ ${_fmt(analysis.cateringBreakdown.total)}',
            ],
            bold: true,
            bg: lightPink,
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: analysis.cateringBreakdown.minimumRevenueReached
                  ? successBg
                  : warningBg,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              analysis.cateringBreakdown.minimumRevenueReached
                  ? '✓ Mindestumsatz (ca. € ${_fmt(analysis.cateringBreakdown.minimumRevenue)}) ist erreicht.'
                  : '⚠ Mindestumsatz (ca. € ${_fmt(analysis.cateringBreakdown.minimumRevenue)}) noch nicht erreicht – beim Caterer prüfen.',
              style: pw.TextStyle(
                fontSize: 9,
                color: analysis.cateringBreakdown.minimumRevenueReached
                    ? successColor
                    : warningColor,
              ),
            ),
          ),
        ],
      ),
    );

    // ── Seite 2: Budgetposten + Zahlungsplan ──────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // ── 4. Alle Budgetposten ──────────────────────────────────────────
          _sectionTitle('4. Alle Budgetposten', primaryColor),
          pw.SizedBox(height: 8),

          _tableHeader([
            'Bezeichnung',
            'Kategorie',
            'Geplant',
            'Tatsächlich',
            'Status',
          ], primaryColor),

          ...budgetItems.map((item) {
            final isOver = item.actual > item.planned && item.planned > 0;
            final label = categoryLabels[item.category] ?? item.category;
            return _tableRow(
              [
                item.name,
                label,
                '€ ${_fmt(item.planned)}',
                '€ ${_fmt(item.actual)}',
                item.paid ? 'Bezahlt' : (isOver ? 'Überzogen' : 'Offen'),
              ],
              bg: isOver ? errorBg : (item.paid ? successBg : PdfColors.white),
              lastColColor: item.paid
                  ? successColor
                  : isOver
                  ? errorColor
                  : greyText,
            );
          }),

          // Summen-Zeile
          _tableRow(
            [
              'Gesamt',
              '',
              '€ ${_fmt(totalPlanned)}',
              '€ ${_fmt(totalActual)}',
              '',
            ],
            bold: true,
            bg: lightPink,
          ),
          pw.SizedBox(height: 20),

          // ── 5. Zahlungsplan ───────────────────────────────────────────────
          if (paymentPlans.isNotEmpty) ...[
            _sectionTitle('5. Zahlungsplan', primaryColor),
            pw.SizedBox(height: 8),

            // Zahlungsplan-Zusammenfassung
            pw.Row(
              children: [
                _summaryBox(
                  'Gesamt',
                  '€ ${_fmt(paymentPlans.fold(0.0, (s, p) => s + p.amount))}',
                  lightPink,
                  borderColor,
                  darkText,
                ),
                pw.SizedBox(width: 8),
                _summaryBox(
                  'Bezahlt',
                  '€ ${_fmt(paymentPlans.where((p) => p.paid).fold(0.0, (s, p) => s + p.amount))}',
                  successBg,
                  successColor,
                  successColor,
                ),
                pw.SizedBox(width: 8),
                _summaryBox(
                  'Offen',
                  '€ ${_fmt(paymentPlans.where((p) => !p.paid).fold(0.0, (s, p) => s + p.amount))}',
                  warningBg,
                  warningColor,
                  warningColor,
                ),
              ],
            ),
            pw.SizedBox(height: 10),

            _tableHeader([
              'Dienstleister',
              'Typ',
              'Fälligkeit',
              'Betrag',
              'Status',
            ], primaryColor),

            ...paymentPlans.map((plan) {
              final isOverdue = plan.isOverdue;
              return _tableRow(
                [
                  plan.vendorName,
                  plan.paymentTypeLabel,
                  _dateFormat.format(plan.dueDate),
                  '€ ${_fmt(plan.amount)}',
                  plan.paid
                      ? 'Bezahlt'
                      : isOverdue
                      ? 'ÜBERFÄLLIG'
                      : 'Offen',
                ],
                bg: plan.paid
                    ? successBg
                    : isOverdue
                    ? errorBg
                    : PdfColors.white,
                lastColColor: plan.paid
                    ? successColor
                    : isOverdue
                    ? errorColor
                    : greyText,
              );
            }),
          ],

          pw.SizedBox(height: 20),

          // ── Footer mit Fußnote ────────────────────────────────────────────
          pw.Divider(color: borderColor),
          pw.SizedBox(height: 4),
          pw.Text(
            'Erstellt mit HeartPebble · ${_dateFormat.format(DateTime.now())} · '
            'Alle Angaben ohne Gewähr.',
            style: const pw.TextStyle(color: greyText, fontSize: 8),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    // ── PDF ausgeben ──────────────────────────────────────────────────────
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
          'Budget-Bericht_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  // ── Helper: Section Title ─────────────────────────────────────────────────
  static pw.Widget _sectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: color, width: 1.5)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ── Helper: Summary Box ───────────────────────────────────────────────────
  static pw.Widget _summaryBox(
    String label,
    String value,
    PdfColor bg,
    PdfColor border,
    PdfColor textColor,
  ) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: border, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: textColor)),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper: Table Header ──────────────────────────────────────────────────
  static pw.Widget _tableHeader(List<String> cols, PdfColor bg) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg,
        borderRadius: const pw.BorderRadius.vertical(
          top: pw.Radius.circular(4),
        ),
      ),
      child: pw.Row(
        children: cols
            .map(
              (col) => pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: pw.Text(
                    col,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Helper: Table Row ─────────────────────────────────────────────────────
  static pw.Widget _tableRow(
    List<String> cells, {
    PdfColor bg = PdfColors.white,
    bool bold = false,
    PdfColor lastColColor = const PdfColor.fromInt(0xFF212121),
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: bg,
        border: pw.Border(
          bottom: pw.BorderSide(
            color: const PdfColor.fromInt(0xFFe0d0d8),
            width: 0.5,
          ),
        ),
      ),
      child: pw.Row(
        children: cells.asMap().entries.map((entry) {
          final isLast = entry.key == cells.length - 1;
          return pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 5,
              ),
              child: pw.Text(
                entry.value,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: isLast
                      ? lastColColor
                      : const PdfColor.fromInt(0xFF212121),
                ),
                overflow: pw.TextOverflow.clip,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
