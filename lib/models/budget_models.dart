// ================================
// BUDGET ITEM MODEL
// ================================

class BudgetItem {
  final int? id;
  final String name;
  final double planned;
  final double actual;
  final String category;
  final String notes;
  final bool paid;

  BudgetItem({
    this.id,
    required this.name,
    required this.planned,
    required this.actual,
    this.category = 'other',
    this.notes = '',
    this.paid = false,
  });

  BudgetItem copyWith({
    int? id,
    String? name,
    double? planned,
    double? actual,
    String? category,
    String? notes,
    bool? paid,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      planned: planned ?? this.planned,
      actual: actual ?? this.actual,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      paid: paid ?? this.paid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'planned': planned,
      'actual': actual,
      'category': category,
      'notes': notes,
      'paid': paid ? 1 : 0,
    };
  }

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id']?.toInt(),
      name: map['name'] ?? '',
      planned: (map['planned'] ?? 0).toDouble(),
      actual: (map['actual'] ?? 0).toDouble(),
      category: map['category'] ?? 'other',
      notes: map['notes'] ?? '',
      paid: (map['paid'] ?? 0) == 1,
    );
  }
}

// ================================
// BUDGET CATEGORY STATS
// ================================

class BudgetCategoryStats {
  final String category;
  final double plannedTotal;
  final double actualTotal;
  final int itemCount;

  BudgetCategoryStats({
    required this.category,
    required this.plannedTotal,
    required this.actualTotal,
    required this.itemCount,
  });

  double get percentage =>
      plannedTotal > 0 ? (actualTotal / plannedTotal) * 100 : 0.0;

  double get remaining => plannedTotal - actualTotal;
}
