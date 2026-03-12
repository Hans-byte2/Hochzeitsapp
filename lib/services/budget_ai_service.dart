import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/wedding_models.dart';

class BudgetAiAnalysis {
  final int score;
  final String statusLabel;
  final String summary;
  final List<String> recommendations;
  final double perPersonCostActual;
  final double perPersonCostPlanned;
  final double totalSavingsPotential;
  final int overBudgetCount;

  const BudgetAiAnalysis({
    required this.score,
    required this.statusLabel,
    required this.summary,
    required this.recommendations,
    required this.perPersonCostActual,
    required this.perPersonCostPlanned,
    required this.totalSavingsPotential,
    required this.overBudgetCount,
  });
}

class BudgetAiService {
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';

  /// Analysiert das Budget mit Claude AI.
  /// [budgetItems] – alle Budgetposten
  /// [totalBudget] – das eingestellte Gesamtbudget
  /// [guestCount] – Anzahl erwachsene Gäste
  /// [childCount] – Anzahl Kinder
  /// [childMenuPrice] – Preis Kindersmenü in €
  /// [adultMenuPrice] – Preis Erwachsenenmenü in €
  static Future<BudgetAiAnalysis> analyze({
    required List<BudgetItem> budgetItems,
    required double totalBudget,
    required int guestCount,
    required int childCount,
    required double childMenuPrice,
    required double adultMenuPrice,
    required Map<String, String> categoryLabels,
  }) async {
    final totalPlanned = budgetItems.fold(0.0, (s, i) => s + i.planned);
    final totalActual = budgetItems.fold(0.0, (s, i) => s + i.actual);
    final totalGuests = guestCount + childCount;

    // Kategorien-Zusammenfassung bauen
    final Map<String, Map<String, double>> catStats = {};
    for (final item in budgetItems) {
      catStats.putIfAbsent(item.category, () => {'planned': 0, 'actual': 0});
      catStats[item.category]!['planned'] =
          (catStats[item.category]!['planned'] ?? 0) + item.planned;
      catStats[item.category]!['actual'] =
          (catStats[item.category]!['actual'] ?? 0) + item.actual;
    }

    final categoryLines = catStats.entries
        .map((e) {
          final label = categoryLabels[e.key] ?? e.key;
          final planned = e.value['planned']!.toStringAsFixed(0);
          final actual = e.value['actual']!.toStringAsFixed(0);
          final diff = (e.value['actual']! - e.value['planned']!);
          final diffStr = diff > 0
              ? '+${diff.toStringAsFixed(0)}'
              : diff.toStringAsFixed(0);
          return '- $label: geplant ${planned}€, tatsächlich ${actual}€ ($diffStr€)';
        })
        .join('\n');

    final cateringActual =
        adultMenuPrice * guestCount + childMenuPrice * childCount;
    final perPersonActual = totalGuests > 0 ? totalActual / totalGuests : 0.0;
    final perPersonPlanned = totalGuests > 0 ? totalPlanned / totalGuests : 0.0;
    final overCount = budgetItems
        .where((i) => i.actual > i.planned && i.planned > 0)
        .length;

    final prompt =
        '''
Du bist ein erfahrener Hochzeitsplaner und Budget-Berater. Analysiere folgendes Hochzeitsbudget und gib eine präzise, persönliche Einschätzung auf Deutsch.

BUDGET-ÜBERSICHT:
- Gesamtbudget: ${totalBudget.toStringAsFixed(0)}€
- Geplante Gesamtkosten: ${totalPlanned.toStringAsFixed(0)}€
- Tatsächliche Kosten bisher: ${totalActual.toStringAsFixed(0)}€
- Differenz: ${(totalActual - totalBudget).toStringAsFixed(0)}€

GÄSTE:
- Erwachsene: $guestCount (à ${adultMenuPrice.toStringAsFixed(0)}€/Person)
- Kinder: $childCount (à ${childMenuPrice.toStringAsFixed(0)}€/Kind)
- Catering-Kosten (berechnet): ${cateringActual.toStringAsFixed(0)}€

KATEGORIEN:
$categoryLines

Antworte NUR mit einem JSON-Objekt (kein Markdown, keine Erklärung drumherum):
{
  "score": <0-100, Gesamtbewertung der Budget-Gesundheit>,
  "statusLabel": <kurzes Emoji+Label, z.B. "✅ Im Budget" oder "⚠️ Leicht überzogen" oder "🚨 Stark überzogen">,
  "summary": <2-3 Sätze persönliche Einschätzung, direkt und konkret>,
  "recommendations": [
    "<konkreter Tipp 1 mit Einsparpotenzial in €>",
    "<konkreter Tipp 2>",
    "<konkreter Tipp 3>",
    "<konkreter Tipp 4 falls sinnvoll, sonst weglassen>"
  ],
  "savingsPotential": <realistisches Einsparpotenzial in €, als Zahl>
}
''';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 1000,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text =
            (data['content'] as List).firstWhere(
                  (b) => b['type'] == 'text',
                )['text']
                as String;

        // JSON sauber extrahieren
        final cleanJson = text.replaceAll(RegExp(r'```json|```'), '').trim();
        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;

        return BudgetAiAnalysis(
          score: (parsed['score'] as num).toInt(),
          statusLabel: parsed['statusLabel'] as String,
          summary: parsed['summary'] as String,
          recommendations: List<String>.from(parsed['recommendations'] as List),
          perPersonCostActual: perPersonActual,
          perPersonCostPlanned: perPersonPlanned,
          totalSavingsPotential: (parsed['savingsPotential'] as num).toDouble(),
          overBudgetCount: overCount,
        );
      } else {
        throw Exception('API Fehler: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('BudgetAiService Fehler: $e');
      // Fallback ohne KI
      return _fallbackAnalysis(
        totalBudget: totalBudget,
        totalPlanned: totalPlanned,
        totalActual: totalActual,
        totalGuests: totalGuests,
        overCount: overCount,
        perPersonActual: perPersonActual,
        perPersonPlanned: perPersonPlanned,
      );
    }
  }

  static BudgetAiAnalysis _fallbackAnalysis({
    required double totalBudget,
    required double totalPlanned,
    required double totalActual,
    required int totalGuests,
    required int overCount,
    required double perPersonActual,
    required double perPersonPlanned,
  }) {
    final diff = totalActual - totalBudget;
    final pct = totalBudget > 0 ? (totalActual / totalBudget) * 100 : 0;

    String status;
    int score;
    if (pct <= 85) {
      status = '✅ Gut im Budget';
      score = 90;
    } else if (pct <= 100) {
      status = '🟡 Knapp im Budget';
      score = 72;
    } else if (pct <= 115) {
      status = '⚠️ Leicht überzogen';
      score = 55;
    } else {
      status = '🚨 Stark überzogen';
      score = 30;
    }

    return BudgetAiAnalysis(
      score: score,
      statusLabel: status,
      summary: diff > 0
          ? 'Das Budget ist um ${diff.toStringAsFixed(0)} € überschritten ($overCount Kategorien). Überprüfe die größten Posten auf Einsparpotenzial.'
          : 'Das Budget liegt gut im Rahmen. ${(totalBudget - totalActual).toStringAsFixed(0)} € verbleiben noch.',
      recommendations: [
        'Vergleiche Angebote bei den teuersten Kategorien erneut.',
        'Prüfe ob optionale Extras reduziert werden können.',
        'Spreche mit Dienstleistern über Paketangebote.',
      ],
      perPersonCostActual: perPersonActual,
      perPersonCostPlanned: perPersonPlanned,
      totalSavingsPotential: 0,
      overBudgetCount: overCount,
    );
  }
}
