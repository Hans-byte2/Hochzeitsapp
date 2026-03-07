// lib/sync/models/sync_models.dart
import 'dart:convert';

enum SyncTable {
  guests,
  tasks,
  budgetItems,
  tables,
  weddingData,
  dienstleister, // ← NEU
}

extension SyncTableExtension on SyncTable {
  String get dbName {
    switch (this) {
      case SyncTable.guests:
        return 'guests';
      case SyncTable.tasks:
        return 'tasks';
      case SyncTable.budgetItems:
        return 'budget_items';
      case SyncTable.tables:
        return 'tables';
      case SyncTable.weddingData:
        return 'wedding_data';
      case SyncTable.dienstleister:
        return 'dienstleister';
    }
  }

  /// Dienstleister nutzen String-IDs (UUID-ähnlich), alle anderen Integer-IDs.
  bool get hasStringId => this == SyncTable.dienstleister;
}

class SyncRecord {
  final SyncTable table;
  final int localId;
  final Map<String, dynamic> data;
  final String updatedAt;
  final bool isDeleted;

  const SyncRecord({
    required this.table,
    required this.localId,
    required this.data,
    required this.updatedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toJson() => {
    'table': table.dbName,
    'local_id': localId,
    'data': data,
    'updated_at': updatedAt,
    'is_deleted': isDeleted,
  };

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    final tableName = json['table'] as String;
    final table = SyncTable.values.firstWhere(
      (t) => t.dbName == tableName,
      orElse: () => SyncTable.guests,
    );
    return SyncRecord(
      table: table,
      localId: json['local_id'] as int,
      data: Map<String, dynamic>.from(json['data'] as Map),
      updatedAt: json['updated_at'] as String,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );
  }
}

class SyncPayload {
  final String senderDeviceId;
  final String sentAt;
  final List<SyncRecord> records;
  final SyncPayloadType type;

  const SyncPayload({
    required this.senderDeviceId,
    required this.sentAt,
    required this.records,
    required this.type,
  });

  String toJsonString() => jsonEncode({
    'sender_device_id': senderDeviceId,
    'sent_at': sentAt,
    'records': records.map((r) => r.toJson()).toList(),
    'type': type.name,
  });

  factory SyncPayload.fromJsonString(String jsonStr) {
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return SyncPayload(
      senderDeviceId: json['sender_device_id'] as String,
      sentAt: json['sent_at'] as String,
      records: (json['records'] as List)
          .map((r) => SyncRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
      type: SyncPayloadType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => SyncPayloadType.delta,
      ),
    );
  }
}

enum SyncPayloadType { delta, full, ping, pong, requestFull }

class PairInfo {
  final String pairId;
  final String myDeviceId;
  final String partnerDeviceId;
  final String pairedAt;

  const PairInfo({
    required this.pairId,
    required this.myDeviceId,
    required this.partnerDeviceId,
    required this.pairedAt,
  });

  Map<String, dynamic> toMap() => {
    'pair_id': pairId,
    'my_device_id': myDeviceId,
    'partner_device_id': partnerDeviceId,
    'paired_at': pairedAt,
  };

  factory PairInfo.fromMap(Map<String, dynamic> map) => PairInfo(
    pairId: map['pair_id'] as String,
    myDeviceId: map['my_device_id'] as String,
    partnerDeviceId: map['partner_device_id'] as String,
    pairedAt: map['paired_at'] as String,
  );
}

enum SyncConnectionState {
  unpaired,
  connecting,
  connected,
  partnerOffline,
  syncing,
  error,
}

class SyncStatus {
  final SyncConnectionState connectionState;
  final DateTime? lastSyncAt;
  final int? pendingChanges;
  final String? errorMessage;
  final bool isPartnerOnline;

  const SyncStatus({
    required this.connectionState,
    this.lastSyncAt,
    this.pendingChanges,
    this.errorMessage,
    this.isPartnerOnline = false,
  });

  SyncStatus copyWith({
    SyncConnectionState? connectionState,
    DateTime? lastSyncAt,
    int? pendingChanges,
    String? errorMessage,
    bool? isPartnerOnline,
  }) => SyncStatus(
    connectionState: connectionState ?? this.connectionState,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    pendingChanges: pendingChanges ?? this.pendingChanges,
    errorMessage: errorMessage ?? this.errorMessage,
    isPartnerOnline: isPartnerOnline ?? this.isPartnerOnline,
  );

  bool get isPaired => connectionState != SyncConnectionState.unpaired;
  bool get canSync =>
      connectionState == SyncConnectionState.connected ||
      connectionState == SyncConnectionState.partnerOffline;
}
