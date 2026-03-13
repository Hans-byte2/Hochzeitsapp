// lib/models/wedding_models.dart
//
// COMPLETE VERSION mit Timestamps + Soft Deletes + Location
// v2: Guest erweitert um Kinder-Tracking + KI-Scoring
// v3: PaymentPlan hinzugefügt

// ================================
// GUEST MODEL
// ================================

enum RelationshipType { familie, freunde, kollegen, bekannte }

enum PriorityBadge { vip, hoch, mittel, niedrig }

class Guest {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String confirmed;
  final String dietaryRequirements;
  final int? tableNumber;
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;
  final int childrenCount;
  final String? childrenNames;
  final String? relationshipType;
  final bool isVip;
  final int distanceKm;
  final double priorityScore;
  final String? scoreUpdatedAt;
  final String? conflictsJson;
  final String? knowsJson;
  final String? ageGroup;
  final String? hobbies;

  Guest({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.confirmed,
    required this.dietaryRequirements,
    this.tableNumber,
    this.updatedAt,
    this.deleted = 0,
    this.deletedAt,
    this.childrenCount = 0,
    this.childrenNames,
    this.relationshipType,
    this.isVip = false,
    this.distanceKm = 0,
    this.priorityScore = 0.0,
    this.scoreUpdatedAt,
    this.conflictsJson,
    this.knowsJson,
    this.ageGroup,
    this.hobbies,
  });

  PriorityBadge get priorityBadge {
    if (isVip || priorityScore >= 80) return PriorityBadge.vip;
    if (priorityScore >= 60) return PriorityBadge.hoch;
    if (priorityScore >= 40) return PriorityBadge.mittel;
    return PriorityBadge.niedrig;
  }

