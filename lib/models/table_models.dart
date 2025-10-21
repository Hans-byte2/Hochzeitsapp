// ================================
// TABLE DATA MODEL
// ================================

class TableData {
  final int id;
  final String tableName;
  final int tableNumber;
  final int seats;

  TableData({
    required this.id,
    required this.tableName,
    required this.tableNumber,
    required this.seats,
  });

  TableData copyWith({
    int? id,
    String? tableName,
    int? tableNumber,
    int? seats,
  }) {
    return TableData(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      tableNumber: tableNumber ?? this.tableNumber,
      seats: seats ?? this.seats,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'table_number': tableNumber,
      'seats': seats,
    };
  }

  factory TableData.fromMap(Map<String, dynamic> map) {
    return TableData(
      id: map['id'],
      tableName: map['table_name'] ?? '',
      tableNumber: map['table_number'],
      seats: map['seats'] ?? 8,
    );
  }
}
