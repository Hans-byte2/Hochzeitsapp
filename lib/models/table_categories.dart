// lib/models/table_categories.dart
//
// Tisch-Kategorien für HeartPebble.
// Ein Tisch kann mehrere Kategorien haben.
// Gespeichert als kommagetrennte String in TableData/TableModel: 'familie,freunde'

enum TableCategory { brautpaar, familie, freunde, kollegen, bekannte }

extension TableCategoryX on TableCategory {
  String get value {
    switch (this) {
      case TableCategory.brautpaar:
        return 'brautpaar';
      case TableCategory.familie:
        return 'familie';
      case TableCategory.freunde:
        return 'freunde';
      case TableCategory.kollegen:
        return 'kollegen';
      case TableCategory.bekannte:
        return 'bekannte';
    }
  }

  String get label {
    switch (this) {
      case TableCategory.brautpaar:
        return '💍 Brautpaar';
      case TableCategory.familie:
        return '👨‍👩‍👧 Familie';
      case TableCategory.freunde:
        return '🤝 Freunde';
      case TableCategory.kollegen:
        return '💼 Kollegen';
      case TableCategory.bekannte:
        return '👋 Bekannte';
    }
  }

  String get shortLabel {
    switch (this) {
      case TableCategory.brautpaar:
        return 'Brautpaar';
      case TableCategory.familie:
        return 'Familie';
      case TableCategory.freunde:
        return 'Freunde';
      case TableCategory.kollegen:
        return 'Kollegen';
      case TableCategory.bekannte:
        return 'Bekannte';
    }
  }

  // Welche Gast-RelationshipTypes passen zu dieser Kategorie?
  List<String> get matchingRelationships {
    switch (this) {
      case TableCategory.brautpaar:
        return ['familie', 'freunde'];
      case TableCategory.familie:
        return ['familie'];
      case TableCategory.freunde:
        return ['freunde'];
      case TableCategory.kollegen:
        return ['kollegen'];
      case TableCategory.bekannte:
        return ['bekannte', 'kollegen'];
    }
  }

  // Hartes Constraint: nur passende Gäste dürfen zugewiesen werden?
  bool get isHard {
    switch (this) {
      case TableCategory.familie:
        return true; // Familie bleibt unter sich
      default:
        return false; // Alle anderen sind weich
    }
  }

  // Bonus wenn Gast passt, Malus wenn nicht
  double get matchBonus => 25.0;
  double get mismatchMalus {
    switch (this) {
      case TableCategory.familie:
        return 0.0; // Hart — wird vor Score-Berechnung gefiltert
      case TableCategory.brautpaar:
        return 5.0;
      case TableCategory.freunde:
        return 12.0;
      case TableCategory.kollegen:
        return 15.0;
      case TableCategory.bekannte:
        return 10.0;
    }
  }

  static TableCategory? fromValue(String v) {
    for (final c in TableCategory.values) {
      if (c.value == v) return c;
    }
    return null;
  }
}

class TableCategories {
  static List<TableCategory> parse(String? value) {
    if (value == null || value.isEmpty) return [];
    return value
        .split(',')
        .map((s) => TableCategoryX.fromValue(s.trim()))
        .whereType<TableCategory>()
        .toList();
  }

  static String serialize(List<TableCategory> cats) =>
      cats.map((c) => c.value).join(',');

  /// Gibt false zurück wenn ein hartes Constraint den Gast ausschließt.
  /// Gibt null zurück wenn kein Constraint (Tisch hat keine Kategorien).
  static bool? hardCheck({
    required String? guestRelationship,
    required List<TableCategory> tableCategories,
  }) {
    if (tableCategories.isEmpty || guestRelationship == null) return null;
    for (final cat in tableCategories.where((c) => c.isHard)) {
      if (!cat.matchingRelationships.contains(guestRelationship)) return false;
    }
    return true;
  }

  /// Berechnet Kategorie-Score (Bonus/Malus) für einen Gast an einem Tisch.
  static double score({
    required String? guestRelationship,
    required List<TableCategory> tableCategories,
  }) {
    if (tableCategories.isEmpty || guestRelationship == null) return 0.0;
    double s = 0.0;
    for (final cat in tableCategories) {
      if (cat.matchingRelationships.contains(guestRelationship)) {
        s += cat.matchBonus;
      } else {
        s -= cat.mismatchMalus;
      }
    }
    return s;
  }
}
