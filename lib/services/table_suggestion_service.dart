// lib/services/table_suggestion_service.dart

import '../models/wedding_models.dart';
import '../models/table_categories.dart';
import 'guest_scoring_service.dart';

// ════════════════════════════════════════════════════════════════
// RESULT MODELS
// ════════════════════════════════════════════════════════════════

class TableAssignment {
  final TableModel table;
  final List<Guest> guests;
  final double compatibilityScore;
  final List<ConflictWarning> conflicts;

  TableAssignment({
    required this.table,
    required this.guests,
    required this.compatibilityScore,
    required this.conflicts,
  });

  int get totalPersons => guests.fold(0, (s, g) => s + g.totalPersons);
  bool get isOverCapacity => totalPersons > table.seats;
  bool get hasConflicts => conflicts.isNotEmpty;

  String get scoreLabel {
    if (compatibilityScore >= 30) return 'Sehr gut';
    if (compatibilityScore >= 15) return 'Gut';
    if (compatibilityScore >= 0) return 'Ok';
    return 'Konflikt!';
  }

  List<TableCategory> get categories =>
      TableCategories.parse(table.categoriesRaw);
}

class ConflictWarning {
  final Guest guestA;
  final Guest guestB;
  final String message;

  ConflictWarning({
    required this.guestA,
    required this.guestB,
    required this.message,
  });
}

class CategoryMismatch {
  final Guest guest;
  final String guestRelationship;
  final String tableName;
  final String message;

  CategoryMismatch({
    required this.guest,
    required this.guestRelationship,
    required this.tableName,
    required this.message,
  });
}

class TableSuggestionResult {
  final List<TableAssignment> assignments;
  final List<Guest> unassignedGuests;
  final List<ConflictWarning> globalConflicts;
  final List<CategoryMismatch> categoryMismatches;
  final int totalConflicts;
  final double overallScore;

  TableSuggestionResult({
    required this.assignments,
    required this.unassignedGuests,
    required this.globalConflicts,
    required this.categoryMismatches,
    required this.totalConflicts,
    required this.overallScore,
  });

  bool get hasUnassigned => unassignedGuests.isNotEmpty;
  bool get hasConflicts => totalConflicts > 0;
  bool get hasCategoryMismatches => categoryMismatches.isNotEmpty;
}

// ════════════════════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════════════════════

class TableSuggestionService {
  // ── Hilfsmethoden ────────────────────────────────────────────

