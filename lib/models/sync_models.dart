/// Datenmodelle für Export/Import

class SyncData {
  final int version;
  final DateTime exportedAt;
  final Map<String, dynamic>? weddingInfo;
  final List<Map<String, dynamic>> guests;
  final List<Map<String, dynamic>> budgetItems;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> serviceProviders;

  SyncData({
    required this.version,
    required this.exportedAt,
    this.weddingInfo,
    required this.guests,
    required this.budgetItems,
    required this.tasks,
    required this.tables,
    required this.serviceProviders,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exported_at': exportedAt?.toIso8601String(),
      'wedding_info': weddingInfo,
      'guests': guests,
      'budget_items': budgetItems,
      'tasks': tasks,
      'tables': tables,
      'service_providers': serviceProviders,
    };
  }

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      version: json['version'] ?? 1,
      exportedAt: DateTime.parse(json['exported_at']),
      weddingInfo: json['wedding_info'],
      guests: List<Map<String, dynamic>>.from(json['guests'] ?? []),
      budgetItems: List<Map<String, dynamic>>.from(json['budget_items'] ?? []),
      tasks: List<Map<String, dynamic>>.from(json['tasks'] ?? []),
      tables: List<Map<String, dynamic>>.from(json['tables'] ?? []),
      serviceProviders: List<Map<String, dynamic>>.from(
        json['service_providers'] ?? [],
      ),
    );
  }
}

class ImportResult {
  final bool success;
  final String message;
  final ImportStatistics? statistics;

  ImportResult({required this.success, required this.message, this.statistics});
}

class ImportStatistics {
  final int guestsAdded;
  final int guestsUpdated;
  final int budgetItemsAdded;
  final int budgetItemsUpdated;
  final int tasksAdded;
  final int tasksUpdated;
  final int tablesAdded;
  final int tablesUpdated;
  final int serviceProvidersAdded;
  final int serviceProvidersUpdated;

  ImportStatistics({
    required this.guestsAdded,
    required this.guestsUpdated,
    required this.budgetItemsAdded,
    required this.budgetItemsUpdated,
    required this.tasksAdded,
    required this.tasksUpdated,
    required this.tablesAdded,
    required this.tablesUpdated,
    required this.serviceProvidersAdded,
    required this.serviceProvidersUpdated,
  });

  int get totalAdded =>
      guestsAdded +
      budgetItemsAdded +
      tasksAdded +
      tablesAdded +
      serviceProvidersAdded;

  int get totalUpdated =>
      guestsUpdated +
      budgetItemsUpdated +
      tasksUpdated +
      tablesUpdated +
      serviceProvidersUpdated;

  int get totalChanges => totalAdded + totalUpdated;

  @override
  String toString() {
    final parts = <String>[];

    if (guestsAdded > 0) parts.add('$guestsAdded Gäste hinzugefügt');
    if (guestsUpdated > 0) parts.add('$guestsUpdated Gäste aktualisiert');
    if (budgetItemsAdded > 0)
      parts.add('$budgetItemsAdded Budget-Einträge hinzugefügt');
    if (budgetItemsUpdated > 0)
      parts.add('$budgetItemsUpdated Budget-Einträge aktualisiert');
    if (tasksAdded > 0) parts.add('$tasksAdded Aufgaben hinzugefügt');
    if (tasksUpdated > 0) parts.add('$tasksUpdated Aufgaben aktualisiert');
    if (tablesAdded > 0) parts.add('$tablesAdded Tische hinzugefügt');
    if (tablesUpdated > 0) parts.add('$tablesUpdated Tische aktualisiert');
    if (serviceProvidersAdded > 0)
      parts.add('$serviceProvidersAdded Dienstleister hinzugefügt');
    if (serviceProvidersUpdated > 0)
      parts.add('$serviceProvidersUpdated Dienstleister aktualisiert');

    if (parts.isEmpty) {
      return 'Keine Änderungen';
    }

    return parts.join(', ');
  }

  String toDetailedString() {
    return '''
Importiert:
  Gäste: $guestsAdded neu, $guestsUpdated aktualisiert
  Budget: $budgetItemsAdded neu, $budgetItemsUpdated aktualisiert
  Aufgaben: $tasksAdded neu, $tasksUpdated aktualisiert
  Tische: $tablesAdded neu, $tablesUpdated aktualisiert
  Dienstleister: $serviceProvidersAdded neu, $serviceProvidersUpdated aktualisiert
  
Gesamt: $totalAdded neu, $totalUpdated aktualisiert
''';
  }
}
