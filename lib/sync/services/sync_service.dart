// lib/sync/services/sync_service.dart
// ═══════════════════════════════════════════════════════════════
// SYNC SERVICE – HAUPT-ORCHESTRATOR
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sync_models.dart';
import 'sync_repository.dart';
import 'supabase_signaling.dart';
import 'sync_logger.dart';
import '../../config/sync_config.dart';

class SyncService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────
  static final SyncService instance = SyncService._();
  SyncService._();

  final _repository = SyncRepository();
  final _signaling = SupabaseSignaling.instance;

  SyncStatus _status = const SyncStatus(
    connectionState: SyncConnectionState.unpaired,
  );

  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  // ── Öffentlicher Zustand ─────────────────────────────────────

  SyncStatus get status => _status;
  bool get isPaired => _signaling.isPaired;
  PairInfo? get pairInfo => _signaling.pairInfo;

  // ── Initialisierung ──────────────────────────────────────────

  Future<void> initialize() async {
    SyncLogger.info('SyncService wird initialisiert...');

    _signaling.onMessageReceived = _onPayloadReceived;
    _signaling.onPartnerStatusChanged = _onPartnerStatusChanged;

    try {
      await _signaling.initialize();

      if (_signaling.isPaired) {
        _setStatus(
          _status.copyWith(connectionState: SyncConnectionState.connecting),
        );
        _startAutoSync();
      }

      SyncLogger.success('SyncService bereit');
    } catch (e) {
      _setStatus(
        _status.copyWith(
          connectionState: SyncConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
      SyncLogger.error('SyncService Initialisierung fehlgeschlagen', e);
    }
  }

  // ── Pairing ──────────────────────────────────────────────────

  Future<String> createPairingCode() async {
    return _signaling.createPairingCode();
  }

  Future<PairInfo?> waitForPartner(String code) async {
    final pairInfo = await _signaling.waitForPartner(code);
    if (pairInfo != null) {
      _onPaired(pairInfo);
    }
    return pairInfo;
  }

  Future<PairInfo?> joinWithCode(String code) async {
    final pairInfo = await _signaling.joinWithCode(code);
    if (pairInfo != null) {
      _onPaired(pairInfo);
    }
    return pairInfo;
  }

  void _onPaired(PairInfo pairInfo) {
    SyncLogger.success('Pairing erfolgreich: ${pairInfo.pairId}');
    _setStatus(
      _status.copyWith(connectionState: SyncConnectionState.connected),
    );
    _startAutoSync();
    syncNow(fullSync: true);
  }

  Future<void> unpair() async {
    _stopAutoSync();
    await _signaling.unpair();
    _setStatus(const SyncStatus(connectionState: SyncConnectionState.unpaired));
    SyncLogger.info('Pairing aufgehoben');
  }

  // ── Sync senden ──────────────────────────────────────────────

  /// Sendet lokale Änderungen an den Partner.
  /// Verwendet ausschließlich _lastSentKey – wird NICHT durch
  /// empfangene Daten zurückgesetzt.
  Future<void> syncNow({bool fullSync = false}) async {
    if (!isPaired) {
      SyncLogger.info('Kein Pairing – Sync übersprungen');
      return;
    }
    if (_isSyncing) {
      SyncLogger.info('Sync läuft bereits');
      return;
    }

    _isSyncing = true;
    _setStatus(_status.copyWith(connectionState: SyncConnectionState.syncing));

    try {
      // Letzten Sende-Zeitpunkt laden (getrennt vom Empfangs-Zeitpunkt!)
      final lastSentAt = fullSync ? null : await _repository.getLastSyncedAt();

      final records = await _repository.getChangedRecords(since: lastSentAt);

      if (records.isEmpty && !fullSync) {
        SyncLogger.info('Keine lokalen Änderungen seit $lastSentAt');
      } else {
        final myDeviceId = await _signaling.getOrCreateDeviceId();
        final payload = SyncPayload(
          senderDeviceId: myDeviceId,
          sentAt: DateTime.now().toIso8601String(),
          records: records,
          type: fullSync ? SyncPayloadType.full : SyncPayloadType.delta,
        );

        await _signaling.sendPayload(payload);
        SyncLogger.success(
          '${records.length} Records gesendet (${payload.type.name})',
        );
      }

      // NUR Sende-Timestamp aktualisieren
      final now = DateTime.now().toIso8601String();
      await _repository.setLastSyncedAt(now);

      _setStatus(
        _status.copyWith(
          connectionState: _status.isPartnerOnline
              ? SyncConnectionState.connected
              : SyncConnectionState.partnerOffline,
          lastSyncAt: DateTime.now(),
          pendingChanges: 0,
        ),
      );
    } catch (e) {
      SyncLogger.error('Sync fehlgeschlagen', e);
      _setStatus(
        _status.copyWith(
          connectionState: SyncConnectionState.error,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      _isSyncing = false;
    }
  }

  // ── Eingehende Nachrichten ───────────────────────────────────

  void _onPayloadReceived(SyncPayload payload) async {
    SyncLogger.info(
      'Payload empfangen: ${payload.type.name}, '
      '${payload.records.length} Records von ${payload.senderDeviceId}',
    );

    if (payload.type == SyncPayloadType.ping) {
      final myDeviceId = await _signaling.getOrCreateDeviceId();
      await _signaling.sendPayload(
        SyncPayload(
          senderDeviceId: myDeviceId,
          sentAt: DateTime.now().toIso8601String(),
          records: [],
          type: SyncPayloadType.pong,
        ),
      );
      return;
    }

    if (payload.type == SyncPayloadType.requestFull) {
      await syncNow(fullSync: true);
      return;
    }

    if (payload.records.isNotEmpty) {
      final result = await _repository.applyRecords(payload.records);
      SyncLogger.success('Empfangene Daten angewendet: $result');

      // UI benachrichtigen
      notifyListeners();
    }

    // ⚠️ KEIN setLastSyncedAt hier! Das würde den Sende-Timestamp
    // überschreiben und Gerät B würde danach seine eigenen Änderungen
    // nicht mehr als "neu" erkennen → Richtungsfehler.
    // Der Empfangs-Timestamp wird in applyRecords() selbst gesetzt.

    _setStatus(_status.copyWith(lastSyncAt: DateTime.now()));
  }

  void _onPartnerStatusChanged(bool isOnline) {
    SyncLogger.info('Partner ${isOnline ? "online" : "offline"}');

    _setStatus(
      _status.copyWith(
        isPartnerOnline: isOnline,
        connectionState: isOnline
            ? SyncConnectionState.connected
            : SyncConnectionState.partnerOffline,
      ),
    );

    if (isOnline && !_isSyncing) {
      syncNow();
    }
  }

  // ── Auto-Sync ────────────────────────────────────────────────

  void _startAutoSync() {
    _stopAutoSync();
    _autoSyncTimer = Timer.periodic(
      Duration(seconds: SyncConfig.autoSyncIntervalSeconds),
      (_) => syncNow(),
    );
    SyncLogger.info(
      'Auto-Sync gestartet (alle ${SyncConfig.autoSyncIntervalSeconds}s)',
    );
  }

  void _stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  // ── Pending Changes ──────────────────────────────────────────

  Future<void> refreshPendingChanges() async {
    final lastSyncedAt = await _repository.getLastSyncedAt();
    final count = await _repository.countPendingChanges(lastSyncedAt);
    _setStatus(_status.copyWith(pendingChanges: count));
  }

  // ── Hilfsmethoden ───────────────────────────────────────────

  void _setStatus(SyncStatus newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopAutoSync();
    super.dispose();
  }
}
