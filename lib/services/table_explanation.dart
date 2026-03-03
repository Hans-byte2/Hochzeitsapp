// lib/services/table_explanation.dart
//
// "Warum-Button" — erklaert dem User warum genau diese Gaeste
// an einem Tisch sitzen. Wird in table_suggestion_screen.dart verwendet.
//
// Scoring-Uebersicht (zur Anzeige):
//   Kategorie-Match   +25 pro passendem Gast
//   Kennt sich        +20 pro Paar
//   Gleiche Altersgruppe +15 pro Gast (Gruppe > 1)
//   Gemeinsame Hobbys +10 pro geteiltem Hobby
//   Gleiche Beziehungsgruppe +10 pro Gast (Gruppe > 1)
//   Konflikt          -100

import '../models/table_categories.dart';
import '../services/table_suggestion_service.dart';

// ─────────────────────────────────────────────────────────────────
// Datenmodelle
// ─────────────────────────────────────────────────────────────────

enum ExplanationReasonType {
  category,
  knows,
  ageGroup,
  hobbies,
  relationship,
  conflict,
}

class ExplanationReason {
  final String icon;
  final String label;
  final String detail;
  final double score;
  final ExplanationReasonType type;

  const ExplanationReason({
    required this.icon,
    required this.label,
    required this.detail,
    required this.score,
    required this.type,
  });

  bool get isNegative => score < 0;

  /// Farb-Schlüssel für die UI (AppColors-kompatibel)
  String get colorKey {
    if (type == ExplanationReasonType.conflict) return 'error';
    if (score >= 40) return 'primary';
    if (score >= 20) return 'tertiary';
    return 'secondary';
  }
}

class TableExplanation {
  final String tableName;
  final double totalScore;
  final int guestCount;
  final List<ExplanationReason> reasons;

  const TableExplanation({
    required this.tableName,
    required this.totalScore,
    required this.guestCount,
    required this.reasons,
  });

  bool get hasReasons => reasons.isNotEmpty;
  bool get hasConflicts =>
      reasons.any((r) => r.type == ExplanationReasonType.conflict);

  List<ExplanationReason> get positiveReasons =>
      reasons.where((r) => !r.isNegative).toList();

  List<ExplanationReason> get negativeReasons =>
      reasons.where((r) => r.isNegative).toList();

  /// Zusammenfassung als einzelner Satz (z.B. fuer Tooltip)
  String get summary {
    if (!hasReasons) return 'Kein besonderer Grund — zufaellige Zuweisung.';
    if (hasConflicts) {
      return '⚠️ Konflikt an diesem Tisch! Bitte pruefen.';
    }
    final top = positiveReasons.first;
    return '${top.icon} ${top.label}: ${top.detail}';
  }
}

// ─────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────

class TableExplanationService {
  /// Hauptmethode: gibt vollstaendige Erklaerung fuer einen Tisch zurueck.
  static TableExplanation explain(TableAssignment assignment) {
    final guests = assignment.guests;
    final cats = TableCategories.parse(assignment.table.categoriesRaw);
    final reasons = <ExplanationReason>[];

    // ① Kategorie-Passung
    if (cats.isNotEmpty) {
      final catLabels = cats.map((c) => c.shortLabel).join(', ');
      final mc = guests
          .where(
            (g) => cats.any(
              (cat) => cat.matchingRelationships.contains(g.relationshipType),
            ),
          )
          .length;
      if (mc > 0) {
        reasons.add(
          ExplanationReason(
            icon: '🏷️',
            label: 'Tisch-Kategorie: $catLabels',
            detail:
                '$mc von ${guests.length} Gaesten passen zur Kategorie '
                '(+${(mc * 25).toInt()} Punkte)',
            score: mc * 25.0,
            type: ExplanationReasonType.category,
          ),
        );
      }
    }

    // ② Kennt-sich Paare
    final kp = <String>[];
    for (int i = 0; i < guests.length; i++) {
      for (int j = i + 1; j < guests.length; j++) {
        final a = guests[i];
        final b = guests[j];
        if (a.id != null &&
            b.id != null &&
            (a.knowsGuest(b.id!) || b.knowsGuest(a.id!))) {
          kp.add('${a.firstName} & ${b.firstName}');
        }
      }
    }
    if (kp.isNotEmpty) {
      final extra = kp.length > 3 ? ' und ${kp.length - 3} weitere' : '';
      reasons.add(
        ExplanationReason(
          icon: '🤝',
          label: 'Kennen sich',
          detail:
              kp.take(3).join(', ') +
              extra +
              ' (+${(kp.length * 20).toInt()} Punkte)',
          score: kp.length * 20.0,
          type: ExplanationReasonType.knows,
        ),
      );
    }

    // ③ Gleiche Altersgruppe
    final ac = <String, int>{};
    for (final g in guests) {
      if (g.ageGroup != null) ac[g.ageGroup!] = (ac[g.ageGroup!] ?? 0) + 1;
    }
    final topAge = ac.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topAge.isNotEmpty) {
      final t = topAge.first;
      reasons.add(
        ExplanationReason(
          icon: '👥',
          label: 'Altersgruppe: ${_ageLabel(t.key)}',
          detail:
              '${t.value} Gaeste in der gleichen Altersgruppe '
              '(+${(t.value * 15).toInt()} Punkte)',
          score: t.value * 15.0,
          type: ExplanationReasonType.ageGroup,
        ),
      );
    }

