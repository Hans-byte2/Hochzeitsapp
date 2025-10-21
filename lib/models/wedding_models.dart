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

  Guest({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.confirmed,
    required this.dietaryRequirements,
    this.tableNumber,
  });

  Guest copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? email,
    String? confirmed,
    String? dietaryRequirements,
    int? tableNumber,
  }) {
    return Guest(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      confirmed: confirmed ?? this.confirmed,
      dietaryRequirements: dietaryRequirements ?? this.dietaryRequirements,
      tableNumber: tableNumber ?? this.tableNumber,
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
    );
  }
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

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.category = 'other',
    this.priority = 'medium',
    this.deadline,
    this.completed = false,
    required this.createdDate,
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
    );
  }
}
