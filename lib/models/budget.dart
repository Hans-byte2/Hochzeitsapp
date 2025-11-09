class Budget {
  final String id; // UUID
  final String category;
  final double plannedAmount;
  final double actualAmount;
  final String notes;
  final bool paid; // NEU: Bezahlt-Status
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

  Budget({
    required this.id,
    required this.category,
    required this.plannedAmount,
    required this.actualAmount,
    required this.notes,
    this.paid = false, // NEU: Default false
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
  });

  // Kopie erstellen mit geänderten Werten
  Budget copyWith({
    String? id,
    String? category,
    double? plannedAmount,
    double? actualAmount,
    String? notes,
    bool? paid,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      plannedAmount: plannedAmount ?? this.plannedAmount,
      actualAmount: actualAmount ?? this.actualAmount,
      notes: notes ?? this.notes,
      paid: paid ?? this.paid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // Aus Map erstellen (von Datenbank)
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      category: map['category'] as String,
      plannedAmount: (map['planned_amount'] as num).toDouble(),
      actualAmount: (map['actual_amount'] as num).toDouble(),
      notes: map['notes'] as String? ?? '',
      paid: (map['paid'] as int?) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int) == 1,
    );
  }

  // In Map umwandeln (für Datenbank)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'planned_amount': plannedAmount,
      'actual_amount': actualAmount,
      'notes': notes,
      'paid': paid ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  // Für Export/Import
  Map<String, dynamic> toJson() => toMap();
  factory Budget.fromJson(Map<String, dynamic> json) => Budget.fromMap(json);

  @override
  String toString() {
    return 'Budget(id: $id, category: $category, planned: $plannedAmount, actual: $actualAmount)';
  }
}