  List<String> get childrenNamesList {
    if (childrenNames == null || childrenNames!.isEmpty) return [];
    try {
      final cleaned = childrenNames!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '');
      if (cleaned.isEmpty) return [];
      return cleaned
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<int> get conflictIds {
    if (conflictsJson == null || conflictsJson!.isEmpty) return [];
    try {
      final cleaned = conflictsJson!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll(' ', '');
      if (cleaned.isEmpty) return [];
      return cleaned
          .split(',')
          .map((e) => int.tryParse(e) ?? -1)
          .where((e) => e >= 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<int> get knowsIds {
    if (knowsJson == null || knowsJson!.isEmpty) return [];
    try {
      final cleaned = knowsJson!
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll(' ', '');
      if (cleaned.isEmpty) return [];
      return cleaned
          .split(',')
          .map((e) => int.tryParse(e) ?? -1)
          .where((e) => e >= 0)
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<String> get hobbiesList {
    if (hobbies == null || hobbies!.isEmpty) return [];
    return hobbies!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool hasConflictWith(int guestId) => conflictIds.contains(guestId);
  bool knowsGuest(int guestId) => knowsIds.contains(guestId);

  Guest copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? confirmed,
    String? dietaryRequirements,
    int? tableNumber,
    String? updatedAt,
    int? deleted,
    String? deletedAt,
    int? childrenCount,
    String? childrenNames,
    String? relationshipType,
    bool? isVip,
    int? distanceKm,
    double? priorityScore,
    String? scoreUpdatedAt,
    String? conflictsJson,
    String? knowsJson,
    String? ageGroup,
    String? hobbies,
  }) {
    return Guest(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      confirmed: confirmed ?? this.confirmed,
      dietaryRequirements: dietaryRequirements ?? this.dietaryRequirements,
      tableNumber: tableNumber ?? this.tableNumber,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      childrenCount: childrenCount ?? this.childrenCount,
      childrenNames: childrenNames ?? this.childrenNames,
      relationshipType: relationshipType ?? this.relationshipType,
      isVip: isVip ?? this.isVip,
      distanceKm: distanceKm ?? this.distanceKm,
      priorityScore: priorityScore ?? this.priorityScore,
      scoreUpdatedAt: scoreUpdatedAt ?? this.scoreUpdatedAt,
      conflictsJson: conflictsJson ?? this.conflictsJson,
      knowsJson: knowsJson ?? this.knowsJson,
      ageGroup: ageGroup ?? this.ageGroup,
      hobbies: hobbies ?? this.hobbies,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'first_name': firstName,
    'last_name': lastName,
    'email': email,
    'confirmed': confirmed,
    'dietary_requirements': dietaryRequirements,
    'table_number': tableNumber,
    'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    'deleted': deleted,
    'deleted_at': deletedAt,
    'children_count': childrenCount,
    'children_names': childrenNames,
    'relationship_type': relationshipType,
    'is_vip': isVip ? 1 : 0,
    'distance_km': distanceKm,
    'priority_score': priorityScore,
    'score_updated_at': scoreUpdatedAt,
    'conflicts_json': conflictsJson,
    'knows_json': knowsJson,
    'age_group': ageGroup,
    'hobbies': hobbies,
  };

  factory Guest.fromMap(Map<String, dynamic> map) => Guest(
    id: map['id']?.toInt(),
    firstName: map['first_name'] ?? '',
    lastName: map['last_name'] ?? '',
    email: map['email'] ?? '',
    confirmed: map['confirmed'] ?? 'pending',
    dietaryRequirements: map['dietary_requirements'] ?? '',
    tableNumber: map['table_number']?.toInt(),
    updatedAt: map['updated_at'],
    deleted: map['deleted'] ?? 0,
    deletedAt: map['deleted_at'],
    childrenCount: map['children_count']?.toInt() ?? 0,
    childrenNames: map['children_names'],
    relationshipType: map['relationship_type'],
    isVip: (map['is_vip'] ?? 0) == 1,
    distanceKm: map['distance_km']?.toInt() ?? 0,
    priorityScore: (map['priority_score'] ?? 0.0).toDouble(),
    scoreUpdatedAt: map['score_updated_at'],
    conflictsJson: map['conflicts_json'],
    knowsJson: map['knows_json'],
    ageGroup: map['age_group'],
    hobbies: map['hobbies'],
  );

  bool get isDeleted => deleted == 1;
  int get totalPersons => 1 + childrenCount;
}

// ================================
// TASK MODEL
// ================================

class Task {
  final int? id;
  final String title;
  final String description;
  final String category;
  final String priority;
  final DateTime? deadline;
  final bool completed;
  final DateTime createdDate;
  final String location;
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.category = 'other',
    this.priority = 'medium',
    this.deadline,
    this.completed = false,
    required this.createdDate,
    this.location = '',
    this.updatedAt,
    this.deleted = 0,
    this.deletedAt,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? priority,
    DateTime? deadline,
    bool? completed,
    DateTime? createdDate,
    String? location,
    String? updatedAt,
    int? deleted,
    String? deletedAt,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    deadline: deadline ?? this.deadline,
    completed: completed ?? this.completed,
    createdDate: createdDate ?? this.createdDate,
    location: location ?? this.location,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority,
    'deadline': deadline?.toIso8601String(),
    'completed': completed ? 1 : 0,
    'created_date': createdDate.toIso8601String(),
    'location': location,
    'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    'deleted': deleted,
    'deleted_at': deletedAt,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id']?.toInt(),
    title: map['title'] ?? '',
    description: map['description'] ?? '',
    category: map['category'] ?? 'other',
    priority: map['priority'] ?? 'medium',
    deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
    completed: map['completed'] == 1,
    createdDate: DateTime.parse(map['created_date']),
    location: map['location'] ?? '',
    updatedAt: map['updated_at'],
    deleted: map['deleted'] ?? 0,
    deletedAt: map['deleted_at'],
  );

  bool get isDeleted => deleted == 1;
}

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
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;

  BudgetItem({
    this.id,
    required this.name,
    this.planned = 0.0,
    this.actual = 0.0,
    this.category = 'other',
    this.notes = '',
    this.paid = false,
    this.updatedAt,
    this.deleted = 0,
    this.deletedAt,
  });

  BudgetItem copyWith({
    int? id,
    String? name,
    double? planned,
    double? actual,
    String? category,
    String? notes,
    bool? paid,
    String? updatedAt,
    int? deleted,
    String? deletedAt,
  }) => BudgetItem(
    id: id ?? this.id,
    name: name ?? this.name,
    planned: planned ?? this.planned,
    actual: actual ?? this.actual,
    category: category ?? this.category,
    notes: notes ?? this.notes,
    paid: paid ?? this.paid,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'planned': planned,
    'actual': actual,
    'category': category,
    'notes': notes,
    'paid': paid ? 1 : 0,
    'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    'deleted': deleted,
    'deleted_at': deletedAt,
  };

  factory BudgetItem.fromMap(Map<String, dynamic> map) => BudgetItem(
    id: map['id']?.toInt(),
    name: map['name'] ?? '',
    planned: (map['planned'] ?? 0.0).toDouble(),
    actual: (map['actual'] ?? 0.0).toDouble(),
    category: map['category'] ?? 'other',
    notes: map['notes'] ?? '',
    paid: map['paid'] == 1,
    updatedAt: map['updated_at'],
    deleted: map['deleted'] ?? 0,
    deletedAt: map['deleted_at'],
  );

  bool get isDeleted => deleted == 1;
}

// ================================
// TABLE MODEL
// ================================

class TableModel {
  final int? id;
  final String tableName;
  final int tableNumber;
  final int seats;
  final String? categoriesRaw;
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;

  TableModel({
    this.id,
    required this.tableName,
    required this.tableNumber,
    this.seats = 8,
    this.categoriesRaw,
    this.updatedAt,
    this.deleted = 0,
    this.deletedAt,
  });

  TableModel copyWith({
    int? id,
    String? tableName,
    int? tableNumber,
    int? seats,
    String? categoriesRaw,
    String? updatedAt,
    int? deleted,
    String? deletedAt,
  }) => TableModel(
    id: id ?? this.id,
    tableName: tableName ?? this.tableName,
    tableNumber: tableNumber ?? this.tableNumber,
    seats: seats ?? this.seats,
    categoriesRaw: categoriesRaw ?? this.categoriesRaw,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'table_name': tableName,
    'table_number': tableNumber,
    'seats': seats,
    'categories': categoriesRaw,
    'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    'deleted': deleted,
    'deleted_at': deletedAt,
  };

  factory TableModel.fromMap(Map<String, dynamic> map) => TableModel(
    id: map['id']?.toInt(),
    tableName: map['table_name'] ?? '',
    tableNumber: map['table_number']?.toInt() ?? 0,
    seats: map['seats']?.toInt() ?? 8,
    categoriesRaw: map['categories'],
    updatedAt: map['updated_at'],
    deleted: map['deleted'] ?? 0,
    deletedAt: map['deleted_at'],
  );

  bool get isDeleted => deleted == 1;
}

// ================================
// PAYMENT PLAN MODEL  (v17)
// ================================

enum PaymentType { anzahlung, restzahlung, pauschale }

class PaymentPlan {
  final int? id;
  final String vendorName;
  final double amount;
  final DateTime dueDate;
  final PaymentType paymentType;
  final bool paid;
  final String notes;
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;

  PaymentPlan({
    this.id,
    required this.vendorName,
    required this.amount,
    required this.dueDate,
    required this.paymentType,
    this.paid = false,
    this.notes = '',
    this.updatedAt,
    this.deleted = 0,
    this.deletedAt,
  });

  String get paymentTypeLabel {
    switch (paymentType) {
      case PaymentType.anzahlung:
        return 'Anzahlung';
      case PaymentType.restzahlung:
        return 'Restzahlung';
      case PaymentType.pauschale:
        return 'Pauschale';
    }
  }

  PaymentPlan copyWith({
    int? id,
    String? vendorName,
    double? amount,
    DateTime? dueDate,
    PaymentType? paymentType,
    bool? paid,
    String? notes,
    String? updatedAt,
    int? deleted,
    String? deletedAt,
  }) => PaymentPlan(
    id: id ?? this.id,
    vendorName: vendorName ?? this.vendorName,
    amount: amount ?? this.amount,
    dueDate: dueDate ?? this.dueDate,
    paymentType: paymentType ?? this.paymentType,
    paid: paid ?? this.paid,
    notes: notes ?? this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'vendor_name': vendorName,
    'amount': amount,
    'due_date': dueDate.toIso8601String(),
    'payment_type': paymentType.name,
    'paid': paid ? 1 : 0,
    'notes': notes,
    'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
    'deleted': deleted,
    'deleted_at': deletedAt,
  };

  factory PaymentPlan.fromMap(Map<String, dynamic> map) => PaymentPlan(
    id: map['id']?.toInt(),
    vendorName: map['vendor_name'] ?? '',
    amount: (map['amount'] ?? 0.0).toDouble(),
    dueDate: DateTime.parse(map['due_date']),
    paymentType: PaymentType.values.firstWhere(
      (e) => e.name == map['payment_type'],
      orElse: () => PaymentType.pauschale,
    ),
    paid: (map['paid'] ?? 0) == 1,
    notes: map['notes'] ?? '',
    updatedAt: map['updated_at'],
    deleted: map['deleted'] ?? 0,
    deletedAt: map['deleted_at'],
  );

  bool get isDeleted => deleted == 1;
  bool get isOverdue => !paid && dueDate.isBefore(DateTime.now());
  bool get isDueSoon {
    final diff = dueDate.difference(DateTime.now()).inDays;
    return !paid && diff >= 0 && diff <= 14;
  }
}
