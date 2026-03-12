import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../widgets/budget_donut_chart.dart';
import '../models/wedding_models.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import 'budget_detail_screen.dart';
import '../widgets/forms/smart_text_field.dart';
import '../sync/services/sync_service.dart';
import '../services/budget_ai_service.dart';

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
                Icons.picture_as_pdf,
                color: Colors.red,
                size: 32,
              ),
              title: const Text('Als PDF exportieren'),
              subtitle: const Text('Übersichtliche Zusammenfassung'),
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
  Widget _buildQuickChips() {
    final chips = [
      (
        '👥',
        'Pro Person',
        _totalGuests > 0 ? '€${_formatCurrency(_perPersonActual)}' : '–',
        false,
      ),
      (
        '👶',
        'Kinder-Menü',
        _childCount > 0 ? '€${_formatCurrency(_childMenuPrice)}/Kind' : '–',
        false,
      ),
      (
        '🚨',
        'Überzogen',
        '$_overBudgetCategoryCount ${_overBudgetCategoryCount == 1 ? 'Kat.' : 'Kat.'}',
        _overBudgetCategoryCount > 0,
      ),
    ];

    return Row(
      children: chips.map((chip) {
        final (icon, label, value, isWarn) = chip;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: chip == chips.last ? 0 : 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              color: isWarn ? Colors.red.shade50 : Colors.white,
              border: Border.all(
                color: isWarn ? Colors.red.shade200 : Colors.grey.shade200,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isWarn ? Colors.red.shade700 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              'Alle Budgetposten',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          _budgetItems.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      'Noch keine Budgetposten hinzugefügt.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _budgetItems.length,
                  itemBuilder: (context, index) {
                    final item = _budgetItems[index];
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
// KI BUDGET ANALYSE BOTTOM SHEET
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

class _AiBudgetAnalysisSheetState extends State<_AiBudgetAnalysisSheet> {
  int _tab = 0; // 0=Übersicht, 1=Pro Kopf, 2=Tipps
  BudgetAiAnalysis? _analysis;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final result = await BudgetAiService.analyze(
        budgetItems: widget.budgetItems,
        totalBudget: widget.totalBudget,
        guestCount: widget.guestCount,
        childCount: widget.childCount,
        childMenuPrice: widget.childMenuPrice,
        adultMenuPrice: widget.adultMenuPrice,
        categoryLabels: widget.categoryLabels,
      );
      if (mounted) setState(() => _analysis = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 4),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(),
                  const SizedBox(height: 16),

                  // Tabs
                  _buildTabs(),
                  const SizedBox(height: 16),

                  // Content
                  if (_isLoading)
                    _buildLoadingState()
                  else if (_error != null)
                    _buildErrorState()
                  else if (_analysis != null)
                    _buildContent(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6d3050), Color(0xFFa05070)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🤖', style: TextStyle(fontSize: 26)),
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
                    fontSize: 17,
                  ),
                ),
                Text(
                  '${widget.guestCount + widget.childCount} Gäste · ${widget.guestCount} Erw. + ${widget.childCount} Kinder',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_analysis != null) ...[
            Column(
              children: [
                Text(
                  '${_analysis!.score}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '/ 100',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const tabs = ['📊 Übersicht', '👥 Pro Kopf', '💡 Tipps'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final active = _tab == i;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              margin: EdgeInsets.only(right: i < tabs.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFa05070)
                    : const Color(0xFFf5eaf0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tabs[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : const Color(0xFFa05070),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'KI analysiert euer Budget …',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            'Analyse konnte nicht geladen werden.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loadAnalysis,
            child: const Text('Erneut versuchen'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final a = _analysis!;
    if (_tab == 0) return _buildOverviewTab(a);
    if (_tab == 1) return _buildPerPersonTab();
    return _buildTipsTab(a);
  }

  Widget _buildOverviewTab(BudgetAiAnalysis a) {
    final totalPlanned = widget.budgetItems.fold(0.0, (s, i) => s + i.planned);
    final totalActual = widget.budgetItems.fold(0.0, (s, i) => s + i.actual);
    final diff = totalActual - widget.totalBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: diff > 0 ? Colors.red.shade50 : Colors.green.shade50,
            border: Border.all(
              color: diff > 0 ? Colors.red.shade200 : Colors.green.shade200,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  a.statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: diff > 0
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Zahlen
        ...[
          (
            'Gesamtbudget',
            '€${widget.formatCurrency(widget.totalBudget)}',
            false,
          ),
          ('Geplante Kosten', '€${widget.formatCurrency(totalPlanned)}', false),
          ('Ausgegeben', '€${widget.formatCurrency(totalActual)}', diff > 0),
          (
            'Differenz',
            '${diff > 0 ? '+' : ''}€${widget.formatCurrency(diff)}',
            diff > 0,
          ),
        ].map(
          (row) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: row.$3 ? Colors.red.shade50 : const Color(0xFFfaf5f8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: row.$3 ? Colors.red.shade200 : const Color(0xFFf0e6ec),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  row.$1,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  row.$2,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: row.$3 ? Colors.red : Colors.black87,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFfaf5f8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            a.summary,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF7a5060),
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerPersonTab() {
    final totalGuests = widget.guestCount + widget.childCount;
    final cateringActual =
        widget.adultMenuPrice * widget.guestCount +
        widget.childMenuPrice * widget.childCount;
    final a = _analysis!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gästestruktur
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFfdf0f5),
            border: Border.all(color: const Color(0xFFf0d0dc)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gästestruktur & Catering',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 12),
              _perPersonRow(
                '👩‍👨 Erwachsene',
                '${widget.guestCount} Pers.',
                '× €${widget.formatCurrency(widget.adultMenuPrice)} = €${widget.formatCurrency(widget.adultMenuPrice * widget.guestCount)}',
              ),
              const SizedBox(height: 8),
              _perPersonRow(
                '👶 Kinder',
                '${widget.childCount} Kinder',
                '× €${widget.formatCurrency(widget.childMenuPrice)} = €${widget.formatCurrency(widget.childMenuPrice * widget.childCount)}',
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Catering gesamt',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '€${widget.formatCurrency(cateringActual)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFFa05070),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Gesamtkosten pro Person
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFfaf5f8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gesamtkosten pro Person',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Geplant', style: TextStyle(color: Colors.grey)),
                  Text(
                    '€${widget.formatCurrency(a.perPersonCostPlanned)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Aktuell', style: TextStyle(color: Colors.grey)),
                  Text(
                    '€${widget.formatCurrency(a.perPersonCostActual)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: a.perPersonCostActual > a.perPersonCostPlanned
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: a.perPersonCostPlanned > 0
                      ? (a.perPersonCostPlanned / a.perPersonCostActual).clamp(
                          0.0,
                          1.0,
                        )
                      : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFa05070)),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalGuests Gäste gesamt',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _perPersonRow(String title, String count, String calc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            Text(
              count,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        Text(
          calc,
          style: const TextStyle(color: Color(0xFF7a5060), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildTipsTab(BudgetAiAnalysis a) {
    return Column(
      children: [
        ...a.recommendations.map(
          (rec) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFfaf5f8),
              border: Border.all(color: const Color(0xFFf0e6ec)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rec,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4a3040),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (a.totalSavingsPotential > 0)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Text('💰', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gesamteinsparpotenzial: ca. €${widget.formatCurrency(a.totalSavingsPotential)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
