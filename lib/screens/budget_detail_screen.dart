import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../app_colors.dart';
import '../data/database_helper.dart';
import '../models/budget.dart'; // NEU: Budget Model

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
  List<Budget> _categoryItems = []; // GEÄNDERT: Budget Objekte
  bool _isLoading = true;
  double _categoryPlanned = 0.0;
  double _categoryActual = 0.0;
  final _uuid = const Uuid(); // NEU: UUID Generator

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

      // NEU: Verwende getBudgetsByCategory
      final categoryItems = await DatabaseHelper.instance.getBudgetsByCategory(
        widget.category,
      );

      double planned = 0.0;
      double actual = 0.0;

      for (final item in categoryItems) {
        planned += item.plannedAmount;
        actual += item.actualAmount;
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
      print('Fehler beim Laden der Kategorie-Items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addNewBudgetItem() async {
    double newPlanned = 0.0;
    double newActual = 0.0;
    String newNotes = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (builderContext) {
        return AlertDialog(
          title: Text('Neuer Posten: ${widget.categoryName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            autofocus: true,
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
                                newPlanned = double.tryParse(value) ?? 0.0,
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
                                newActual = double.tryParse(value) ?? 0.0,
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
                      'Notizen (optional)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                        hintText: 'z.B. Hochzeitslocation Mühlenhof',
                      ),
                      onChanged: (value) => newNotes = value,
                    ),
                  ],
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
              onPressed: () {
                Navigator.pop(context, {
                  'planned': newPlanned,
                  'actual': newActual,
                  'notes': newNotes,
                });
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      try {
        // NEU: Erstelle Budget-Objekt mit UUID
        final budget = Budget(
          id: _uuid.v4(),
          category: widget.category,
          plannedAmount: result['planned'],
          actualAmount: result['actual'],
          notes: result['notes'] ?? '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await DatabaseHelper.instance.insertBudget(budget);
        await _loadCategoryItems();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Posten hinzugefügt')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
        }
      }
    }
  }

  Future<void> _editBudgetItemInDetail(Budget item) async {
    double editPlanned = item.plannedAmount;
    double editActual = item.actualAmount;
    String editNotes = item.notes;

    final plannedController = TextEditingController(
      text: editPlanned.toStringAsFixed(0),
    );
    final actualController = TextEditingController(
      text: editActual.toStringAsFixed(0),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (builderContext) {
        return AlertDialog(
          title: const Text('Posten bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                            controller: plannedController,
                            autofocus: true,
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
                            controller: actualController,
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
                      'Notizen (optional)',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: TextEditingController(text: editNotes),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: (value) => editNotes = value,
                    ),
                  ],
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
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: builderContext,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Löschen bestätigen'),
                    content: const Text(
                      'Möchten Sie diesen Posten wirklich löschen?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Abbrechen'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Löschen'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  Navigator.pop(builderContext, {'delete': true});
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Löschen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'planned': editPlanned,
                  'actual': editActual,
                  'notes': editNotes,
                });
              },
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      if (result['delete'] == true) {
        await _deleteItem(item.id);
      } else {
        try {
          // NEU: Update mit Budget-Objekt
          final updatedBudget = item.copyWith(
            plannedAmount: result['planned'],
            actualAmount: result['actual'],
            notes: result['notes'],
            updatedAt: DateTime.now(),
          );

          await DatabaseHelper.instance.updateBudget(updatedBudget);
          await _loadCategoryItems();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Änderungen gespeichert')),
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
    }
  }

  Future<void> _deleteItem(String id) async {
    try {
      await DatabaseHelper.instance.deleteBudget(id);
      await _loadCategoryItems();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Posten gelöscht')));
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
    final categoryColor = _categoryColors[widget.category] ?? AppColors.primary;

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
                                          Expanded(
                                            child: Text(
                                              widget.categoryName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          PopupMenuButton<String>(
                                            onSelected: (value) {
                                              if (value == 'edit') {
                                                _editBudgetItemInDetail(item);
                                              } else if (value == 'delete') {
                                                _deleteItem(item.id);
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
                                              '€${_formatCurrency(item.plannedAmount)}',
                                              Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildDetailCard(
                                              'Tatsächlich',
                                              '€${_formatCurrency(item.actualAmount)}',
                                              Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.notes.isNotEmpty) ...[
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
