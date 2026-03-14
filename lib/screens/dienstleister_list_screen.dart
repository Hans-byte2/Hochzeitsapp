import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dienstleister_models.dart';
import '../data/database_helper.dart';
import '../data/dienstleister_database.dart';
import '../services/dienstleister_score_service.dart';
import 'dienstleister_detail_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import '../widgets/forms/smart_text_field.dart';
import '../sync/services/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DienstleisterListScreen extends StatefulWidget {
  const DienstleisterListScreen({super.key});

  @override
  State<DienstleisterListScreen> createState() =>
      DienstleisterListScreenState();
}

class DienstleisterListScreenState extends State<DienstleisterListScreen> {
  List<Dienstleister> _alleDienstleister = [];
  List<DienstleisterZahlung> _alleZahlungen = [];
  Map<String, DienstleisterScore> _scores = {};
  double _gesamtBudget = 0.0;
  bool _isLoading = true;

  final List<DienstleisterKategorie> _selectedKategorien = [];
  VergleichsTag? _selectedVergleichsTag;
  String _sortierung = 'name-asc';

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');
  final ScrollController _scrollController = ScrollController();
  final Map<DienstleisterKategorie, GlobalKey> _kategorieKeys = {};

  void _syncNow() {
    SyncService.instance.syncNow().catchError(
      (e) => debugPrint('Sync-Fehler: $e'),
    );
  }

  void reload() => _loadData();

  String _formatCurrency(double amount) => _currencyFormat.format(amount);

  @override
  void initState() {
    super.initState();
    for (var k in DienstleisterKategorie.values)
      _kategorieKeys[k] = GlobalKey();
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
      final gesamtBudget = await DatabaseHelper.instance.getTotalBudget();

      final scores = <String, DienstleisterScore>{};
      for (final d in dienstleister) {
        final dZahlungen = zahlungen
            .where((z) => z.dienstleisterId == d.id)
            .toList();
        final kommunikationsLog = await DatabaseHelper.instance
            .getKommunikationsLogFuer(d.id);
        scores[d.id] = DienstleisterScoreService.berechne(
          d: d,
          zahlungen: dZahlungen,
          kommunikationsLog: kommunikationsLog,
          gesamtBudget: gesamtBudget,
        );
      }

      setState(() {
        _alleDienstleister = dienstleister;
        _alleZahlungen = zahlungen;
        _scores = scores;
        _gesamtBudget = gesamtBudget;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Map<DienstleisterKategorie, Map<String, dynamic>> get _kategorieStats {
    final stats = <DienstleisterKategorie, Map<String, dynamic>>{};
    for (var k in DienstleisterKategorie.values) {
      final list = _alleDienstleister.where((d) => d.kategorie == k).toList();
      final gesamtkosten = list.fold<double>(
        0.0,
        (s, d) => s + (d.angebotsSumme?.betrag ?? 0.0),
      );
      if (list.isNotEmpty)
        stats[k] = {'dienstleister': list, 'gesamtkosten': gesamtkosten};
    }
    return stats;
  }

  Map<String, dynamic> get _gesamtStats {
    final gesamtkosten = _alleDienstleister.fold<double>(
      0.0,
      (s, d) => s + (d.angebotsSumme?.betrag ?? 0.0),
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
          !_selectedKategorien.contains(d.kategorie))
        return false;
      if (_selectedVergleichsTag != null &&
          d.vergleichsTag != _selectedVergleichsTag)
        return false;
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
      case 'score-desc':
        result.sort(
          (a, b) => (_scores[b.id]?.gesamt ?? 0).compareTo(
            _scores[a.id]?.gesamt ?? 0,
          ),
        );
        break;
      default:
        result.sort((a, b) => a.name.compareTo(b.name));
    }
    return result;
  }

  List<DienstleisterZahlung> _getZahlungenFuer(String id) =>
      _alleZahlungen.where((z) => z.dienstleisterId == id).toList();

  DateTime? _getNaechstesFaelligkeitsdatum(Dienstleister d) {
    final zahlungen = _getZahlungenFuer(d.id);
    final daten = <DateTime>[];
    if (d.optionBis != null && d.optionBis!.isAfter(DateTime.now()))
      daten.add(d.optionBis!);
    for (var z in zahlungen.where(
      (z) =>
          !z.bezahlt &&
          z.faelligAm != null &&
          z.faelligAm!.isAfter(DateTime.now()),
    )) {
      daten.add(z.faelligAm!);
    }
    if (daten.isEmpty) return null;
    daten.sort();
    return daten.first;
  }

  void _scrollToKategorie(DienstleisterKategorie k) {
    final key = _kategorieKeys[k];
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

  // FIX: Edit-Button öffnet jetzt Detail-Screen, nicht Form-Dialog
  void _openDetailScreen(Dienstleister d) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DienstleisterDetailScreen(dienstleisterId: d.id),
      ),
    ).then((_) => _loadData());
  }