    // ④ Gemeinsame Hobbys
    final hc = <String, int>{};
    for (final g in guests) {
      for (final h in g.hobbiesList) {
        final k = h.toLowerCase().trim();
        if (k.isNotEmpty) hc[k] = (hc[k] ?? 0) + 1;
      }
    }
    final sh = hc.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sh.isNotEmpty) {
      final pts = sh.fold(0.0, (s, e) => s + (e.value - 1) * 10.0);
      reasons.add(
        ExplanationReason(
          icon: '🎯',
          label: 'Gemeinsame Hobbys',
          detail:
              sh.take(3).map((e) => '${e.key} (${e.value}x)').join(', ') +
              ' (+${pts.toInt()} Punkte)',
          score: pts,
          type: ExplanationReasonType.hobbies,
        ),
      );
    }

    // ⑤ Gleiche Beziehungsgruppe
    final rc = <String, int>{};
    for (final g in guests) {
      if (g.relationshipType != null) {
        rc[g.relationshipType!] = (rc[g.relationshipType!] ?? 0) + 1;
      }
    }
    final topRel = rc.entries.where((e) => e.value > 1).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (topRel.isNotEmpty) {
      final t = topRel.first;
      reasons.add(
        ExplanationReason(
          icon: _relIcon(t.key),
          label: 'Gruppe: ${_relLabel(t.key)}',
          detail:
              '${t.value} Gaeste aus derselben Beziehungsgruppe '
              '(+${(t.value * 10).toInt()} Punkte)',
          score: t.value * 10.0,
          type: ExplanationReasonType.relationship,
        ),
      );
    }

    // ⑥ Konflikte  (negativ — erscheinen immer am Ende)
    for (final c in assignment.conflicts) {
      reasons.add(
        ExplanationReason(
          icon: '⚠️',
          label: 'Konflikt vorhanden',
          detail: c.message,
          score: -100.0,
          type: ExplanationReasonType.conflict,
        ),
      );
    }

    // Positive absteigend nach Score, dann negative
    reasons.sort((a, b) {
      if (a.isNegative != b.isNegative) return a.isNegative ? 1 : -1;
      return b.score.compareTo(a.score);
    });

    return TableExplanation(
      tableName: assignment.table.tableName,
      totalScore: assignment.compatibilityScore,
      guestCount: guests.length,
      reasons: reasons,
    );
  }

  // ── Hilfsmethoden ────────────────────────────────────────────

  static String _ageLabel(String k) =>
      const {
        'kind': 'Kinder',
        'jugendlich': 'Jugendliche',
        'erwachsen': 'Erwachsene',
        'senior': 'Senioren',
      }[k] ??
      k;

  static String _relLabel(String k) =>
      const {
        'familie': 'Familie',
        'freunde': 'Freunde',
        'kollegen': 'Kollegen',
        'bekannte': 'Bekannte',
      }[k] ??
      k;

  static String _relIcon(String k) {
    switch (k) {
      case 'familie':
        return '👨‍👩‍👧';
      case 'freunde':
        return '🤝';
      case 'kollegen':
        return '💼';
      case 'bekannte':
        return '👋';
      default:
        return '👤';
    }
  }
}
