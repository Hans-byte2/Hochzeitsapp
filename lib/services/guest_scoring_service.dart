// lib/services/guest_scoring_service.dart
//
// Lokaler KI-Score für Gäste (0–100), vollständig offline.
//
// Einzel-Score (Priorität):
//   VIP +40, Familie +30, Freunde +20, Kollegen +10, Bekannte +5
//   Zugesagt +15, Offen +5, Abgesagt -10
//   Nah (<50km) +10, Mittel (50-200km) +5, Kinder +5
//
// Tisch-Kompatibilität:
//   Konflikt → -100 (hart, dominiert alles)
//   Kennt sich → +20
//   Gleiche Altersgruppe → +15
//   Gemeinsame Hobbys → +10 pro Hobby
//   Gleicher Beziehungstyp → +10

import '../models/wedding_models.dart';

class GuestScoringService {
  // ════════════════════════════════════════════════════════
  // EINZEL-SCORE
  // ════════════════════════════════════════════════════════

  static double calculateScore(Guest guest) {
    double score = 0.0;

    if (guest.isVip) score += 40.0;

    switch (guest.relationshipType) {
      case 'familie':
        score += 30.0;
        break;
      case 'freunde':
        score += 20.0;
        break;
      case 'kollegen':
        score += 10.0;
        break;
      case 'bekannte':
        score += 5.0;
        break;
    }

    switch (guest.confirmed) {
      case 'yes':
        score += 15.0;
        break;
      case 'pending':
        score += 5.0;
        break;
      case 'no':
        score -= 10.0;
        break;
    }

    if (guest.distanceKm > 0) {
      if (guest.distanceKm < 50)
        score += 10.0;
      else if (guest.distanceKm <= 200)
        score += 5.0;
    }

    if (guest.childrenCount > 0) score += 5.0;

    return score.clamp(0.0, 100.0);
  }

  static List<Guest> recalculateAll(List<Guest> guests) {
    return guests
        .map(
          (g) => g.copyWith(
            priorityScore: calculateScore(g),
            scoreUpdatedAt: DateTime.now().toIso8601String(),
          ),
        )
        .toList();
  }

  // ════════════════════════════════════════════════════════
  // TISCH-KOMPATIBILITÄT
  // ════════════════════════════════════════════════════════

  /// Score zwischen zwei Gästen. Negativ = sollten NICHT zusammensitzen.
  static double compatibilityScore(Guest a, Guest b) {
    if (a.id == null || b.id == null) return 0.0;

    // Konflikt dominiert alles
    if (a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!)) {
      return -100.0;
    }

    double score = 0.0;

    if (a.knowsGuest(b.id!) || b.knowsGuest(a.id!)) score += 20.0;

    if (a.ageGroup != null && b.ageGroup != null && a.ageGroup == b.ageGroup) {
      score += 15.0;
    }

    final hobbiesA = a.hobbiesList.map((h) => h.toLowerCase()).toSet();
    final hobbiesB = b.hobbiesList.map((h) => h.toLowerCase()).toSet();
    score += hobbiesA.intersection(hobbiesB).length * 10.0;

    if (a.relationshipType != null &&
        b.relationshipType != null &&
        a.relationshipType == b.relationshipType) {
      score += 10.0;
    }

    return score;
  }

  /// Durchschnittlicher Kompatibilitäts-Score einer ganzen Gruppe.
  static double groupCompatibilityScore(List<Guest> group) {
    if (group.length < 2) return 0.0;
    double total = 0.0;
    int pairs = 0;
    for (int i = 0; i < group.length; i++) {
      for (int j = i + 1; j < group.length; j++) {
        total += compatibilityScore(group[i], group[j]);
        pairs++;
      }
    }
    return pairs > 0 ? total / pairs : 0.0;
  }

  /// true wenn die Gruppe mindestens einen Konflikt enthält.
  static bool groupHasConflict(List<Guest> group) {
    for (int i = 0; i < group.length; i++) {
      for (int j = i + 1; j < group.length; j++) {
        final a = group[i];
        final b = group[j];
        if (a.id != null &&
            b.id != null &&
            (a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!))) {
          return true;
        }
      }
    }
    return false;
  }

  /// Gibt alle Konflikt-Paare in einer Gruppe zurück.
  static List<List<Guest>> getConflictPairs(List<Guest> group) {
    final conflicts = <List<Guest>>[];
    for (int i = 0; i < group.length; i++) {
      for (int j = i + 1; j < group.length; j++) {
        final a = group[i];
        final b = group[j];
        if (a.id != null &&
            b.id != null &&
            (a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!))) {
          conflicts.add([a, b]);
        }
      }
    }
    return conflicts;
  }

  // ════════════════════════════════════════════════════════
  // ERKLÄRUNGEN (für UI-Tooltips)
  // ════════════════════════════════════════════════════════

  static String explainScore(Guest guest) {
    final parts = <String>[];
    if (guest.isVip) parts.add('VIP +40');
    switch (guest.relationshipType) {
      case 'familie':
        parts.add('Familie +30');
        break;
      case 'freunde':
        parts.add('Freunde +20');
        break;
      case 'kollegen':
        parts.add('Kollegen +10');
        break;
      case 'bekannte':
        parts.add('Bekannte +5');
        break;
    }
    switch (guest.confirmed) {
      case 'yes':
        parts.add('Zugesagt +15');
        break;
      case 'pending':
        parts.add('Offen +5');
        break;
      case 'no':
        parts.add('Abgesagt -10');
        break;
    }
    if (guest.distanceKm > 0 && guest.distanceKm < 50)
      parts.add('Nah +10');
    else if (guest.distanceKm >= 50 && guest.distanceKm <= 200)
      parts.add('Mittelweit +5');
    if (guest.childrenCount > 0) parts.add('Kinder +5');
    return parts.isEmpty ? 'Kein Score' : parts.join(' · ');
  }

  static String explainCompatibility(Guest a, Guest b) {
    if (a.id == null || b.id == null) return '';
    if (a.hasConflictWith(b.id!) || b.hasConflictWith(a.id!))
      return '⚠️ Konflikt – nicht zusammensetzen!';
    final parts = <String>[];
    if (a.knowsGuest(b.id!) || b.knowsGuest(a.id!))
      parts.add('Kennen sich +20');
    if (a.ageGroup != null && a.ageGroup == b.ageGroup)
      parts.add('Gleiche Altersgruppe +15');
    final common = a.hobbiesList
        .map((h) => h.toLowerCase())
        .toSet()
        .intersection(b.hobbiesList.map((h) => h.toLowerCase()).toSet());
    if (common.isNotEmpty)
      parts.add('Hobbys: ${common.join(", ")} +${common.length * 10}');
    if (a.relationshipType != null && a.relationshipType == b.relationshipType)
      parts.add('Gleiche Gruppe +10');
    return parts.isEmpty ? 'Neutral (0)' : parts.join(' · ');
  }
}
