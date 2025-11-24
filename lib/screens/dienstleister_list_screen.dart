import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dienstleister_models.dart';
import '../data/dienstleister_database.dart';
import 'dienstleister_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';

class DienstleisterListScreen extends StatefulWidget {
  const DienstleisterListScreen({Key? key}) : super(key: key);

  @override
  State<DienstleisterListScreen> createState() =>
      _DienstleisterListScreenState();
}

class _DienstleisterListScreenState extends State<DienstleisterListScreen> {
  List<Dienstleister> _alleDienstleister = [];
  List<DienstleisterZahlung> _alleZahlungen = [];
  bool _isLoading = true;

  List<DienstleisterKategorie> _selectedKategorien = [];
  String _sortierung = 'name-asc';

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');
  final ScrollController _scrollController = ScrollController();
  final Map<DienstleisterKategorie, GlobalKey> _kategorieKeys = {};

  String _formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  @override
  void initState() {
    super.initState();
    for (var kategorie in DienstleisterKategorie.values) {
      _kategorieKeys[kategorie] = GlobalKey();
    }
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dienstleister = await DienstleisterDatabase.instance
          .getAlleDienstleister();
      final zahlungen = await DienstleisterDatabase.instance.getAlleZahlungen();
      setState(() {
        _alleDienstleister = dienstleister;
        _alleZahlungen = zahlungen;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<DienstleisterKategorie, Map<String, dynamic>> get _kategorieStats {
    final stats = <DienstleisterKategorie, Map<String, dynamic>>{};
    for (var kategorie in DienstleisterKategorie.values) {
      final dienstleister = _alleDienstleister
          .where((d) => d.kategorie == kategorie)
          .toList();
      final gesamtkosten = dienstleister.fold<double>(
        0.0,
        (sum, d) => sum + (d.angebotsSumme?.betrag ?? 0.0),
      );
      if (dienstleister.isNotEmpty) {
        stats[kategorie] = {
          'dienstleister': dienstleister,
          'gesamtkosten': gesamtkosten,
        };
      }
    }
    return stats;
  }

  Map<String, dynamic> get _gesamtStats {
    final gesamtkosten = _alleDienstleister.fold<double>(
      0.0,
      (sum, d) => sum + (d.angebotsSumme?.betrag ?? 0.0),
    );
    final gebucht = _alleDienstleister
        .where(
          (d) =>
              d.status == DienstleisterStatus.gebucht ||
              d.status == DienstleisterStatus.briefingFertig ||
              d.status == DienstleisterStatus.geliefert ||
              d.status == DienstleisterStatus.abgerechnet ||
              d.status == DienstleisterStatus.bewertet,
        )
        .length;

    return {
      'gesamtkosten': gesamtkosten,
      'gebucht': gebucht,
      'gesamt': _alleDienstleister.length,
    };
  }

  List<Dienstleister> get _gefilterteDienstleister {
    var result = _alleDienstleister.where((d) {
      if (_selectedKategorien.isNotEmpty &&
          !_selectedKategorien.contains(d.kategorie)) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortierung) {
      case 'name-desc':
        result.sort((a, b) => b.name.compareTo(a.name));
        break;
      case 'bewertung-desc':
        result.sort((a, b) => b.bewertung.compareTo(a.bewertung));
        break;
      case 'preis-asc':
        result.sort(
          (a, b) => (a.angebotsSumme?.betrag ?? 0).compareTo(
            b.angebotsSumme?.betrag ?? 0,
          ),
        );
        break;
      case 'preis-desc':
        result.sort(
          (a, b) => (b.angebotsSumme?.betrag ?? 0).compareTo(
            a.angebotsSumme?.betrag ?? 0,
          ),
        );
        break;
      default:
        result.sort((a, b) => a.name.compareTo(b.name));
    }

    return result;
  }

  List<DienstleisterZahlung> _getZahlungenFuer(String dienstleisterId) {
    return _alleZahlungen
        .where((z) => z.dienstleisterId == dienstleisterId)
        .toList();
  }

  DateTime? _getNaechstesFaelligkeitsdatum(Dienstleister d) {
    final zahlungen = _getZahlungenFuer(d.id);
    final offeneZahlungen = zahlungen
        .where(
          (z) =>
              !z.bezahlt &&
              z.faelligAm != null &&
              z.faelligAm!.isAfter(DateTime.now()),
        )
        .toList();

    final daten = <DateTime>[];
    if (d.optionBis != null && d.optionBis!.isAfter(DateTime.now())) {
      daten.add(d.optionBis!);
    }
    for (var z in offeneZahlungen) {
      daten.add(z.faelligAm!);
    }

    if (daten.isEmpty) return null;
    daten.sort();
    return daten.first;
  }

  void _scrollToKategorie(DienstleisterKategorie kategorie) {
    final key = _kategorieKeys[kategorie];
    if (key?.currentContext != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      });
    }
  }

  void _showDienstleisterDialog([Dienstleister? dienstleister]) {
    showDialog(
      context: context,
      builder: (context) => _DienstleisterFormDialog(
        dienstleister: dienstleister,
        onSave: () => _loadData(),
      ),
    );
  }

  // NEUE METHODE: Dienstleister löschen mit Bestätigung
  Future<void> _deleteDienstleister(Dienstleister dienstleister) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dienstleister löschen?'),
        content: Text(
          'Möchten Sie "${dienstleister.name}" wirklich löschen? '
          'Dies löscht auch alle zugehörigen Zahlungen, Notizen und Aufgaben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DienstleisterDatabase.instance.deleteDienstleister(
          dienstleister.id,
        );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${dienstleister.name} wurde gelöscht'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Fehler beim Löschen: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showExportDialog() async {
    final scheme = Theme.of(context).colorScheme;

    if (_alleDienstleister.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Keine Dienstleister zum Exportieren vorhanden'),
          backgroundColor: scheme.tertiary,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dienstleister exportieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 32,
              ),
              title: const Text('Als PDF exportieren'),
              subtitle: const Text('Übersichtliche Liste'),
              onTap: () {
                Navigator.pop(context);
                _exportAsPdf();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.table_chart,
                color: Colors.green,
                size: 32,
              ),
              title: const Text('Als Excel exportieren'),
              subtitle: const Text('Detaillierte Auswertung'),
              onTap: () {
                Navigator.pop(context);
                _exportAsExcel();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAsPdf() async {
    final scheme = Theme.of(context).colorScheme;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await PdfExportService.exportServiceProvidersToPdf(_alleDienstleister);

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('PDF erfolgreich erstellt!'),
              ],
            ),
            backgroundColor: scheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Erstellen: $e')),
              ],
            ),
            backgroundColor: scheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _exportAsExcel() async {
    final scheme = Theme.of(context).colorScheme;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ExcelExportService.exportServiceProvidersToExcel(
        _alleDienstleister,
      );

      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Excel-Datei erfolgreich erstellt!'),
              ],
            ),
            backgroundColor: scheme.primary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Erstellen: $e')),
              ],
            ),
            backgroundColor: scheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importFromExcel() async {
    final scheme = Theme.of(context).colorScheme;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final result = await ExcelExportService.importServiceProvidersFromExcel();

      if (mounted) Navigator.pop(context);

      if (result != null) {
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${result['imported']} Dienstleister erfolgreich importiert! (${result['skipped']} übersprungen)',
                    ),
                  ),
                ],
              ),
              backgroundColor: scheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Importieren: $e')),
              ],
            ),
            backgroundColor: scheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final stats = _gesamtStats;
    final kategorieStats = _kategorieStats;
    final gefilterteListe = _gefilterteDienstleister;

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dienstleister',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verwalten Sie Ihr Dream-Team für den großen Tag',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _importFromExcel,
                          icon: const Icon(Icons.upload_file),
                          tooltip: 'Importieren',
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _showExportDialog,
                          icon: const Icon(Icons.share),
                          tooltip: 'Exportieren',
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.secondaryContainer,
                            foregroundColor: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showDienstleisterDialog(),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Dienstleister hinzufügen'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Gesamtkosten',
                        '€${_formatCurrency(stats['gesamtkosten'])}',
                        Icons.euro,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Dienstleister',
                        '${stats['gesamt']}',
                        Icons.people,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildStatCard(
                        'Gebucht',
                        '${stats['gebucht']}',
                        Icons.check_circle,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (kategorieStats.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kostenaufteilung nach Kategorien',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 60,
                            sections: _buildPieChartSections(kategorieStats),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 250,
                        child: ListView(
                          children: kategorieStats.entries.map((entry) {
                            final kategorie = entry.key;
                            final data = entry.value;
                            final prozent = stats['gesamtkosten'] > 0
                                ? (data['gesamtkosten'] /
                                      stats['gesamtkosten'] *
                                      100)
                                : 0.0;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedKategorien.clear();
                                  _selectedKategorien.add(kategorie);
                                });
                                _scrollToKategorie(kategorie);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: kategorie.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      kategorie.icon,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            kategorie.label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${data['dienstleister'].length} Dienstleister',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '€${_formatCurrency(data['gesamtkosten'])}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          '${prozent.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _sortierung,
                      decoration: InputDecoration(
                        labelText: 'Sortierung',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'name-asc',
                          child: Text('Name (A-Z)'),
                        ),
                        DropdownMenuItem(
                          value: 'name-desc',
                          child: Text('Name (Z-A)'),
                        ),
                        DropdownMenuItem(
                          value: 'bewertung-desc',
                          child: Text('Bewertung (Höchste)'),
                        ),
                        DropdownMenuItem(
                          value: 'preis-asc',
                          child: Text('Preis (Günstigste)'),
                        ),
                        DropdownMenuItem(
                          value: 'preis-desc',
                          child: Text('Preis (Teuerste)'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _sortierung = value!),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kategorien',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        if (_selectedKategorien.isNotEmpty)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _selectedKategorien.clear()),
                            icon: const Icon(Icons.clear, size: 14),
                            label: const Text(
                              'Zurücksetzen',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: DienstleisterKategorie.values.map((kategorie) {
                        final isSelected = _selectedKategorien.contains(
                          kategorie,
                        );
                        return FilterChip(
                          label: Text(
                            kategorie.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          selectedColor: scheme.primary.withOpacity(0.2),
                          checkmarkColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedKategorien.clear();
                                _selectedKategorien.add(kategorie);
                              } else {
                                _selectedKategorien.remove(kategorie);
                              }
                            });

                            if (selected) {
                              _scrollToKategorie(kategorie);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (gefilterteListe.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      _alleDienstleister.isEmpty
                          ? 'Noch keine Dienstleister hinzugefügt.'
                          : 'Keine Dienstleister gefunden, die den Kriterien entsprechen.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                ),
              )
            else
              ..._kategorieStats.entries.map((entry) {
                final kategorie = entry.key;
                final data = entry.value;
                final gefiltert = gefilterteListe
                    .where((d) => d.kategorie == kategorie)
                    .toList();

                if (gefiltert.isEmpty) return const SizedBox.shrink();

                return Column(
                  key: _kategorieKeys[kategorie],
                  children: [
                    Card(
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(kategorie.icon, color: scheme.primary),
                                const SizedBox(width: 12),
                                Text(
                                  kategorie.label,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${gefiltert.length} Dienstleister • €${_formatCurrency(data['gesamtkosten'])}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: gefiltert.length,
                              itemBuilder: (context, index) {
                                return _buildDienstleisterListItem(
                                  gefiltert[index],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
    Map<DienstleisterKategorie, Map<String, dynamic>> kategorieStats,
  ) {
    return kategorieStats.entries.map((entry) {
      final kategorie = entry.key;
      final kosten = entry.value['gesamtkosten'] as double;
      return PieChartSectionData(
        value: kosten,
        title: '€${_formatCurrency(kosten)}',
        color: kategorie.color,
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildDienstleisterListItem(Dienstleister dienstleister) {
    final zahlungen = _getZahlungenFuer(dienstleister.id);
    final alleBezahlt =
        zahlungen.isNotEmpty && zahlungen.every((z) => z.bezahlt);
    final naechstesFrist = _getNaechstesFaelligkeitsdatum(dienstleister);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DienstleisterDetailScreen(dienstleisterId: dienstleister.id),
          ),
        ).then((_) => _loadData());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (dienstleister.istFavorit) ...[
                  const Icon(Icons.favorite, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    dienstleister.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: dienstleister.status.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dienstleister.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: dienstleister.status.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Bearbeiten Button
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () => _showDienstleisterDialog(dienstleister),
                  tooltip: 'Bearbeiten',
                ),
                // Löschen Button
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () => _deleteDienstleister(dienstleister),
                  tooltip: 'Löschen',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (dienstleister.hauptkontakt.name.isNotEmpty)
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dienstleister.hauptkontakt.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Icon(Icons.euro, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      _formatCurrency(dienstleister.angebotsSumme?.betrag ?? 0),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                if (naechstesFrist != null)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${naechstesFrist.day}.${naechstesFrist.month}.${naechstesFrist.year}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                const SizedBox(width: 12),
                if (alleBezahlt)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bezahlt',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DienstleisterFormDialog extends StatefulWidget {
  final Dienstleister? dienstleister;
  final VoidCallback onSave;

  const _DienstleisterFormDialog({this.dienstleister, required this.onSave});

  @override
  State<_DienstleisterFormDialog> createState() =>
      _DienstleisterFormDialogState();
}

class _DienstleisterFormDialogState extends State<_DienstleisterFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _kontaktNameController;
  late TextEditingController _emailController;
  late TextEditingController _telefonController;
  late TextEditingController _websiteController;
  late TextEditingController _instagramController;
  late TextEditingController _angebotController;
  late TextEditingController _notizenController;

  late DienstleisterKategorie _kategorie;
  late DienstleisterStatus _status;
  DateTime? _optionBis;
  bool _istFavorit = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dienstleister;
    _nameController = TextEditingController(text: d?.name ?? '');
    _kontaktNameController = TextEditingController(
      text: d?.hauptkontakt.name ?? '',
    );
    _emailController = TextEditingController(text: d?.hauptkontakt.email ?? '');
    _telefonController = TextEditingController(
      text: d?.hauptkontakt.telefon ?? '',
    );
    _websiteController = TextEditingController(text: d?.website ?? '');
    _instagramController = TextEditingController(text: d?.instagram ?? '');
    _angebotController = TextEditingController(
      text: d?.angebotsSumme?.betrag.toStringAsFixed(0) ?? '',
    );
    _notizenController = TextEditingController(text: d?.notizen ?? '');

    _kategorie = d?.kategorie ?? DienstleisterKategorie.sonstiges;
    _status = d?.status ?? DienstleisterStatus.recherche;
    _optionBis = d?.optionBis;
    _istFavorit = d?.istFavorit ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _kontaktNameController.dispose();
    _emailController.dispose();
    _telefonController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _angebotController.dispose();
    _notizenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dienstleister = Dienstleister(
      id:
          widget.dienstleister?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      kategorie: _kategorie,
      status: _status,
      website: _websiteController.text.isEmpty ? null : _websiteController.text,
      instagram: _instagramController.text,
      hauptkontakt: Kontakt(
        name: _kontaktNameController.text,
        email: _emailController.text,
        telefon: _telefonController.text,
      ),
      angebotsSumme: _angebotController.text.isNotEmpty
          ? Geld(betrag: double.parse(_angebotController.text))
          : null,
      optionBis: _optionBis,
      logistik: widget.dienstleister?.logistik ?? Logistik(),
      notizen: _notizenController.text,
      istFavorit: _istFavorit,
    );

    if (widget.dienstleister != null) {
      await DienstleisterDatabase.instance.updateDienstleister(dienstleister);
    } else {
      await DienstleisterDatabase.instance.createDienstleister(dienstleister);
    }

    widget.onSave();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          children: [
            AppBar(
              title: Text(
                widget.dienstleister != null
                    ? 'Dienstleister bearbeiten'
                    : 'Neuen Dienstleister anlegen',
              ),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.isEmpty ?? true ? 'Pflichtfeld' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<DienstleisterKategorie>(
                        value: _kategorie,
                        decoration: const InputDecoration(
                          labelText: 'Kategorie',
                          border: OutlineInputBorder(),
                        ),
                        items: DienstleisterKategorie.values
                            .map(
                              (k) => DropdownMenuItem(
                                value: k,
                                child: Text(k.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _kategorie = v!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<DienstleisterStatus>(
                        value: _status,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                        ),
                        items: DienstleisterStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _angebotController,
                        decoration: const InputDecoration(
                          labelText: 'Angebotssumme (€)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _kontaktNameController,
                        decoration: const InputDecoration(
                          labelText: 'Ansprechpartner',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'E-Mail',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _telefonController,
                              decoration: const InputDecoration(
                                labelText: 'Telefon',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _websiteController,
                              decoration: const InputDecoration(
                                labelText: 'Website',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _instagramController,
                              decoration: const InputDecoration(
                                labelText: 'Instagram',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Option gültig bis'),
                        subtitle: Text(
                          _optionBis != null
                              ? '${_optionBis!.day}.${_optionBis!.month}.${_optionBis!.year}'
                              : 'Nicht gesetzt',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _optionBis ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (date != null) {
                              setState(() => _optionBis = date);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notizenController,
                        decoration: const InputDecoration(
                          labelText: 'Notizen',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      CheckboxListTile(
                        title: const Text('Als Favorit markieren'),
                        value: _istFavorit,
                        onChanged: (v) =>
                            setState(() => _istFavorit = v ?? false),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                    ),
                    child: const Text('Speichern'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
