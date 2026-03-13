import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../widgets/budget_donut_chart.dart';
import '../models/wedding_models.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import 'budget_detail_screen.dart';
import 'payment_plan_screen.dart';
import 'auto_budget_allocation_sheet.dart';
import '../widgets/forms/smart_text_field.dart';
import '../sync/services/sync_service.dart';
import '../services/budget_ai_service.dart';
import '../services/budget_report_pdf_service.dart';

class EnhancedBudgetPage extends StatefulWidget {
  const EnhancedBudgetPage({super.key});

  @override
  State<EnhancedBudgetPage> createState() => EnhancedBudgetPageState();
}

class EnhancedBudgetPageState extends State<EnhancedBudgetPage> {
  List<BudgetItem> _budgetItems = [];
  bool _isLoading = true;
  bool _showForm = false;
  double _totalBudget = 0.0;
  final _totalBudgetController = TextEditingController();

  // ── Smart Budget: Gästedaten ─────────────────────────────────────────────
  int _guestCount = 0;
  int _childCount = 0;
  double _childMenuPrice = 0.0;
  double _adultMenuPrice = 0.0;
  bool _bannerDismissed = false;

  // ── Bezahlt-Filter ───────────────────────────────────────────────────────
  String _paidFilter = 'all'; // 'all' | 'open' | 'paid'

  final Map<String, String> _categoryLabels = {
    'location': 'Location & Catering',
    'catering': 'Verpflegung',
    'clothing': 'Kleidung & Styling',
    'decoration': 'Dekoration & Blumen',
    'music': 'Musik & Unterhaltung',
    'photography': 'Fotografie & Video',
    'flowers': 'Blumen & Floristik',
    'transport': 'Transport',
    'rings': 'Ringe & Schmuck',
    'other': 'Sonstiges',
  };

  final Map<String, Color> _categoryColors = {
    'location': Colors.blue,
    'catering': Colors.green,
    'clothing': Colors.purple,
    'decoration': Colors.pink,
    'music': Colors.orange,
    'photography': Colors.teal,
    'flowers': Colors.red,
    'transport': Colors.indigo,
    'rings': Colors.amber,
    'other': Colors.grey,
  };

  String _selectedCategory = 'other';
  final _itemNameController = TextEditingController();
  final _plannedAmountController = TextEditingController();
  final _actualAmountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isPaid = false;

  final Map<String, bool> _fieldValidation = {};

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');

  String _formatCurrency(double amount) => _currencyFormat.format(amount);

  void _syncNow() {
    SyncService.instance.syncNow().catchError((e) {
      debugPrint('Sync-Fehler: $e');
    });
  }

