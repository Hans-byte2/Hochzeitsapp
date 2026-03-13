import '../models/wedding_models.dart';

// ── Richtwerte pro Kategorie (% vom Gesamtbudget) ────────────────────────────
// Quelle: deutsche Hochzeits-Durchschnittswerte
const Map<String, _BenchmarkRange> kCategoryBenchmarks = {
  'location': _BenchmarkRange(0.30, 0.40, 'Location & Catering'),
  'catering': _BenchmarkRange(0.30, 0.40, 'Verpflegung'),
  'clothing': _BenchmarkRange(0.08, 0.12, 'Kleidung & Styling'),
  'decoration': _BenchmarkRange(0.05, 0.08, 'Dekoration & Blumen'),
  'music': _BenchmarkRange(0.04, 0.07, 'Musik & Unterhaltung'),
  'photography': _BenchmarkRange(0.08, 0.12, 'Fotografie & Video'),
  'flowers': _BenchmarkRange(0.03, 0.06, 'Blumen & Floristik'),
  'transport': _BenchmarkRange(0.02, 0.04, 'Transport'),
  'rings': _BenchmarkRange(0.05, 0.10, 'Ringe & Schmuck'),
  'other': _BenchmarkRange(0.03, 0.08, 'Sonstiges'),
};

class _BenchmarkRange {
  final double min;
  final double max;
  final String label;
  const _BenchmarkRange(this.min, this.max, this.label);
}

// ── Ergebnis-Klassen ─────────────────────────────────────────────────────────

class CategoryBenchmarkResult {
  final String categoryKey;
  final String categoryLabel;
  final double actualAmount;
  final double plannedAmount;
  final double benchmarkMin; // absolut in €
  final double benchmarkMax; // absolut in €
  final double benchmarkPct; // tatsächlicher %-Anteil
  final BenchmarkStatus status;
  final double deviation; // € über/unter Richtwert-Mitte

  const CategoryBenchmarkResult({
    required this.categoryKey,
    required this.categoryLabel,
    required this.actualAmount,
    required this.plannedAmount,
    required this.benchmarkMin,
    required this.benchmarkMax,
    required this.benchmarkPct,
    required this.status,
    required this.deviation,
  });
}

enum BenchmarkStatus { ok, warning, over }

class ScenarioResult {
  final int guestsRemoved;
  final double savings;
  final double newTotal;
  final double newPerPerson;

  const ScenarioResult({
    required this.guestsRemoved,
    required this.savings,
    required this.newTotal,
    required this.newPerPerson,
  });
}

class CateringBreakdown {
  final double roomRent; // Raummiete Pauschale
  final double adultCatering; // Erwachsene × Preis
  final double childCatering; // Kinder × Preis
  final double minimumRevenue; // Mindestumsatz (0 wenn nicht relevant)
  final double total;
  final bool minimumRevenueReached;

  const CateringBreakdown({
    required this.roomRent,
    required this.adultCatering,
    required this.childCatering,
    required this.minimumRevenue,
    required this.total,
    required this.minimumRevenueReached,
  });
}

class BudgetAiAnalysis {
  final int score;
  final String statusLabel;
  final String summary;
  final List<String> recommendations;
  final double perPersonCostActual; // Gesamtkosten / Gäste
  final double perPersonCostPlanned;
  final double cateringPerAdult; // nur Erwachsenen-Menüpreis
  final double cateringPerChild; // nur Kinderteller-Preis
  final double totalSavingsPotential;
  final int overBudgetCount;

  // Neu: Richtwert-Analyse
  final List<CategoryBenchmarkResult> benchmarks;

  // Neu: Catering-Aufschlüsselung
  final CateringBreakdown cateringBreakdown;

  // Neu: Szenario-Daten (Basis für den Slider)
  final double
  costPerGuestDependent; // € pro Gast der wegfällt (Catering + Kinder-Anteil)

