import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget_models.dart';
import '../data/database_helper.dart';
import 'dart:math' as math;

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<BudgetItem> _budgetItems = [];
  bool _isLoading = true;
  double _totalBudget = 50000.0;

  late TabController _tabController;

  String _filterCategory = 'Alle';
  String _sortBy = 'category';
  bool _showPaidOnly = false;
  bool _showUnpaidOnly = false;

  final _nameController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _actualCostController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = BudgetCategories.defaults[0];
  bool _isPaid = false;

  Map<String, double>? _cachedStats;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadBudget();
    _loadTotalBudget();
  }

  @override
  void dispose() {
    // ✅ 1. Animation stoppen
    _animationController.stop();

    // ✅ 2. Animation Controller disposen
    _animationController.dispose();

    // ✅ 3. Tab Controller disposen
    _tabController.dispose();

    // ✅ 4. Text Controller disposen
    _notesController.dispose();
    _actualCostController.dispose();
    _estimatedCostController.dispose();
    _nameController.dispose();

    // ✅ 5. Super zuletzt
    super.dispose();
  }

  Future<void> _loadBudget() async {
    if (!mounted) return; // ✅

    setState(() => _isLoading = true);

    try {
      final items = await _db.getBudgetItems();

      if (!mounted) return; // ✅

      setState(() {
        _budgetItems = items;
        _isLoading = false;
        _cachedStats = null;
      });

      if (mounted) {
        // ✅
        _animationController.forward(from: 0.0);
      }
    } catch (e) {
      if (!mounted) return; // ✅

      setState(() => _isLoading = false);

      if (mounted) {
        // ✅
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler beim Laden: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Erneut versuchen',
              onPressed: _loadBudget,
              textColor: Colors.white,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadTotalBudget() async {
    // TODO: Aus SharedPreferences laden
  }

  Future<void> _saveTotalBudget() async {
    // TODO: In SharedPreferences speichern
  }

  Future<void> _addBudgetItem() async {
    if (_nameController.text.trim().isEmpty) {
      _showErrorSnackBar('Bitte gib eine Bezeichnung ein');
      return;
    }

    if (_estimatedCostController.text.trim().isEmpty) {
      _showErrorSnackBar('Bitte gib einen geschätzten Preis ein');
      return;
    }

    final estimatedCost = _parseCurrency(_estimatedCostController.text);
    if (estimatedCost == null || estimatedCost <= 0) {
      _showErrorSnackBar('Bitte gib einen gültigen Preis ein');
      return;
    }

    double actualCost = 0.0;
    if (_actualCostController.text.trim().isNotEmpty) {
      actualCost = _parseCurrency(_actualCostController.text) ?? 0.0;
    }

    if (_isPaid && actualCost == 0.0) {
      actualCost = estimatedCost;
    }

    final newItem = BudgetItem(
      name: _nameController.text.trim(),
      category: _selectedCategory,
      estimatedCost: estimatedCost,
      actualCost: actualCost,
      isPaid: _isPaid,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    try {
      await _db.insertBudgetItem(newItem);

      if (!mounted) return; // ✅

      _nameController.clear();
      _estimatedCostController.clear();
      _actualCostController.clear();
      _notesController.clear();

      if (!mounted) return; // ✅

      setState(() {
        _selectedCategory = BudgetCategories.defaults[0];
        _isPaid = false;
      });

      await _loadBudget();

      if (!mounted) return; // ✅

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Budgetposten "${newItem.name}" hinzugefügt'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      if (!mounted) return; // ✅

      _tabController.animateTo(0);
    } catch (e) {
      if (!mounted) return; // ✅
      _showErrorSnackBar('Fehler beim Hinzufügen: $e');
    }
  }

  Future<void> _updateBudgetItem(BudgetItem item) async {
    try {
      await _db.updateBudgetItem(item);

      if (!mounted) return; // ✅

      await _loadBudget();

      if (!mounted) return; // ✅

      _showSuccessSnackBar('Budgetposten aktualisiert');
    } catch (e) {
      if (!mounted) return; // ✅
      _showErrorSnackBar('Fehler beim Aktualisieren: $e');
    }
  }

  Future<void> _togglePaid(BudgetItem item) async {
    final updatedItem = item.copyWith(
      isPaid: !item.isPaid,
      actualCost: !item.isPaid ? item.estimatedCost : item.actualCost,
      updatedAt: DateTime.now(),
    );

    await _updateBudgetItem(updatedItem);
  }

  Future<void> _deleteBudgetItem(BudgetItem item) async {
    if (!mounted) return; // ✅

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Möchtest du "${item.name}" wirklich löschen?'),
            const SizedBox(height: 8),
            Text(
              'Kategorie: ${item.category}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              'Betrag: ${_formatCurrency(item.estimatedCost)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
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

    if (confirm == true && mounted) {
      // ✅
      try {
        await _db.deleteBudgetItem(item.id);

        if (!mounted) return; // ✅

        await _loadBudget();

        if (!mounted) return; // ✅

        _showSuccessSnackBar('Budgetposten "${item.name}" gelöscht');
      } catch (e) {
        if (!mounted) return; // ✅
        _showErrorSnackBar('Fehler beim Löschen: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<BudgetItem> _getFilteredItems() {
    var items = _budgetItems;

    if (_filterCategory != 'Alle') {
      items = items.where((item) => item.category == _filterCategory).toList();
    }

    if (_showPaidOnly) {
      items = items.where((item) => item.isPaid).toList();
    } else if (_showUnpaidOnly) {
      items = items.where((item) => !item.isPaid).toList();
    }

    switch (_sortBy) {
      case 'name':
        items.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'estimated':
        items.sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));
        break;
      case 'actual':
        items.sort((a, b) => b.actualCost.compareTo(a.actualCost));
        break;
      case 'category':
      default:
        items.sort((a, b) {
          final catCompare = a.category.compareTo(b.category);
          if (catCompare != 0) return catCompare;
          return a.name.compareTo(b.name);
        });
    }

    return items;
  }

  double? _parseCurrency(String text) {
    try {
      return double.parse(text.replaceAll('.', '').replaceAll(',', '.').trim());
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBudget,
            tooltip: 'Aktualisieren',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportBudget();
                  break;
                case 'import':
                  _importBudget();
                  break;
                case 'clear':
                  _clearAllBudgetItems();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload),
                    SizedBox(width: 12),
                    Text('Exportieren'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 12),
                    Text('Importieren'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 12),
                    Text('Alle löschen', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Übersicht'),
            Tab(icon: Icon(Icons.list), text: 'Liste'),
            Tab(icon: Icon(Icons.add), text: 'Neu'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildOverviewTab(), _buildListTab(), _buildAddTab()],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadBudget,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTotalBudgetCard(),
          const SizedBox(height: 16),
          _buildBudgetOverview(),
          const SizedBox(height: 16),
          _buildStatsCards(),
          const SizedBox(height: 16),
          _buildCategoryBreakdown(),
          const SizedBox(height: 16),
          _buildRecentItems(),
        ],
      ),
    );
  }

  Widget _buildTotalBudgetCard() {
    final totalEstimated = _budgetItems.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCost,
    );
    final totalActual = _budgetItems.fold<double>(
      0,
      (sum, item) => sum + item.actualCost,
    );
    final remaining = _totalBudget - totalActual;
    final percentUsed = _totalBudget > 0
        ? (totalActual / _totalBudget * 100)
        : 0;

    final isOverBudget = percentUsed > 100;
    final isNearLimit = percentUsed > 80 && percentUsed <= 100;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOverBudget
                ? [Colors.red.shade400, Colors.red.shade600]
                : isNearLimit
                ? [Colors.orange.shade400, Colors.orange.shade600]
                : [Colors.blue.shade400, Colors.blue.shade600],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gesamtbudget',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _editTotalBudget,
                    tooltip: 'Budget bearbeiten',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _formatCurrency(_totalBudget),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (percentUsed / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? Colors.red.shade900 : Colors.white,
                  ),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verbraucht',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${percentUsed.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        remaining < 0 ? 'Überschritten' : 'Verbleibend',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCurrency(remaining.abs()),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isOverBudget) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Budget überschritten!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetOverview() {
    final totalEstimated = _budgetItems.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCost,
    );
    final totalActual = _budgetItems.fold<double>(
      0,
      (sum, item) => sum + item.actualCost,
    );

    final categoryData = <String, double>{};
    for (var item in _budgetItems) {
      categoryData[item.category] =
          (categoryData[item.category] ?? 0) + item.actualCost;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Budget-Übersicht',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_budgetItems.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Details'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (categoryData.isNotEmpty)
              Column(
                children: [
                  SizedBox(height: 250, child: _buildDonutChart(categoryData)),
                  const SizedBox(height: 20),
                  _buildChartLegend(categoryData),
                ],
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.pie_chart_outline,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Budgetposten vorhanden',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => _tabController.animateTo(2),
                        icon: const Icon(Icons.add),
                        label: const Text('Ersten Posten hinzufügen'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(Map<String, double> data) {
    final total = data.values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) {
      return const Center(child: Text('Keine Daten'));
    }

    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.amber.shade400,
      Colors.indigo.shade400,
      Colors.pink.shade400,
      Colors.cyan.shade400,
      Colors.lime.shade400,
      Colors.brown.shade400,
      Colors.deepOrange.shade400,
      Colors.lightGreen.shade400,
    ];

    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomPaint(
        painter: _DonutChartPainter(data, colors, total),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Gesamt',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                _formatCurrency(total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartLegend(Map<String, double> data) {
    final total = data.values.fold<double>(0, (sum, value) => sum + value);
    final sortedData = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.amber.shade400,
      Colors.indigo.shade400,
      Colors.pink.shade400,
      Colors.cyan.shade400,
      Colors.lime.shade400,
      Colors.brown.shade400,
      Colors.deepOrange.shade400,
      Colors.lightGreen.shade400,
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: sortedData.asMap().entries.map((entry) {
        final index = entry.key;
        final category = entry.value.key;
        final value = entry.value.value;
        final percent = (value / total * 100).toStringAsFixed(1);

        return SizedBox(
          width: (MediaQuery.of(context).size.width - 80) / 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$percent% • ${_formatCurrency(value)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatsCards() {
    final totalEstimated = _budgetItems.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCost,
    );
    final totalActual = _budgetItems.fold<double>(
      0,
      (sum, item) => sum + item.actualCost,
    );
    final paidCount = _budgetItems.where((item) => item.isPaid).length;
    final unpaidCount = _budgetItems.length - paidCount;
    final difference = totalActual - totalEstimated;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Geplant',
                _formatCurrency(totalEstimated),
                Colors.blue,
                Icons.receipt_long,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Ausgegeben',
                _formatCurrency(totalActual),
                Colors.orange,
                Icons.payments,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Bezahlt',
                paidCount.toString(),
                Colors.green,
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Ausstehend',
                unpaidCount.toString(),
                Colors.grey,
                Icons.schedule,
              ),
            ),
          ],
        ),
        if (difference.abs() > 0) ...[
          const SizedBox(height: 12),
          _buildStatCard(
            difference > 0 ? 'Über Budget' : 'Unter Budget',
            _formatCurrency(difference.abs()),
            difference > 0 ? Colors.red : Colors.green,
            difference > 0 ? Icons.arrow_upward : Icons.arrow_downward,
            fullWidth: true,
          ),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    bool fullWidth = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: fullWidth ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    final categoryTotals = <String, Map<String, double>>{};

    for (var item in _budgetItems) {
      if (!categoryTotals.containsKey(item.category)) {
        categoryTotals[item.category] = {'estimated': 0, 'actual': 0};
      }
      categoryTotals[item.category]!['estimated'] =
          (categoryTotals[item.category]!['estimated'] ?? 0) +
          item.estimatedCost;
      categoryTotals[item.category]!['actual'] =
          (categoryTotals[item.category]!['actual'] ?? 0) + item.actualCost;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value['actual']!.compareTo(a.value['actual']!));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ausgaben nach Kategorie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (sortedCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Noch keine Kategorien vorhanden',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...sortedCategories.map((entry) {
                final category = entry.key;
                final estimated = entry.value['estimated']!;
                final actual = entry.value['actual']!;
                final percent = estimated > 0 ? (actual / estimated * 100) : 0;
                final itemCount = _budgetItems
                    .where((item) => item.category == category)
                    .length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _filterCategory = category;
                      });
                      _tabController.animateTo(1);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '$itemCount',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${_formatCurrency(actual)} / ${_formatCurrency(estimated)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (percent / 100).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent > 100
                                    ? Colors.red
                                    : percent > 80
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${percent.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (percent > 100)
                                Text(
                                  'Überschritten',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.red[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItems() {
    if (_budgetItems.isEmpty) return const SizedBox.shrink();

    final recentItems = [..._budgetItems]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
      ..take(5);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Zuletzt hinzugefügt',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _tabController.animateTo(1),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Alle'),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = recentItems[index];
              return _buildBudgetItemTile(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildListTab() {
    final filteredItems = _getFilteredItems();

    return Column(
      children: [
        _buildFilterChips(),
        Expanded(
          child: filteredItems.isEmpty
              ? _buildEmptyList()
              : RefreshIndicator(
                  onRefresh: _loadBudget,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: _buildBudgetItemCard(item),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Alle',
                  _filterCategory == 'Alle',
                  () => setState(() => _filterCategory = 'Alle'),
                ),
                const SizedBox(width: 8),
                ...BudgetCategories.defaults.map((category) {
                  final count = _budgetItems
                      .where((item) => item.category == category)
                      .length;
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      '$category ($count)',
                      _filterCategory == category,
                      () => setState(() => _filterCategory = category),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(
                'Bezahlt',
                _showPaidOnly,
                () => setState(() {
                  _showPaidOnly = !_showPaidOnly;
                  if (_showPaidOnly) _showUnpaidOnly = false;
                }),
                icon: Icons.check_circle,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Ausstehend',
                _showUnpaidOnly,
                () => setState(() {
                  _showUnpaidOnly = !_showUnpaidOnly;
                  if (_showUnpaidOnly) _showPaidOnly = false;
                }),
                icon: Icons.schedule,
              ),
              const Spacer(),
              PopupMenuButton<String>(
                icon: Icon(Icons.sort, color: Colors.grey[700]),
                onSelected: (value) {
                  setState(() => _sortBy = value);
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'category',
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          color: _sortBy == 'category' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Nach Kategorie',
                          style: TextStyle(
                            fontWeight: _sortBy == 'category'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'name',
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_by_alpha,
                          color: _sortBy == 'name' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Nach Name',
                          style: TextStyle(
                            fontWeight: _sortBy == 'name'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'estimated',
                    child: Row(
                      children: [
                        Icon(
                          Icons.euro,
                          color: _sortBy == 'estimated' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Nach geschätztem Preis',
                          style: TextStyle(
                            fontWeight: _sortBy == 'estimated'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'actual',
                    child: Row(
                      children: [
                        Icon(
                          Icons.payments,
                          color: _sortBy == 'actual' ? Colors.blue : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Nach tatsächlichem Preis',
                          style: TextStyle(
                            fontWeight: _sortBy == 'actual'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool selected,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 4)],
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildEmptyList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              _filterCategory != 'Alle'
                  ? 'Keine Posten in "$_filterCategory"'
                  : 'Noch keine Budgetposten',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _filterCategory != 'Alle'
                  ? 'Ändere den Filter oder füge neue Posten hinzu'
                  : 'Füge deinen ersten Budgetposten hinzu',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (_filterCategory != 'Alle') {
                  setState(() => _filterCategory = 'Alle');
                } else {
                  _tabController.animateTo(2);
                }
              },
              icon: Icon(_filterCategory != 'Alle' ? Icons.clear : Icons.add),
              label: Text(
                _filterCategory != 'Alle'
                    ? 'Filter zurücksetzen'
                    : 'Posten hinzufügen',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetItemCard(BudgetItem item) {
    final difference = item.actualCost - item.estimatedCost;
    final hasNotes = item.notes != null && item.notes!.isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          _showItemOptions(item);
        },
        onLongPress: () => _showItemOptions(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      item.isPaid ? Icons.check_circle : Icons.circle_outlined,
                      color: item.isPaid ? Colors.green : Colors.grey,
                      size: 28,
                    ),
                    onPressed: () => _togglePaid(item),
                    tooltip: item.isPaid ? 'Bezahlt' : 'Als bezahlt markieren',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            decoration: item.isPaid
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.category,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (hasNotes) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.notes,
                                size: 14,
                                color: Colors.grey[600],
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
                        _formatCurrency(item.actualCost),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: item.isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'von ${_formatCurrency(item.estimatedCost)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              if (difference.abs() > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (difference > 0 ? Colors.red : Colors.green)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        difference > 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: difference > 0 ? Colors.red : Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${difference > 0 ? '+' : ''}${_formatCurrency(difference.abs())}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: difference > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetItemTile(BudgetItem item) {
    return ListTile(
      leading: IconButton(
        icon: Icon(
          item.isPaid ? Icons.check_circle : Icons.circle_outlined,
          color: item.isPaid ? Colors.green : Colors.grey,
        ),
        onPressed: () => _togglePaid(item),
      ),
      title: Text(
        item.name,
        style: TextStyle(
          decoration: item.isPaid ? TextDecoration.lineThrough : null,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${item.category}${item.notes != null ? ' • ${item.notes}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatCurrency(item.actualCost),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: item.isPaid ? Colors.green : Colors.orange,
            ),
          ),
          Text(
            _formatCurrency(item.estimatedCost),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
      onTap: () {
        _showItemOptions(item);
      },
    );
  }

  Widget _buildAddTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_circle,
                        color: Colors.blue.shade700,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Neuer Budgetposten',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Füge einen neuen Posten zu deinem Budget hinzu',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildAddForm(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Bezeichnung *',
            hintText: 'z.B. Location-Miete, Hochzeitstorte',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.label),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          textCapitalization: TextCapitalization.sentences,
          autofocus: false,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Kategorie',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          items: BudgetCategories.defaults.map((category) {
            return DropdownMenuItem(value: category, child: Text(category));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _estimatedCostController,
          decoration: InputDecoration(
            labelText: 'Geschätzter Preis *',
            hintText: '0,00',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.euro),
            suffixText: '€',
            filled: true,
            fillColor: Colors.grey[50],
            helperText: 'Was du ungefähr ausgeben möchtest',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _actualCostController,
          decoration: InputDecoration(
            labelText: 'Tatsächlicher Preis (optional)',
            hintText: '0,00',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.payments),
            suffixText: '€',
            filled: true,
            fillColor: Colors.grey[50],
            helperText: 'Was du tatsächlich ausgegeben hast',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Notizen (optional)',
            hintText: 'Zusätzliche Informationen',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.notes),
            filled: true,
            fillColor: Colors.grey[50],
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: SwitchListTile(
            title: const Text(
              'Bereits bezahlt',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _isPaid
                  ? 'Dieser Posten wurde bereits bezahlt'
                  : 'Noch nicht bezahlt',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _isPaid,
            onChanged: (value) {
              setState(() => _isPaid = value);
            },
            secondary: Icon(
              _isPaid ? Icons.check_circle : Icons.schedule,
              color: _isPaid ? Colors.green : Colors.orange,
            ),
            activeColor: Colors.green,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _addBudgetItem,
            icon: const Icon(Icons.add_circle),
            label: const Text(
              'Budgetposten hinzufügen',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              _nameController.clear();
              _estimatedCostController.clear();
              _actualCostController.clear();
              _notesController.clear();
              setState(() {
                _selectedCategory = BudgetCategories.defaults[0];
                _isPaid = false;
              });

              if (!mounted) return; // ✅

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Formular zurückgesetzt')),
              );
            },
            icon: const Icon(Icons.clear),
            label: const Text('Formular zurücksetzen'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editTotalBudget() async {
    if (!mounted) return; // ✅

    final controller = TextEditingController(
      text: _totalBudget.toStringAsFixed(2).replaceAll('.', ','),
    );

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gesamtbudget bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Gesamtbudget',
                suffixText: '€',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Text(
              'Gib dein geplantes Gesamtbudget für die Hochzeit ein',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
              final value = _parseCurrency(controller.text);
              Navigator.pop(context, value);
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result != null && result > 0 && mounted) {
      // ✅
      setState(() => _totalBudget = result);
      await _saveTotalBudget();

      if (!mounted) return; // ✅

      _showSuccessSnackBar(
        'Gesamtbudget aktualisiert: ${_formatCurrency(result)}',
      );
    }
  }

  void _showFilterDialog() {
    if (!mounted) return; // ✅

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter & Sortierung'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kategorie',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Alle', ...BudgetCategories.defaults].map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _filterCategory == category,
                  onSelected: (selected) {
                    setState(() {
                      _filterCategory = category;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Nur bezahlte'),
              value: _showPaidOnly,
              onChanged: (value) {
                setState(() {
                  _showPaidOnly = value ?? false;
                  if (_showPaidOnly) _showUnpaidOnly = false;
                });
              },
            ),
            CheckboxListTile(
              title: const Text('Nur ausstehende'),
              value: _showUnpaidOnly,
              onChanged: (value) {
                setState(() {
                  _showUnpaidOnly = value ?? false;
                  if (_showUnpaidOnly) _showPaidOnly = false;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterCategory = 'Alle';
                _showPaidOnly = false;
                _showUnpaidOnly = false;
              });
              Navigator.pop(context);
            },
            child: const Text('Zurücksetzen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showItemOptions(BudgetItem item) {
    if (!mounted) return; // ✅

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Bearbeiten'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(item);
              },
            ),
            ListTile(
              leading: Icon(
                item.isPaid ? Icons.circle_outlined : Icons.check_circle,
              ),
              title: Text(
                item.isPaid
                    ? 'Als unbezahlt markieren'
                    : 'Als bezahlt markieren',
              ),
              onTap: () {
                Navigator.pop(context);
                _togglePaid(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Löschen', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteBudgetItem(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BudgetItem item) {
    if (!mounted) return; // ✅

    showDialog(
      context: context,
      builder: (context) => _EditBudgetDialog(
        item: item,
        onUpdate: _updateBudgetItem,
        onError: _showErrorSnackBar,
        parseCurrency: _parseCurrency,
      ),
    );
  }

  Future<void> _exportBudget() async {
    _showSuccessSnackBar('Export-Funktion wird bald verfügbar sein');
  }

  Future<void> _importBudget() async {
    _showSuccessSnackBar('Import-Funktion wird bald verfügbar sein');
  }

  Future<void> _clearAllBudgetItems() async {
    if (!mounted) return; // ✅

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alle löschen?'),
        content: const Text(
          'Möchtest du wirklich ALLE Budgetposten löschen? Diese Aktion kann nicht rückgängig gemacht werden!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Alle löschen'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // ✅
      try {
        for (var item in _budgetItems) {
          await _db.deleteBudgetItem(item.id);
        }

        if (!mounted) return; // ✅

        await _loadBudget();

        if (!mounted) return; // ✅

        _showSuccessSnackBar('Alle Budgetposten gelöscht');
      } catch (e) {
        if (!mounted) return; // ✅
        _showErrorSnackBar('Fehler beim Löschen: $e');
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(intPart[i]);
    }

    return '${buffer.toString()},${decPart} €';
  }
}

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> data;
  final List<Color> colors;
  final double total;

  _DonutChartPainter(this.data, this.colors, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final innerRadius = radius * 0.6;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius - innerRadius
      ..strokeCap = StrokeCap.round;

    double startAngle = -math.pi / 2;

    int colorIndex = 0;
    for (var entry in data.entries) {
      if (entry.value == 0) continue;

      final sweepAngle = (entry.value / total) * 2 * math.pi;
      paint.color = colors[colorIndex % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
      colorIndex++;
    }

    final innerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _EditBudgetDialog extends StatefulWidget {
  final BudgetItem item;
  final Future<void> Function(BudgetItem) onUpdate;
  final void Function(String) onError;
  final double? Function(String) parseCurrency;

  const _EditBudgetDialog({
    required this.item,
    required this.onUpdate,
    required this.onError,
    required this.parseCurrency,
  });

  @override
  State<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends State<_EditBudgetDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _estimatedController;
  late final TextEditingController _actualController;
  late final TextEditingController _notesController;
  late String _selectedCategory;
  late bool _isPaid;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _estimatedController = TextEditingController(
      text: widget.item.estimatedCost.toStringAsFixed(2).replaceAll('.', ','),
    );
    _actualController = TextEditingController(
      text: widget.item.actualCost.toStringAsFixed(2).replaceAll('.', ','),
    );
    _notesController = TextEditingController(text: widget.item.notes ?? '');
    _selectedCategory = widget.item.category;
    _isPaid = widget.item.isPaid;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _actualController.dispose();
    _estimatedController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Budgetposten bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Bezeichnung',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
                border: OutlineInputBorder(),
              ),
              items: BudgetCategories.defaults.map((cat) {
                return DropdownMenuItem(value: cat, child: Text(cat));
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _estimatedController,
              decoration: const InputDecoration(
                labelText: 'Geschätzter Preis',
                border: OutlineInputBorder(),
                suffixText: '€',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actualController,
              decoration: const InputDecoration(
                labelText: 'Tatsächlicher Preis',
                border: OutlineInputBorder(),
                suffixText: '€',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notizen',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('Bereits bezahlt'),
              value: _isPaid,
              onChanged: (value) {
                setState(() => _isPaid = value ?? false);
              },
              controlAffinity: ListTileControlAffinity.leading,
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
        ElevatedButton(
          onPressed: () async {
            final estimated = widget.parseCurrency(_estimatedController.text);
            final actual = widget.parseCurrency(_actualController.text);

            if (_nameController.text.trim().isEmpty ||
                estimated == null ||
                actual == null) {
              widget.onError('Bitte fülle alle Pflichtfelder aus');
              return;
            }

            final updatedItem = widget.item.copyWith(
              name: _nameController.text.trim(),
              category: _selectedCategory,
              estimatedCost: estimated,
              actualCost: actual,
              isPaid: _isPaid,
              notes: _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
              updatedAt: DateTime.now(),
            );

            await widget.onUpdate(updatedItem);

            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
