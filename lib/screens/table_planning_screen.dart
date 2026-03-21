import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../models/table_models.dart';
import '../models/table_categories.dart';
import '../data/database_helper.dart';
import '../app_colors.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/premium_service.dart'; // NEU
import '../widgets/upgrade_bottom_sheet.dart'; // NEU
import 'table_suggestion_screen.dart';
import '../sync/services/sync_service.dart';

class TischplanungPage extends StatefulWidget {
  final List<Guest> guests;
  final Future<void> Function(Guest) onUpdateGuest;

  const TischplanungPage({
    super.key,
    required this.guests,
    required this.onUpdateGuest,
  });

  @override
  State<TischplanungPage> createState() => TischplanungPageState();
}

class TischplanungPageState extends State<TischplanungPage> {
  List<TableData> tables = [];
  bool _isLoadingTables = true;
  String newTableName = '';
  int newTableSeats = 8;
  String newTableCategories = '';

  final _db = DatabaseHelper.instance;

  void _syncNow() {
    SyncService.instance.syncNow().catchError((e) {
      debugPrint('Sync-Fehler: $e');
    });
  }

  void reload() {
    _loadTablesFromDb();
  }

  @override
  void initState() {
    super.initState();
    _loadTablesFromDb();
  }

  Future<void> _loadTablesFromDb() async {
    try {
      final dbTables = await _db.getAllTables();
      final loaded = dbTables
          .map(
            (t) => TableData(
              id: t.id!,
              tableName: t.tableName,
              tableNumber: t.tableNumber,
              seats: t.seats,
              categoriesRaw: t.categoriesRaw,
            ),
          )
          .toList();
      if (mounted) {
        setState(() {
          tables = loaded;
          _isLoadingTables = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingTables = false);
    }
  }

  @override
  void didUpdateWidget(TischplanungPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  // ── NEU: Limit-Prüfung vor Tisch anlegen ─────────────────────────────────
  void _onAddTableTapped() {
    if (!PremiumService.instance.canAddTable(tables.length)) {
      UpgradeBottomSheet.show(
        context,
        featureName: 'Unbegrenzte Tische',
        featureDescription:
            'Du hast das Free-Limit von ${PremiumService.kFreeTableLimit} Tischen erreicht. '
            'Mit Premium planst du ohne Einschränkungen.',
      );
      return;
    }
    _showTableForm();
  }

  void _openSuggestion() {
    if (tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst Tische anlegen'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final confirmedGuests = widget.guests
        .where((g) => g.confirmed == 'yes')
        .length;
    if (confirmedGuests == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine zugesagten Gäste vorhanden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final tableModels = tables
        .map(
          (t) => TableModel(
            id: t.id,
            tableName: t.tableName,
            tableNumber: t.tableNumber,
            seats: t.seats,
            categoriesRaw: t.categoriesRaw,
          ),
        )
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TableSuggestionScreen(
          guests: widget.guests,
          tables: tableModels,
          onApplySuggestion: (Map<int, int> assignments) async {
            for (final guest in widget.guests.where(
              (g) => g.confirmed == 'yes',
            )) {
              if (guest.tableNumber != null && guest.tableNumber != 0) {
                await widget.onUpdateGuest(guest.copyWith(tableNumber: 0));
              }
            }
            for (final entry in assignments.entries) {
              final matches = widget.guests.where((g) => g.id == entry.key);
              if (matches.isNotEmpty) {
                await widget.onUpdateGuest(
                  matches.first.copyWith(tableNumber: entry.value),
                );
              }
            }
            _syncNow();
            if (mounted) setState(() {});
          },
          onUndoSuggestion: (Map<int, int?> snapshot) async {
            for (final entry in snapshot.entries) {
              final matches = widget.guests.where((g) => g.id == entry.key);
              if (matches.isNotEmpty) {
                await widget.onUpdateGuest(
                  matches.first.copyWith(tableNumber: entry.value ?? 0),
                );
              }
            }
            _syncNow();
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  List<Guest> _getRelevantGuests() => widget.guests
      .where((g) => g.confirmed == 'yes' || g.confirmed == 'pending')
      .toList();
  List<Guest> _getGuestsForTable(int tableNumber) =>
      _getRelevantGuests().where((g) => g.tableNumber == tableNumber).toList();
  List<Guest> _getUnassignedGuests() => _getRelevantGuests()
      .where(
        (g) =>
            g.tableNumber == null ||
            g.tableNumber == 0 ||
            !tables.any((t) => t.tableNumber == g.tableNumber),
      )
      .toList();
  int get seatedGuestsCount =>
      _getRelevantGuests().length - _getUnassignedGuests().length;

  Future<bool> _assignGuestToTable(Guest guest, int tableNumber) async {
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);
    if (guest.tableNumber == tableNumber) return true;
    final currentGuestsAtTable = _getGuestsForTable(
      tableNumber,
    ).where((g) => g.id != guest.id).length;
    if (currentGuestsAtTable >= table.seats) {
      _showTableFullError();
      return false;
    }
    final updatedGuest = guest.copyWith(tableNumber: tableNumber);
    await widget.onUpdateGuest(updatedGuest);
    _syncNow();
    return true;
  }

  Future<void> _removeGuestFromTable(Guest guest) async {
    await widget.onUpdateGuest(guest.copyWith(tableNumber: 0));
    _syncNow();
  }

  Future<void> _addTable() async {
    if (newTableName.isEmpty) return;
    final nextTableNumber = tables.isEmpty
        ? 1
        : tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) + 1;
    final model = TableModel(
      tableName: newTableName,
      tableNumber: nextTableNumber,
      seats: newTableSeats,
      categoriesRaw: newTableCategories.isEmpty ? null : newTableCategories,
    );
    try {
      final saved = await _db.createTable(model);
      if (mounted) {
        setState(() {
          tables.add(
            TableData(
              id: saved.id!,
              tableName: saved.tableName,
              tableNumber: saved.tableNumber,
              seats: saved.seats,
              categoriesRaw: saved.categoriesRaw,
            ),
          );
          newTableName = '';
          newTableSeats = 8;
          newTableCategories = '';
        });
      }
      _syncNow();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
    }
  }

  void _deleteTable(int tableId) {
    showDialog(
      context: context,
      builder: (builderContext) {
        final scheme = Theme.of(builderContext).colorScheme;
        return AlertDialog(
          title: const Text("Tisch loeschen"),
          content: const Text("Alle Gaeste werden wieder freigegeben."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(builderContext),
              child: const Text("Abbrechen"),
            ),
            ElevatedButton(
              onPressed: () async {
                final table = tables.firstWhere((t) => t.id == tableId);
                final guestsToUpdate = _getRelevantGuests()
                    .where((g) => g.tableNumber == table.tableNumber)
                    .toList();
                for (final guest in guestsToUpdate) {
                  await _removeGuestFromTable(guest);
                }
                await _db.deleteTable(tableId);
                if (mounted) {
                  setState(() {
                    tables.removeWhere((t) => t.id == tableId);
                  });
                }
                _syncNow();
                if (mounted) Navigator.pop(builderContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text("Loeschen"),
            ),
          ],
        );
      },
    );
  }

  void _showTableForm() {
    final nameController = TextEditingController();
    final seatsController = TextEditingController(text: '8');
    List<TableCategory> selectedCats = [];

    showDialog(
      context: context,
      builder: (builderContext) => StatefulBuilder(
        builder: (ctx, setDS) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Neuer Tisch'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Tischname'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: seatsController,
                    decoration: const InputDecoration(labelText: 'Plaetze'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kategorien',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Beeinflusst den automatischen Sitzvorschlag',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TableCategory.values.map((cat) {
                      final sel = selectedCats.contains(cat);
                      return FilterChip(
                        label: Text(
                          cat.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: sel,
                        onSelected: (v) => setDS(() {
                          if (v) {
                            selectedCats.add(cat);
                          } else {
                            selectedCats.remove(cat);
                          }
                        }),
                        selectedColor: scheme.primaryContainer,
                        checkmarkColor: scheme.primary,
                        side: BorderSide(
                          color: sel ? scheme.primary : scheme.outlineVariant,
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedCats.any((c) => c.isHard))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.lock, size: 12, color: scheme.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Familientisch: Nur Gaeste mit Beziehung "Familie" werden zugewiesen.',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(builderContext),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty) {
                    newTableName = nameController.text;
                    newTableSeats = int.tryParse(seatsController.text) ?? 8;
                    newTableCategories = TableCategories.serialize(
                      selectedCats,
                    );
                    _addTable();
                    Navigator.pop(builderContext);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                ),
                child: const Text('Erstellen'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTablePropertiesDialog(TableData table) {
    final nameController = TextEditingController(text: table.tableName);
    final seatsController = TextEditingController(text: table.seats.toString());
    List<TableCategory> selectedCats = TableCategories.parse(
      table.categoriesRaw,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDia) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: const Text('Tisch bearbeiten'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tischname',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.table_restaurant),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: seatsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Anzahl Plätze',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event_seat),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tisch-Kategorie',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TableCategory.values.map((cat) {
                      final selected = selectedCats.contains(cat);
                      return FilterChip(
                        label: Text(
                          cat.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: selected,
                        onSelected: (val) => setDia(() {
                          if (val) {
                            selectedCats.add(cat);
                          } else {
                            selectedCats.remove(cat);
                          }
                        }),
                        selectedColor: AppColors.primary.withOpacity(0.2),
                        checkmarkColor: AppColors.primary,
                      );
                    }).toList(),
                  ),
                  if (selectedCats.contains(TableCategory.familie)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Familientische nehmen nur Gäste mit Beziehung "Familie" an',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Speichern'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final newName = nameController.text.trim();
                  final newSeats =
                      int.tryParse(seatsController.text.trim()) ?? table.seats;
                  if (newName.isEmpty) return;
                  final newCatsRaw = TableCategories.serialize(selectedCats);
                  final updatedModel = TableModel(
                    id: table.id,
                    tableName: newName,
                    tableNumber: table.tableNumber,
                    seats: newSeats,
                    categoriesRaw: newCatsRaw.isEmpty ? null : newCatsRaw,
                  );
                  try {
                    await _db.updateTable(updatedModel);
                    if (mounted) {
                      setState(() {
                        final idx = tables.indexWhere((t) => t.id == table.id);
                        if (idx != -1) {
                          tables[idx] = TableData(
                            id: table.id,
                            tableName: newName,
                            tableNumber: table.tableNumber,
                            seats: newSeats,
                            categoriesRaw: newCatsRaw.isEmpty
                                ? null
                                : newCatsRaw,
                          );
                        }
                      });
                      _syncNow();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tisch "$newName" gespeichert'),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fehler: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTableDialog(TableData table) {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (builderContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final tableGuests = _getGuestsForTable(table.tableNumber);
          final allFreeGuests = _getUnassignedGuests();
          final freeGuests = searchQuery.isEmpty
              ? allFreeGuests
              : allFreeGuests.where((guest) {
                  final fullName = '${guest.firstName} ${guest.lastName}'
                      .toLowerCase();
                  return fullName.contains(searchQuery.toLowerCase());
                }).toList();

          return Dialog(
            child: SizedBox(
              width: 600,
              height: 700,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.tableName,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: scheme.onPrimary,
                                ),
                              ),
                              Text(
                                '${tableGuests.length} von ${table.seats} Plätzen belegt',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onPrimary.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: scheme.onPrimary),
                          onPressed: () => Navigator.pop(builderContext),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DragTarget<Guest>(
                      onAcceptWithDetails: (details) {
                        final guest = details.data;
                        if (guest.tableNumber != table.tableNumber) {
                          _assignGuestToTable(guest, table.tableNumber).then((
                            success,
                          ) {
                            if (success) setDialogState(() {});
                          });
                        }
                      },
                      onWillAcceptWithDetails: (details) => true,
                      builder: (context, candidateData, rejectedData) {
                        final isHighlighted = candidateData.isNotEmpty;
                        final isDraggingFromThisTable =
                            candidateData.isNotEmpty &&
                            candidateData.first?.tableNumber ==
                                table.tableNumber;
                        return Container(
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? (isDraggingFromThisTable
                                      ? theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withOpacity(0.3)
                                      : scheme.primaryContainer.withOpacity(
                                          0.3,
                                        ))
                                : theme.colorScheme.surfaceContainerHighest
                                      .withOpacity(0.2),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Gäste am Tisch (${tableGuests.length})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isHighlighted &&
                                      !isDraggingFromThisTable) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hier ablegen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: tableGuests.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_off_outlined,
                                              size: 40,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Keine Gäste am Tisch',
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Scrollbar(
                                        thumbVisibility: true,
                                        child: ListView.builder(
                                          itemCount: tableGuests.length,
                                          itemBuilder: (context, index) {
                                            final guest = tableGuests[index];
                                            return Draggable<Guest>(
                                              data: guest,
                                              feedback: Material(
                                                elevation: 6,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  width: 180,
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: scheme.primary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${guest.firstName} ${guest.lastName}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: scheme.onPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.3,
                                                child: _buildTinyGuestCard(
                                                  guest,
                                                  scheme.primary,
                                                  null,
                                                ),
                                              ),
                                              child: _buildTinyGuestCard(
                                                guest,
                                                scheme.primary,
                                                () {
                                                  _removeGuestFromTable(
                                                    guest,
                                                  ).then((_) {
                                                    setDialogState(() {});
                                                  });
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: theme.colorScheme.surface,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Gast suchen...',
                        hintStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  searchQuery = '';
                                  setDialogState(() {});
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: theme.dividerColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (value) {
                        searchQuery = value;
                        setDialogState(() {});
                      },
                    ),
                  ),
                  SizedBox(
                    height: 150,
                    child: DragTarget<Guest>(
                      onAcceptWithDetails: (details) {
                        final guest = details.data;
                        if (guest.tableNumber == table.tableNumber) {
                          _removeGuestFromTable(
                            guest,
                          ).then((_) => setDialogState(() {}));
                        }
                      },
                      onWillAcceptWithDetails: (details) => true,
                      builder: (context, candidateData, rejectedData) {
                        final isHighlighted = candidateData.isNotEmpty;
                        final isDraggingFromTable =
                            candidateData.isNotEmpty &&
                            candidateData.first?.tableNumber ==
                                table.tableNumber;
                        return Container(
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? (isDraggingFromTable
                                      ? scheme.errorContainer
                                      : scheme.surfaceContainerHighest)
                                : theme.colorScheme.surface,
                            border: isHighlighted && isDraggingFromTable
                                ? Border.all(color: scheme.error, width: 2)
                                : Border.all(color: theme.dividerColor),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_add, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Freie Gäste (${freeGuests.length}${searchQuery.isNotEmpty ? ' von ${allFreeGuests.length}' : ''})',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (isHighlighted && isDraggingFromTable) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      'Hier ablegen zum Entfernen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: scheme.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: freeGuests.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              searchQuery.isNotEmpty
                                                  ? Icons.search_off
                                                  : Icons.check_circle_outline,
                                              size: 24,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              searchQuery.isNotEmpty
                                                  ? 'Keine Gäste gefunden'
                                                  : 'Alle Gäste sind platziert',
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Scrollbar(
                                        thumbVisibility: true,
                                        child: ListView.builder(
                                          itemCount: freeGuests.length,
                                          itemBuilder: (context, index) {
                                            final guest = freeGuests[index];
                                            return Draggable<Guest>(
                                              data: guest,
                                              feedback: Material(
                                                elevation: 6,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                child: Container(
                                                  width: 180,
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: scheme.secondary,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${guest.firstName} ${guest.lastName}',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: scheme.onSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.3,
                                                child: _buildTinyGuestCard(
                                                  guest,
                                                  scheme.secondary,
                                                  null,
                                                ),
                                              ),
                                              child: _buildTinyGuestCard(
                                                guest,
                                                scheme.secondary,
                                                () async {
                                                  final success =
                                                      await _assignGuestToTable(
                                                        guest,
                                                        table.tableNumber,
                                                      );
                                                  if (success) {
                                                    setDialogState(() {});
                                                  }
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(builderContext),
                          child: const Text('Schließen'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTinyGuestCard(Guest guest, Color color, VoidCallback? onAction) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      elevation: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              radius: 12,
              child: Text(
                guest.firstName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${guest.firstName} ${guest.lastName}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (guest.dietaryRequirements.isNotEmpty)
                    Text(
                      guest.dietaryRequirements,
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (onAction != null)
              IconButton(
                icon: Icon(
                  color == scheme.primary || color == scheme.secondary
                      ? Icons.remove_circle
                      : Icons.add_circle,
                  color: color == scheme.primary || color == scheme.secondary
                      ? scheme.error
                      : scheme.primary,
                  size: 18,
                ),
                onPressed: onAction,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 2),
            Icon(Icons.drag_indicator, size: 16, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }

  void _showGuestAssignDialog(Guest guest) {
    showDialog(
      context: context,
      builder: (builderContext) {
        final scheme = Theme.of(builderContext).colorScheme;
        return AlertDialog(
          title: Text('${guest.firstName} ${guest.lastName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tisch zuweisen:'),
              const SizedBox(height: 8),
              ...tables.map((table) {
                final tableGuests = _getGuestsForTable(table.tableNumber);
                return ListTile(
                  title: Text(table.tableName),
                  subtitle: Text('${tableGuests.length}/${table.seats} Plätze'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    await _assignGuestToTable(guest, table.tableNumber);
                    Navigator.pop(builderContext);
                  },
                );
              }),
              const Divider(),
              ListTile(
                title: const Text('Nicht zuweisen'),
                leading: Icon(Icons.remove_circle, color: scheme.error),
                onTap: () async {
                  await _removeGuestFromTable(guest);
                  Navigator.pop(builderContext);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(builderContext),
              child: const Text('Schließen'),
            ),
          ],
        );
      },
    );
  }

  void _showTableFullError() {
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('Tisch ist bereits voll belegt!')),
          ],
        ),
        backgroundColor: scheme.error,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showExportDialog() async {
    if (widget.guests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Keine Gäste zum Exportieren vorhanden'),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Tischplanung exportieren'),
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
                subtitle: const Text('Schöne Übersicht für Gäste'),
                onTap: () {
                  Navigator.pop(context);
                  _exportAsPDF();
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.table_chart,
                  color: scheme.primary,
                  size: 32,
                ),
                title: const Text('Als Excel exportieren'),
                subtitle: const Text('Komplette Tischplanung mit Details'),
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
        );
      },
    );
  }

  Future<void> _exportAsPDF() async {
    final scheme = Theme.of(context).colorScheme;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await PdfExportService.exportTablePlanToPdf(tables, widget.guests);
      if (mounted) Navigator.pop(context);
      if (mounted)
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
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted)
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

  Future<void> _exportAsExcel() async {
    final scheme = Theme.of(context).colorScheme;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await ExcelExportService.exportSeatingPlanToExcel(widget.guests, tables);
      if (mounted) Navigator.pop(context);
      if (mounted)
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
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted)
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // ── NEU: Limit-Status ─────────────────────────────────────────────────
    final isPremium = PremiumService.instance.isPremium;
    final tableLimit = PremiumService.kFreeTableLimit;
    final isAtLimit = !isPremium && tables.length >= tableLimit;
    final isNearLimit = !isPremium && tables.length >= (tableLimit - 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 600;
        final unassignedGuests = _getUnassignedGuests();
        final relevantGuests = _getRelevantGuests();
        final excludedGuestsCount =
            widget.guests.length - relevantGuests.length;

        return Padding(
          padding: EdgeInsets.all(isTablet ? 16 : 8),
          child: Column(
            children: [
              // ── NEU: Limit-Banner ───────────────────────────────────
              if (isNearLimit || isAtLimit) ...[
                GestureDetector(
                  onTap: () => UpgradeBottomSheet.show(
                    context,
                    featureName: 'Unbegrenzte Tische',
                    featureDescription:
                        'Mit Premium planst du ohne Einschränkungen.',
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isAtLimit
                          ? Colors.red.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAtLimit ? Colors.red : Colors.orange,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAtLimit ? Icons.lock : Icons.warning_amber,
                          color: isAtLimit ? Colors.red : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isAtLimit
                                ? 'Limit erreicht: ${tables.length}/$tableLimit Tische'
                                : 'Fast voll: ${tables.length}/$tableLimit Tische (Free-Limit)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isAtLimit
                                  ? Colors.red
                                  : Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          'Premium ›',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAtLimit ? Colors.red : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.dividerColor, width: 1),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
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
                                  'Tischplanung',
                                  style: TextStyle(
                                    fontSize: isTablet ? 24 : 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Gäste durch Ziehen oder Tippen zuweisen',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: isTablet ? 14 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _openSuggestion,
                            icon: const Icon(Icons.auto_awesome, size: 20),
                            tooltip: 'KI-Tischvorschlag',
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.primaryContainer,
                              foregroundColor: scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _showExportDialog,
                            icon: const Icon(Icons.share, size: 20),
                            tooltip: 'Exportieren',
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.secondaryContainer,
                              foregroundColor: scheme.onSecondaryContainer,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // ── NEU: Button mit Limit-Prüfung ──
                          ElevatedButton.icon(
                            onPressed: _onAddTableTapped,
                            icon: Icon(isAtLimit ? Icons.lock : Icons.add),
                            label: Text(
                              isTablet
                                  ? (isAtLimit
                                        ? 'Limit ($tableLimit)'
                                        : 'Neuer Tisch')
                                  : (isAtLimit ? 'Limit' : 'Tisch'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isAtLimit
                                  ? Colors.grey
                                  : scheme.primary,
                              foregroundColor: scheme.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatCard(
                            'Gesamt',
                            relevantGuests.length.toString(),
                            scheme.primary,
                            isTablet,
                          ),
                          SizedBox(width: isTablet ? 16 : 8),
                          _buildStatCard(
                            'Platziert',
                            seatedGuestsCount.toString(),
                            scheme.tertiary,
                            isTablet,
                          ),
                          SizedBox(width: isTablet ? 16 : 8),
                          _buildStatCard(
                            'Frei',
                            unassignedGuests.length.toString(),
                            scheme.secondary,
                            isTablet,
                          ),
                        ],
                      ),
                      if (excludedGuestsCount > 0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$excludedGuestsCount abgesagte Gäste werden nicht angezeigt',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    color: theme.colorScheme.onSurfaceVariant,
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
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: tables.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.table_restaurant,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Keine Tische erstellt'),
                                  Text(
                                    'Klicken Sie auf "Neuer Tisch"',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isTablet ? 3 : 2,
                                    crossAxisSpacing: isTablet ? 16 : 8,
                                    mainAxisSpacing: isTablet ? 16 : 8,
                                    childAspectRatio: isTablet ? 1.0 : 0.9,
                                  ),
                              itemCount: tables.length,
                              itemBuilder: (context, index) {
                                final table = tables[index];
                                final tableGuests = _getGuestsForTable(
                                  table.tableNumber,
                                );
                                return DragTargetTableCard(
                                  table: table,
                                  guests: tableGuests,
                                  onDelete: () => _deleteTable(table.id),
                                  onEdit: () =>
                                      _showTablePropertiesDialog(table),
                                  onGuestDropped: (guest) {
                                    _assignGuestToTable(
                                      guest,
                                      table.tableNumber,
                                    );
                                  },
                                  onGuestTap: _showGuestAssignDialog,
                                  isTablet: isTablet,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: isTablet ? 180 : 140,
                      child: UnassignedGuestsArea(
                        guests: unassignedGuests,
                        onGuestDropped: (guest) => _removeGuestFromTable(guest),
                        onGuestTap: _showGuestAssignDialog,
                        isTablet: isTablet,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    bool isTablet,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 12 : 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 20 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 12 : 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================
// DRAG & DROP WIDGETS – unverändert
// ================================

class DraggableGuestCard extends StatelessWidget {
  final Guest guest;
  final VoidCallback onTap;
  final bool isTablet;

  const DraggableGuestCard({
    super.key,
    required this.guest,
    required this.onTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Draggable<Guest>(
      data: guest,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.secondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${guest.firstName} ${guest.lastName}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: scheme.onSecondary,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildGuestContainer(context),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: _buildGuestContainer(context),
      ),
    );
  }

  Widget _buildGuestContainer(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(isTablet ? 8 : 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.secondary.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${guest.firstName} ${guest.lastName}',
              style: TextStyle(fontSize: isTablet ? 12 : 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (guest.dietaryRequirements.isNotEmpty)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class DragTargetTableCard extends StatelessWidget {
  final TableData table;
  final List<Guest> guests;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Function(Guest) onGuestDropped;
  final Function(Guest) onGuestTap;
  final bool isTablet;

  const DragTargetTableCard({
    super.key,
    required this.table,
    required this.guests,
    required this.onDelete,
    required this.onEdit,
    required this.onGuestDropped,
    required this.onGuestTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DragTarget<Guest>(
      onAcceptWithDetails: (details) => onGuestDropped(details.data),
      onWillAcceptWithDetails: (details) =>
          details.data.tableNumber != table.tableNumber,
      builder: (builderContext, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        final canAccept = guests.length < table.seats;
        final isFromThisTable =
            candidateData.isNotEmpty &&
            candidateData.first?.tableNumber == table.tableNumber;
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: theme.dividerColor, width: 1),
          ),
          elevation: isHighlighted ? 8 : 2,
          color: isHighlighted
              ? (isFromThisTable
                    ? scheme.surfaceContainerHighest
                    : (canAccept
                          ? scheme.primaryContainer
                          : scheme.errorContainer))
              : scheme.surface,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: guests.length >= table.seats
                      ? scheme.errorContainer
                      : scheme.secondaryContainer,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        table.tableName,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSecondaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: guests.length >= table.seats
                                ? scheme.error.withOpacity(0.15)
                                : scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${guests.length}/${table.seats}',
                            style: TextStyle(
                              fontSize: 9,
                              color: guests.length >= table.seats
                                  ? scheme.error
                                  : scheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: scheme.primary,
                            size: 16,
                          ),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          tooltip: 'Bearbeiten',
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: scheme.error,
                            size: 16,
                          ),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          tooltip: 'Löschen',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTablet ? 8 : 6),
                  child: guests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isHighlighted
                                    ? (canAccept
                                          ? Icons.add_circle
                                          : Icons.block)
                                    : Icons.add_circle_outline,
                                color: isHighlighted
                                    ? (canAccept
                                          ? scheme.primary
                                          : scheme.error)
                                    : scheme.onSurfaceVariant,
                                size: isTablet ? 32 : 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isHighlighted
                                    ? (canAccept
                                          ? 'Hier ablegen'
                                          : 'Tisch voll!')
                                    : 'Leer',
                                style: TextStyle(
                                  color: isHighlighted
                                      ? (canAccept
                                            ? scheme.primary
                                            : scheme.error)
                                      : scheme.onSurfaceVariant,
                                  fontSize: isTablet ? 12 : 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: guests.length,
                          padding: EdgeInsets.zero,
                          itemBuilder: (context, index) {
                            final guest = guests[index];
                            return Draggable<Guest>(
                              data: guest,
                              feedback: Material(
                                elevation: 6,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 120,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${guest.firstName} ${guest.lastName}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.3,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 8 : 6,
                                    vertical: isTablet ? 6 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest,
                                    border: Border.all(
                                      color: theme.dividerColor,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${guest.firstName} ${guest.lastName}',
                                          style: TextStyle(
                                            fontSize: isTablet ? 11 : 10,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.drag_indicator,
                                        size: 12,
                                        color: theme.dividerColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () => onGuestTap(guest),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 8 : 6,
                                    vertical: isTablet ? 6 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.surface,
                                    border: Border.all(
                                      color: theme.dividerColor,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.shadowColor.withOpacity(
                                          0.1,
                                        ),
                                        spreadRadius: 1,
                                        blurRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${guest.firstName} ${guest.lastName}',
                                          style: TextStyle(
                                            fontSize: isTablet ? 11 : 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (guest.dietaryRequirements.isNotEmpty)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          margin: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Icon(
                                        Icons.drag_indicator,
                                        size: 14,
                                        color: theme.dividerColor,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class UnassignedGuestsArea extends StatelessWidget {
  final List<Guest> guests;
  final Function(Guest) onGuestDropped;
  final Function(Guest) onGuestTap;
  final bool isTablet;

  const UnassignedGuestsArea({
    super.key,
    required this.guests,
    required this.onGuestDropped,
    required this.onGuestTap,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DragTarget<Guest>(
      onAcceptWithDetails: (details) => onGuestDropped(details.data),
      onWillAcceptWithDetails: (details) => true,
      builder: (builderContext, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHighlighted
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHighest.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted ? scheme.secondary : theme.dividerColor,
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      'Freie Gäste (${guests.length})',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (isHighlighted)
                      Text(
                        'Hier ablegen um zu entfernen',
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 10,
                          color: scheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: guests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isHighlighted
                                  ? Icons.person_add
                                  : Icons.check_circle_outline,
                              size: 40,
                              color: isHighlighted
                                  ? scheme.secondary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isHighlighted
                                  ? 'Hier ablegen'
                                  : 'Alle Gäste sind platziert!',
                              style: TextStyle(
                                color: isHighlighted
                                    ? scheme.secondary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.all(isTablet ? 8 : 4),
                        child: ListView.builder(
                          itemCount: guests.length,
                          itemBuilder: (context, index) => DraggableGuestCard(
                            guest: guests[index],
                            onTap: () => onGuestTap(guests[index]),
                            isTablet: isTablet,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