  const BudgetAiAnalysis({
    required this.score,
    required this.statusLabel,
    required this.summary,
    required this.recommendations,
    required this.perPersonCostActual,
    required this.perPersonCostPlanned,
    required this.cateringPerAdult,
    required this.cateringPerChild,
    required this.totalSavingsPotential,
    required this.overBudgetCount,
    required this.benchmarks,
    required this.cateringBreakdown,
    required this.costPerGuestDependent,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class BudgetAiService {
  static BudgetAiAnalysis analyze({
    required List<BudgetItem> budgetItems,
    required double totalBudget,
    required int guestCount, // Erwachsene
    required int childCount, // Kinder
    required double childMenuPrice,
    required double adultMenuPrice,
    required Map<String, String> categoryLabels,
  }) {
    final totalGuests = guestCount + childCount;
    final totalPlanned = budgetItems.fold(0.0, (s, i) => s + i.planned);
    final totalActual = budgetItems.fold(0.0, (s, i) => s + i.actual);

    // Kategorien-Aggregation
    final Map<String, double> catPlanned = {};
    final Map<String, double> catActual = {};
    for (final item in budgetItems) {
      catPlanned[item.category] =
          (catPlanned[item.category] ?? 0) + item.planned;
      catActual[item.category] = (catActual[item.category] ?? 0) + item.actual;
    }

    final overCategories = catPlanned.keys
        .where(
          (k) =>
              (catActual[k] ?? 0) > (catPlanned[k] ?? 0) &&
              (catPlanned[k] ?? 0) > 0,
        )
        .toList();
    final overCount = budgetItems
        .where((i) => i.actual > i.planned && i.planned > 0)
        .length;

    final perPersonActual = totalGuests > 0 ? totalActual / totalGuests : 0.0;
    final perPersonPlanned = totalGuests > 0 ? totalPlanned / totalGuests : 0.0;

    final budgetUsagePct = totalBudget > 0
        ? (totalActual / totalBudget) * 100
        : 0.0;
    final plannedUsagePct = totalBudget > 0
        ? (totalPlanned / totalBudget) * 100
        : 0.0;

    // ── Richtwert-Benchmarks ─────────────────────────────────────────────────
    final List<CategoryBenchmarkResult> benchmarks = [];
    for (final entry in kCategoryBenchmarks.entries) {
      final key = entry.key;
      final bench = entry.value;
      final actual = catActual[key] ?? 0.0;
      final planned = catPlanned[key] ?? 0.0;
      if (planned == 0 && actual == 0) continue; // Kategorie nicht genutzt

      final benchMinAbs = totalBudget * bench.min;
      final benchMaxAbs = totalBudget * bench.max;
      final benchMidAbs = (benchMinAbs + benchMaxAbs) / 2;
      final actualPct = totalBudget > 0 ? actual / totalBudget : 0.0;
      final deviation = actual - benchMidAbs;

      BenchmarkStatus status;
      if (actual <= benchMaxAbs * 1.05) {
        status = BenchmarkStatus.ok;
      } else if (actual <= benchMaxAbs * 1.20) {
        status = BenchmarkStatus.warning;
      } else {
        status = BenchmarkStatus.over;
      }

      benchmarks.add(
        CategoryBenchmarkResult(
          categoryKey: key,
          categoryLabel: categoryLabels[key] ?? bench.label,
          actualAmount: actual,
          plannedAmount: planned,
          benchmarkMin: benchMinAbs,
          benchmarkMax: benchMaxAbs,
          benchmarkPct: actualPct,
          status: status,
          deviation: deviation,
        ),
      );
    }

    // ── Catering-Aufschlüsselung ─────────────────────────────────────────────
    // Raummiete = location-Kategorie falls vorhanden, sonst 0
    final roomRent = catActual['location'] ?? 0.0;
    final adultCatering = adultMenuPrice * guestCount;
    final childCatering = childMenuPrice * childCount;
    final cateringFood = adultCatering + childCatering;
    // Mindestumsatz: wenn location+catering zusammen gebucht, schätzen wir
    // den Mindestumsatz als 80% von (location planned + catering planned)
    final locationPlanned = catPlanned['location'] ?? 0.0;
    final cateringPlanned = catPlanned['catering'] ?? 0.0;
    final estimatedMinRevenue = (locationPlanned + cateringPlanned) * 0.80;
    final cateringTotal = roomRent + cateringFood;
    final minRevenueReached = cateringTotal >= estimatedMinRevenue;

    final cateringBreakdown = CateringBreakdown(
      roomRent: roomRent,
      adultCatering: adultCatering,
      childCatering: childCatering,
      minimumRevenue: estimatedMinRevenue,
      total: cateringTotal,
      minimumRevenueReached: minRevenueReached,
    );

    // ── Kosten pro wegfallendem Gast (Szenario-Basis) ────────────────────────
    // Gastabhängig: Catering-Menüpreis (Erwachsener). Kinder-Anteil separat.
    final costPerGuestDependent = adultMenuPrice;

    // ── Score ────────────────────────────────────────────────────────────────
    int score = 100;
    if (budgetUsagePct > 100)
      score -= ((budgetUsagePct - 100) * 1.5).round().clamp(0, 40);
    score -= (overCategories.length * 5).clamp(0, 25);
    if (plannedUsagePct > 95 && totalActual < totalPlanned * 0.5) score -= 10;
    // Abzug für Kategorien deutlich über Richtwert
    final overBenchCount = benchmarks
        .where((b) => b.status == BenchmarkStatus.over)
        .length;
    score -= (overBenchCount * 4).clamp(0, 16);
    score = score.clamp(0, 100);

    // ── Status-Label ─────────────────────────────────────────────────────────
    String statusLabel;
    if (budgetUsagePct <= 75)
      statusLabel = '✅ Gut im Budget';
    else if (budgetUsagePct <= 90)
      statusLabel = '🟡 Im Budget';
    else if (budgetUsagePct <= 100)
      statusLabel = '🟠 Knapp';
    else if (budgetUsagePct <= 115)
      statusLabel = '⚠️ Leicht überzogen';
    else
      statusLabel = '🚨 Stark überzogen';

    // ── Summary ──────────────────────────────────────────────────────────────
    final diff = totalActual - totalBudget;
    String summary;
    if (diff <= 0 && overCategories.isEmpty) {
      summary =
          'Euer Budget ist gut unter Kontrolle. '
          'Noch ${(totalBudget - totalActual).toStringAsFixed(0)} € verfügbar. '
          'Alle Kategorien liegen im Rahmen.';
    } else if (diff <= 0 && overCategories.isNotEmpty) {
      final catNames = overCategories
          .map((k) => categoryLabels[k] ?? kCategoryBenchmarks[k]?.label ?? k)
          .join(', ');
      summary =
          'Das Gesamtbudget ist noch im Rahmen, aber '
          '${overCategories.length == 1 ? 'eine Kategorie überschreitet' : '${overCategories.length} Kategorien überschreiten'} '
          'den geplanten Betrag: $catNames.';
    } else {
      final overPct = ((diff / totalBudget) * 100).toStringAsFixed(1);
      final catNames = overCategories
          .take(2)
          .map((k) => categoryLabels[k] ?? kCategoryBenchmarks[k]?.label ?? k)
          .join(' und ');
      summary =
          'Das Budget ist um ${diff.toStringAsFixed(0)} € (${overPct}%) überschritten. '
          '${catNames.isNotEmpty ? 'Haupttreiber: $catNames.' : ''} '
          'Überprüft die größten Posten auf Einsparpotenzial.';
    }

    // ── Empfehlungen ─────────────────────────────────────────────────────────
    final List<String> recommendations = [];
    double savingsPotential = 0;

    for (final cat in overCategories.take(3)) {
      final planned = catPlanned[cat] ?? 0;
      final actual = catActual[cat] ?? 0;
      final overBy = actual - planned;
      final label =
          categoryLabels[cat] ?? kCategoryBenchmarks[cat]?.label ?? cat;
      savingsPotential += overBy * 0.5;

      switch (cat) {
        case 'location':
          recommendations.add(
            '$label: +${overBy.toStringAsFixed(0)} € über Budget. '
            'Nebenkosten (Bestuhlung, Technik, Reinigung) nachverhandeln.',
          );
          break;
        case 'catering':
          recommendations.add(
            '$label: +${overBy.toStringAsFixed(0)} € über Budget. '
            'Menü-Varianten prüfen oder Gänge beim Abendessen reduzieren.',
          );
          break;
        case 'decoration':
        case 'flowers':
          recommendations.add(
            '$label: +${overBy.toStringAsFixed(0)} € über Budget. '
            'DIY-Elemente oder reduzierte Tischgestecke sparen 200–400 €.',
          );
          break;
        case 'photography':
          recommendations.add(
            '$label: +${overBy.toStringAsFixed(0)} € über Budget. '
            'Videografie prüfen oder Stundenzahl reduzieren.',
          );
          break;
        case 'music':
          recommendations.add(
            '$label: +${overBy.toStringAsFixed(0)} € über Budget. '
            'Playlist für Hintergrundmusik spart gegenüber Live-Band.',
          );
          break;
        default:
          recommendations.add(
            '$label: +${overBy.toStringAsFixed(0)} € über Budget. '
            'Einzelne Posten auf Streichmöglichkeiten prüfen.',
          );
      }
    }

    // Richtwert-Überschreitungen ergänzen (wenn nicht schon durch overCategories abgedeckt)
    for (final b
        in benchmarks.where((b) => b.status == BenchmarkStatus.over).take(2)) {
      if (!overCategories.contains(b.categoryKey)) {
        final overBy = b.actualAmount - b.benchmarkMax;
        recommendations.add(
          '${b.categoryLabel} liegt ${overBy.toStringAsFixed(0)} € '
          'über dem typischen Richtwert (${(b.benchmarkPct * 100).toStringAsFixed(0)}% '
          'vs. ${(kCategoryBenchmarks[b.categoryKey]!.max * 100).toStringAsFixed(0)}% '
          'des Budgets).',
        );
        savingsPotential += overBy * 0.4;
      }
    }

    if (childCount > 0 && childMenuPrice > 0) {
      recommendations.add(
        '👶 Kinder-Menüs: $childCount × ${childMenuPrice.toStringAsFixed(0)} € = '
        '${(childCount * childMenuPrice).toStringAsFixed(0)} €. '
        'Kinder unter 4 Jahren oft kostenlos – beim Caterer nachfragen.',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        '✅ Alle Kategorien liegen im Budget und im Richtwert-Bereich. '
        'Halte einen Puffer von 5–10% für Unvorhergesehenes zurück.',
      );
    }

    if (budgetUsagePct > 88 && diff <= 0) {
      recommendations.add(
        '⚠️ Das Budget ist zu ${budgetUsagePct.toStringAsFixed(0)}% verplant. '
        'Plane einen Notfallpuffer von mind. ${(totalBudget * 0.05).toStringAsFixed(0)} € ein.',
      );
      savingsPotential += totalBudget * 0.03;
    }

    return BudgetAiAnalysis(
      score: score,
      statusLabel: statusLabel,
      summary: summary,
      recommendations: recommendations,
      perPersonCostActual: perPersonActual,
      perPersonCostPlanned: perPersonPlanned,
      cateringPerAdult: adultMenuPrice,
      cateringPerChild: childMenuPrice,
      totalSavingsPotential: savingsPotential,
      overBudgetCount: overCount,
      benchmarks: benchmarks,
      cateringBreakdown: cateringBreakdown,
      costPerGuestDependent: costPerGuestDependent,
    );
  }
}
