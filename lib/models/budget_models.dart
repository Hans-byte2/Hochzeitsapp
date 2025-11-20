import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Kategorien für Budget-Einträge
class BudgetCategories {
  static const List<String> defaults = [
    'Location',
    'Catering',
    'Fotografie',
    'Musik',
    'Dekoration',
    'Blumen',
    'Kleidung',
    'Ringe',
    'Einladungen',
    'Transport',
    'Unterkunft',
    'Hochzeitstorte',
    'Sonstiges',
  ];
}

/// Einzelner Budget-Eintrag
class BudgetItem {
  final String id;
  final String name;
  final String category;
  final double estimatedCost;
  final double actualCost;
  final bool isPaid;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  BudgetItem({
    String? id,
    required this.name,
    required this.category,
    required this.estimatedCost,
    this.actualCost = 0.0,
    this.isPaid = false,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Aus Map erstellen (für Datenbank)
  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      estimatedCost: (map['estimated_cost'] as num).toDouble(),
      actualCost: (map['actual_cost'] as num?)?.toDouble() ?? 0.0,
      isPaid: (map['is_paid'] as int) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Zu Map konvertieren (für Datenbank)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'estimated_cost': estimatedCost,
      'actual_cost': actualCost,
      'is_paid': isPaid ? 1 : 0,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // ✅ KEIN is_deleted mehr!
    };
  }

  /// Aus JSON erstellen (für Import/Export)
  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String,
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      actualCost: (json['actualCost'] as num?)?.toDouble() ?? 0.0,
      isPaid: json['isPaid'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Zu JSON konvertieren (für Import/Export)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'estimatedCost': estimatedCost,
      'actualCost': actualCost,
      'isPaid': isPaid,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Kopie mit geänderten Werten erstellen
  BudgetItem copyWith({
    String? id,
    String? name,
    String? category,
    double? estimatedCost,
    double? actualCost,
    bool? isPaid,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Differenz zwischen geschätzten und tatsächlichen Kosten
  double get difference => actualCost - estimatedCost;

  /// Ist über dem Budget?
  bool get isOverBudget => actualCost > estimatedCost;

  /// Prozentsatz der Ausgaben
  double get percentSpent =>
      estimatedCost > 0 ? (actualCost / estimatedCost * 100) : 0;

  @override
  String toString() {
    return 'BudgetItem(id: $id, name: $name, category: $category, '
        'estimated: $estimatedCost, actual: $actualCost, paid: $isPaid)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BudgetItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Budget-Statistiken
class BudgetStatistics {
  final double totalEstimated;
  final double totalActual;
  final int totalItems;
  final int paidItems;
  final int unpaidItems;
  final double difference;
  final Map<String, double> categoryBreakdown;

  BudgetStatistics({
    required this.totalEstimated,
    required this.totalActual,
    required this.totalItems,
    required this.paidItems,
    required this.unpaidItems,
    required this.difference,
    required this.categoryBreakdown,
  });

  factory BudgetStatistics.fromItems(List<BudgetItem> items) {
    double totalEstimated = 0;
    double totalActual = 0;
    int paidItems = 0;
    final categoryBreakdown = <String, double>{};

    for (var item in items) {
      totalEstimated += item.estimatedCost;
      totalActual += item.actualCost;
      if (item.isPaid) paidItems++;

      categoryBreakdown[item.category] =
          (categoryBreakdown[item.category] ?? 0) + item.actualCost;
    }

    return BudgetStatistics(
      totalEstimated: totalEstimated,
      totalActual: totalActual,
      totalItems: items.length,
      paidItems: paidItems,
      unpaidItems: items.length - paidItems,
      difference: totalActual - totalEstimated,
      categoryBreakdown: categoryBreakdown,
    );
  }

  bool get isOverBudget => difference > 0;
  double get percentSpent =>
      totalEstimated > 0 ? (totalActual / totalEstimated * 100) : 0;
}
