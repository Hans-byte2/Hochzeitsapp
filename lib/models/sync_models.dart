// lib/models/sync_models.dart
//
// V6 – Payment Plans in Sync eingebunden

class SyncData {
  final int version;
  final DateTime exportedAt;
  final List<Map<String, dynamic>> guests;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> budgetItems;
  final List<Map<String, dynamic>> tables;
  final List<Map<String, dynamic>> serviceProviders;
  final List<Map<String, dynamic>> paymentPlans; // NEU v6
  final Map<String, dynamic>? weddingInfo;

  SyncData({
    required this.version,
    required this.exportedAt,
    required this.guests,
    required this.tasks,
    required this.budgetItems,
    required this.tables,
    required this.serviceProviders,
    this.paymentPlans = const [],
    this.weddingInfo,
  });

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'exportedAt': exportedAt.toIso8601String(),
      'guests': guests,
      'tasks': tasks,
      'budgetItems': budgetItems,
      'tables': tables,
      'serviceProviders': serviceProviders,
      'paymentPlans': paymentPlans,
      'weddingInfo': weddingInfo,
    };
  }

  factory SyncData.fromJson(Map<String, dynamic> json) {
    return SyncData(
      version: json['version'] ?? 1,
      exportedAt: DateTime.parse(json['exportedAt']),
      guests: List<Map<String, dynamic>>.from(json['guests'] ?? []),
      tasks: List<Map<String, dynamic>>.from(json['tasks'] ?? []),
      budgetItems: List<Map<String, dynamic>>.from(json['budgetItems'] ?? []),
      tables: List<Map<String, dynamic>>.from(json['tables'] ?? []),
      serviceProviders: List<Map<String, dynamic>>.from(
        json['serviceProviders'] ?? [],
      ),
      // Ältere .heartpebble Dateien haben paymentPlans nicht → leere Liste
      paymentPlans: List<Map<String, dynamic>>.from(json['paymentPlans'] ?? []),
      weddingInfo: json['weddingInfo'],
    );
  }
}

class ImportResult {
  final bool success;
  final String message;
  final ImportStatistics statistics;

  ImportResult({
    required this.success,
    required this.message,
    required this.statistics,
  });
}

class ImportStatistics {
  final int guestsAdded;
  final int guestsUpdated;
  final int guestsDeleted;
  final int guestsSkipped;

  final int budgetItemsAdded;
  final int budgetItemsUpdated;
  final int budgetItemsDeleted;
  final int budgetItemsSkipped;

  final int tasksAdded;
  final int tasksUpdated;
  final int tasksDeleted;
  final int tasksSkipped;

  final int tablesAdded;
  final int tablesUpdated;
  final int tablesDeleted;
  final int tablesSkipped;

  final int serviceProvidersAdded;
  final int serviceProvidersUpdated;
  final int serviceProvidersDeleted;
  final int serviceProvidersSkipped;

  // NEU v6: Payment Plans
  final int paymentPlansAdded;
  final int paymentPlansUpdated;
  final int paymentPlansDeleted;
  final int paymentPlansSkipped;

  ImportStatistics({
    this.guestsAdded = 0,
    this.guestsUpdated = 0,
    this.guestsDeleted = 0,
    this.guestsSkipped = 0,
    this.budgetItemsAdded = 0,
    this.budgetItemsUpdated = 0,
    this.budgetItemsDeleted = 0,
    this.budgetItemsSkipped = 0,
    this.tasksAdded = 0,
    this.tasksUpdated = 0,
    this.tasksDeleted = 0,
    this.tasksSkipped = 0,
    this.tablesAdded = 0,
    this.tablesUpdated = 0,
    this.tablesDeleted = 0,
    this.tablesSkipped = 0,
    this.serviceProvidersAdded = 0,
    this.serviceProvidersUpdated = 0,
    this.serviceProvidersDeleted = 0,
    this.serviceProvidersSkipped = 0,
    this.paymentPlansAdded = 0,
    this.paymentPlansUpdated = 0,
    this.paymentPlansDeleted = 0,
    this.paymentPlansSkipped = 0,
  });

