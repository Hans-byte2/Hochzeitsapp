import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../models/table_models.dart';
import '../app_colors.dart';
import '../services/excel_export_service.dart';
import '../services/pdf_export_service.dart';

class TischplanungPage extends StatefulWidget {
  final List<Guest> guests;
  final Future<void> Function(Guest) onUpdateGuest;

  const TischplanungPage({
    Key? key,
    required this.guests,
    required this.onUpdateGuest,
  }) : super(key: key);

  @override
  State<TischplanungPage> createState() => _TischplanungPageState();
}

class _TischplanungPageState extends State<TischplanungPage> {
  List<TableData> tables = [];
  String newTableName = '';
  int newTableSeats = 8;

  @override
  void initState() {
    super.initState();
    print('🟢 INIT: ${widget.guests.length} Gäste');
    tables = [
      TableData(id: 1, tableName: 'Brautpaar', tableNumber: 1, seats: 8),
      TableData(id: 2, tableName: 'Familie Braut', tableNumber: 2, seats: 6),
      TableData(
        id: 3,
        tableName: 'Familie Bräutigam',
        tableNumber: 3,
        seats: 6,
      ),
      TableData(id: 4, tableName: 'Freunde', tableNumber: 4, seats: 10),
    ];
  }

  @override
  void didUpdateWidget(TischplanungPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    print(
      '🔄 WIDGET UPDATE: ${oldWidget.guests.length} → ${widget.guests.length} Gäste',
    );
    // Prüfe ob sich die Gäste-Liste geändert hat
    final oldUnassigned = oldWidget.guests
        .where(
          (g) =>
              (g.confirmed == 'yes' || g.confirmed == 'pending') &&
              (g.tableNumber == null || g.tableNumber == 0),
        )
        .length;
    final newUnassigned = widget.guests
        .where(
          (g) =>
              (g.confirmed == 'yes' || g.confirmed == 'pending') &&
              (g.tableNumber == null || g.tableNumber == 0),
        )
        .length;
    print('📊 Freie Gäste: $oldUnassigned → $newUnassigned');
  }

  // Nur Gäste mit Status 'yes' oder 'pending' werden berücksichtigt
  List<Guest> _getRelevantGuests() {
    return widget.guests
        .where((g) => g.confirmed == 'yes' || g.confirmed == 'pending')
        .toList();
  }

  List<Guest> _getGuestsForTable(int tableNumber) {
    return _getRelevantGuests()
        .where((g) => g.tableNumber == tableNumber)
        .toList();
  }

  List<Guest> _getUnassignedGuests() {
    return _getRelevantGuests()
        .where(
          (g) =>
              g.tableNumber == null ||
              g.tableNumber == 0 ||
              !tables.any((t) => t.tableNumber == g.tableNumber),
        )
        .toList();
  }

  int get seatedGuestsCount =>
      _getRelevantGuests().length - _getUnassignedGuests().length;

  Future<bool> _assignGuestToTable(Guest guest, int tableNumber) async {
    // Finde den Tisch
    final table = tables.firstWhere((t) => t.tableNumber == tableNumber);

    // Prüfe ob Gast bereits an diesem Tisch sitzt
    if (guest.tableNumber == tableNumber) {
      print('⚠️ Gast ${guest.firstName} ist bereits an Tisch $tableNumber');
      return true; // Kein Fehler, aber nichts tun
    }

    // Zähle aktuelle Gäste am Tisch (ohne den aktuellen Gast)
    final currentGuestsAtTable = _getGuestsForTable(
      tableNumber,
    ).where((g) => g.id != guest.id).length;

    // Prüfe ob noch Platz ist
    if (currentGuestsAtTable >= table.seats) {
      print(
        '❌ Tisch $tableNumber ist voll! (${currentGuestsAtTable}/${table.seats})',
      );
      _showTableFullError();
      return false; // Fehler - Tisch voll
    }

    print(
      '🔵 ASSIGN: ${guest.firstName} ${guest.lastName} → Tisch $tableNumber (${currentGuestsAtTable + 1}/${table.seats})',
    );
    final updatedGuest = guest.copyWith(tableNumber: tableNumber);
    await widget.onUpdateGuest(updatedGuest);
    print('✅ ASSIGN fertig');
    return true; // Erfolgreich
  }