  void _showNeuenDienstleisterDialog() {
    showDialog(
      context: context,
      builder: (context) => _DienstleisterFormDialog(
        onSave: () {
          _loadData();
          _syncNow();
        },
      ),
    );
  }

  Future<void> _deleteDienstleister(Dienstleister d) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dienstleister löschen?'),
        content: Text(
          'Möchten Sie „${d.name}" wirklich löschen? Dies löscht auch alle zugehörigen Daten.',
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
        await DienstleisterDatabase.instance.deleteDienstleister(d.id);
        _syncNow();
        await _loadData();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${d.name} wurde gelöscht'),
              backgroundColor: Colors.green,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
          );
      }
    }
  }

  // ── VERGLEICHS-MODAL für gleiche Kategorie ──────────────────────────────
  void _showKategorieVergleich(DienstleisterKategorie kategorie) {
    final liste =
        _alleDienstleister.where((d) => d.kategorie == kategorie).toList()
          ..sort(
            (a, b) => (a.angebotsSumme?.betrag ?? 0).compareTo(
              b.angebotsSumme?.betrag ?? 0,
            ),
          );

    if (liste.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Mindestens 2 Dienstleister in der Kategorie für Vergleich nötig',
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(kategorie.icon, color: kategorie.color, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${kategorie.label} vergleichen',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(14),
                itemCount: liste.length,
                itemBuilder: (context, index) {
                  final d = liste[index];
                  final score = _scores[d.id];
                  final isCheapest =
                      index == 0 && (d.angebotsSumme?.betrag ?? 0) > 0;
                  final isFavorit = d.vergleichsTag == VergleichsTag.favorit;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isFavorit
                            ? Colors.green
                            : isCheapest
                            ? Colors.orange.shade300
                            : Colors.grey.shade300,
                        width: isFavorit ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isFavorit) ...[
                                const Icon(
                                  Icons.star,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                              ],
                              if (isCheapest && !isFavorit) ...[
                                Icon(
                                  Icons.trending_down,
                                  color: Colors.orange.shade600,
                                  size: 16,
                                ),
                                const SizedBox(width: 5),
                              ],
                              Expanded(
                                child: Text(
                                  d.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              if (score != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: score.color.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: score.color.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    '⭐ ${score.gesamt}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: score.color,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Preis
                          Row(
                            children: [
                              Expanded(
                                child: _vergleichsZelle(
                                  'Preis',
                                  d.angebotsSumme != null
                                      ? '€${_currencyFormat.format(d.angebotsSumme!.betrag)}'
                                      : '–',
                                  isCheapest ? Colors.orange.shade700 : null,
                                ),
                              ),
                              Expanded(
                                child: _vergleichsZelle(
                                  'Bewertung',
                                  d.bewertung > 0
                                      ? '${'⭐' * d.bewertung.toInt()} (${d.bewertung.toStringAsFixed(1)})'
                                      : '–',
                                  null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: _vergleichsZelle(
                                  'Status',
                                  d.status.label,
                                  d.status.color,
                                ),
                              ),
                              Expanded(
                                child: _vergleichsZelle(
                                  'Kontakt',
                                  d.hauptkontakt.name.isNotEmpty
                                      ? d.hauptkontakt.name
                                      : '–',
                                  null,
                                ),
                              ),
                            ],
                          ),
                          if (d.notizen.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              d.notizen,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (d.hauptkontakt.telefon.isNotEmpty)
                                _miniContactBtn(
                                  Icons.phone,
                                  Colors.green,
                                  () => _launchUrl(
                                    'tel:${d.hauptkontakt.telefon}',
                                  ),
                                ),
                              if (d.hauptkontakt.email.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                _miniContactBtn(
                                  Icons.email,
                                  Colors.blue,
                                  () => _launchUrl(
                                    'mailto:${d.hauptkontakt.email}',
                                  ),
                                ),
                              ],
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _openDetailScreen(d);
                                },
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text(
                                  'Details',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vergleichsZelle(String label, String value, Color? valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _miniContactBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 15, color: color),
      ),
    );
  }

  Future<void> _showExportDialog() async {
    if (_alleDienstleister.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 32,
              ),
              title: const Text('Als PDF'),
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
              title: const Text('Als Excel'),
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
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await PdfExportService.exportServiceProvidersToPdf(_alleDienstleister);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF erstellt!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAsExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await ExcelExportService.exportServiceProvidersToExcel(
        _alleDienstleister,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Excel erstellt!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importFromExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final result = await ExcelExportService.importServiceProvidersFromExcel();
      if (mounted) Navigator.pop(context);
      if (result != null) {
        _syncNow();
        await _loadData();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${result['imported']} importiert (${result['skipped']} übersprungen)',
              ),
              backgroundColor: Colors.green,
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = _gesamtStats;
    final kategorieStats = _kategorieStats;
    final gefilterteListe = _gefilterteDienstleister;
    final budgetInsight = DienstleisterScoreService.budgetInsight(
      alle: _alleDienstleister,
      gesamtBudget: _gesamtBudget,
    );

    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
                      const SizedBox(height: 3),
                      Text(
                        'Verwalten Sie Ihr Dream-Team',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showNeuenDienstleisterDialog,
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Dienstleister hinzufügen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Budget-Insight
            if (budgetInsight != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: budgetInsight.startsWith('⚠️')
                      ? Colors.red.shade50
                      : budgetInsight.startsWith('⚡')
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: budgetInsight.startsWith('⚠️')
                        ? Colors.red.shade200
                        : budgetInsight.startsWith('⚡')
                        ? Colors.orange.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  budgetInsight,
                  style: TextStyle(
                    fontSize: 12,
                    color: budgetInsight.startsWith('⚠️')
                        ? Colors.red.shade700
                        : budgetInsight.startsWith('⚡')
                        ? Colors.orange.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Stats
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
            const SizedBox(height: 14),

            // Kostenaufteilung
            if (kategorieStats.isNotEmpty) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kostenaufteilung',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 170,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 50,
                            sections: kategorieStats.entries
                                .map(
                                  (e) => PieChartSectionData(
                                    value: e.value['gesamtkosten'],
                                    title:
                                        '€${_formatCurrency(e.value['gesamtkosten'])}',
                                    color: e.key.color,
                                    radius: 42,
                                    titleStyle: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 200,
                        child: ListView(
                          children: kategorieStats.entries.map((entry) {
                            final k = entry.key;
                            final data = entry.value;
                            final gesamtkosten =
                                stats['gesamtkosten'] as double;
                            final prozent = gesamtkosten > 0
                                ? (data['gesamtkosten'] / gesamtkosten * 100)
                                : 0.0;
                            final kannVergleichen =
                                (data['dienstleister'] as List).length >= 2;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedKategorien.clear();
                                  _selectedKategorien.add(k);
                                });
                                _scrollToKategorie(k);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 5),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 11,
                                      height: 11,
                                      decoration: BoxDecoration(
                                        color: k.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    Icon(
                                      k.icon,
                                      size: 15,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            k.label,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            '${(data['dienstleister'] as List).length} Dienstleister',
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
                                          '€${_formatCurrency(data['gesamtkosten'] as double)}',
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
                                    if (kannVergleichen) ...[
                                      const SizedBox(width: 6),
                                      Tooltip(
                                        message: 'Vergleichen',
                                        child: InkWell(
                                          onTap: () =>
                                              _showKategorieVergleich(k),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: scheme.primary.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Icon(
                                              Icons.compare_arrows,
                                              size: 14,
                                              color: scheme.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
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
              const SizedBox(height: 14),
            ],

            // Filter
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _sortierung,
                      decoration: InputDecoration(
                        labelText: 'Sortierung',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
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
                          value: 'score-desc',
                          child: Text('Score (Höchste) ⭐'),
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
                      onChanged: (v) => setState(() => _sortierung = v!),
                    ),
                    const SizedBox(height: 14),

                    // Vergleichs-Tag Filter
                    Row(
                      children: [
                        Text(
                          'Vergleichs-Tag',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedVergleichsTag != null)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _selectedVergleichsTag = null),
                            icon: const Icon(Icons.clear, size: 13),
                            label: const Text(
                              'Reset',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: VergleichsTag.values.map((tag) {
                        final isSelected = _selectedVergleichsTag == tag;
                        return FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tag.icon,
                                size: 11,
                                color: isSelected
                                    ? tag.color
                                    : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                tag.label,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: tag.color.withOpacity(0.2),
                          checkmarkColor: tag.color,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (sel) => setState(
                            () => _selectedVergleichsTag = sel ? tag : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Text(
                          'Kategorien',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedKategorien.isNotEmpty)
                          TextButton.icon(
                            onPressed: () =>
                                setState(() => _selectedKategorien.clear()),
                            icon: const Icon(Icons.clear, size: 13),
                            label: const Text(
                              'Reset',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: DienstleisterKategorie.values.map((k) {
                        final isSelected = _selectedKategorien.contains(k);
                        return FilterChip(
                          label: Text(
                            k.label,
                            style: const TextStyle(fontSize: 11),
                          ),
                          selected: isSelected,
                          selectedColor: scheme.primary.withOpacity(0.2),
                          checkmarkColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedKategorien.clear();
                                _selectedKategorien.add(k);
                              } else {
                                _selectedKategorien.remove(k);
                              }
                            });
                            if (sel) _scrollToKategorie(k);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Liste
            if (gefilterteListe.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      _alleDienstleister.isEmpty
                          ? 'Noch keine Dienstleister hinzugefügt.'
                          : 'Keine Dienstleister gefunden.',
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
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                            child: Row(
                              children: [
                                Icon(
                                  kategorie.icon,
                                  color: scheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  kategorie.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${gefiltert.length} • €${_formatCurrency(data['gesamtkosten'] as double)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                const Spacer(),
                                // Vergleich-Button in Kategorie-Header (wenn >= 2)
                                if (gefiltert.length >= 2)
                                  Tooltip(
                                    message: 'Vergleichen',
                                    child: InkWell(
                                      onTap: () =>
                                          _showKategorieVergleich(kategorie),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: scheme.primary.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.compare_arrows,
                                              size: 15,
                                              color: scheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Vergleichen',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: scheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 350),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: gefiltert.length,
                              itemBuilder: (context, index) =>
                                  _buildDienstleisterListItem(gefiltert[index]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              }),
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
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildDienstleisterListItem(Dienstleister d) {
    final zahlungen = _getZahlungenFuer(d.id);
    final alleBezahlt =
        zahlungen.isNotEmpty && zahlungen.every((z) => z.bezahlt);
    final naechstesFrist = _getNaechstesFaelligkeitsdatum(d);
    final score = _scores[d.id];

    return InkWell(
      // Tippen → Detail-Screen
      onTap: () => _openDetailScreen(d),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
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
                if (d.istFavorit) ...[
                  const Icon(Icons.favorite, size: 14, color: Colors.red),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    d.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Score Badge
                if (score != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: score.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: score.color.withOpacity(0.4)),
                    ),
                    child: Text(
                      '${score.gesamt}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: score.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                ],

                // Vergleichs-Tag Badge
                if (d.vergleichsTag != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: d.vergleichsTag!.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          d.vergleichsTag!.icon,
                          size: 10,
                          color: d.vergleichsTag!.color,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          d.vergleichsTag!.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: d.vergleichsTag!.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                ],

                // Status
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: d.status.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    d.status.label,
                    style: TextStyle(
                      fontSize: 9,
                      color: d.status.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // FIX: Edit öffnet Detail-Screen
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  color: Colors.blue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Details öffnen',
                  onPressed: () => _openDetailScreen(d),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  tooltip: 'Löschen',
                  onPressed: () => _deleteDienstleister(d),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Schnellkontakt + Info-Zeile
            Row(
              children: [
                // Schnellkontakt
                if (d.hauptkontakt.telefon.isNotEmpty) ...[
                  _miniQuickBtn(
                    Icons.phone,
                    Colors.green,
                    () => _launchUrl('tel:${d.hauptkontakt.telefon}'),
                  ),
                  const SizedBox(width: 5),
                ],
                if (d.hauptkontakt.email.isNotEmpty) ...[
                  _miniQuickBtn(
                    Icons.email,
                    Colors.blue,
                    () => _launchUrl('mailto:${d.hauptkontakt.email}'),
                  ),
                  const SizedBox(width: 8),
                ],

                // Preis
                Row(
                  children: [
                    Icon(Icons.euro, size: 13, color: Colors.grey.shade600),
                    const SizedBox(width: 3),
                    Text(
                      _formatCurrency(d.angebotsSumme?.betrag ?? 0),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // Fälligkeitsdatum
                if (naechstesFrist != null) ...[
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${naechstesFrist.day}.${naechstesFrist.month}.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],

                // Bezahlt Badge
                if (alleBezahlt) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 11,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Bezahlt',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniQuickBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 13, color: color),
      ),
    );
  }
}

// ============================================================================
// NEUER DIENSTLEISTER FORM DIALOG (nur für neue Einträge)
// Bearbeitung erfolgt über den Detail-Screen
// ============================================================================

class _DienstleisterFormDialog extends StatefulWidget {
  final VoidCallback onSave;

  const _DienstleisterFormDialog({required this.onSave});

  @override
  State<_DienstleisterFormDialog> createState() =>
      _DienstleisterFormDialogState();
}

class _DienstleisterFormDialogState extends State<_DienstleisterFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _kontaktNameController;
  late TextEditingController _emailController;
  late TextEditingController _telefonController;
  late TextEditingController _websiteController;
  late TextEditingController _angebotController;

  DienstleisterKategorie _kategorie = DienstleisterKategorie.sonstiges;
  DienstleisterStatus _status = DienstleisterStatus.recherche;

  final Map<String, bool> _fieldValidation = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _kontaktNameController = TextEditingController();
    _emailController = TextEditingController();
    _telefonController = TextEditingController();
    _websiteController = TextEditingController();
    _angebotController = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _kontaktNameController,
      _emailController,
      _telefonController,
      _websiteController,
      _angebotController,
    ])
      c.dispose();
    super.dispose();
  }

  void _updateFieldValidation(String key, bool isValid) {
    if (mounted) setState(() => _fieldValidation[key] = isValid);
  }

  bool get _areAllFieldsValid => _fieldValidation['name'] ?? false;

  Future<void> _save() async {
    if (!_areAllFieldsValid) return;
    final dienstleister = Dienstleister(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      kategorie: _kategorie,
      status: _status,
      website: _websiteController.text.isEmpty ? null : _websiteController.text,
      instagram: '',
      hauptkontakt: Kontakt(
        name: _kontaktNameController.text,
        email: _emailController.text,
        telefon: _telefonController.text,
      ),
      angebotsSumme: _angebotController.text.isNotEmpty
          ? Geld(betrag: double.tryParse(_angebotController.text) ?? 0)
          : null,
      logistik: Logistik(),
    );
    await DienstleisterDatabase.instance.createDienstleister(dienstleister);
    widget.onSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dienstleister hinzugefügt! ✓'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 620),
        child: Column(
          children: [
            AppBar(
              title: const Text('Neuen Dienstleister anlegen'),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hinweis
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 15,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Alle weiteren Details (Bewertung, Logistik, Notizen...) können nach dem Erstellen im Detail-Screen bearbeitet werden.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SmartTextField(
                      label: 'Name *',
                      fieldKey: 'name',
                      isRequired: true,
                      controller: _nameController,
                      onValidationChanged: _updateFieldValidation,
                      isDisabled: false,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty)
                          return 'Erforderlich';
                        if (v.trim().length < 2) return 'Min. 2 Zeichen';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<DienstleisterKategorie>(
                      initialValue: _kategorie,
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
                    const SizedBox(height: 14),
                    SmartTextField(
                      label: 'Angebotssumme (€)',
                      fieldKey: 'angebot',
                      isRequired: false,
                      controller: _angebotController,
                      onValidationChanged: _updateFieldValidation,
                      isDisabled: false,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v != null &&
                            v.trim().isNotEmpty &&
                            double.tryParse(v.trim()) == null)
                          return 'Ungültige Zahl';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    SmartTextField(
                      label: 'Ansprechpartner',
                      fieldKey: 'kontakt_name',
                      isRequired: false,
                      controller: _kontaktNameController,
                      onValidationChanged: _updateFieldValidation,
                      isDisabled: false,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SmartTextField(
                            label: 'Telefon',
                            fieldKey: 'telefon',
                            isRequired: false,
                            controller: _telefonController,
                            onValidationChanged: _updateFieldValidation,
                            isDisabled: false,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SmartTextField(
                            label: 'E-Mail',
                            fieldKey: 'email',
                            isRequired: false,
                            controller: _emailController,
                            onValidationChanged: _updateFieldValidation,
                            isDisabled: false,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Abbrechen'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _areAllFieldsValid ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _areAllFieldsValid
                          ? scheme.primary
                          : Colors.grey[300],
                      foregroundColor: Colors.white,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _areAllFieldsValid ? Icons.add : Icons.add_outlined,
                        ),
                        const SizedBox(width: 7),
                        const Text('Erstellen'),
                      ],
                    ),
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
