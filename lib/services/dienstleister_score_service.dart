// lib/services/dienstleister_score_service.dart
//
// Offline-Scoring für Dienstleister – kein API-Call, rein regelbasiert.
// Score 0–100, aufgeteilt in 5 Dimensionen.

import 'package:flutter/material.dart';
import '../models/dienstleister_models.dart';

/// Ergebnis einer Score-Berechnung
class DienstleisterScore {
  final int gesamt; // 0–100
  final int statusScore; // 0–25
  final int preisScore; // 0–25
  final int aktivitaetScore; // 0–20
  final int vollstaendigkeitScore; // 0–20
  final int bewertungScore; // 0–10
  final List<String> hinweise; // Konkrete Handlungsempfehlungen
  final ScoreKlasse klasse;

  const DienstleisterScore({
    required this.gesamt,
    required this.statusScore,
    required this.preisScore,
    required this.aktivitaetScore,
    required this.vollstaendigkeitScore,
    required this.bewertungScore,
    required this.hinweise,
    required this.klasse,
  });

  String get label => klasse.label;
  Color get color => klasse.color;
}

enum ScoreKlasse {
  ausgezeichnet, // 80–100
  gut, // 60–79
  okay, // 40–59
  verbesserungsbedarf, // 20–39
  kritisch; // 0–19

  String get label {
    switch (this) {
      case ScoreKlasse.ausgezeichnet:
        return 'Ausgezeichnet';
      case ScoreKlasse.gut:
        return 'Gut';
      case ScoreKlasse.okay:
        return 'Okay';
      case ScoreKlasse.verbesserungsbedarf:
        return 'Verbesserung';
      case ScoreKlasse.kritisch:
        return 'Kritisch';
    }
  }

  // flutter/material Color – import im Service nicht nötig, wir geben hex zurück
  // Hinweis: Wir importieren flutter nur wegen Color – kein Problem
  Color get color {
    switch (this) {
      case ScoreKlasse.ausgezeichnet:
        return const Color(0xFF4CAF50); // grün
      case ScoreKlasse.gut:
        return const Color(0xFF8BC34A); // hellgrün
      case ScoreKlasse.okay:
        return const Color(0xFFFFC107); // amber
      case ScoreKlasse.verbesserungsbedarf:
        return const Color(0xFFFF9800); // orange
      case ScoreKlasse.kritisch:
        return const Color(0xFFF44336); // rot
    }
  }
}

// ignore: avoid_classes_with_only_static_members
class DienstleisterScoreService {
  /// Berechnet den Score für einen Dienstleister.
  ///
  /// [zahlungen] – alle Zahlungen dieses Dienstleisters
  /// [kommunikationsLog] – alle Log-Einträge
  /// [gesamtBudget] – Hochzeitsbudget (für Preisanteil-Berechnung)
  static DienstleisterScore berechne({
    required Dienstleister d,
    required List<DienstleisterZahlung> zahlungen,
    required List<KommunikationsLogEintrag> kommunikationsLog,
    required double gesamtBudget,
  }) {
    final hinweise = <String>[];

    // ── 1. STATUS-SCORE (0–25) ───────────────────────────────────────────────
    int statusScore = _statusScore(d, hinweise);

    // ── 2. PREIS-SCORE (0–25) ────────────────────────────────────────────────
    int preisScore = _preisScore(d, zahlungen, gesamtBudget, hinweise);

    // ── 3. AKTIVITÄTS-SCORE (0–20) ──────────────────────────────────────────
    int aktivitaetScore = _aktivitaetScore(d, kommunikationsLog, hinweise);

    // ── 4. VOLLSTÄNDIGKEITS-SCORE (0–20) ────────────────────────────────────
    int vollstaendigkeitScore = _vollstaendigkeitScore(d, hinweise);

    // ── 5. BEWERTUNGS-SCORE (0–10) ──────────────────────────────────────────
    int bewertungScore = _bewertungScore(d, hinweise);

    final gesamt = (statusScore +
            preisScore +
            aktivitaetScore +
            vollstaendigkeitScore +
            bewertungScore)
        .clamp(0, 100);

    return DienstleisterScore(
      gesamt: gesamt,
      statusScore: statusScore,
      preisScore: preisScore,
      aktivitaetScore: aktivitaetScore,
      vollstaendigkeitScore: vollstaendigkeitScore,
      bewertungScore: bewertungScore,
      hinweise: hinweise,
      klasse: _klasse(gesamt),
    );
  }

  // ── STATUS-SCORE ─────────────────────────────────────────────────────────
  static int _statusScore(Dienstleister d, List<String> h) {
    switch (d.status) {
      case DienstleisterStatus.bewertet:
        return 25;
      case DienstleisterStatus.abgerechnet:
        return 23;
      case DienstleisterStatus.geliefert:
        return 22;
      case DienstleisterStatus.briefingFertig:
        return 20;
      case DienstleisterStatus.gebucht:
        return 18;
      case DienstleisterStatus.shortlist:
        h.add('Dienstleister ist auf der Shortlist – jetzt buchen?');
        return 12;
      case DienstleisterStatus.angebot:
        h.add('Angebot liegt vor – Entscheidung treffen');
        return 8;
      case DienstleisterStatus.angefragt:
        h.add('Noch keine Antwort – nachhaken?');
        return 5;
      case DienstleisterStatus.recherche:
        h.add('Noch in der Recherche – Kontakt aufnehmen');
        return 0;
    }
  }

