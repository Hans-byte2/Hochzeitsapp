// lib/config/sync_config.dart
// ═══════════════════════════════════════════════════════════════
// SYNC KONFIGURATION – Hier nur deine Supabase-Keys eintragen!
// ═══════════════════════════════════════════════════════════════

class SyncConfig {
  // ── Supabase ────────────────────────────────────────────────
  static const String supabaseUrl =
      'https://qtmjqphsadffapbmfhgl.supabase.co'; // z.B. https://xyzxyz.supabase.co
  static const String supabaseAnonKey =
      'sb_publishable_XYCkxX5_GB69ramzoQHszA_iPUmramG';

  // ── Pairing ─────────────────────────────────────────────────
  /// Wie lange ein Pairing-Code gültig ist (in Minuten)
  static const int pairingCodeExpiryMinutes = 10;

  /// Länge des angezeigten Pairing-Codes
  static const int pairingCodeLength = 6;

  // ── Sync-Verhalten ──────────────────────────────────────────
  /// Intervall für automatischen Hintergrund-Sync (in Sekunden)
  static const int autoSyncIntervalSeconds = 30;

  /// Maximale Anzahl Sync-Einträge pro Übertragung (Batching)
  static const int maxSyncBatchSize = 100;

  // ── Tabellennamen in Supabase ────────────────────────────────
  static const String pairsTable = 'device_pairs';
  static const String syncChannel = 'heartpebble-sync';

  // ── Debug ───────────────────────────────────────────────────
  static const bool enableDebugLogs = true;
}
