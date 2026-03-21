// lib/screens/settings_page.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/profile_providers.dart';
import '../services/theme_providers.dart';
import '../services/sync_service.dart';
import '../services/premium_service.dart';
import '../theme/theme_variant.dart';
import '../widgets/theme_picker_grid.dart';
import '../data/database_helper.dart';
import '../widgets/upgrade_bottom_sheet.dart';

class SettingsPage extends ConsumerWidget {
  final Future<void> Function()? onDataReloaded;

  const SettingsPage({super.key, this.onDataReloaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── FIX: Scaffold mit eigenem AppBar damit das ListView
    // die volle Höhe bekommt und korrekt scrollt, auch wenn
    // SettingsPage als Tab-Kind eingebettet ist.
    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _Section(title: 'Profil', child: _ProfileCard()),
          const SizedBox(height: 16),
          const _Section(title: 'Erscheinungsbild', child: _AppearanceCard()),
          const SizedBox(height: 16),
          _Section(
            title: 'Synchronisation',
            child: _SyncCard(onDataReloaded: onDataReloaded),
          ),
          const SizedBox(height: 16),
          const _Section(title: 'Allgemein', child: _GeneralCard()),
          const SizedBox(height: 16),
          const _Section(title: 'Über HeartPebble', child: _AboutCard()),
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            const _Section(
              title: '🛠 Debug – Premium',
              child: _DebugPremiumCard(),
            ),
          ],
          // Extra-Abstand am Ende damit der letzte Eintrag nicht vom
          // System-Navigationbereich verdeckt wird.
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================================
// DEBUG PREMIUM CARD
// ============================================================================

class _DebugPremiumCard extends StatefulWidget {
  const _DebugPremiumCard();

  @override
  State<_DebugPremiumCard> createState() => _DebugPremiumCardState();
}

class _DebugPremiumCardState extends State<_DebugPremiumCard> {
  bool get _isPremium => PremiumService.instance.isPremium;

  Future<void> _unlock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('debug_force_free');
    final db = await DatabaseHelper.instance.database;
    await PremiumService.instance.unlock(db);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Premium aktiviert'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _revoke() async {
    final db = await DatabaseHelper.instance.database;
    await PremiumService.instance.revoke(db);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Premium deaktiviert'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetMigration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('premium_migration_v1');
    await prefs.setBool('debug_force_free', true);
    final db = await DatabaseHelper.instance.database;
    await PremiumService.instance.revoke(db);
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Migration zurückgesetzt – App neu starten!'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isPremium
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isPremium ? Colors.green : Colors.orange,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isPremium ? Icons.workspace_premium : Icons.lock_outline,
                color: _isPremium ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isPremium ? 'Premium aktiv' : 'Free-Version aktiv',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isPremium ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Feature-Flags:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _FlagChip(
              'Partner-Sync',
              PremiumService.instance.canUsePartnerSync,
            ),
            _FlagChip('KI-Features', PremiumService.instance.canUseAI),
            _FlagChip(
              'Zahlungsplan',
              PremiumService.instance.canUsePaymentPlan,
            ),
            _FlagChip(
              'Notifications',
              PremiumService.instance.canUseNotifications,
            ),
            _FlagChip(
              'Smart Budget',
              PremiumService.instance.canUseSmartBudget,
            ),
            _FlagChip('Budget PDF', PremiumService.instance.canUseBudgetPdf),
            _FlagChip('Export Budget', PremiumService.instance.canExportBudget),
            _FlagChip(
              'Gäste (${PremiumService.instance.guestLimit == 999999 ? '∞' : PremiumService.instance.guestLimit})',
              _isPremium,
            ),
            _FlagChip(
              'Tische (${PremiumService.instance.tableLimit == 999999 ? '∞' : PremiumService.instance.tableLimit})',
              _isPremium,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isPremium ? null : _unlock,
                icon: const Icon(Icons.workspace_premium, size: 18),
                label: const Text('Premium aktivieren'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isPremium ? _revoke : null,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Zurücksetzen'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetMigration,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Free testen (Migration zurücksetzen)'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nur im Debug-Build sichtbar. Im Release-Build durch In-App-Purchase ersetzt.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip(this.label, this.enabled);
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        '${enabled ? '✓' : '✗'} $label',
        style: TextStyle(
          fontSize: 11,
          color: enabled ? Colors.green : Colors.red,
        ),
      ),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: enabled
          ? Colors.green.withOpacity(0.08)
          : Colors.red.withOpacity(0.08),
      side: BorderSide(
        color: enabled
            ? Colors.green.withOpacity(0.3)
            : Colors.red.withOpacity(0.3),
      ),
    );
  }
}

// ============================================================================
// SECTION
// ============================================================================

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.titleMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textStyle),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ],
    );
  }
}

