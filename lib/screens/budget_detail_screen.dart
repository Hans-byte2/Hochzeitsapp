import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database_helper.dart';
import '../models/wedding_models.dart';
// Smart Validation Import
import '../widgets/forms/smart_text_field.dart';

class CategoryDetailPage extends StatefulWidget {
  final String category;
  final String categoryName;

  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.categoryName,
  });

  @override
  State<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends State<CategoryDetailPage> {
  List<BudgetItem> _categoryItems = [];
  bool _isLoading = true;
  double _categoryPlanned = 0.0;
  double _categoryActual = 0.0;

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

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');

  String _formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  @override
  void initState() {
    super.initState();
    _loadCategoryItems();
  }

  Future<void> _loadCategoryItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final allItems = await DatabaseHelper.instance.getAllBudgetItems();
      final categoryItems = allItems
          .where((item) => (item.category ?? 'other') == widget.category)
          .toList();

      double planned = 0.0;
      double actual = 0.0;

      for (final item in categoryItems) {
        final p = item.planned;
        final a = item.actual;
        planned += p is num ? p.toDouble() : 0.0;
        actual += a is num ? a.toDouble() : 0.0;
      }

      if (mounted) {
        setState(() {
          _categoryItems = categoryItems;
          _categoryPlanned = planned;
          _categoryActual = actual;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fehler beim Laden der Kategorie-Items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _togglePaid(int id, bool currentStatus) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'budget_items',
        {'paid': currentStatus ? 0 : 1},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _loadCategoryItems();
    } catch (e) {
      debugPrint('Fehler beim Aktualisieren des Bezahlt-Status: $e');
    }
  }

  Future<void> _addNewBudgetItem() async {
    showDialog(
      context: context,
      builder: (builderContext) => _AddBudgetItemDialog(
        category: widget.category,
        categoryName: widget.categoryName,
        onSave: _loadCategoryItems,
      ),
    );
  }

  Future<void> _editBudgetItemInDetail(BudgetItem item) async {
    showDialog(
      context: context,
      builder: (builderContext) => _EditBudgetItemDialog(
        item: item,
        onSave: _loadCategoryItems,
        onDelete: () => _deleteItem(item.id as int),
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('budget_items', where: 'id = ?', whereArgs: [id]);
      await _loadCategoryItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Posten gelöscht! ✓'),
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
    final categoryColor = _categoryColors[widget.category] ?? scheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.categoryName),
        backgroundColor: categoryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: categoryColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatColumn(
                        'Geplant',
                        '€${_formatCurrency(_categoryPlanned)}',
                        Icons.schedule,
                      ),
                      _buildStatColumn(
                        'Ausgegeben',
                        '€${_formatCurrency(_categoryActual)}',
                        Icons.account_balance_wallet,
                      ),
                      _buildStatColumn(
                        'Posten',
                        '${_categoryItems.length}',
                        Icons.list,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _categoryItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Noch keine Posten in dieser Kategorie',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tippe auf + um einen neuen Posten hinzuzufügen',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _categoryItems.length,
                          itemBuilder: (context, index) {
                            final item = _categoryItems[index];
                            final isPaid = (item.paid ?? 0) == 1;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                onTap: () => _editBudgetItemInDetail(item),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _togglePaid(
                                              item.id as int,
                                              isPaid,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: isPaid
                                                    ? Colors.green
                                                    : Colors.grey.shade300,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                isPaid
                                                    ? Icons.check
                                                    : Icons.circle_outlined,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              item.name ?? '',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                decoration: isPaid
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: isPaid
                                                    ? Colors.grey
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _editBudgetItemInDetail(item);
                                              } else if (value == 'delete') {
                                                _deleteItem(item.id as int);
                                              }
                                            },
                                            itemBuilder: (context) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.edit,
                                                      color: Colors.blue,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('Bearbeiten'),
                                                  ],
                                                ),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text('Löschen'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildDetailCard(
                                              'Geplant',
                                              '€${_formatCurrency((item.planned is num) ? (item.planned as num).toDouble() : 0.0)}',
                                              scheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildDetailCard(
                                              'Tatsächlich',
                                              '€${_formatCurrency((item.actual is num) ? (item.actual as num).toDouble() : 0.0)}',
                                              scheme.secondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.notes != null &&
                                          item.notes
                                              .toString()
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Notizen:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.notes,
                                                style: const TextStyle(
                                                  fontSize: 14,
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
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewBudgetItem,
        backgroundColor: categoryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildDetailCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD BUDGET ITEM DIALOG - Mit Smart Validation UND InputFormatter
// ============================================================================

class _AddBudgetItemDialog extends StatefulWidget {
  final String category;
  final String categoryName;
  final VoidCallback onSave;

  const _AddBudgetItemDialog({
    required this.category,
    required this.categoryName,
    required this.onSave,
  });

  @override
  State<_AddBudgetItemDialog> createState() => _AddBudgetItemDialogState();
}

class _AddBudgetItemDialogState extends State<_AddBudgetItemDialog> {
  final _nameController = TextEditingController();
  final _plannedController = TextEditingController();
  final _actualController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isPaid = false;

  final Map<String, bool> _fieldValidation = {};

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
    return (_fieldValidation['name'] ?? false) &&
        (_fieldValidation['planned'] ?? false);
  }

  double? _parseGermanNumber(String value) {
    if (value.trim().isEmpty) return null;
    // Ersetze Komma durch Punkt
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _save() async {
    if (!_isFormValid) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('budget_items', {
        'name': _nameController.text.trim(),
        'planned': _parseGermanNumber(_plannedController.text) ?? 0.0,
        'actual': _parseGermanNumber(_actualController.text) ?? 0.0,
        'category': widget.category,
        'notes': _notesController.text.trim(),
        'paid': _isPaid ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
        'deleted': 0,
      });

      widget.onSave();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Posten hinzugefügt! ✓'),
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
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text('Neuer Posten: ${widget.categoryName}'),
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

            // Bezeichnung - PFLICHT
            SmartTextField(
              label: 'Bezeichnung',
              fieldKey: 'name',
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

            // Geplant / Tatsächlich MIT INPUT FORMATTER
            Row(
              children: [
                Expanded(
                  child: SmartTextField(
                    label: 'Geplant (€)',
                    fieldKey: 'planned',
                    isRequired: true,
                    controller: _plannedController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Erforderlich';
                      }
                      final parsed = _parseGermanNumber(value);
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
                    label: 'Tatsächlich (€)',
                    fieldKey: 'actual',
                    isRequired: false,
                    controller: _actualController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final parsed = _parseGermanNumber(value);
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

            // Notizen
            SmartTextField(
              label: 'Notizen (optional)',
              fieldKey: 'notes',
              isRequired: false,
              controller: _notesController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 12),

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
        ElevatedButton(
          onPressed: _isFormValid ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isFormValid ? scheme.primary : Colors.grey[300],
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isFormValid ? Icons.add_circle : Icons.add_circle_outline),
              const SizedBox(width: 8),
              const Text('Hinzufügen'),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// EDIT BUDGET ITEM DIALOG - Mit Smart Validation UND InputFormatter
// ============================================================================

class _EditBudgetItemDialog extends StatefulWidget {
  final BudgetItem item;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _EditBudgetItemDialog({
    required this.item,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_EditBudgetItemDialog> createState() => _EditBudgetItemDialogState();
}

class _EditBudgetItemDialogState extends State<_EditBudgetItemDialog> {
  late TextEditingController _nameController;
  late TextEditingController _plannedController;
  late TextEditingController _actualController;
  late TextEditingController _notesController;
  late bool _isPaid;

  final Map<String, bool> _fieldValidation = {};

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name ?? '');
    _plannedController = TextEditingController(
      text:
          ((widget.item.planned is num)
                  ? (widget.item.planned as num).toDouble()
                  : 0.0)
              .toStringAsFixed(0),
    );
    _actualController = TextEditingController(
      text:
          ((widget.item.actual is num)
                  ? (widget.item.actual as num).toDouble()
                  : 0.0)
              .toStringAsFixed(0),
    );
    _notesController = TextEditingController(text: widget.item.notes ?? '');
    _isPaid = (widget.item.paid ?? 0) == 1;
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

  double? _parseGermanNumber(String value) {
    if (value.trim().isEmpty) return null;
    // Ersetze Komma durch Punkt
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  Future<void> _save() async {
    if (!_isFormValid) return;

    try {
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'budget_items',
        {
          'name': _nameController.text.trim(),
          'planned': _parseGermanNumber(_plannedController.text) ?? 0.0,
          'actual': _parseGermanNumber(_actualController.text) ?? 0.0,
          'notes': _notesController.text.trim(),
          'paid': _isPaid ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [widget.item.id],
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
                Text('Änderungen gespeichert! ✓'),
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
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Löschen bestätigen'),
        content: const Text('Möchten Sie diesen Posten wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onDelete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Posten bearbeiten'),
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

            // Geplant / Tatsächlich MIT INPUT FORMATTER
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Erforderlich';
                      }
                      final parsed = _parseGermanNumber(value);
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
                    label: 'Tatsächlich (€)',
                    fieldKey: 'edit_actual',
                    isRequired: false,
                    controller: _actualController,
                    onValidationChanged: _updateFieldValidation,
                    isDisabled: false,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final parsed = _parseGermanNumber(value);
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

            // Notizen
            SmartTextField(
              label: 'Notizen (optional)',
              fieldKey: 'edit_notes',
              isRequired: false,
              controller: _notesController,
              onValidationChanged: _updateFieldValidation,
              isDisabled: false,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 12),

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
          onPressed: _confirmDelete,
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Löschen'),
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
