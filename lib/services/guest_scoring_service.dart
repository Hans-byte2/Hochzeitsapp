// lib/services/guest_scoring_service.dart
//
// Lokaler KI-Score für Gäste (0–100), vollständig offline.
//
// Score-Faktoren:
//   VIP-Status        → +40 Punkte (hard cap oben)
//   Beziehungstyp     → Familie +30, Freunde +20, Kollegen +10, Bekannte +5
//   RSVP-Status       → Zugesagt +15, Offen +5, Abgesagt -10
//   Entfernung        → < 50km +10, 50–200km +5, > 200km 0
//   Kinder vorhanden  → +5 (Familie mit Kindern bevorzugen)

import '../models/wedding_models.dart';

class GuestScoringService {
  /// Berechnet einen Prioritäts-Score (0.0 – 100.0) für einen Gast.
  /// Vollständig lokal, kein Internet nötig.
  static double calculateScore(Guest guest) {
    double score = 0.0;

    // ── VIP ──────────────────────────────────────────────────────
    if (guest.isVip) {
      score += 40.0;
    }

    // ── Beziehungstyp ─────────────────────────────────────────────
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

    // ── RSVP-Status ───────────────────────────────────────────────
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

    // ── Entfernung ────────────────────────────────────────────────
    if (guest.distanceKm > 0) {
      if (guest.distanceKm < 50) {
        score += 10.0;
      } else if (guest.distanceKm <= 200) {
        score += 5.0;
      }
      // > 200km → kein Bonus (weite Anreise = tendenziell weniger sicher)
    }

    // ── Kinder ────────────────────────────────────────────────────
    if (guest.childrenCount > 0) {
      score += 5.0;
    }

    // ── Normalisieren auf 0–100 ───────────────────────────────────
    return score.clamp(0.0, 100.0);
  }

  /// Berechnet Scores für eine ganze Liste neu (z.B. nach Bulk-Import).
  static List<Guest> recalculateAll(List<Guest> guests) {
    return guests.map((g) {
      final score = calculateScore(g);
      return g.copyWith(
        priorityScore: score,
        scoreUpdatedAt: DateTime.now().toIso8601String(),
      );
    }).toList();
  }

  /// Gibt eine lesbare Erklärung des Scores zurück (für Tooltip/Detail-Ansicht).
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

    if (guest.distanceKm > 0 && guest.distanceKm < 50) {
      parts.add('Nah +10');
    } else if (guest.distanceKm >= 50 && guest.distanceKm <= 200) {
      parts.add('Mittel +5');
    }

    if (guest.childrenCount > 0) parts.add('Kinder +5');

    if (parts.isEmpty) return 'Kein Score berechnet';
    return parts.join(' · ');
  }
}