  Future<void> _removeGuestFromTable(Guest guest) async {
    print(
      '🟠 REMOVE: ${guest.firstName} ${guest.lastName} von Tisch ${guest.tableNumber}',
    );
    print(
      '   Guest ID: ${guest.id}, aktuelle tableNumber: ${guest.tableNumber}',
    );
    // WICHTIG: Setze auf 0 statt null, weil copyWith mit null nicht funktioniert!
    final updatedGuest = guest.copyWith(tableNumber: 0);
    print(
      '   Neuer Guest: ID ${updatedGuest.id}, neue tableNumber: ${updatedGuest.tableNumber}',
    );
    await widget.onUpdateGuest(updatedGuest);
    print('✅ REMOVE fertig');

    // Debug: Prüfe ob der Gast wirklich updated wurde
    final checkGuest = widget.guests.firstWhere((g) => g.id == guest.id);
    print(
      '   🔍 Check: Guest ${checkGuest.firstName} hat jetzt tableNumber: ${checkGuest.tableNumber}',
    );
  }

  void _addTable() {
    if (newTableName.isNotEmpty) {
      final nextTableNumber = tables.isEmpty
          ? 1
          : tables.map((t) => t.tableNumber).reduce((a, b) => a > b ? a : b) +
                1;

      setState(() {
        tables.add(
          TableData(
            id: DateTime.now().millisecondsSinceEpoch,
            tableName: newTableName,
            tableNumber: nextTableNumber,
            seats: newTableSeats,
          ),
        );
        newTableName = '';
        newTableSeats = 8;
      });
    }
  }

