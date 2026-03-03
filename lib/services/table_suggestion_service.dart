// lib/services/table_suggestion_service.dart
//
// Algorithmus für automatische Tischzuweisung.
//
// Strategie (Greedy + Konflikt-Prüfung):
//   1. Konflikte werden als harte Constraints behandelt (nie zusammen)
//   2. Gäste werden nach Score sortiert (VIPs zuerst)
//   3. Jeder Gast wird dem Tisch zugewiesen der den höchsten
//      Kompatibilitäts-Score mit den bereits sitzenden Gästen hat
//   4. Kinder bleiben bei ihren Eltern (gleicher Tisch)
//   5. Altersgruppen werden bevorzugt gebündelt
//
// Ergebnis: TableSuggestionResult mit Tisch→Gäste Mapping + Warnungen

import '../models/wedding_models.dart';
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

class TableSuggestionResult {
  final List<TableAssignment> assignments;
  final List<Guest> unassignedGuests;
  final List<ConflictWarning> globalConflicts;
  final int totalConflicts;
  final double overallScore;

  TableSuggestionResult({
    required this.assignments,
    required this.unassignedGuests,
    required this.globalConflicts,
    required this.totalConflicts,
    required this.overallScore,
  });

  bool get hasUnassigned => unassignedGuests.isNotEmpty;
  bool get hasConflicts => totalConflicts > 0;
}

// ════════════════════════════════════════════════════════════════
// SERVICE
// ════════════════════════════════════════════════════════════════

class TableSuggestionService {
  /// Hauptmethode: Berechnet optimale Tischzuweisung.
  /// Nur Gäste mit confirmed == 'yes' werden berücksichtigt.
  static TableSuggestionResult suggest({
    required List<Guest> allGuests,
    required List<TableModel> tables,
  }) {
    if (tables.isEmpty) {
      return TableSuggestionResult(
        assignments: [],
        unassignedGuests: allGuests.where((g) => g.confirmed == 'yes').toList(),
        globalConflicts: [],
        totalConflicts: 0,
        overallScore: 0,
      );
    }

    // Nur zugesagte Gäste
    final guests = allGuests.where((g) => g.confirmed == 'yes').toList();

    // Nach Score sortieren (wichtigste Gäste zuerst → bessere Plätze)
    guests.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

    // Tisch-Slots initialisieren
    final Map<int, List<Guest>> tableMap = {};
    for (final t in tables) {
      tableMap[t.id!] = [];
    }

    final List<Guest> unassigned = [];

    // ── Greedy-Zuweisung ─────────────────────────────────────────
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

    // ── Ergebnis zusammenbauen ────────────────────────────────────
    final assignments = <TableAssignment>[];
    final globalConflicts = <ConflictWarning>[];
    double totalScore = 0.0;
    int conflictCount = 0;

    for (final table in tables) {
      final seated = tableMap[table.id!] ?? [];
      final conflicts = _detectConflicts(seated);

      final score = GuestScoringService.groupCompatibilityScore(seated);
      totalScore += score;
      conflictCount += conflicts.length;
      globalConflicts.addAll(conflicts);

      assignments.add(
        TableAssignment(
          table: table,
          guests: seated,
          compatibilityScore: score,
          conflicts: conflicts,
        ),
      );
    }

    final overallScore = assignments.isNotEmpty
        ? totalScore / assignments.length
        : 0.0;

    return TableSuggestionResult(
      assignments: assignments,
      unassignedGuests: unassigned,
      globalConflicts: globalConflicts,
      totalConflicts: conflictCount,
      overallScore: overallScore,
    );
  }

  // ── Besten Tisch für einen Gast finden ───────────────────────
  static int? _findBestTable({
    required Guest guest,
    required List<TableModel> tables,
    required Map<int, List<Guest>> tableMap,
  }) {
    int? bestTableId;
    double bestScore = double.negativeInfinity;

    for (final table in tables) {
      final seated = tableMap[table.id!]!;

      // Kapazität prüfen (Personen = Gäste + Kinder)
      final currentPersons = seated.fold(0, (s, g) => s + g.totalPersons);
      if (currentPersons + guest.totalPersons > table.seats) continue;

      // Konflikte prüfen (hart — Tisch wird übersprungen)
      bool hasConflict = false;
      for (final s in seated) {
        if (s.id != null && guest.id != null) {
          if (guest.hasConflictWith(s.id!) || s.hasConflictWith(guest.id!)) {
            hasConflict = true;
            break;
          }
        }
      }
      if (hasConflict) continue;

      // Kompatibilitäts-Score berechnen
      double score = 0.0;
      if (seated.isEmpty) {
        // Leerer Tisch: kleiner Bonus damit nicht alle auf einen Tisch wollen
        score = 5.0;
      } else {
        for (final s in seated) {
          score += GuestScoringService.compatibilityScore(guest, s);
        }
        score = score / seated.length;
      }

      // Bonus: Kennt jemanden am Tisch
      for (final s in seated) {
        if (s.id != null && guest.knowsGuest(s.id!)) {
          score += 15.0;
          break;
        }
      }

      // Bonus: Gleiche Altersgruppe am Tisch
      if (guest.ageGroup != null) {
        final sameAge = seated
            .where((s) => s.ageGroup == guest.ageGroup)
            .length;
        score += sameAge * 5.0;
      }

      if (score > bestScore) {
        bestScore = score;
        bestTableId = table.id;
      }
    }

    return bestTableId;
  }

  // ── Konflikte in einer Gruppe erkennen ───────────────────────
  static List<ConflictWarning> _detectConflicts(List<Guest> seated) {
    final warnings = <ConflictWarning>[];
    for (int i = 0; i < seated.length; i++) {
      for (int j = i + 1; j < seated.length; j++) {
        final a = seated[i];
        final b = seated[j];
        if (a.id != null && b.id != null) {
          if (a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!)) {
            warnings.add(
              ConflictWarning(
                guestA: a,
                guestB: b,
                message:
                    '${a.firstName} ${a.lastName} & ${b.firstName} ${b.lastName} haben einen Konflikt',
              ),
            );
          }
        }
      }
    }
    return warnings;
  }

  /// Analysiert nur — ohne Zuweisung.
  /// Gibt zurück welche Gäste sich kennen und welche Konflikte existieren.
  static Map<String, dynamic> analyzeGuests(List<Guest> guests) {
    final confirmed = guests.where((g) => g.confirmed == 'yes').toList();
    final allConflicts = <ConflictWarning>[];
    final allKnows = <List<Guest>>[];

    for (int i = 0; i < confirmed.length; i++) {
      for (int j = i + 1; j < confirmed.length; j++) {
        final a = confirmed[i];
        final b = confirmed[j];
        if (a.id != null && b.id != null) {
          if (a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!)) {
            allConflicts.add(
              ConflictWarning(
                guestA: a,
                guestB: b,
                message: '${a.firstName} & ${b.firstName}',
              ),
            );
          }
          if (a.knowsGuest(b.id!) || b.knowsGuest(a.id!)) {
            allKnows.add([a, b]);
          }
        }
      }
    }

    return {
      'conflicts': allConflicts,
      'knows': allKnows,
      'totalConflicts': allConflicts.length,
      'totalKnows': allKnows.length,
    };
  }
}
