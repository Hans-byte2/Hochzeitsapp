// lib/models/table_models.dart
//
// Lokales Tisch-Modell für die Tischplanungs-UI.
// Wird in TischplanungPage verwendet und bei Bedarf zu TableModel konvertiert.

import 'table_categories.dart';

class TableData {
  final int id;
  final String tableName;
  final int tableNumber;
  final int seats;

  /// Kommagetrennte Kategorien: 'familie', 'freunde', 'kollegen', 'bekannte', 'brautpaar'
  final String? categoriesRaw;

  const TableData({
    required this.id,
    required this.tableName,
    required this.tableNumber,
    this.seats = 8,
    this.categoriesRaw,
  });

  /// Geparste Kategorien-Liste.
  List<TableCategory> get categories => TableCategories.parse(categoriesRaw);

  TableData copyWith({
    int? id,
    String? tableName,
    int? tableNumber,
    int? seats,
    String? categoriesRaw,
  }) {
    return TableData(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      tableNumber: tableNumber ?? this.tableNumber,
      seats: seats ?? this.seats,
      categoriesRaw: categoriesRaw ?? this.categoriesRaw,
    );
  }
}