// ============================================================================
// PROFILE CARD
// ============================================================================

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => _pickImage(context, ref),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                backgroundImage: state.imagePath != null
                    ? FileImage(File(state.imagePath!))
                    : null,
                child: state.imagePath == null
                    ? const Icon(Icons.person, size: 36)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Profilbild für die Startseite festlegen.\nEs wird hinter den Eingabefeldern für\nNamen und Hochzeitsdatum angezeigt.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.imagePath != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => controller.setImagePath(null),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Profilbild entfernen'),
            ),
          ),
      ],
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final filename =
        'profile_${DateTime.now().millisecondsSinceEpoch.toString()}.jpg';
    final file = File('${dir.path}/$filename');
    await File(image.path).copy(file.path);
    await ref.read(profileControllerProvider.notifier).setImagePath(file.path);
    if (context.mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilbild aktualisiert')));
  }
}

// ============================================================================
// APPEARANCE CARD
// ============================================================================

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(themeControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Farbschema'),
        const SizedBox(height: 8),
        const ThemePickerGrid(),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('Schnellwahl'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ModeChip(
              label: 'Sand (hell)',
              onTap: () => controller.setVariant(ThemeVariant.sandVintageCream),
            ),
            _ModeChip(
              label: 'Vintage Mint',
              onTap: () => controller.setVariant(ThemeVariant.vintageMint),
            ),
            _ModeChip(
              label: 'Mint Fresh',
              onTap: () => controller.setVariant(ThemeVariant.mintFresh),
            ),
            _ModeChip(
              label: 'Frozen Mint',
              onTap: () => controller.setVariant(ThemeVariant.frozenMint),
            ),
            _ModeChip(
              label: 'Pink',
              onTap: () => controller.setVariant(ThemeVariant.romanticPink),
            ),
            _ModeChip(
              label: 'Creme',
              onTap: () => controller.setVariant(ThemeVariant.cremeElegance),
            ),
            _ModeChip(
              label: 'Gold',
              onTap: () => controller.setVariant(ThemeVariant.royalGold),
            ),
            _ModeChip(
              label: 'Schwarz/Weiß',
              onTap: () => controller.setVariant(ThemeVariant.blackWhite),
            ),
            _ModeChip(
              label: 'Dunkel',
              onTap: () => controller.setVariant(ThemeVariant.vintageMintDark),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      ActionChip(label: Text(label), onPressed: onTap);
}

// ============================================================================
// SYNC CARD
// ============================================================================

class _SyncCard extends ConsumerStatefulWidget {
  final Future<void> Function()? onDataReloaded;
  const _SyncCard({this.onDataReloaded});

  @override
  ConsumerState<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends ConsumerState<_SyncCard> {
  final SyncService _syncService = SyncService();
  bool _isExporting = false;
  bool _isImporting = false;
  String _databaseSize = '...';
  Map<String, int> _recordCounts = {};

  @override
  void initState() {
    super.initState();
    _loadDatabaseInfo();
  }

  Future<void> _loadDatabaseInfo() async {
    final size = await _syncService.getDatabaseSize();
    final counts = await _syncService.countAllRecords();
    if (mounted)
      setState(() {
        _databaseSize = size;
        _recordCounts = counts;
      });
  }

  void _onExportTapped() {
    if (!PremiumService.instance.canUsePartnerSync) {
      UpgradeBottomSheet.show(
        context,
        featureName: 'Partner-Sync',
        featureDescription:
            'Teile deine Hochzeitsplanung in Echtzeit mit deinem Partner. Export und Import sind ein Premium-Feature.',
      );
      return;
    }
    _handleExport();
  }

  void _onImportTapped() {
    if (!PremiumService.instance.canUsePartnerSync) {
      UpgradeBottomSheet.show(
        context,
        featureName: 'Partner-Sync',
        featureDescription:
            'Importiere Daten deines Partners und plant gemeinsam. Export und Import sind ein Premium-Feature.',
      );
      return;
    }
    _handleImport();
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    try {
      final success = await _syncService.shareExportedData();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Daten erfolgreich exportiert! 📤'
                  : 'Export abgebrochen',
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['heartpebble'],
      dialogTitle: 'Backup-Datei auswählen',
    );
    if (result == null || result.files.single.path == null) return;
    final filePath = result.files.single.path!;
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daten importieren?'),
        content: const Text(
          'Die importierten Daten werden mit deinen aktuellen Daten zusammengeführt. Neuere Einträge überschreiben ältere.\n\nMöchtest du fortfahren?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importieren'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isImporting = true);
    try {
      final result = await _syncService.importData(filePath, mergeData: true);
      if (mounted) {
        if (result.success) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Import erfolgreich!'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.statistics.toDetailedString()),
                  const SizedBox(height: 16),
                  const Text(
                    'Die App wird jetzt die Daten neu laden.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              actions: [
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (widget.onDataReloaded != null) {
                      await widget.onDataReloaded!();
                    } else {
                      _loadDatabaseInfo();
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Hinweis: Bitte App neu starten um alle Daten zu sehen.',
                            ),
                            duration: Duration(seconds: 3),
                            backgroundColor: Colors.orange,
                          ),
                        );
                    }
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = PremiumService.instance.canUsePartnerSync;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isPremium) ...[
          GestureDetector(
            onTap: () => UpgradeBottomSheet.show(
              context,
              featureName: 'Partner-Sync',
              featureDescription:
                  'Teile deine Hochzeitsplanung mit deinem Partner.',
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Partner-Sync ist ein Premium-Feature',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    'Upgrade ›',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        Row(
          children: [
            const Icon(Icons.info_outline, size: 20),
            const SizedBox(width: 8),
            Text('Datenbankgröße: $_databaseSize'),
          ],
        ),

        if (_recordCounts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _StatChip('Gäste', _recordCounts['guests'] ?? 0),
              _StatChip('Budget', _recordCounts['budgetItems'] ?? 0),
              _StatChip('Aufgaben', _recordCounts['tasks'] ?? 0),
              _StatChip('Tische', _recordCounts['tables'] ?? 0),
              _StatChip(
                'Dienstleister',
                _recordCounts['serviceProviders'] ?? 0,
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _isExporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.upload, color: isPremium ? null : Colors.grey),
          title: Text(
            'Daten exportieren',
            style: TextStyle(color: isPremium ? null : Colors.grey),
          ),
          subtitle: const Text(
            'Teile deine Hochzeitsplanung mit deinem Partner',
          ),
          trailing: isPremium
              ? const Icon(Icons.chevron_right)
              : const Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 20,
                ),
          enabled: !_isExporting && !_isImporting,
          onTap: _onExportTapped,
        ),

        const Divider(height: 1),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _isImporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.download, color: isPremium ? null : Colors.grey),
          title: Text(
            'Daten importieren',
            style: TextStyle(color: isPremium ? null : Colors.grey),
          ),
          subtitle: const Text('Lade eine Backup-Datei von deinem Partner'),
          trailing: isPremium
              ? const Icon(Icons.chevron_right)
              : const Icon(
                  Icons.workspace_premium,
                  color: Colors.amber,
                  size: 20,
                ),
          enabled: !_isExporting && !_isImporting,
          onTap: _onImportTapped,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.count);
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $count', style: const TextStyle(fontSize: 12)),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ============================================================================
// ABOUT CARD
// ============================================================================

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Version'),
          subtitle: Text('1.0.0'),
        ),
        const Divider(height: 1),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Datenschutz'),
          subtitle: const Text('Alle Daten bleiben lokal auf deinem Gerät'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Datenschutz'),
                content: const Text(
                  'HeartPebble funktioniert komplett offline. Alle deine Daten werden nur lokal auf deinem Gerät gespeichert. Wir sammeln keine Daten und es gibt keine Cloud-Synchronisation.\n\nBeim Export erstellst du eine Datei, die du manuell teilen kannst.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// GENERAL CARD
// ============================================================================

class _GeneralCard extends StatelessWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.language),
          title: Text('Sprache'),
          subtitle: Text('Deutsch'),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.attach_money),
          title: Text('Währung'),
          subtitle: Text('EUR'),
        ),
      ],
    );
  }
}