  static bool _hasConflict(Guest a, Guest b) {
    if (a.id == null || b.id == null) return false;
    return a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!);
  }

  static bool _conflictsWithAnySeated(Guest guest, List<Guest> seated) {
    for (final s in seated) {
      if (_hasConflict(guest, s)) return true;
    }
    return false;
  }

  /// Prüft hartes Kategorie-Constraint:
  /// Gibt false zurück wenn ein Gast aufgrund seiner Beziehung
  /// an diesem Tisch NICHT erlaubt ist.
  static bool _passesHardCategoryCheck(Guest guest, TableModel table) {
    final cats = TableCategories.parse(table.categoriesRaw);
    final result = TableCategories.hardCheck(
      guestRelationship: guest.relationshipType,
      tableCategories: cats,
    );
    // null = kein Constraint → erlaubt
    // true = Constraint geprüft → erlaubt
    // false = hartes Constraint verletzt → NICHT erlaubt
    return result != false;
  }

  // ── Hauptmethode ─────────────────────────────────────────────

  static TableSuggestionResult suggest({
    required List<Guest> allGuests,
    required List<TableModel> tables,
  }) {
    if (tables.isEmpty) {
      return TableSuggestionResult(
        assignments: [],
        unassignedGuests: allGuests.where((g) => g.confirmed == 'yes').toList(),
        globalConflicts: [],
        categoryMismatches: [],
        totalConflicts: 0,
        overallScore: 0,
      );
    }

    final guests = allGuests.where((g) => g.confirmed == 'yes').toList();
    // VIPs und Familie zuerst
    guests.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    final Map<int, List<Guest>> tableMap = {for (final t in tables) t.id!: []};
    final List<Guest> unassigned = [];

    for (final guest in guests) {
      final bestTableId = _findBestTable(
        guest: guest,
        tables: tables,
        tableMap: tableMap,
      );
      if (bestTableId != null) {
        tableMap[bestTableId]!.add(guest);
      } else {
        unassigned.add(guest);
      }
    }

    // Ergebnis zusammenbauen
    final assignments = <TableAssignment>[];
    final globalConflicts = <ConflictWarning>[];
    final categoryMismatches = <CategoryMismatch>[];
    double totalScore = 0.0;

    for (final table in tables) {
      final seated = tableMap[table.id!] ?? [];
      final conflicts = _detectConflicts(seated);
      globalConflicts.addAll(conflicts);

      // Kategorie-Mismatches erkennen (weiche Verletzungen für Anzeige)
      final cats = TableCategories.parse(table.categoriesRaw);
      if (cats.isNotEmpty) {
        for (final g in seated) {
          final catScore = TableCategories.score(
            guestRelationship: g.relationshipType,
            tableCategories: cats,
          );
          if (catScore < 0) {
            categoryMismatches.add(
              CategoryMismatch(
                guest: g,
                guestRelationship: g.relationshipType ?? 'unbekannt',
                tableName: table.tableName,
                message:
                    '${g.firstName} ${g.lastName} (${g.relationshipType ?? "?"}) → ${table.tableName}',
              ),
            );
          }
        }
      }

      final score = seated.isEmpty
          ? 0.0
          : GuestScoringService.groupCompatibilityScore(seated);
      totalScore += score;

      assignments.add(
        TableAssignment(
          table: table,
          guests: seated,
          compatibilityScore: score,
          conflicts: conflicts,
        ),
      );
    }

    return TableSuggestionResult(
      assignments: assignments,
      unassignedGuests: unassigned,
      globalConflicts: globalConflicts,
      categoryMismatches: categoryMismatches,
      totalConflicts: globalConflicts.length,
      overallScore: assignments.isEmpty ? 0 : totalScore / assignments.length,
    );
  }

  // ── Besten Tisch finden ───────────────────────────────────────

  static int? _findBestTable({
    required Guest guest,
    required List<TableModel> tables,
    required Map<int, List<Guest>> tableMap,
  }) {
    int? bestTableId;
    double bestScore = double.negativeInfinity;

    for (final table in tables) {
      final seated = tableMap[table.id!]!;

      // ① Kapazität
      final occupancy = seated.fold(0, (s, g) => s + g.totalPersons);
      if (occupancy + guest.totalPersons > table.seats) continue;

      // ② Hartes Konflikt-Constraint
      if (_conflictsWithAnySeated(guest, seated)) continue;

      // ③ Hartes Kategorie-Constraint (z.B. Familientisch → kein Bekannter)
      if (!_passesHardCategoryCheck(guest, table)) continue;

      // ④ Score berechnen
      double score = seated.isEmpty ? 5.0 : 0.0;

      if (seated.isNotEmpty) {
        double sum = 0.0;
        bool abort = false;
        for (final s in seated) {
          final ps = GuestScoringService.compatibilityScore(guest, s);
          if (ps < -50) {
            abort = true;
            break;
          }
          sum += ps;
        }
        if (abort) continue;
        score = sum / seated.length;

        // Bonus: kennt jemanden
        if (seated.any((s) => s.id != null && guest.knowsGuest(s.id!))) {
          score += 15.0;
        }
        // Bonus: gleiche Altersgruppe
        if (guest.ageGroup != null) {
          score +=
              seated.where((s) => s.ageGroup == guest.ageGroup).length * 5.0;
        }
      }

      // ⑤ Kategorie-Score (Bonus/Malus, weich)
      final cats = TableCategories.parse(table.categoriesRaw);
      score += TableCategories.score(
        guestRelationship: guest.relationshipType,
        tableCategories: cats,
      );

      if (score > bestScore) {
        bestScore = score;
        bestTableId = table.id;
      }
    }

    return bestTableId;
  }

  // ── Konflikte erkennen ────────────────────────────────────────

  static List<ConflictWarning> _detectConflicts(List<Guest> seated) {
    final warnings = <ConflictWarning>[];
    for (int i = 0; i < seated.length; i++) {
      for (int j = i + 1; j < seated.length; j++) {
        if (_hasConflict(seated[i], seated[j])) {
          warnings.add(
            ConflictWarning(
              guestA: seated[i],
              guestB: seated[j],
              message: '${seated[i].firstName} & ${seated[j].firstName}',
            ),
          );
        }
      }
    }
    return warnings;
  }
}
