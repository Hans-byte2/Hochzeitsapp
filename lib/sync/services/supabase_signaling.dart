// lib/sync/services/supabase_signaling.dart
import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sync_models.dart';
import '../../config/sync_config.dart';
import 'sync_logger.dart';

typedef OnMessageReceived = void Function(SyncPayload payload);
typedef OnPartnerStatusChanged = void Function(bool isOnline);

class SupabaseSignaling {
  static final SupabaseSignaling instance = SupabaseSignaling._();
  SupabaseSignaling._();

  static const String _pairInfoKey = 'sync_pair_info';
  static const String _deviceIdKey = 'sync_device_id';

  SupabaseClient? _client;
  RealtimeChannel? _channel;
  PairInfo? _pairInfo;

  OnMessageReceived? onMessageReceived;
  OnPartnerStatusChanged? onPartnerStatusChanged;

  // Zählt wie viele Partner-Presence-Events aktiv sind
  int _partnerPresenceCount = 0;

  bool get isInitialized => _client != null;
  PairInfo? get pairInfo => _pairInfo;
  bool get isPaired => _pairInfo != null;

  Future<void> initialize() async {
    if (_client != null) return;
    try {
      await Supabase.initialize(
        url: SyncConfig.supabaseUrl,
        anonKey: SyncConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      SyncLogger.success('Supabase initialisiert');
      await _loadPairInfo();
      if (_pairInfo != null) {
        await _subscribeToChannel(_pairInfo!);
        SyncLogger.info('Gespeichertes Pairing geladen: ${_pairInfo!.pairId}');
      }
    } catch (e) {
      SyncLogger.error('Supabase Initialisierung fehlgeschlagen', e);
      rethrow;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);
    if (deviceId == null) {
      deviceId = _generateSimpleUuid();
      await prefs.setString(_deviceIdKey, deviceId);
      SyncLogger.info('Neue Geräte-ID erstellt: $deviceId');
    }
    return deviceId;
  }

  String _generateSimpleUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.hashCode.abs().toString().padLeft(8, '0');
    return 'hp-$random-${now.toString().substring(now.toString().length - 6)}';
  }

  Future<String> createPairingCode() async {
    _ensureInitialized();
    final deviceId = await getOrCreateDeviceId();
    final code = _generatePairingCode();
    final expiresAt = DateTime.now()
        .add(Duration(minutes: SyncConfig.pairingCodeExpiryMinutes))
        .toIso8601String();
    try {
      await _client!.from(SyncConfig.pairsTable).insert({
        'pair_code': code,
        'device_a_id': deviceId,
        'device_b_id': null,
        'expires_at': expiresAt,
        'status': 'waiting',
      });
      SyncLogger.info('Pairing-Code erstellt: $code');
      return code;
    } catch (e) {
      SyncLogger.error('Fehler beim Erstellen des Pairing-Codes', e);
      rethrow;
    }
  }

