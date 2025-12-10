// lib/models/wedding_models.dart
//
// COMPLETE VERSION mit Timestamps + Soft Deletes + Location

// ================================
// GUEST MODEL
// ================================

class Guest {
  final int? id;
  final String firstName;
  final String lastName;
  final String email;
  final String confirmed;
  final String dietaryRequirements;
  final int? tableNumber;

  // NEU: Timestamps + Soft Delete
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;

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
  });

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
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
    };
  }

  factory Guest.fromMap(Map<String, dynamic> map) {
    return Guest(
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
    );
  }

  bool get isDeleted => deleted == 1;
}

// ================================
// TASK MODEL (MIT LOCATION!)
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

  // NEU: Location-Feld
  final String location;

  // NEU: Timestamps + Soft Delete
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
    this.location = '', // NEU!
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
    String? location, // NEU!
    String? updatedAt,
    int? deleted,
    String? deletedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      deadline: deadline ?? this.deadline,
      completed: completed ?? this.completed,
      createdDate: createdDate ?? this.createdDate,
      location: location ?? this.location, // NEU!
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'deadline': deadline?.toIso8601String(),
      'completed': completed ? 1 : 0,
      'created_date': createdDate.toIso8601String(),
      'location': location, // NEU!
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'deleted': deleted,
      'deleted_at': deletedAt,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id']?.toInt(),
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'other',
      priority: map['priority'] ?? 'medium',
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'])
          : null,
      completed: map['completed'] == 1,
      createdDate: DateTime.parse(map['created_date']),
      location: map['location'] ?? '', // NEU!
      updatedAt: map['updated_at'],
      deleted: map['deleted'] ?? 0,
      deletedAt: map['deleted_at'],
    );
  }

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

  // NEU: Timestamps + Soft Delete
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
  }) {
    return BudgetItem(
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
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'deleted': deleted,
      'deleted_at': deletedAt,
    };
  }

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
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
  }

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

  // NEU: Timestamps + Soft Delete
  final String? updatedAt;
  final int deleted;
  final String? deletedAt;

  TableModel({
    this.id,
    required this.tableName,
    required this.tableNumber,
    this.seats = 8,
    this.updatedAt,
    this.deleted = 0,
    this.deletedAt,
  });

  TableModel copyWith({
    int? id,
    String? tableName,
    int? tableNumber,
    int? seats,
    String? updatedAt,
    int? deleted,
    String? deletedAt,
  }) {
    return TableModel(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      tableNumber: tableNumber ?? this.tableNumber,
      seats: seats ?? this.seats,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'table_number': tableNumber,
      'seats': seats,
      'updated_at': updatedAt ?? DateTime.now().toIso8601String(),
      'deleted': deleted,
      'deleted_at': deletedAt,
    };
  }

  factory TableModel.fromMap(Map<String, dynamic> map) {
    return TableModel(
      id: map['id']?.toInt(),
      tableName: map['table_name'] ?? '',
      tableNumber: map['table_number']?.toInt() ?? 0,
      seats: map['seats']?.toInt() ?? 8,
      updatedAt: map['updated_at'],
      deleted: map['deleted'] ?? 0,
      deletedAt: map['deleted_at'],
    );
  }

  bool get isDeleted => deleted == 1;
}