  String toDetailedString() {
    final List<String> parts = [];

    if (guestsAdded > 0) parts.add('✅ $guestsAdded Gäste hinzugefügt');
    if (guestsUpdated > 0) parts.add('🔄 $guestsUpdated Gäste aktualisiert');
    if (guestsDeleted > 0) parts.add('🗑️ $guestsDeleted Gäste gelöscht');
    if (guestsSkipped > 0) {
      parts.add('⏭️ $guestsSkipped Gäste übersprungen (lokal neuer)');
    }

    if (budgetItemsAdded > 0) {
      parts.add('✅ $budgetItemsAdded Budget-Einträge hinzugefügt');
    }
    if (budgetItemsUpdated > 0) {
      parts.add('🔄 $budgetItemsUpdated Budget-Einträge aktualisiert');
    }
    if (budgetItemsDeleted > 0) {
      parts.add('🗑️ $budgetItemsDeleted Budget-Einträge gelöscht');
    }
    if (budgetItemsSkipped > 0) {
      parts.add('⏭️ $budgetItemsSkipped Budget übersprungen');
    }

    if (tasksAdded > 0) parts.add('✅ $tasksAdded Aufgaben hinzugefügt');
    if (tasksUpdated > 0) parts.add('🔄 $tasksUpdated Aufgaben aktualisiert');
    if (tasksDeleted > 0) parts.add('🗑️ $tasksDeleted Aufgaben gelöscht');
    if (tasksSkipped > 0) parts.add('⏭️ $tasksSkipped Aufgaben übersprungen');

    if (tablesAdded > 0) parts.add('✅ $tablesAdded Tische hinzugefügt');
    if (tablesUpdated > 0) parts.add('🔄 $tablesUpdated Tische aktualisiert');
    if (tablesDeleted > 0) parts.add('🗑️ $tablesDeleted Tische gelöscht');
    if (tablesSkipped > 0) parts.add('⏭️ $tablesSkipped Tische übersprungen');

    if (serviceProvidersAdded > 0) {
      parts.add('✅ $serviceProvidersAdded Dienstleister hinzugefügt');
    }
    if (serviceProvidersUpdated > 0) {
      parts.add('🔄 $serviceProvidersUpdated Dienstleister aktualisiert');
    }
    if (serviceProvidersDeleted > 0) {
      parts.add('🗑️ $serviceProvidersDeleted Dienstleister gelöscht');
    }
    if (serviceProvidersSkipped > 0) {
      parts.add('⏭️ $serviceProvidersSkipped Dienstleister übersprungen');
    }

    if (paymentPlansAdded > 0) {
      parts.add('✅ $paymentPlansAdded Zahlungspläne hinzugefügt');
    }
    if (paymentPlansUpdated > 0) {
      parts.add('🔄 $paymentPlansUpdated Zahlungspläne aktualisiert');
    }
    if (paymentPlansDeleted > 0) {
      parts.add('🗑️ $paymentPlansDeleted Zahlungspläne gelöscht');
    }
    if (paymentPlansSkipped > 0) {
      parts.add(
        '⏭️ $paymentPlansSkipped Zahlungspläne übersprungen (lokal neuer)',
      );
    }

    return parts.isEmpty ? 'Keine Änderungen' : parts.join('\n');
  }

  String toShortString() {
    final total =
        guestsAdded +
        guestsUpdated +
        guestsDeleted +
        budgetItemsAdded +
        budgetItemsUpdated +
        budgetItemsDeleted +
        tasksAdded +
        tasksUpdated +
        tasksDeleted +
        tablesAdded +
        tablesUpdated +
        tablesDeleted +
        serviceProvidersAdded +
        serviceProvidersUpdated +
        serviceProvidersDeleted +
        paymentPlansAdded +
        paymentPlansUpdated +
        paymentPlansDeleted;

    if (total == 0) return 'Keine Änderungen';
    return '$total Änderungen synchronisiert';
  }

  bool get hadConflicts {
    return guestsSkipped > 0 ||
        budgetItemsSkipped > 0 ||
        tasksSkipped > 0 ||
        tablesSkipped > 0 ||
        serviceProvidersSkipped > 0 ||
        paymentPlansSkipped > 0;
  }

  bool get hadDeletions {
    return guestsDeleted > 0 ||
        budgetItemsDeleted > 0 ||
        tasksDeleted > 0 ||
        tablesDeleted > 0 ||
        serviceProvidersDeleted > 0 ||
        paymentPlansDeleted > 0;
  }
}