  Future<PairInfo?> waitForPartner(
    String code, {
    Duration timeout = const Duration(minutes: 10),
  }) async {
    _ensureInitialized();
    final deviceId = await getOrCreateDeviceId();
    final completer = Completer<PairInfo?>();
    Timer? pollTimer;
    Timer? timeoutTimer;

    timeoutTimer = Timer(timeout, () {
      pollTimer?.cancel();
      if (!completer.isCompleted) completer.complete(null);
    });

    pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final result = await _client!
            .from(SyncConfig.pairsTable)
            .select()
            .eq('pair_code', code)
            .eq('device_a_id', deviceId)
            .eq('status', 'paired')
            .maybeSingle();

        if (result != null) {
          pollTimer?.cancel();
          timeoutTimer?.cancel();
          final pairInfo = PairInfo(
            pairId: result['id'] as String,
            myDeviceId: deviceId,
            partnerDeviceId: result['device_b_id'] as String,
            pairedAt: DateTime.now().toIso8601String(),
          );
          await _savePairInfo(pairInfo);
          await _subscribeToChannel(pairInfo);
          if (!completer.isCompleted) completer.complete(pairInfo);
        }
      } catch (e) {
        SyncLogger.error('Polling-Fehler', e);
      }
    });

    return completer.future;
  }

  Future<PairInfo?> joinWithCode(String code) async {
    _ensureInitialized();
    final deviceId = await getOrCreateDeviceId();
    try {
      final existing = await _client!
          .from(SyncConfig.pairsTable)
          .select()
          .eq('pair_code', code.toUpperCase())
          .eq('status', 'waiting')
          .maybeSingle();

      if (existing == null) {
        SyncLogger.info('Code nicht gefunden oder abgelaufen: $code');
        return null;
      }

      final expiresAt = DateTime.parse(existing['expires_at'] as String);
      if (DateTime.now().isAfter(expiresAt)) {
        SyncLogger.info('Code abgelaufen: $code');
        return null;
      }

      final partnerDeviceId = existing['device_a_id'] as String;
      await _client!
          .from(SyncConfig.pairsTable)
          .update({'device_b_id': deviceId, 'status': 'paired'})
          .eq('pair_code', code.toUpperCase());

      final pairInfo = PairInfo(
        pairId: existing['id'] as String,
        myDeviceId: deviceId,
        partnerDeviceId: partnerDeviceId,
        pairedAt: DateTime.now().toIso8601String(),
      );
      await _savePairInfo(pairInfo);
      await _subscribeToChannel(pairInfo);
      SyncLogger.success('Pairing erfolgreich: ${pairInfo.pairId}');
      return pairInfo;
    } catch (e) {
      SyncLogger.error('Fehler beim Einlösen des Codes', e);
      rethrow;
    }
  }

  Future<void> _subscribeToChannel(PairInfo pairInfo) async {
    await _unsubscribe();
    _partnerPresenceCount = 0;

    final channelName = '${SyncConfig.syncChannel}:${pairInfo.pairId}';
    final myDeviceId = pairInfo.myDeviceId;

    _channel = _client!.channel(channelName);

    // Nachrichten empfangen
    _channel!.onBroadcast(
      event: 'sync',
      callback: (payload) {
        try {
          final jsonStr = payload['data'] as String?;
          if (jsonStr == null) return;
          final syncPayload = SyncPayload.fromJsonString(jsonStr);
          if (syncPayload.senderDeviceId == myDeviceId) return;
          SyncLogger.info(
            'Nachricht empfangen: ${syncPayload.type.name}, '
            '${syncPayload.records.length} Records',
          );
          onMessageReceived?.call(syncPayload);
        } catch (e) {
          SyncLogger.error('Fehler beim Verarbeiten der Nachricht', e);
        }
      },
    );

    // Presence: Zähler-basiert statt presenceState-Parsing
    _channel!.onPresenceSync((RealtimePresenceSyncPayload event) {
      SyncLogger.debug('Presence sync event: $event');
      // Online wenn mindestens 1 Presence-Zähler aktiv
      final isOnline = _partnerPresenceCount > 0;
      onPartnerStatusChanged?.call(isOnline);
    });

    _channel!.onPresenceJoin((RealtimePresenceJoinPayload newPresences) {
      _partnerPresenceCount++;
      SyncLogger.info('Partner joined, count: $_partnerPresenceCount');
      onPartnerStatusChanged?.call(true);
    });

    _channel!.onPresenceLeave((RealtimePresenceLeavePayload leftPresences) {
      if (_partnerPresenceCount > 0) _partnerPresenceCount--;
      SyncLogger.info('Partner left, count: $_partnerPresenceCount');
      onPartnerStatusChanged?.call(_partnerPresenceCount > 0);
    });

    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        SyncLogger.success('Realtime-Kanal verbunden: $channelName');
        _channel!.track({'online': true, 'device': myDeviceId});
      } else if (error != null) {
        SyncLogger.error('Kanal-Fehler: $status', error);
      }
    });
  }

  Future<void> sendPayload(SyncPayload payload) async {
    if (_channel == null) {
      SyncLogger.error('Kein aktiver Kanal');
      return;
    }
    try {
      await _channel!.sendBroadcastMessage(
        event: 'sync',
        payload: {'data': payload.toJsonString()},
      );
      SyncLogger.info(
        'Payload gesendet: ${payload.type.name}, ${payload.records.length} Records',
      );
    } catch (e) {
      SyncLogger.error('Fehler beim Senden des Payloads', e);
      rethrow;
    }
  }

  Future<void> unpair() async {
    await _unsubscribe();
    _pairInfo = null;
    _partnerPresenceCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pairInfoKey);
    SyncLogger.info('Pairing aufgehoben');
  }

  Future<void> _unsubscribe() async {
    if (_channel != null) {
      await _client?.removeChannel(_channel!);
      _channel = null;
    }
  }

  Future<void> _savePairInfo(PairInfo info) async {
    _pairInfo = info;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pairInfoKey, jsonEncode(info.toMap()));
    SyncLogger.info('PairInfo gespeichert');
  }

  Future<void> _loadPairInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_pairInfoKey);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _pairInfo = PairInfo.fromMap(map);
      } catch (e) {
        SyncLogger.error('Fehler beim Laden des PairInfo', e);
      }
    }
  }

  String _generatePairingCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    var seed = DateTime.now().millisecondsSinceEpoch;
    var code = '';
    for (int i = 0; i < SyncConfig.pairingCodeLength; i++) {
      seed = (seed * 1664525 + 1013904223) & 0xFFFFFFFF;
      code += chars[seed % chars.length];
    }
    return code;
  }

  void _ensureInitialized() {
    if (_client == null) {
      throw StateError(
        'SupabaseSignaling nicht initialisiert. Rufe initialize() zuerst auf.',
      );
    }
  }
}