  void reload() {
    _loadBudgetItems();
    _loadTotalBudget();
    _loadGuestData();
  }

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadBudgetItems();
    _loadTotalBudget();
    _loadGuestData();
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    _itemNameController.dispose();
    _plannedAmountController.dispose();
    _actualAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Gästezahl + Menüpreise aus DB laden ──────────────────────────────────
  Future<void> _loadGuestData() async {
    try {
      final guests = await DatabaseHelper.instance.getAllGuests();
      // Erwachsene = Anzahl Gäste (jeder Gast zählt als 1 Erwachsener)
      final adults = guests.length;
      // Kinder = Summe aller children_count Felder
      final children = guests.fold(0, (sum, g) => sum + g.childrenCount);

      // Menüpreise aus Settings laden (Fallback auf Defaults)
      final adultPrice =
          await DatabaseHelper.instance.getSetting('adult_menu_price') ?? '65';
      final childPrice =
          await DatabaseHelper.instance.getSetting('child_menu_price') ?? '28';

      if (mounted) {
        setState(() {
          _guestCount = adults;
          _childCount = children;
          _adultMenuPrice = double.tryParse(adultPrice) ?? 65.0;
          _childMenuPrice = double.tryParse(childPrice) ?? 28.0;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Gästedaten: $e');
    }
  }

  void _updateFieldValidation(String fieldKey, bool isValid) {
    if (mounted) setState(() => _fieldValidation[fieldKey] = isValid);
  }

  bool get _isFormValid =>
      (_fieldValidation['item_name'] ?? false) &&
      (_fieldValidation['planned_amount'] ?? false);

  // ── Budget-Überschreitung ─────────────────────────────────────────────────
  bool get _isOverBudget => _totalBudget > 0 && totalActual > _totalBudget;

  int get _overBudgetCategoryCount =>
      _budgetItems.where((i) => i.actual > i.planned && i.planned > 0).length;

  double get _overBudgetAmount => _totalBudget > 0
      ? (totalActual - _totalBudget).clamp(0, double.infinity)
      : 0;

  // ── Pro-Kopf ──────────────────────────────────────────────────────────────
  int get _totalGuests => _guestCount + _childCount;

  double get _perPersonActual =>
      _totalGuests > 0 ? totalActual / _totalGuests : 0;

  Future<void> _loadTotalBudget() async {
    try {
      final budget = await DatabaseHelper.instance.getTotalBudget();
      if (mounted) {
        setState(() {
          _totalBudget = budget;
          _totalBudgetController.text = budget.toStringAsFixed(0);
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden des Gesamtbudgets: $e');
    }
  }

  Future<void> _saveTotalBudget(double budget) async {
    try {
      await DatabaseHelper.instance.setTotalBudget(budget);
      if (mounted) setState(() => _totalBudget = budget);
      _syncNow();
    } catch (e) {
      debugPrint('Fehler beim Speichern des Gesamtbudgets: $e');
    }
  }

  Future<void> _showEditTotalBudgetDialog() async {
    final controller = TextEditingController(
      text: _totalBudget.toStringAsFixed(0),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesamtbudget bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Geben Sie Ihr geplantes Gesamtbudget ein:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Gesamtbudget (€)',
                prefixText: '€ ',
                hintText: '0',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.pop(context, value);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != null) await _saveTotalBudget(result);
  }

  Future<void> _initializeDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;
      for (final sql in [
        "ALTER TABLE budget_items ADD COLUMN category TEXT DEFAULT 'other'",
        "ALTER TABLE budget_items ADD COLUMN notes TEXT DEFAULT ''",
        "ALTER TABLE budget_items ADD COLUMN paid INTEGER DEFAULT 0",
      ]) {
        try {
          await db.execute(sql);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Fehler beim Initialisieren der Datenbank: $e');
    }
  }

  Future<void> _loadBudgetItems() async {
    try {
      setState(() => _isLoading = true);
      final items = await DatabaseHelper.instance.getAllBudgetItems();
      if (mounted) {
        setState(() {
          _budgetItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Budget-Items: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double get totalPlanned =>
      _budgetItems.fold(0.0, (sum, item) => sum + item.planned);

  double get totalActual =>
      _budgetItems.fold(0.0, (sum, item) => sum + item.actual);

  double get remaining => totalPlanned - totalActual;

  Map<String, Map<String, dynamic>> get categoryStats {
    final stats = <String, Map<String, dynamic>>{};
    for (final category in _categoryLabels.keys) {
      final items = _budgetItems.where((i) => i.category == category).toList();
      stats[category] = {
        'plannedTotal': items.fold(0.0, (s, i) => s + i.planned),
        'actualTotal': items.fold(0.0, (s, i) => s + i.actual),
        'itemCount': items.length,
      };
    }
    return stats;
  }

  Future<void> _showExportDialog() async {
    if (_budgetItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Budgetposten zum Exportieren vorhanden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Budget exportieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.summarize_outlined,
                color: Colors.purple,
                size: 32,
              ),
              title: const Text('Budget-Bericht (PDF)'),
              subtitle: const Text(
                'Vollständig: Ampeln, Catering, Zahlungsplan',
              ),
              onTap: () {
                Navigator.pop(context);
                _exportBudgetReport();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 32,
              ),
              title: const Text('Als PDF exportieren'),
              subtitle: const Text('Einfache Zusammenfassung'),
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

  Future<void> _exportBudgetReport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final paymentPlans = await DatabaseHelper.instance.getAllPaymentPlans();
      if (!mounted) return;
      await BudgetReportPdfService.exportBudgetReport(
        budgetItems: _budgetItems,
        paymentPlans: paymentPlans,
        totalBudget: _totalBudget,
        guestCount: _guestCount,
        childCount: _childCount,
        adultMenuPrice: _adultMenuPrice,
        childMenuPrice: _childMenuPrice,
        categoryLabels: _categoryLabels,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Fehler: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _exportAsPdf() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await PdfExportService.exportBudgetToPdf(_budgetItems);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('PDF erfolgreich erstellt!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
                Expanded(child: Text('Fehler: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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
      await ExcelExportService.exportBudgetToExcel(_budgetItems);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Excel-Datei erfolgreich erstellt!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
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
                Expanded(child: Text('Fehler: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _togglePaid(int id, bool currentPaidStatus) async {
    try {
      final item = _budgetItems.firstWhere((i) => i.id == id);
      await DatabaseHelper.instance.updateBudgetItem(
        item.copyWith(paid: !currentPaidStatus),
      );
      await _loadBudgetItems();
      _syncNow();
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren des Bezahlt-Status: $e');
    }
  }

  Future<void> _addBudgetItem() async {
    if (!_isFormValid) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('budget_items', {
        'name': _itemNameController.text.trim(),
        'planned': double.tryParse(_plannedAmountController.text) ?? 0.0,
        'actual': double.tryParse(_actualAmountController.text) ?? 0.0,
        'category': _selectedCategory,
        'notes': _notesController.text.trim(),
        'paid': _isPaid ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted': 0,
      });

      _itemNameController.clear();
      _plannedAmountController.clear();
      _actualAmountController.clear();
      _notesController.clear();
      _fieldValidation.clear();
      setState(() {
        _isPaid = false;
        _selectedCategory = 'other';
        _showForm = false;
      });
      await _loadBudgetItems();
      _syncNow();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Budgetposten hinzugefügt!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Fehler beim Hinzufügen des Budget-Items: $e');
    }
  }

  Future<void> _editBudgetItem(BudgetItem item) async {
    showDialog(
      context: context,
      builder: (_) => _BudgetItemEditDialog(
        item: item,
        categoryLabels: _categoryLabels,
        onSave: () {
          _loadBudgetItems();
          _syncNow();
        },
      ),
    );
  }

  // ── KI-Analyse Dialog öffnen ──────────────────────────────────────────────
  void _showAiAnalysisDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiBudgetAnalysisSheet(
        budgetItems: _budgetItems,
        totalBudget: _totalBudget,
        guestCount: _guestCount,
        childCount: _childCount,
        childMenuPrice: _childMenuPrice,
        adultMenuPrice: _adultMenuPrice,
        categoryLabels: _categoryLabels,
        formatCurrency: _formatCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget Übersicht',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Behalten Sie Ihre Hochzeitskosten im Blick',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Badge-Icon für Budget-Tab
              Stack(
                clipBehavior: Clip.none,
                children: [
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
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _showForm = !_showForm;
                    if (!_showForm) {
                      _itemNameController.clear();
                      _plannedAmountController.clear();
                      _actualAmountController.clear();
                      _notesController.clear();
                      _fieldValidation.clear();
                    }
                  });
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Neu', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Überschreitungs-Banner ───────────────────────────────────────
          if (_isOverBudget && !_bannerDismissed) ...[
            _buildOverBudgetBanner(),
            const SizedBox(height: 12),
          ],

          // ── KI-Analyse Button ────────────────────────────────────────────
          _buildAiAnalysisButton(),
          const SizedBox(height: 12),

          // ── Auto-Budget Button (nur wenn noch keine Posten) ────────────
          if (_budgetItems.isEmpty && _totalBudget > 0) ...[
            _buildAutoBudgetButton(),
            const SizedBox(height: 12),
          ],

          // ── Quick-Chips: Pro Kopf / Kinder / Überzogen ───────────────────
          _buildQuickChips(),
          const SizedBox(height: 16),

          _buildTotalBudgetCard(),
          const SizedBox(height: 16),
          if (_showForm) ...[_buildAddItemForm(), const SizedBox(height: 16)],
          _buildCategoryBreakdown(),
          const SizedBox(height: 16),
          _buildBudgetItemsList(),
        ],
      ),
    );
  }

  // ── Überschreitungs-Banner ─────────────────────────────────────────────────
  Widget _buildOverBudgetBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🚨', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget überschritten',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${_overBudgetCategoryCount} ${_overBudgetCategoryCount == 1 ? 'Kategorie' : 'Kategorien'} über dem Budget · +€${_formatCurrency(_overBudgetAmount)} gesamt',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _bannerDismissed = true),
            icon: Icon(Icons.close, color: Colors.red.shade400, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ── KI-Analyse Button ──────────────────────────────────────────────────────
  Widget _buildAiAnalysisButton() {
    final isOver = _isOverBudget;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showAiAnalysisDialog,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2c1810), Color(0xFF6d3050)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2c1810).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Text('🤖', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KI Budget-Analyse',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Pro-Kopf-Kosten · Einsparpotenzial · Empfehlungen',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isOver)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_overBudgetCategoryCount} Warnung${_overBudgetCategoryCount != 1 ? 'en' : ''}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick-Chips ────────────────────────────────────────────────────────────
  // Catering-Preis pro Erwachsenem (nur Catering-Kategorie / Erwachsene)
  double get _cateringPerAdult {
    if (_guestCount == 0) return _adultMenuPrice;
    return _adultMenuPrice;
  }

  Widget _buildAutoBudgetButton() {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AutoBudgetAllocationSheet(
            totalBudget: _totalBudget,
            onApplied: () {
              _loadBudgetItems();
              _syncNow();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Budget-Aufteilung übernommen!'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.06),
          border: Border.all(color: scheme.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              color: scheme.primary,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget automatisch aufteilen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    'Richtwerte für alle Kategorien als Startpunkt',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentPlanButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaymentPlanScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payment_outlined, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(
              'Zahlungsplan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Menüpreis-Settings Dialog ───────────────────────────────────────────
  Future<void> _showMenuPriceSettings() async {
    final adultCtrl = TextEditingController(
      text: _adultMenuPrice.toStringAsFixed(0),
    );
    final childCtrl = TextEditingController(
      text: _childMenuPrice.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Menüpreise anpassen',
          style: TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: adultCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Erwachsenen-Menü (€)',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: childCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Kinderteller (€)',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () async {
              final adult = double.tryParse(adultCtrl.text) ?? _adultMenuPrice;
              final child = double.tryParse(childCtrl.text) ?? _childMenuPrice;
              await DatabaseHelper.instance.setSetting(
                'adult_menu_price',
                adult.toString(),
              );
              await DatabaseHelper.instance.setSetting(
                'child_menu_price',
                child.toString(),
              );
              if (mounted) {
                setState(() {
                  _adultMenuPrice = adult;
                  _childMenuPrice = child;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChips() {
    final chips = [
      (
        '👥',
        'Gesamt/Kopf',
        _totalGuests > 0 ? '€${_formatCurrency(_perPersonActual)}' : '–',
        false,
      ),
      (
        '🍽️',
        'Catering/Kopf',
        _guestCount > 0 ? '€${_formatCurrency(_adultMenuPrice)}' : '–',
        false,
      ),
      (
        '👶',
        'Kind-Menü',
        _childCount > 0 ? '€${_formatCurrency(_childMenuPrice)}' : '–',
        false,
      ),
      (
        '🚨',
        'Überzogen',
        '$_overBudgetCategoryCount Kat.',
        _overBudgetCategoryCount > 0,
      ),
    ];

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(chips.length, (index) {
              final (icon, label, value, isWarn) = chips[index];
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < chips.length - 1 ? 6 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isWarn ? Colors.red.shade50 : Colors.white,
                    border: Border.all(
                      color: isWarn
                          ? Colors.red.shade200
                          : Colors.grey.shade200,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isWarn ? Colors.red.shade700 : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _showMenuPriceSettings,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.tune_rounded,
              size: 18,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isActive = _paidFilter == value;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _paidFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? scheme.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? scheme.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _paidSummaryBadge(String label, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            Text(
              amount,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBudgetCard() {
    final scheme = Theme.of(context).colorScheme;
    final budgetRemaining = _totalBudget - totalActual;
    final percentageUsed = _totalBudget > 0
        ? (totalActual / _totalBudget) * 100
        : 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.primary, scheme.primary.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gesamtbudget',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '€${_formatCurrency(_totalBudget)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Badge für Überschreitung
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _showEditTotalBudgetDialog,
                        tooltip: 'Gesamtbudget bearbeiten',
                      ),
                      if (_isOverBudget)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.primary,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$_overBudgetCategoryCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _budgetRow('Davon verplant:', totalPlanned),
                    const SizedBox(height: 8),
                    _budgetRow('Ausgegeben:', totalActual),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Verbleibend:',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          '€${_formatCurrency(budgetRemaining)}',
                          style: TextStyle(
                            color: budgetRemaining >= 0
                                ? Colors.white
                                : Colors.red.shade200,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (percentageUsed / 100).clamp(0.0, 1.0),
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentageUsed > 100 ? Colors.red : Colors.white,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${percentageUsed.toStringAsFixed(1)}% verwendet',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _budgetRow(String label, double amount) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(color: Colors.white)),
      Text(
        '€${_formatCurrency(amount)}',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    ],
  );

  Widget _buildAddItemForm() {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Neuen Budgetposten hinzufügen',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _isFormValid
                  ? 1.0
                  : (_fieldValidation.values.where((v) => v).length / 2.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _isFormValid ? Colors.green : scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_fieldValidation.values.where((v) => v).length} von 2 Pflichtfeldern ausgefüllt',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _categoryLabels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            SmartTextField(
              label: 'Bezeichnung',
              fieldKey: 'item_name',
              isRequired: true,
              controller: _itemNameController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Bezeichnung ist erforderlich';
                if (v.trim().length < 2) return 'Mindestens 2 Zeichen';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SmartTextField(
                    label: 'Geplanter Betrag (€)',
                    fieldKey: 'planned_amount',
                    isRequired: true,
                    controller: _plannedAmountController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Betrag erforderlich';
                      final p = double.tryParse(v.trim());
                      if (p == null) return 'Ungültige Zahl';
                      if (p < 0) return 'Muss >= 0 sein';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SmartTextField(
                    label: 'Tatsächlicher Betrag (€)',
                    fieldKey: 'actual_amount',
                    isRequired: false,
                    controller: _actualAmountController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final p = double.tryParse(v.trim());
                        if (p == null) return 'Ungültige Zahl';
                        if (p < 0) return 'Muss >= 0 sein';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SmartTextField(
              label: 'Notizen',
              fieldKey: 'notes',
              isRequired: false,
              controller: _notesController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Bereits bezahlt'),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isFormValid ? _addBudgetItem : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid
                        ? scheme.primary
                        : Colors.grey[300],
                    foregroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isFormValid
                            ? Icons.add_circle
                            : Icons.add_circle_outline,
                      ),
                      const SizedBox(width: 8),
                      const Text('Hinzufügen'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showForm = false;
                      _itemNameController.clear();
                      _plannedAmountController.clear();
                      _actualAmountController.clear();
                      _notesController.clear();
                      _fieldValidation.clear();
                    });
                  },
                  child: const Text('Abbrechen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final stats = categoryStats;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kategorie-Aufschlüsselung',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.8,
              ),
              itemCount: _categoryLabels.length,
              itemBuilder: (context, index) {
                final category = _categoryLabels.keys.elementAt(index);
                final label = _categoryLabels[category]!;
                final color = _categoryColors[category]!;
                final stat = stats[category]!;
                final isOver =
                    stat['actualTotal'] > stat['plannedTotal'] &&
                    stat['plannedTotal'] > 0;
                final percentage = stat['plannedTotal'] > 0
                    ? (stat['actualTotal'] / stat['plannedTotal']) * 100
                    : 0.0;

                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CategoryDetailPage(
                          category: category,
                          categoryName: label,
                        ),
                      ),
                    );
                    _loadBudgetItems();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isOver
                          ? Colors.red.withOpacity(0.05)
                          : color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isOver
                            ? Colors.red.withOpacity(0.3)
                            : color.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                if (isOver)
                                  const Text(
                                    '⚠️',
                                    style: TextStyle(fontSize: 8),
                                  )
                                else
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 8,
                                  color: color,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          'Geplant: €${_formatCurrency(stat['plannedTotal'])}',
                          style: const TextStyle(fontSize: 8),
                        ),
                        Text(
                          'Tatsächlich: €${_formatCurrency(stat['actualTotal'])}',
                          style: TextStyle(
                            fontSize: 8,
                            color: isOver ? Colors.red : null,
                            fontWeight: isOver ? FontWeight.bold : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        LinearProgressIndicator(
                          value: (percentage / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isOver ? Colors.red : color,
                          ),
                          minHeight: 2,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${stat['itemCount']} Posten ->',
                          style: const TextStyle(
                            fontSize: 7,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItemsList() {
    final dividerColor = Theme.of(context).dividerColor;

    // Filter anwenden
    final filteredItems = _budgetItems.where((item) {
      if (_paidFilter == 'paid') return item.paid;
      if (_paidFilter == 'open') return !item.paid;
      return true;
    }).toList();

    final totalOpen = _budgetItems
        .where((i) => !i.paid)
        .fold(0.0, (s, i) => s + i.actual);
    final totalPaid = _budgetItems
        .where((i) => i.paid)
        .fold(0.0, (s, i) => s + i.actual);
    final openCount = _budgetItems.where((i) => !i.paid).length;
    final paidCount = _budgetItems.where((i) => i.paid).length;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header mit Filter-Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Budgetposten',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Zusammenfassung offen/bezahlt
                Row(
                  children: [
                    _paidSummaryBadge(
                      '${openCount} offen',
                      '€${_formatCurrency(totalOpen)}',
                      Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    _paidSummaryBadge(
                      '${paidCount} bezahlt',
                      '€${_formatCurrency(totalPaid)}',
                      Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Filter-Toggle
                Row(
                  children: [
                    _filterChip('Alle', 'all'),
                    const SizedBox(width: 6),
                    _filterChip('Offen', 'open'),
                    const SizedBox(width: 6),
                    _filterChip('Bezahlt', 'paid'),
                  ],
                ),
              ],
            ),
          ),
          filteredItems.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      _paidFilter == 'all'
                          ? 'Noch keine Budgetposten hinzugefügt.'
                          : _paidFilter == 'open'
                          ? 'Alle Posten sind bereits bezahlt ✅'
                          : 'Noch keine Posten als bezahlt markiert.',
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final category = item.category;
                    final isPaid = item.paid;
                    final isItemOver =
                        item.actual > item.planned && item.planned > 0;

                    return InkWell(
                      onTap: () => _editBudgetItem(item),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isItemOver
                                ? Colors.red.shade200
                                : dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(6),
                          color: isItemOver ? Colors.red.shade50 : null,
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _togglePaid(item.id!, isPaid),
                              child: Icon(
                                isPaid
                                    ? Icons.check_circle
                                    : Icons.check_circle_outline,
                                color: isPaid
                                    ? Colors.green
                                    : Colors.grey.shade400,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      decoration: isPaid
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isPaid
                                          ? Colors.grey
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (_categoryColors[category] ??
                                                      Colors.grey)
                                                  .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color:
                                                (_categoryColors[category] ??
                                                        Colors.grey)
                                                    .withOpacity(0.3),
                                          ),
                                        ),
                                        child: Text(
                                          _categoryLabels[category] ??
                                              'Sonstiges',
                                          style: TextStyle(
                                            fontSize: 8,
                                            color:
                                                _categoryColors[category] ??
                                                Colors.grey,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (item.notes.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            item.notes,
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.grey,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '€${_formatCurrency(item.actual)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isItemOver
                                        ? Colors.red
                                        : Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'geplant: €${_formatCurrency(item.planned)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16),
                              onPressed: () => _editBudgetItem(item),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ============================================================================
// KI BUDGET ANALYSE BOTTOM SHEET  (4 Tabs: Übersicht / Pro Gast / Catering / Tipps)
// ============================================================================

class _AiBudgetAnalysisSheet extends StatefulWidget {
  final List<BudgetItem> budgetItems;
  final double totalBudget;
  final int guestCount;
  final int childCount;
  final double childMenuPrice;
  final double adultMenuPrice;
  final Map<String, String> categoryLabels;
  final String Function(double) formatCurrency;

  const _AiBudgetAnalysisSheet({
    required this.budgetItems,
    required this.totalBudget,
    required this.guestCount,
    required this.childCount,
    required this.childMenuPrice,
    required this.adultMenuPrice,
    required this.categoryLabels,
    required this.formatCurrency,
  });

  @override
  State<_AiBudgetAnalysisSheet> createState() => _AiBudgetAnalysisSheetState();
}

class _AiBudgetAnalysisSheetState extends State<_AiBudgetAnalysisSheet>
    with SingleTickerProviderStateMixin {
  int _tab = 0; // 0=Übersicht, 1=Pro Gast, 2=Catering, 3=Tipps
  BudgetAiAnalysis? _analysis;
  late TabController _tabController;

  // Szenario-Slider
  int _scenarioRemove = 0;

  // Getränke-Rechner
  bool _openBar = true;
  double _drinksPerPersonPerHour = 2.0;
  double _hoursOfEvent = 6.0;
  double _pricePerDrink = 4.5;
  double _openBarPricePerPerson = 35.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _tab = _tabController.index);
      }
    });
    // Analyse sofort synchron berechnen
    _analysis = BudgetAiService.analyze(
      budgetItems: widget.budgetItems,
      totalBudget: widget.totalBudget,
      guestCount: widget.guestCount,
      childCount: widget.childCount,
      childMenuPrice: widget.childMenuPrice,
      adultMenuPrice: widget.adultMenuPrice,
      categoryLabels: widget.categoryLabels,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _fmt(double v) => widget.formatCurrency(v);

  // Ampelfarbe
  Color _ampelColor(BenchmarkStatus s) {
    switch (s) {
      case BenchmarkStatus.ok:
        return Colors.green.shade600;
      case BenchmarkStatus.warning:
        return Colors.orange.shade600;
      case BenchmarkStatus.over:
        return Colors.red.shade600;
    }
  }

  Color _ampelBg(BenchmarkStatus s) {
    switch (s) {
      case BenchmarkStatus.ok:
        return Colors.green.shade50;
      case BenchmarkStatus.warning:
        return Colors.orange.shade50;
      case BenchmarkStatus.over:
        return Colors.red.shade50;
    }
  }

  String _ampelLabel(BenchmarkStatus s) {
    switch (s) {
      case BenchmarkStatus.ok:
        return 'OK';
      case BenchmarkStatus.warning:
        return '+';
      case BenchmarkStatus.over:
        return '!!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _analysis!;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_graph_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Budget-Analyse',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        a.statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score-Kreis
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: a.score >= 75
                        ? Colors.green.shade50
                        : a.score >= 50
                        ? Colors.orange.shade50
                        : Colors.red.shade50,
                    border: Border.all(
                      color: a.score >= 75
                          ? Colors.green.shade300
                          : a.score >= 50
                          ? Colors.orange.shade300
                          : Colors.red.shade300,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${a.score}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: a.score >= 75
                            ? Colors.green.shade700
                            : a.score >= 50
                            ? Colors.orange.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(text: 'Übersicht'),
                Tab(text: 'Pro Gast'),
                Tab(text: 'Catering'),
                Tab(text: 'Tipps'),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(a),
                _buildPerGuestTab(a),
                _buildCateringTab(a),
                _buildTipsTab(a),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 0: ÜBERSICHT  (Zahlen + Richtwert-Ampeln)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab(BudgetAiAnalysis a) {
    final totalActual = widget.budgetItems.fold(0.0, (s, i) => s + i.actual);
    final totalPlanned = widget.budgetItems.fold(0.0, (s, i) => s + i.planned);
    final diff = totalActual - widget.totalBudget;
    final isOver = diff > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Zahlen-Übersicht
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Gesamtbudget',
                '${_fmt(widget.totalBudget)} €',
                null,
                false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                'Ausgegeben',
                '${_fmt(totalActual)} €',
                null,
                isOver,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Verplant',
                '${_fmt(totalPlanned)} €',
                null,
                false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                isOver ? 'Überzogen' : 'Verfügbar',
                '${isOver ? '+' : ''}${_fmt(diff.abs())} €',
                null,
                isOver,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Ampel-Banner
        _ampelBanner(totalActual),
        const SizedBox(height: 16),

        // KI-Zusammenfassung
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            a.summary,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        const SizedBox(height: 16),

        // Richtwert-Vergleich mit visuellen Balken
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Richtwerte vs. dein Budget',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                _legendDot(Colors.green.shade400),
                const SizedBox(width: 3),
                Text(
                  'OK',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                _legendDot(Colors.orange.shade400),
                const SizedBox(width: 3),
                Text(
                  'Achtung',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                _legendDot(Colors.red.shade400),
                const SizedBox(width: 3),
                Text(
                  'Überzogen',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...a.benchmarks.map((b) => _benchmarkRow(b)),
      ],
    );
  }

  Widget _ampelBanner(double totalActual) {
    final diff = totalActual - widget.totalBudget;
    final pct = widget.totalBudget > 0
        ? (totalActual / widget.totalBudget) * 100
        : 0.0;

    Color bgColor;
    Color borderColor;
    Color textColor;
    String label;
    String sub;
    if (pct <= 90) {
      bgColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      textColor = Colors.green.shade800;
      label = '🟢 Grün – gut im Budget';
      sub =
          'Noch ${_fmt((widget.totalBudget - totalActual).abs())} € Spielraum';
    } else if (pct <= 100) {
      bgColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade200;
      textColor = Colors.orange.shade800;
      label = '🟡 Gelb – knapp';
      sub =
          'Noch ${_fmt((widget.totalBudget - totalActual).abs())} € verbleibend';
    } else {
      bgColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      textColor = Colors.red.shade800;
      label = '🔴 Rot – ${(pct - 100).toStringAsFixed(1)}% über Budget';
      sub = '+${_fmt(diff.abs())} € über dem Gesamtbudget';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(fontSize: 12, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  Widget _benchmarkRow(CategoryBenchmarkResult b) {
    final color = _ampelColor(b.status);
    final bgCol = _ampelBg(b.status);
    final badge = _ampelLabel(b.status);
    final pctVal = (b.benchmarkPct * 100).toStringAsFixed(0);
    final rangeMin = (b.benchmarkMin / widget.totalBudget * 100)
        .toStringAsFixed(0);
    final rangeMax = (b.benchmarkMax / widget.totalBudget * 100)
        .toStringAsFixed(0);
    // Bar: wie viel % des Richtwert-Max wurde erreicht
    final barFill = b.benchmarkMax > 0
        ? (b.actualAmount / (b.benchmarkMax * 1.3)).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b.categoryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  b.deviation > 0
                      ? '+${_fmt(b.deviation.abs())} €'
                      : badge == 'OK'
                      ? 'OK'
                      : '-${_fmt(b.deviation.abs())} €',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: barFill,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$pctVal% | Richtwert $rangeMin–$rangeMax%',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1: PRO GAST  (Catering-Kosten + Szenario-Rechner)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildPerGuestTab(BudgetAiAnalysis a) {
    final totalGuests = widget.guestCount + widget.childCount;
    final adultTotal = widget.adultMenuPrice * widget.guestCount;
    final childTotal = widget.childMenuPrice * widget.childCount;
    final cateringTotal = adultTotal + childTotal;

    // Szenario: x Erwachsene weniger
    final scenarioSavings = _scenarioRemove * widget.adultMenuPrice;
    final scenarioNewTotal =
        widget.budgetItems.fold(0.0, (s, i) => s + i.actual) - scenarioSavings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Kosten-Übersicht
        Row(
          children: [
            Expanded(
              child: _metricCard(
                'Erw.-Menü',
                '${_fmt(widget.adultMenuPrice)} €',
                '/Person',
                false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                'Kind-Menü',
                '${_fmt(widget.childMenuPrice)} €',
                '/Kind',
                false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _metricCard(
                '${widget.guestCount} Erw. gesamt',
                '${_fmt(adultTotal)} €',
                null,
                false,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: widget.childCount > 0
                  ? _metricCard(
                      '${widget.childCount} Kinder gesamt',
                      '${_fmt(childTotal)} €',
                      null,
                      false,
                    )
                  : _metricCard('Kinder', '–', null, false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Catering gesamt ($totalGuests Personen)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Text(
                '${_fmt(cateringTotal)} €',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Szenario-Rechner
        const Text(
          'Was wenn wir weniger einladen?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Erwachsene weniger: ',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  Text(
                    '$_scenarioRemove',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _scenarioRemove.toDouble(),
                min: 0,
                max: (widget.guestCount * 0.5).ceilToDouble(),
                divisions: widget.guestCount > 0
                    ? (widget.guestCount ~/ 2)
                    : 10,
                label: '$_scenarioRemove Personen',
                onChanged: (v) => setState(() => _scenarioRemove = v.round()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      'Ersparnis',
                      '${_fmt(scenarioSavings)} €',
                      null,
                      false,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricCard(
                      'Neue Gesamtkosten',
                      '${_fmt(scenarioNewTotal)} €',
                      null,
                      scenarioNewTotal > widget.totalBudget,
                    ),
                  ),
                ],
              ),
              if (_scenarioRemove > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '→ ${_scenarioRemove} Gäste weniger sparen '
                  '${_fmt(scenarioSavings)} € (nur Catering). '
                  'Neue Gesamtkosten: ${_fmt(scenarioNewTotal)} €.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Hinweis: Der Szenario-Rechner zeigt nur die Catering-Ersparnis. '
          'Posten wie Location, Fotografie und Musik sind unabhängig von der Gästezahl.',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2: CATERING  (Pauschale + pro Kopf + Mindestumsatz)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCateringTab(BudgetAiAnalysis a) {
    final c = a.cateringBreakdown;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text(
          'Catering Aufschlüsselung',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        _cateringLine('Raummiete (Location Pauschale)', c.roomRent),
        _cateringLine(
          '${widget.guestCount} Erw. × ${_fmt(widget.adultMenuPrice)} €',
          c.adultCatering,
        ),
        if (widget.childCount > 0)
          _cateringLine(
            '${widget.childCount} Kinder × ${_fmt(widget.childMenuPrice)} €',
            c.childCatering,
          ),
        const Divider(height: 16),
        _cateringLine('Catering gesamt', c.total, bold: true, highlight: true),

        const SizedBox(height: 12),

        // Mindestumsatz-Check
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.minimumRevenueReached
                ? Colors.green.shade50
                : Colors.orange.shade50,
            border: Border.all(
              color: c.minimumRevenueReached
                  ? Colors.green.shade200
                  : Colors.orange.shade200,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                c.minimumRevenueReached
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                color: c.minimumRevenueReached
                    ? Colors.green.shade600
                    : Colors.orange.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  c.minimumRevenueReached
                      ? 'Mindestumsatz (geschätzt ${_fmt(c.minimumRevenue)} €) ist erreicht.'
                      : 'Mindestumsatz (ca. ${_fmt(c.minimumRevenue)} €) noch nicht erreicht '
                            '– beim Caterer prüfen ob Aufpreis anfällt.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.minimumRevenueReached
                        ? Colors.green.shade800
                        : Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Typische Kostenstruktur',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _infoLine('Location', 'Pauschale pro Event (nicht pro Kopf)'),
              _infoLine('Catering', 'Pro Kopf Erwachsene (Menüpreis)'),
              _infoLine(
                'Kinder',
                'Kinderteller-Preis (oft 40–50% des Erw.-Preises)',
              ),
              _infoLine(
                'Getränke',
                'Oft separat: Pauschale oder nach Verbrauch',
              ),
              _infoLine(
                'Hinweis',
                'Mindestumsatz = Location+Catering zusammen mindestens X €',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Getränke-Rechner ─────────────────────────────────────────────
        const Text(
          'Getränke-Rechner',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Open Bar vs. nach Verbrauch Toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _openBar = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _openBar
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Open Bar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _openBar ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _openBar = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_openBar
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Nach Verbrauch',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_openBar ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_openBar) ...[
          // Open Bar: Pauschale pro Person
          _drinkSliderRow(
            label: 'Pauschale pro Person',
            value: _openBarPricePerPerson,
            min: 15,
            max: 80,
            divisions: 65,
            unit: '€/Person',
            onChanged: (v) => setState(() => _openBarPricePerPerson = v),
          ),
          const SizedBox(height: 8),
          _drinkResultCard(
            label: 'Geschätzte Getränkekosten',
            amount:
                _openBarPricePerPerson *
                (widget.guestCount + widget.childCount),
            subtitle:
                '${widget.guestCount + widget.childCount} Pers. × ${_openBarPricePerPerson.toStringAsFixed(0)} €',
          ),
          const SizedBox(height: 6),
          Text(
            'Tipp: Open Bar Pauschalen liegen typisch bei 25–45 € pro Person für 4–6 Stunden.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
        ] else ...[
          // Nach Verbrauch
          _drinkSliderRow(
            label: 'Getränke pro Person/Stunde',
            value: _drinksPerPersonPerHour,
            min: 1,
            max: 5,
            divisions: 8,
            unit: 'Getränke',
            onChanged: (v) => setState(() => _drinksPerPersonPerHour = v),
          ),
          const SizedBox(height: 8),
          _drinkSliderRow(
            label: 'Stunden (Event-Dauer)',
            value: _hoursOfEvent,
            min: 2,
            max: 12,
            divisions: 10,
            unit: 'Std.',
            onChanged: (v) => setState(() => _hoursOfEvent = v),
          ),
          const SizedBox(height: 8),
          _drinkSliderRow(
            label: 'Ø Preis pro Getränk',
            value: _pricePerDrink,
            min: 2,
            max: 10,
            divisions: 16,
            unit: '€',
            onChanged: (v) => setState(() => _pricePerDrink = v),
          ),
          const SizedBox(height: 8),
          _drinkResultCard(
            label: 'Geschätzte Getränkekosten',
            amount:
                _drinksPerPersonPerHour *
                _hoursOfEvent *
                _pricePerDrink *
                (widget.guestCount + widget.childCount),
            subtitle:
                '${widget.guestCount + widget.childCount} Pers. × '
                '${_drinksPerPersonPerHour.toStringAsFixed(1)} × '
                '${_hoursOfEvent.toStringAsFixed(0)} Std. × '
                '${_pricePerDrink.toStringAsFixed(1)} €',
          ),
          const SizedBox(height: 6),
          Text(
            'Tipp: Rechne mit ca. 2–3 Getränken/Stunde. Alkoholfreie Alternativen senken den Schnittpreis.',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _drinkSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Text(
              '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} $unit',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _drinkResultCard({
    required String label,
    required double amount,
    required String subtitle,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          Text(
            '${_fmt(amount)} €',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cateringLine(
    String label,
    double amount, {
    bool bold = false,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? Colors.grey.shade100 : Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${_fmt(amount)} €',
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3: TIPPS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTipsTab(BudgetAiAnalysis a) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (a.totalSavingsPotential > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.savings_outlined,
                  color: Colors.green.shade700,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Einsparpotenzial',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.green.shade800,
                        ),
                      ),
                      Text(
                        'ca. ${_fmt(a.totalSavingsPotential)} € realistisch erreichbar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        ...a.recommendations.map((rec) {
          final isWarning =
              rec.startsWith('⚠️') ||
              rec.contains('über Budget') ||
              rec.contains('überzogen');
          final isChild = rec.startsWith('👶');
          final isGood = rec.startsWith('✅');

          Color bgColor = Colors.grey.shade50;
          Color borderColor = Colors.grey.shade200;
          if (isWarning) {
            bgColor = Colors.orange.shade50;
            borderColor = Colors.orange.shade200;
          }
          if (isGood) {
            bgColor = Colors.green.shade50;
            borderColor = Colors.green.shade200;
          }
          if (isChild) {
            bgColor = Colors.blue.shade50;
            borderColor = Colors.blue.shade200;
          }
          if (rec.contains('über Budget') && rec.contains('+')) {
            bgColor = Colors.red.shade50;
            borderColor = Colors.red.shade200;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(rec, style: const TextStyle(fontSize: 13, height: 1.5)),
          );
        }),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _metricCard(String label, String value, String? unit, bool isDanger) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: isDanger ? Colors.red.shade50 : Colors.grey.shade50,
        border: Border.all(
          color: isDanger ? Colors.red.shade200 : Colors.grey.shade200,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDanger ? Colors.red.shade700 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDanger ? Colors.red.shade700 : Colors.black87,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BUDGET ITEM EDIT DIALOG (unverändert)
// ============================================================================

class _BudgetItemEditDialog extends StatefulWidget {
  final BudgetItem item;
  final Map<String, String> categoryLabels;
  final VoidCallback onSave;

  const _BudgetItemEditDialog({
    required this.item,
    required this.categoryLabels,
    required this.onSave,
  });

  @override
  State<_BudgetItemEditDialog> createState() => _BudgetItemEditDialogState();
}

class _BudgetItemEditDialogState extends State<_BudgetItemEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _plannedController;
  late TextEditingController _actualController;
  late TextEditingController _notesController;
  late String _selectedCategory;
  late bool _isPaid;

  final Map<String, bool> _fieldValidation = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _plannedController = TextEditingController(
      text: widget.item.planned.toStringAsFixed(0),
    );
    _actualController = TextEditingController(
      text: widget.item.actual.toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: widget.item.notes);
    _selectedCategory = widget.item.category;
    _isPaid = widget.item.paid;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plannedController.dispose();
    _actualController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateFieldValidation(String fieldKey, bool isValid) {
    if (mounted) setState(() => _fieldValidation[fieldKey] = isValid);
  }

  bool get _isFormValid =>
      (_fieldValidation['edit_name'] ?? false) &&
      (_fieldValidation['edit_planned'] ?? false);

  Future<void> _save() async {
    if (!_isFormValid) return;
    try {
      await DatabaseHelper.instance.updateBudgetItem(
        widget.item.copyWith(
          name: _nameController.text.trim(),
          planned: double.tryParse(_plannedController.text) ?? 0.0,
          actual: double.tryParse(_actualController.text) ?? 0.0,
          category: _selectedCategory,
          notes: _notesController.text.trim(),
          paid: _isPaid,
        ),
      );
      widget.onSave();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Budgetposten aktualisiert!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e')));
      }
    }
  }

  Future<void> _delete() async {
    try {
      await DatabaseHelper.instance.deleteBudgetItem(widget.item.id!);
      widget.onSave();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Budgetposten gelöscht!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Löschen: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Budgetposten bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _isFormValid
                  ? 1.0
                  : (_fieldValidation.values.where((v) => v).length / 2.0),
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                _isFormValid ? Colors.green : scheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_fieldValidation.values.where((v) => v).length} von 2 Pflichtfeldern ausgefüllt',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                border: OutlineInputBorder(),
              ),
              items: widget.categoryLabels.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v!),
            ),
            const SizedBox(height: 16),
            SmartTextField(
              label: 'Bezeichnung',
              fieldKey: 'edit_name',
              isRequired: true,
              controller: _nameController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty)
                  return 'Bezeichnung ist erforderlich';
                if (v.trim().length < 2) return 'Mindestens 2 Zeichen';
                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SmartTextField(
                    label: 'Geplant (€)',
                    fieldKey: 'edit_planned',
                    isRequired: true,
                    controller: _plannedController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Erforderlich';
                      final p = double.tryParse(v.trim());
                      if (p == null) return 'Ungültig';
                      if (p < 0) return 'Muss >= 0 sein';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SmartTextField(
                    label: 'Tatsächlich (€)',
                    fieldKey: 'edit_actual',
                    isRequired: false,
                    controller: _actualController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty) {
                        final p = double.tryParse(v.trim());
                        if (p == null) return 'Ungültig';
                        if (p < 0) return 'Muss >= 0 sein';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SmartTextField(
              label: 'Notizen',
              fieldKey: 'edit_notes',
              isRequired: false,
              controller: _notesController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Bereits bezahlt'),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v ?? false),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        TextButton(
          onPressed: _delete,
          child: const Text('Löschen', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: _isFormValid ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid ? scheme.primary : Colors.grey[300],
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isFormValid ? Icons.save : Icons.save_outlined),
              const SizedBox(width: 8),
              const Text('Speichern'),
            ],
          ),
        ),
      ],
    );
  }
}
