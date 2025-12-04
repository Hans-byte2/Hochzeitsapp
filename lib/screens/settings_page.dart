// lib/screens/settings_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../services/profile_providers.dart';
import '../services/theme_providers.dart';
import '../services/sync_service.dart'; // NEU
import '../theme/theme_variant.dart';
import '../widgets/theme_picker_grid.dart';

class SettingsPage extends ConsumerWidget {
  final Future<void> Function()? onDataReloaded;

  const SettingsPage({super.key, this.onDataReloaded});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          ), // NEU: Callback übergeben
          const SizedBox(height: 16),
          const _Section(title: 'Allgemein', child: _GeneralCard()),
          const SizedBox(height: 16),
          const _Section(title: 'Über HeartPebble', child: _AboutCard()),
        ],
      ),
    );
  }
}

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

/// 🔹 Nur Profilbild (Namen/Datum bleiben auf der Startseite / DB)
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
                'Profilbild für die Startseite festlegen.\n'
                'Es wird hinter den Eingabefeldern für\n'
                'Namen und Hochzeitsdatum angezeigt.',
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

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profilbild aktualisiert')));
    }
  }
}

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
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

// ============================================================================
// NEU: SYNC CARD - Export/Import Funktionalität
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

    if (mounted) {
      setState(() {
        _databaseSize = size;
        _recordCounts = counts;
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final success = await _syncService.shareExportedData();

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Daten erfolgreich exportiert! 📤'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export abgebrochen'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Export: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _handleImport() async {
    // Datei auswählen
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['heartpebble'],
      dialogTitle: 'Backup-Datei auswählen',
    );

    if (result == null || result.files.single.path == null) {
      return;
    }

    final filePath = result.files.single.path!;

    // Bestätigung anzeigen
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daten importieren?'),
        content: const Text(
          'Die importierten Daten werden mit deinen aktuellen Daten zusammengeführt. '
          'Neuere Einträge überschreiben ältere.\n\n'
          'Möchtest du fortfahren?',
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
          // Erfolgs-Dialog mit Details
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
                  if (result.statistics != null) ...[
                    Text(result.statistics!.toDetailedString()),
                    const SizedBox(height: 16),
                  ],
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

                    // NEU: Trigger kompletten App-Reload via Callback
                    if (widget.onDataReloaded != null) {
                      debugPrint('🔄 Triggering app data reload...');
                      await widget.onDataReloaded!();
                    } else {
                      // Fallback: Nur lokale DB-Info refreshen
                      _loadDatabaseInfo();

                      if (mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Import: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Datenbank Info
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

        // Export Button
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _isExporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          title: const Text('Daten exportieren'),
          subtitle: const Text(
            'Teile deine Hochzeitsplanung mit deinem Partner',
          ),
          trailing: const Icon(Icons.chevron_right),
          enabled: !_isExporting && !_isImporting,
          onTap: _handleExport,
        ),

        const Divider(height: 1),

        // Import Button
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _isImporting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          title: const Text('Daten importieren'),
          subtitle: const Text('Lade eine Backup-Datei von deinem Partner'),
          trailing: const Icon(Icons.chevron_right),
          enabled: !_isExporting && !_isImporting,
          onTap: _handleImport,
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
// NEU: ABOUT CARD - App Info & Datenschutz
// ============================================================================

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('Version'),
          subtitle: const Text('1.0.0'),
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
                  'HeartPebble funktioniert komplett offline. '
                  'Alle deine Daten werden nur lokal auf deinem Gerät gespeichert. '
                  'Wir sammeln keine Daten und es gibt keine Cloud-Synchronisation.\n\n'
                  'Beim Export erstellst du eine Datei, die du manuell teilen kannst.',
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

class _GeneralCard extends StatelessWidget {
  const _GeneralCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
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
