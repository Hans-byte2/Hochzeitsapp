import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import '../widgets/budget_donut_chart.dart';
import '../models/budget_models.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import 'budget_detail_screen.dart';

class EnhancedBudgetPage extends StatefulWidget {
  const EnhancedBudgetPage({super.key});

  @override
  State<EnhancedBudgetPage> createState() => _EnhancedBudgetPageState();
}

class _EnhancedBudgetPageState extends State<EnhancedBudgetPage> {
  List<Map<String, dynamic>> _budgetItems = [];
  bool _isLoading = true;
  bool _showForm = false;
  double _totalBudget = 0.0;
  final _totalBudgetController = TextEditingController();

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
  String _itemName = '';
  double _plannedAmount = 0.0;
  double _actualAmount = 0.0;
  String _notes = '';
  bool _isPaid = false;

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');

  String _formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _loadBudgetItems();
    _loadTotalBudget();
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    super.dispose();
  }

  // Gesamtbudget aus Datenbank laden
  Future<void> _loadTotalBudget() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final result = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['total_budget'],
      );

      if (result.isNotEmpty) {
        final value = result.first['value'];
        setState(() {
          _totalBudget = double.tryParse(value.toString()) ?? 0.0;
          _totalBudgetController.text = _totalBudget.toStringAsFixed(0);
        });
      }
    } catch (e) {
      print('Fehler beim Laden des Gesamtbudgets: $e');
    }
  }

  // Gesamtbudget speichern
  Future<void> _saveTotalBudget(double budget) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('app_settings', {
        'key': 'total_budget',
        'value': budget.toString(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      setState(() {
        _totalBudget = budget;
      });
    } catch (e) {
      print('Fehler beim Speichern des Gesamtbudgets: $e');
    }
  }

  // Dialog zum Bearbeiten des Gesamtbudgets
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

    if (result != null) {
      await _saveTotalBudget(result);
    }
  }

  Future<void> _initializeDatabase() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Spalten hinzufügen (Fehler ignorieren, wenn schon vorhanden)
      try {
        await db.execute(
          'ALTER TABLE budget_items ADD COLUMN category TEXT DEFAULT \'other\'',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE budget_items ADD COLUMN notes TEXT DEFAULT \'\'',
        );
      } catch (_) {}

      try {
        await db.execute(
          'ALTER TABLE budget_items ADD COLUMN paid INTEGER DEFAULT 0',
        );
      } catch (_) {}

      // app_settings Tabelle
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      } catch (e) {
        print('Fehler bei app_settings Tabelle: $e');
      }
    } catch (e) {
      print('Fehler beim Initialisieren der Datenbank: $e');
    }
  }

  Future<void> _loadBudgetItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final items = await DatabaseHelper.instance.getAllBudgetItems();

      if (mounted) {
        setState(() {
          _budgetItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Fehler beim Laden der Budget-Items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double get totalPlanned =>
      _budgetItems.fold(0, (sum, item) => sum + (item['planned'] ?? 0));

  double get totalActual =>
      _budgetItems.fold(0, (sum, item) => sum + (item['actual'] ?? 0));

  double get remaining => totalPlanned - totalActual;

  Map<String, Map<String, dynamic>> get categoryStats {
    Map<String, Map<String, dynamic>> stats = {};
    for (var category in _categoryLabels.keys) {
      final items = _budgetItems
          .where((item) => (item['category'] ?? 'other') == category)
          .toList();
      final plannedCat = items.fold(
        0.0,
        (sum, item) => sum + (item['planned'] ?? 0),
      );
      final actualCat = items.fold(
        0.0,
        (sum, item) => sum + (item['actual'] ?? 0),
      );

      stats[category] = {
        'plannedTotal': plannedCat,
        'actualTotal': actualCat,
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

  List<BudgetItem> _convertToBudgetItems() {
    return _budgetItems.map((map) {
      return BudgetItem(
        id: map['id'],
        name: map['name'] ?? '',
        planned: (map['planned'] ?? 0).toDouble(),
        actual: (map['actual'] ?? 0).toDouble(),
        category: map['category'] ?? 'other',
        notes: map['notes'] ?? '',
        paid: (map['paid'] ?? 0) == 1,
      );
    }).toList();
  }

  Future<void> _exportAsPdf() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final budgetItems = _convertToBudgetItems();
      await PdfExportService.exportBudgetToPdf(budgetItems);

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
                SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Erstellen: $e')),
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
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final budgetItems = _convertToBudgetItems();
      await ExcelExportService.exportBudgetToExcel(budgetItems);

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
                SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Erstellen: $e')),
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
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'budget_items',
        {'paid': currentPaidStatus ? 0 : 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _loadBudgetItems();
    } catch (e) {
      print('Fehler beim Aktualisieren des Bezahlt-Status: $e');
    }
  }

  Future<void> _addBudgetItem() async {
    if (_itemName.isEmpty) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('budget_items', {
        'name': _itemName,
        'planned': _plannedAmount,
        'actual': _actualAmount,
        'category': _selectedCategory,
        'notes': _notes,
        'paid': _isPaid ? 1 : 0,
      });
      setState(() {
        _itemName = '';
        _plannedAmount = 0.0;
        _actualAmount = 0.0;
        _notes = '';
        _isPaid = false;
        _selectedCategory = 'other';
        _showForm = false;
      });
      await _loadBudgetItems();
    } catch (e) {
      print('Fehler beim Hinzufügen des Budget-Items: $e');
    }
  }

  Future<void> _editBudgetItem(Map<String, dynamic> item) async {
    String editName = item['name'];
    double editPlanned = item['planned']?.toDouble() ?? 0.0;
    double editActual = item['actual']?.toDouble() ?? 0.0;
    String editCategory = item['category'] ?? 'other';
    String editNotes = item['notes'] ?? '';
    bool editPaid = (item['paid'] ?? 0) == 1;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (builderContext) {
        String dialogCategory = editCategory;
        bool dialogPaid = editPaid;

        final dialogScheme = Theme.of(builderContext).colorScheme;

        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              title: const Text('Budgetposten bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kategorie',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: dialogCategory,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _categoryLabels.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              dialogCategory = value!;
                              editCategory = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bezeichnung',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: TextEditingController(text: editName),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (value) => editName = value,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Geplant (€)',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: TextEditingController(
                                  text: editPlanned.toString(),
                                ),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) =>
                                    editPlanned = double.tryParse(value) ?? 0.0,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tatsächlich (€)',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: TextEditingController(
                                  text: editActual.toString(),
                                ),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) =>
                                    editActual = double.tryParse(value) ?? 0.0,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notizen',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: TextEditingController(text: editNotes),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: 'Zusätzliche Informationen',
                          ),
                          onChanged: (value) => editNotes = value,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('Bereits bezahlt'),
                      value: dialogPaid,
                      onChanged: (value) {
                        setDialogState(() {
                          dialogPaid = value ?? false;
                          editPaid = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(builderContext),
                  child: const Text('Abbrechen'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(builderContext, {'delete': true}),
                  child: const Text(
                    'Löschen',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(builderContext, {
                      'name': editName,
                      'planned': editPlanned,
                      'actual': editActual,
                      'category': editCategory,
                      'notes': editNotes,
                      'paid': editPaid ? 1 : 0,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dialogScheme.primary,
                    foregroundColor: dialogScheme.onPrimary,
                  ),
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      if (result['delete'] == true) {
        try {
          await DatabaseHelper.instance.deleteBudgetItem(item['id']);
          await _loadBudgetItems();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Budgetposten gelöscht')),
            );
          }
        } catch (e) {
          print('Fehler beim Löschen: $e');
        }
      } else {
        try {
          await DatabaseHelper.instance.updateBudgetItem(
            item['id'],
            result['name'],
            result['planned'],
            result['actual'],
          );
          final db = await DatabaseHelper.instance.database;
          await db.update(
            'budget_items',
            {
              'category': result['category'],
              'notes': result['notes'],
              'paid': result['paid'],
            },
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          await _loadBudgetItems();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Budgetposten aktualisiert')),
            );
          }
        } catch (e) {
          print('Fehler beim Speichern: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
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
              IconButton(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.share),
                tooltip: 'Exportieren',
                style: IconButton.styleFrom(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                onPressed: () => setState(() => _showForm = !_showForm),
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

  // Gesamtbudget Card
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
              // Gesamtbudget, Betrag und Edit-Button
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
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                    onPressed: _showEditTotalBudgetDialog,
                    tooltip: 'Gesamtbudget bearbeiten',
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Davon verplant:',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          '€${_formatCurrency(totalPlanned)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ausgegeben:',
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          '€${_formatCurrency(totalActual)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
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
                        value: percentageUsed / 100,
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

  Widget _buildBudgetOverview() {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: const Size(80, 80),
                        painter: BudgetDonutChartPainter(
                          totalPlanned: totalPlanned,
                          totalActual: totalActual,
                          remaining: remaining,
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${totalPlanned > 0 ? ((totalActual / totalPlanned) * 100).toStringAsFixed(0) : "0"}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Text(
                              'ausgegeben',
                              style: TextStyle(fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(
                                'Geplant',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '€${_formatCurrency(totalPlanned)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                'Ausgegeben',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                '€${_formatCurrency(totalActual)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          Text(
                            'Übrig',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '€${_formatCurrency(remaining)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: remaining >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalPlanned > 0 ? totalActual / totalPlanned : 0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                totalActual > totalPlanned ? Colors.red : scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Geplant',
            '€${_formatCurrency(totalPlanned)}',
            Icons.account_balance_wallet,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Ausgegeben',
            '€${_formatCurrency(totalActual)}',
            totalActual <= totalPlanned
                ? Icons.trending_up
                : Icons.trending_down,
            totalActual <= totalPlanned ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Verbleibt',
            '€${_formatCurrency(remaining)}',
            Icons.savings,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
            const SizedBox(height: 16),
            // Kategorie
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kategorie',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: _categoryLabels.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bezeichnung
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bezeichnung',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    hintText: 'z.B. Hochzeitslocation',
                  ),
                  onChanged: (value) => _itemName = value,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Geplant / Tatsächlich
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Geplanter Betrag (€)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          hintText: '0',
                        ),
                        onChanged: (value) =>
                            _plannedAmount = double.tryParse(value) ?? 0.0,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tatsächlicher Betrag (€)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          hintText: '0',
                        ),
                        onChanged: (value) =>
                            _actualAmount = double.tryParse(value) ?? 0.0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Notizen
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notizen',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    hintText: 'Zusätzliche Informationen',
                  ),
                  onChanged: (value) => _notes = value,
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Bereits bezahlt'),
              value: _isPaid,
              onChanged: (value) => setState(() => _isPaid = value ?? false),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _addBudgetItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                  ),
                  child: const Text('Hinzufügen'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => setState(() => _showForm = false),
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
                final percentage = stat['plannedTotal'] > 0
                    ? (stat['actualTotal'] / stat['plannedTotal']) * 100
                    : 0.0;

                return GestureDetector(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryDetailPage(
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
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: color.withOpacity(0.2)),
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
                          style: const TextStyle(fontSize: 8),
                        ),
                        const SizedBox(height: 2),
                        LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                          minHeight: 2,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${stat['itemCount']} Posten →',
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
                    final category = item['category'] ?? 'other';
                    final isPaid = (item['paid'] ?? 0) == 1;

                    return InkWell(
                      onTap: () => _editBudgetItem(item),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: dividerColor),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _togglePaid(item['id'], isPaid),
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
                                    item['name'],
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
                                      if (item['notes'] != null &&
                                          item['notes']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            item['notes'],
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
                                  '€${_formatCurrency(item['actual'] ?? 0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'geplant: €${_formatCurrency(item['planned'])}',
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
