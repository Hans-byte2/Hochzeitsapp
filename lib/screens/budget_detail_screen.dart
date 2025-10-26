import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_colors.dart';
import '../data/database_helper.dart';

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
  List<Map<String, dynamic>> _categoryItems = [];
  bool _isLoading = true;
  double _categoryPlanned = 0.0;
  double _categoryActual = 0.0;
  int _paidItems = 0;

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

      final allItems = await DatabaseHelper.instance.getAllBudgetItems();
      final categoryItems = allItems
          .where((item) => (item['category'] ?? 'other') == widget.category)
          .toList();

      double planned = 0.0;
      double actual = 0.0;
      int paid = 0;

      for (final item in categoryItems) {
        planned += item['planned'] ?? 0.0;
        actual += item['actual'] ?? 0.0;
        if ((item['paid'] ?? 0) == 1) paid++;
      }

      if (mounted) {
        setState(() {
          _categoryItems = categoryItems;
          _categoryPlanned = planned;
          _categoryActual = actual;
          _paidItems = paid;
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
      print('Fehler beim Aktualisieren des Bezahlt-Status: $e');
    }
  }

  Future<void> _addNewBudgetItem() async {
    String newName = '';
    double newPlanned = 0.0;
    double newActual = 0.0;
    String newNotes = '';
    bool newPaid = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (builderContext) {
        bool dialogPaid = newPaid;

        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              title: Text('Neuer Posten: ${widget.categoryName}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bezeichnung',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            hintText: 'z.B. Hochzeitslocation',
                          ),
                          onChanged: (value) => newName = value,
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
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  hintText: '',
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
                                  hintText: '',
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
                            hintText: '',
                          ),
                          onChanged: (value) => newNotes = value,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: dialogPaid,
                          onChanged: (value) {
                            setDialogState(() {
                              dialogPaid = value ?? false;
                              newPaid = dialogPaid;
                            });
                          },
                        ),
                        const Text('Bereits bezahlt'),
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
                  onPressed: () async {
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          content: Text('Bitte geben Sie eine Bezeichnung ein'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, {
                      'name': newName,
                      'planned': newPlanned,
                      'actual': newActual,
                      'notes': newNotes,
                      'paid': newPaid,
                    });
                  },
                  child: const Text('Hinzufügen'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('budget_items', {
          'name': result['name'],
          'planned': result['planned'],
          'actual': result['actual'],
          'category': widget.category,
          'notes': result['notes'] ?? '',
          'paid': result['paid'] ? 1 : 0,
        });
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

  Future<void> _editBudgetItemInDetail(Map<String, dynamic> item) async {
    String editName = item['name'];
    double editPlanned = item['planned'];
    double editActual = item['actual'] ?? 0.0;
    String editNotes = item['notes'] ?? '';
    bool editPaid = (item['paid'] ?? 0) == 1;

    final plannedController = TextEditingController(
      text: editPlanned.toStringAsFixed(0),
    );
    final actualController = TextEditingController(
      text: editActual.toStringAsFixed(0),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (builderContext) {
        bool dialogPaid = editPaid;

        return StatefulBuilder(
          builder: (statefulContext, setDialogState) {
            return AlertDialog(
              title: Text('Bearbeiten: $editName'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                          autofocus: true,
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
                                controller: plannedController,
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
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: dialogPaid,
                          onChanged: (value) {
                            setDialogState(() {
                              dialogPaid = value ?? false;
                              editPaid = dialogPaid;
                            });
                          },
                        ),
                        const Text('Bereits bezahlt'),
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
                    if (editName.isEmpty) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        const SnackBar(
                          content: Text('Bitte geben Sie eine Bezeichnung ein'),
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context, {
                      'name': editName,
                      'planned': editPlanned,
                      'actual': editActual,
                      'notes': editNotes,
                      'paid': editPaid,
                    });
                  },
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
        await _deleteItem(item['id']);
      } else {
        try {
          final db = await DatabaseHelper.instance.database;
          await db.update(
            'budget_items',
            {
              'name': result['name'],
              'planned': result['planned'],
              'actual': result['actual'],
              'notes': result['notes'],
              'paid': result['paid'] ? 1 : 0,
            },
            where: 'id = ?',
            whereArgs: [item['id']],
          );
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

  Future<void> _deleteItem(int id) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('budget_items', where: 'id = ?', whereArgs: [id]);
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
                            final isPaid = (item['paid'] ?? 0) == 1;

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
                                            onTap: () =>
                                                _togglePaid(item['id'], isPaid),
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
                                              item['name'],
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
                                                _deleteItem(item['id']);
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
                                              '€${_formatCurrency(item['planned'])}',
                                              Colors.blue,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _buildDetailCard(
                                              'Tatsächlich',
                                              '€${_formatCurrency(item['actual'] ?? 0)}',
                                              Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item['notes'] != null &&
                                          item['notes']
                                              .toString()
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
                                                item['notes'],
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
