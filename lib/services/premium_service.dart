import 'package:sqflite/sqflite.dart';

/// Verwaltet den Premium-Status der App.
/// Singleton – wird einmal beim App-Start initialisiert,
/// danach überall per [PremiumService.instance] abrufbar.
class PremiumService {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  bool _isPremium = false;
  bool _isInitialized = false;

  /// Ob der Nutzer Premium hat.
  bool get isPremium => _isPremium;

  /// Ob der Service bereits initialisiert wurde.
  bool get isInitialized => _isInitialized;

  // ─── Limits ─────────────────────────────────────────────────────────────────

  /// Maximale Gästeanzahl in der Free-Version.
  static const int kFreeGuestLimit = 15;

  /// Maximale Tischanzahl in der Free-Version.
  static const int kFreeTableLimit = 15;

  // ─── Initialisierung ────────────────────────────────────────────────────────

  /// Muss einmal beim App-Start aufgerufen werden (vor MaterialApp).
  /// Liest den gespeicherten Premium-Status aus der Datenbank.
  Future<void> init(Database db) async {
    _isPremium = await _loadFromDb(db);
    _isInitialized = true;
  }

  // ─── Status lesen ───────────────────────────────────────────────────────────

  Future<bool> _loadFromDb(Database db) async {
    try {
      final result = await db.query(
        'app_settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: ['is_premium'],
      );
      if (result.isEmpty) return false;
      return result.first['value'] == '1';
    } catch (_) {
      return false;
    }
  }

  // ─── Status setzen ──────────────────────────────────────────────────────────

  /// Schaltet Premium frei (nach erfolgreichem Kauf aufrufen).
  Future<void> unlock(Database db) async {
    await _saveToDb(db, true);
    _isPremium = true;
  }

  /// Setzt Premium zurück (nur für Testzwecke oder Refund).
  Future<void> revoke(Database db) async {
    await _saveToDb(db, false);
    _isPremium = false;
  }

  Future<void> _saveToDb(Database db, bool value) async {
    await db.insert('app_settings', {
      'key': 'is_premium',
      'value': value ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── Gäste ──────────────────────────────────────────────────────────────────

  /// Maximale Gästeanzahl für den aktuellen Plan.
  int get guestLimit => _isPremium ? 999999 : kFreeGuestLimit;

  /// Ob ein weiterer Gast hinzugefügt werden darf.
  bool canAddGuest(int currentCount) {
    if (_isPremium) return true;
    return currentCount < kFreeGuestLimit;
  }

  // ─── Tischplanung ───────────────────────────────────────────────────────────

  /// Maximale Tischanzahl für den aktuellen Plan.
  int get tableLimit => _isPremium ? 999999 : kFreeTableLimit;

  /// Ob ein weiterer Tisch hinzugefügt werden darf.
  bool canAddTable(int currentCount) {
    if (_isPremium) return true;
    return currentCount < kFreeTableLimit;
  }

  // ─── Partner-Sync ───────────────────────────────────────────────────────────

  /// Partner-Sync nur in Premium.
  bool get canUsePartnerSync => _isPremium;

  // ─── KI-Features ────────────────────────────────────────────────────────────

  /// Alle KI-Features (Budget-Dialog, Ampeln, Szenarien, Gast-Scoring) nur in Premium.
  bool get canUseAI => _isPremium;

  // ─── Export ─────────────────────────────────────────────────────────────────

  /// In Free: nur Gästeliste exportierbar.
  /// In Premium: alle Exporte (Budget, Tasks, Tische, Dienstleister).
  bool get canExportGuestList => true; // immer erlaubt
  bool get canExportBudget => _isPremium;
  bool get canExportTasks => _isPremium;
  bool get canExportTables => _isPremium;
  bool get canExportVendors => _isPremium;

  // ─── Budget ─────────────────────────────────────────────────────────────────

  /// Basis Budget-Tracking immer verfügbar.
  /// Smart Budget (KI-Dialog, Ampeln, Auto-Aufteilung) nur Premium.
  bool get canUseSmartBudget => _isPremium;

  // ─── Zahlungsplan ───────────────────────────────────────────────────────────

  bool get canUsePaymentPlan => _isPremium;

  // ─── Notifications ──────────────────────────────────────────────────────────

  bool get canUseNotifications => _isPremium;

  // ─── Budget PDF-Report ──────────────────────────────────────────────────────

  bool get canUseBudgetPdf => _isPremium;
}
