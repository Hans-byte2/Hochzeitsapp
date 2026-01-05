import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';
import '../widgets/budget_donut_chart.dart';
import '../models/wedding_models.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import 'budget_detail_screen.dart';
// Smart Validation Import
import '../widgets/forms/smart_text_field.dart';

class EnhancedBudgetPage extends StatefulWidget {
  const EnhancedBudgetPage({super.key});

  @override
  State<EnhancedBudgetPage> createState() => _EnhancedBudgetPageState();
}

class _EnhancedBudgetPageState extends State<EnhancedBudgetPage> {
  List<BudgetItem> _budgetItems = [];
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
  final _itemNameController = TextEditingController();
  final _plannedAmountController = TextEditingController();
  final _actualAmountController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isPaid = false;

  // Smart Validation State
  final Map<String, bool> _fieldValidation = {};

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
    _itemNameController.dispose();
    _plannedAmountController.dispose();
    _actualAmountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateFieldValidation(String fieldKey, bool isValid) {
    if (mounted) {
      setState(() {
        _fieldValidation[fieldKey] = isValid;
      });
    }
  }

  bool get _isFormValid {
    return (_fieldValidation['item_name'] ?? false) &&
        (_fieldValidation['planned_amount'] ?? false);
  }

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
      _budgetItems.fold(0.0, (sum, item) => sum + item.planned);

  double get totalActual =>
      _budgetItems.fold(0.0, (sum, item) => sum + item.actual);

  double get remaining => totalPlanned - totalActual;

  Map<String, Map<String, dynamic>> get categoryStats {
    Map<String, Map<String, dynamic>> stats = {};
    for (var category in _categoryLabels.keys) {
      final items = _budgetItems
          .where((item) => item.category == category)
          .toList();
      final plannedCat = items.fold(0.0, (sum, item) => sum + item.planned);
      final actualCat = items.fold(0.0, (sum, item) => sum + item.actual);

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

  Future<void> _exportAsPdf() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final budgetItems = _budgetItems;
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

      final budgetItems = _budgetItems;
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
      final item = _budgetItems.firstWhere((item) => item.id == id);
      final updatedItem = item.copyWith(paid: !currentPaidStatus);
      await DatabaseHelper.instance.updateBudgetItem(updatedItem);
      await _loadBudgetItems();
    } catch (e) {
      print('Fehler beim Aktualisieren des Bezahlt-Status: $e');
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

      // Form zurücksetzen
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Budgetposten hinzugefügt! ✓'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Fehler beim Hinzufügen des Budget-Items: $e');
    }
  }

  Future<void> _editBudgetItem(BudgetItem item) async {
    showDialog(
      context: context,
      builder: (builderContext) => _BudgetItemEditDialog(
        item: item,
        categoryLabels: _categoryLabels,
        onSave: () async {
          await _loadBudgetItems();
        },
      ),
    );
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
                onPressed: () {
                  setState(() {
                    _showForm = !_showForm;
                    if (!_showForm) {
                      // Form zurücksetzen beim Schließen
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

  // Smart Validation Add Item Form
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

            // Fortschrittsanzeige
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

            // Kategorie
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Kategorie',
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
              onChanged: (value) => setState(() => _selectedCategory = value!),
            ),

            const SizedBox(height: 16),

            // Bezeichnung - PFLICHT
            SmartTextField(
              label: 'Bezeichnung',
              fieldKey: 'item_name',
              isRequired: true,
              controller: _itemNameController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bezeichnung ist erforderlich';
                }
                if (value.trim().length < 2) {
                  return 'Mindestens 2 Zeichen';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Geplant / Tatsächlich
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Betrag erforderlich';
                      }
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null) {
                        return 'Ungültige Zahl';
                      }
                      if (parsed < 0) {
                        return 'Muss ≥ 0 sein';
                      }
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
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null) {
                          return 'Ungültige Zahl';
                        }
                        if (parsed < 0) {
                          return 'Muss ≥ 0 sein';
                        }
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notizen - Optional
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
              onChanged: (value) => setState(() => _isPaid = value ?? false),
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
                    final category = item.category ?? 'other';
                    final isPaid = (item.paid ?? 0) == 1;

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
                                      if (item.notes != null &&
                                          item.notes.toString().isNotEmpty) ...[
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
                                  '€${_formatCurrency(item.actual ?? 0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
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
// BUDGET ITEM EDIT DIALOG - Mit Smart Validation
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
    if (mounted) {
      setState(() {
        _fieldValidation[fieldKey] = isValid;
      });
    }
  }

  bool get _isFormValid {
    return (_fieldValidation['edit_name'] ?? false) &&
        (_fieldValidation['edit_planned'] ?? false);
  }

  Future<void> _save() async {
    if (!_isFormValid) return;

    try {
      final updatedItem = widget.item.copyWith(
        name: _nameController.text.trim(),
        planned: double.tryParse(_plannedController.text) ?? 0.0,
        actual: double.tryParse(_actualController.text) ?? 0.0,
        category: _selectedCategory,
        notes: _notesController.text.trim(),
        paid: _isPaid,
      );

      await DatabaseHelper.instance.updateBudgetItem(updatedItem);
      widget.onSave();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Budgetposten aktualisiert! ✓'),
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
                Text('Budgetposten gelöscht! ✓'),
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
            // Fortschrittsanzeige
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

            // Kategorie
            DropdownButtonFormField<String>(
              value: _selectedCategory,
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

            // Bezeichnung - PFLICHT
            SmartTextField(
              label: 'Bezeichnung',
              fieldKey: 'edit_name',
              isRequired: true,
              controller: _nameController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bezeichnung ist erforderlich';
                }
                if (value.trim().length < 2) {
                  return 'Mindestens 2 Zeichen';
                }
                return null;
              },
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // Geplant / Tatsächlich
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Erforderlich';
                      }
                      final parsed = double.tryParse(value.trim());
                      if (parsed == null) {
                        return 'Ungültig';
                      }
                      if (parsed < 0) {
                        return 'Muss ≥ 0 sein';
                      }
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
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null) {
                          return 'Ungültig';
                        }
                        if (parsed < 0) {
                          return 'Muss ≥ 0 sein';
                        }
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notizen
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