  void _deleteTable(int tableId) {
    showDialog(
      context: context,
      builder: (builderContext) => AlertDialog(
        title: const Text('Tisch löschen'),
        content: const Text('Alle Gäste werden wieder freigegeben.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(builderContext),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () async {
              final table = tables.firstWhere((t) => t.id == tableId);
              final guestsToUpdate = _getRelevantGuests()
                  .where((g) => g.tableNumber == table.tableNumber)
                  .toList();

              for (final guest in guestsToUpdate) {
                await _removeGuestFromTable(guest);
              }

              setState(() {
                tables.removeWhere((t) => t.id == tableId);
              });
              Navigator.pop(builderContext);
            },
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
  }

  void _showTableForm() {
    final nameController = TextEditingController();
    final seatsController = TextEditingController(text: '8');

    showDialog(
      context: context,
      builder: (builderContext) => AlertDialog(
        title: const Text('Neuer Tisch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tischname'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: seatsController,
              decoration: const InputDecoration(labelText: 'Plätze'),
              keyboardType: TextInputType.number,
            ),
          ],
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
                _addTable();
                Navigator.pop(builderContext);
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _showEditTableDialog(TableData table) {
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (builderContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tableGuests = _getGuestsForTable(table.tableNumber);
          final allFreeGuests = _getUnassignedGuests();

          // Suchfilter für freie Gäste
          final freeGuests = searchQuery.isEmpty
              ? allFreeGuests
              : allFreeGuests.where((guest) {
                  final fullName = '${guest.firstName} ${guest.lastName}'
                      .toLowerCase();
                  return fullName.contains(searchQuery.toLowerCase());
                }).toList();

          return Dialog(
            child: Container(
              width: 600,
              height: 700,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
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
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${tableGuests.length} von ${table.seats} Plätzen belegt',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(builderContext),
                        ),
                      ],
                    ),
                  ),
                  // Gäste am Tisch
                  Expanded(
                    child: DragTarget<Guest>(
                      onAccept: (guest) {
                        // Immer versuchen hinzuzufügen wenn Gast von außerhalb kommt
                        if (guest.tableNumber != table.tableNumber) {
                          _assignGuestToTable(guest, table.tableNumber).then((
                            success,
                          ) {
                            if (success) {
                              setDialogState(() {});
                            }
                          });
                        }
                      },
                      onWillAcceptWithDetails: (details) {
                        // Akzeptiere alle Gäste die nicht bereits am Tisch sind
                        return true;
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHighlighted = candidateData.isNotEmpty;
                        // Prüfe ob gezogener Gast bereits am Tisch ist
                        final isDraggingFromThisTable =
                            candidateData.isNotEmpty &&
                            candidateData.first?.tableNumber ==
                                table.tableNumber;

                        return Container(
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? (isDraggingFromThisTable
                                      ? Colors
                                            .grey
                                            .shade100 // Gast ist bereits hier
                                      : Colors.green.shade50)
                                : Colors.grey.shade50,
                            border: isHighlighted && !isDraggingFromThisTable
                                ? Border.all(color: Colors.green, width: 2)
                                : null,
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
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: tableGuests.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.person_off_outlined,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Keine Gäste am Tisch',
                                              style: TextStyle(
                                                color: Colors.grey,
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
                                                    color: Colors.blue,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${guest.firstName} ${guest.lastName}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.3,
                                                child: _buildTinyGuestCard(
                                                  guest,
                                                  Colors.blue,
                                                  null,
                                                ),
                                              ),
                                              child: _buildTinyGuestCard(
                                                guest,
                                                Colors.blue,
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
                  // Suchfeld
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: Colors.white,
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
                          borderSide: BorderSide(color: Colors.grey.shade300),
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
                  // Freie Gäste
                  Container(
                    height: 150,
                    child: DragTarget<Guest>(
                      onAccept: (guest) {
                        // Gast vom Tisch entfernen
                        if (guest.tableNumber == table.tableNumber) {
                          _removeGuestFromTable(guest).then((_) {
                            setDialogState(() {});
                          });
                        }
                      },
                      onWillAcceptWithDetails: (details) {
                        // Akzeptiere alle Gäste
                        return true;
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHighlighted = candidateData.isNotEmpty;
                        // Prüfe ob gezogener Gast vom Tisch kommt
                        final isDraggingFromTable =
                            candidateData.isNotEmpty &&
                            candidateData.first?.tableNumber ==
                                table.tableNumber;

                        return Container(
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? (isDraggingFromTable
                                      ? Colors.orange.shade100
                                      : Colors.grey.shade100)
                                : Colors.white,
                            border: isHighlighted && isDraggingFromTable
                                ? Border.all(color: Colors.orange, width: 2)
                                : null,
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
                                    const Text(
                                      'Hier ablegen zum Entfernen',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange,
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
                                              color: searchQuery.isNotEmpty
                                                  ? Colors.grey
                                                  : Colors.green,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              searchQuery.isNotEmpty
                                                  ? 'Keine Gäste gefunden'
                                                  : 'Alle Gäste sind platziert',
                                              style: const TextStyle(
                                                color: Colors.grey,
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
                                                    color: Colors.orange,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${guest.firstName} ${guest.lastName}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              childWhenDragging: Opacity(
                                                opacity: 0.3,
                                                child: _buildTinyGuestCard(
                                                  guest,
                                                  Colors.orange,
                                                  null,
                                                ),
                                              ),
                                              child: _buildTinyGuestCard(
                                                guest,
                                                Colors.orange,
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
                  // Footer
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade300),
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
                        color: Colors.grey.shade600,
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
                  color == Colors.blue ? Icons.remove_circle : Icons.add_circle,
                  color: color == Colors.blue ? Colors.red : Colors.green,
                  size: 18,
                ),
                onPressed: onAction,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 2),
            Icon(Icons.drag_indicator, size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showGuestAssignDialog(Guest guest) {
    showDialog(
      context: context,
      builder: (builderContext) => AlertDialog(
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
            }).toList(),
            const Divider(),
            ListTile(
              title: const Text('Nicht zuweisen'),
              leading: const Icon(Icons.remove_circle, color: Colors.orange),
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
      ),
    );
  }

  void _showTableFullError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(child: Text('Tisch ist bereits voll belegt!')),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showExportDialog() async {
    if (widget.guests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Gäste zum Exportieren vorhanden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              leading: const Icon(
                Icons.table_chart,
                color: Colors.green,
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
      ),
    );
  }

  Future<void> _exportAsPDF() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await PdfExportService.exportTablePlanToPdf(tables, widget.guests);

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

      await ExcelExportService.exportSeatingPlanToExcel(widget.guests, tables);

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

  @override
  Widget build(BuildContext context) {
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
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.cardBorder, width: 1),
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
                                    color: Colors.grey,
                                    fontSize: isTablet ? 14 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _showExportDialog,
                            icon: const Icon(Icons.share, size: 20),
                            tooltip: 'Exportieren',
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton.icon(
                            onPressed: _showTableForm,
                            icon: const Icon(Icons.add),
                            label: Text(isTablet ? 'Neuer Tisch' : 'Tisch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
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
                            Colors.blue,
                            isTablet,
                          ),
                          SizedBox(width: isTablet ? 16 : 8),
                          _buildStatCard(
                            'Platziert',
                            seatedGuestsCount.toString(),
                            Colors.green,
                            isTablet,
                          ),
                          SizedBox(width: isTablet ? 16 : 8),
                          _buildStatCard(
                            'Frei',
                            unassignedGuests.length.toString(),
                            Colors.orange,
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
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$excludedGuestsCount abgesagte Gäste werden nicht angezeigt',
                                  style: TextStyle(
                                    fontSize: isTablet ? 12 : 10,
                                    color: Colors.grey.shade700,
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
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.table_restaurant,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 16),
                                  Text('Keine Tische erstellt'),
                                  Text(
                                    'Klicken Sie auf "Neuer Tisch"',
                                    style: TextStyle(color: Colors.grey),
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
                                  onEdit: () => _showEditTableDialog(table),
                                  onGuestDropped: (guest) {
                                    print(
                                      '🎯 Tisch ${table.tableNumber} onDrop: ${guest.firstName}',
                                    );
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
                    Container(
                      height: isTablet ? 180 : 140,
                      child: UnassignedGuestsArea(
                        guests: unassignedGuests,
                        onGuestDropped: (guest) {
                          print(
                            '🎯 Freie Gäste onDrop: ${guest.firstName} (aktuell an Tisch ${guest.tableNumber})',
                          );
                          _removeGuestFromTable(guest);
                        },
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
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================
// DRAG & DROP WIDGETS
// ================================

class DraggableGuestCard extends StatelessWidget {
  final Guest guest;
  final VoidCallback onTap;
  final bool isTablet;

  const DraggableGuestCard({
    Key? key,
    required this.guest,
    required this.onTap,
    required this.isTablet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Draggable<Guest>(
      data: guest,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${guest.firstName} ${guest.lastName}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: _buildGuestContainer()),
      child: GestureDetector(onTap: onTap, child: _buildGuestContainer()),
    );
  }

  Widget _buildGuestContainer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: EdgeInsets.all(isTablet ? 8 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
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
              decoration: const BoxDecoration(
                color: AppColors.primary,
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
    Key? key,
    required this.table,
    required this.guests,
    required this.onDelete,
    required this.onEdit,
    required this.onGuestDropped,
    required this.onGuestTap,
    required this.isTablet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<Guest>(
      onAccept: (guest) => onGuestDropped(guest),
      onWillAcceptWithDetails: (details) {
        // Akzeptiere alle Gäste die nicht bereits an diesem Tisch sind
        return details.data.tableNumber != table.tableNumber;
      },
      builder: (builderContext, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        final canAccept = guests.length < table.seats;
        // Prüfe ob Gast von diesem Tisch kommt
        final isFromThisTable =
            candidateData.isNotEmpty &&
            candidateData.first?.tableNumber == table.tableNumber;

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: AppColors.cardBorder, width: 1),
          ),
          elevation: isHighlighted ? 8 : 2,
          color: isHighlighted
              ? (isFromThisTable
                    ? Colors
                          .grey
                          .shade100 // Gast ist schon hier
                    : (canAccept
                          ? Colors
                                .green
                                .shade50 // Kann hinzugefügt werden
                          : Colors.red.shade50)) // Tisch ist voll
              : Colors.white,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: guests.length >= table.seats
                      ? Colors.red.shade50
                      : AppColors.secondary,
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
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${guests.length}/${table.seats}',
                            style: TextStyle(
                              fontSize: 9,
                              color: guests.length >= table.seats
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
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
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
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
                                    ? (canAccept ? Colors.green : Colors.red)
                                    : Colors.grey,
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
                                      ? (canAccept ? Colors.green : Colors.red)
                                      : Colors.grey,
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
                                    color: Colors.blue.shade200,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${guest.firstName} ${guest.lastName}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                                    color: Colors.grey.shade200,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
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
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.drag_indicator,
                                        size: 12,
                                        color: Colors.grey.shade400,
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
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
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
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      Icon(
                                        Icons.drag_indicator,
                                        size: 14,
                                        color: Colors.grey.shade400,
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
    Key? key,
    required this.guests,
    required this.onGuestDropped,
    required this.onGuestTap,
    required this.isTablet,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<Guest>(
      onAccept: (guest) {
        // Gast zur freien Liste hinzufügen (tableNumber auf null setzen)
        onGuestDropped(guest);
      },
      onWillAcceptWithDetails: (details) {
        // Akzeptiere jeden Gast - keine Einschränkung
        return true;
      },
      builder: (builderContext, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: isHighlighted
                ? Colors.orange.shade100
                : const Color.fromARGB(255, 250, 250, 250),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isHighlighted
                  ? Colors.orange.shade300
                  : const Color.fromARGB(255, 231, 224, 214),
              width: isHighlighted ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 202, 200, 198),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people,
                      color: Color.fromARGB(255, 240, 239, 238),
                    ),
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
                          color: Colors.orange.shade700,
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
                                  ? Colors.orange
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isHighlighted
                                  ? 'Hier ablegen'
                                  : 'Alle Gäste sind platziert!',
                              style: TextStyle(
                                color: isHighlighted
                                    ? Colors.orange.shade700
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.all(isTablet ? 8 : 4),
                        child: ListView.builder(
                          itemCount: guests.length,
                          itemBuilder: (context, index) {
                            return DraggableGuestCard(
                              guest: guests[index],
                              onTap: () => onGuestTap(guests[index]),
                              isTablet: isTablet,
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
