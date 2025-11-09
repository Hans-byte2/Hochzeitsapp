import 'package:uuid/uuid.dart';

// ============= BUDGET ITEM (AKTUALISIERT) =============

class BudgetItem {
  final String id;
  final String name; // ⭐ NEU: Bezeichnung
  final String category;
  final double estimatedCost; // ⭐ UMBENANNT von 'planned'
  final double actualCost; // ⭐ UMBENANNT von 'actual'
  final bool isPaid; // ⭐ UMBENANNT von 'paid'
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;

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
    this.isDeleted = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  // ⭐ RÜCKWÄRTSKOMPATIBILITÄT: Alte Getter für bestehenden Code
  double get planned => estimatedCost;
  double get actual => actualCost;
  bool get paid => isPaid;

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
    bool? isDeleted,
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
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id'] as String,
      name:
          map['name'] as String? ??
          map['category'] as String, // Fallback für alte Daten
      category: map['category'] as String,
      estimatedCost: (map['estimated_cost'] ?? map['planned'] ?? 0) as double,
      actualCost: (map['actual_cost'] ?? map['actual'] ?? 0) as double,
      isPaid: ((map['is_paid'] ?? map['paid'] ?? 0) as int) == 1,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: ((map['is_deleted'] ?? 0) as int) == 1,
    );
  }

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
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

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
      'isDeleted': isDeleted,
    };
  }

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      estimatedCost: (json['estimatedCost'] as num).toDouble(),
      actualCost: (json['actualCost'] as num).toDouble(),
      isPaid: json['isPaid'] as bool,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool,
    );
  }
}

// ============= BUDGET CATEGORIES =============

class BudgetCategories {
  static const List<String> defaults = [
    'Location',
    'Catering',
    'Dekoration',
    'Musik & Entertainment',
    'Fotografie & Video',
    'Brautkleid & Anzug',
    'Blumen',
    'Einladungen & Papeterie',
    'Trauringe',
    'Hochzeitstorte',
    'Transport',
    'Unterhaltung',
    'Flitterwochen',
    'Sonstiges',
  ];
}