  // ── PREIS-SCORE ──────────────────────────────────────────────────────────
  static int _preisScore(
    Dienstleister d,
    List<DienstleisterZahlung> zahlungen,
    double gesamtBudget,
    List<String> h,
  ) {
    final preis = d.angebotsSumme?.betrag ?? 0.0;
    if (preis <= 0) {
      h.add('Kein Angebotspreis hinterlegt');
      return 5;
    }

    // Anteil am Gesamtbudget
    if (gesamtBudget > 0) {
      final anteil = preis / gesamtBudget;
      // Richtwerte nach Kategorie (vereinfacht)
      final maxAnteil = _maxBudgetAnteil(d.kategorie);
      if (anteil > maxAnteil * 1.5) {
        h.add(
          'Preis liegt ${((anteil / maxAnteil - 1) * 100).toStringAsFixed(0)}% über dem typischen Anteil für ${d.kategorie.label}',
        );
        return 8;
      } else if (anteil > maxAnteil * 1.2) {
        h.add('Preis leicht über Richtwert für ${d.kategorie.label}');
        return 15;
      }
    }

    // Zahlungsfortschritt
    if (zahlungen.isNotEmpty) {
      final bezahlt = zahlungen.where((z) => z.bezahlt).length;
      final anteilBezahlt = bezahlt / zahlungen.length;
      if (anteilBezahlt == 1.0) return 25;
      if (anteilBezahlt >= 0.5) return 20;
      return 17;
    }

    return 20;
  }

  // ── AKTIVITÄTS-SCORE ─────────────────────────────────────────────────────
  static int _aktivitaetScore(
    Dienstleister d,
    List<KommunikationsLogEintrag> log,
    List<String> h,
  ) {
    if (log.isEmpty) {
      h.add('Noch kein Kommunikations-Log – ersten Eintrag anlegen');
      return 0;
    }

    final letzter = log
        .map((e) => e.erstelltAm)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final tage = DateTime.now().difference(letzter).inDays;

    if (tage <= 7) return 20;
    if (tage <= 14) return 15;
    if (tage <= 30) {
      h.add('Letzter Kontakt vor $tage Tagen – melde dich wieder');
      return 10;
    }
    if (tage <= 60) {
      h.add('Kein Kontakt seit $tage Tagen');
      return 5;
    }
    h.add('Sehr lange kein Kontakt ($tage Tage) – dringend nachfassen');
    return 0;
  }

  // ── VOLLSTÄNDIGKEITS-SCORE ───────────────────────────────────────────────
  static int _vollstaendigkeitScore(Dienstleister d, List<String> h) {
    int score = 0;
    if (d.hauptkontakt.email.isNotEmpty) score += 4;
    if (d.hauptkontakt.telefon.isNotEmpty) score += 4;
    if (d.angebotsSumme != null) score += 4;
    if (d.notizen.isNotEmpty) score += 3;
    if (d.website != null && d.website!.isNotEmpty) score += 2;
    if (d.tags.isNotEmpty) score += 3;

    if (d.hauptkontakt.email.isEmpty) h.add('E-Mail-Adresse fehlt');
    if (d.angebotsSumme == null) h.add('Angebotspreis fehlt');

    return score.clamp(0, 20);
  }

  // ── BEWERTUNGS-SCORE ─────────────────────────────────────────────────────
  static int _bewertungScore(Dienstleister d, List<String> h) {
    if (d.bewertung <= 0) {
      if (d.status.index >=
          DienstleisterStatus.geliefert.index) {
        h.add('Dienstleister noch nicht bewertet');
      }
      return 0;
    }
    return ((d.bewertung / 5.0) * 10).round().clamp(0, 10);
  }

  // ── HILFSMETHODEN ────────────────────────────────────────────────────────
  static double _maxBudgetAnteil(DienstleisterKategorie k) {
    switch (k) {
      case DienstleisterKategorie.location:
        return 0.35;
      case DienstleisterKategorie.catering:
        return 0.30;
      case DienstleisterKategorie.fotografie:
        return 0.10;
      case DienstleisterKategorie.musik:
        return 0.08;
      case DienstleisterKategorie.video:
        return 0.08;
      case DienstleisterKategorie.floristik:
        return 0.07;
      case DienstleisterKategorie.styling:
        return 0.05;
      case DienstleisterKategorie.kleidung:
        return 0.10;
      case DienstleisterKategorie.torte:
        return 0.04;
      case DienstleisterKategorie.trauredner:
        return 0.04;
      default:
        return 0.05;
    }
  }

  static ScoreKlasse _klasse(int score) {
    if (score >= 80) return ScoreKlasse.ausgezeichnet;
    if (score >= 60) return ScoreKlasse.gut;
    if (score >= 40) return ScoreKlasse.okay;
    if (score >= 20) return ScoreKlasse.verbesserungsbedarf;
    return ScoreKlasse.kritisch;
  }

  /// Gibt eine kurze Budget-Insight-Nachricht zurück.
  /// Für den Insights-Banner im ListScreen.
  static String? budgetInsight({
    required List<Dienstleister> alle,
    required double gesamtBudget,
  }) {
    if (gesamtBudget <= 0 || alle.isEmpty) return null;
    final gesamtKosten = alle.fold<double>(
      0,
      (s, d) => s + (d.angebotsSumme?.betrag ?? 0),
    );
    final anteil = gesamtKosten / gesamtBudget;
    final prozent = (anteil * 100).toStringAsFixed(0);

    if (anteil > 0.95) {
      return '⚠️ Dienstleisterkosten ($prozent% des Budgets) überschreiten fast das Gesamtbudget';
    }
    if (anteil > 0.80) {
      return '⚡ $prozent% des Budgets für Dienstleister – wenig Puffer';
    }
    if (anteil > 0.60) {
      return 'ℹ️ $prozent% des Budgets für Dienstleister (typisch: 60–80%)';
    }
    return '✅ $prozent% des Budgets für Dienstleister – guter Spielraum';
  }
}