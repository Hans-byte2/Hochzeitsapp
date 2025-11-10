import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../app_colors.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';

class GuestPage extends StatefulWidget {
  final List<Guest> guests;
  final Function(Guest) onAddGuest;
  final Function(Guest) onUpdateGuest;
  final Function(int) onDeleteGuest;

  const GuestPage({
    Key? key,
    required this.guests,
    required this.onAddGuest,
    required this.onUpdateGuest,
    required this.onDeleteGuest,
  }) : super(key: key);

  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dietaryController = TextEditingController();
  String _selectedStatus = 'pending';
  Guest? _editingGuest;

  // Filter-Status
  String? _filterStatus;

  void _showGuestDialog([Guest? guest]) {
    _editingGuest = guest;
    if (guest != null) {
      _firstNameController.text = guest.firstName;
      _lastNameController.text = guest.lastName;
      _emailController.text = guest.email;
      _dietaryController.text = guest.dietaryRequirements;
      _selectedStatus = guest.confirmed;
    } else {
      _resetForm();
    }

    showDialog(
      context: context,
      builder: (builderContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) => AlertDialog(
          title: Text(
            _editingGuest != null ? 'Gast bearbeiten' : 'Neuen Gast hinzufügen',
          ),
          content: SingleChildScrollView(
            // <- NEU: ScrollView hinzugefügt
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _firstNameController,
                  decoration: const InputDecoration(labelText: 'Vorname'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _lastNameController,
                  decoration: const InputDecoration(labelText: 'Nachname'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Offen')),
                    DropdownMenuItem(value: 'yes', child: Text('Zugesagt')),
                    DropdownMenuItem(value: 'no', child: Text('Abgesagt')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => _selectedStatus = value!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dietaryController,
                  decoration: const InputDecoration(
                    labelText: 'Besonderheiten',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _resetForm();
                Navigator.pop(builderContext);
              },
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: _saveGuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Speichern',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveGuest() {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      return;
    }

    final guest = Guest(
      id: _editingGuest?.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      confirmed: _selectedStatus,
      dietaryRequirements: _dietaryController.text,
      tableNumber: _editingGuest?.tableNumber,
    );

    if (_editingGuest != null) {
      widget.onUpdateGuest(guest);
    } else {
      widget.onAddGuest(guest);
    }

    _resetForm();
    Navigator.pop(context);
  }

  void _resetForm() {
    _editingGuest = null;
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _dietaryController.clear();
    _selectedStatus = 'pending';
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Offen';
      case 'yes':
        return 'Zugesagt';
      case 'no':
        return 'Abgesagt';
      default:
        return 'Unbekannt';
    }
  }

  // Gefilterte Gästeliste
  List<Guest> _getFilteredGuests() {
    if (_filterStatus == null) {
      return widget.guests;
    }
    return widget.guests.where((g) => g.confirmed == _filterStatus).toList();
  }

  // Export-Funktionen
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
        title: const Text('Gästeliste exportieren'),
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
              subtitle: const Text('Zum Ausdrucken oder Teilen'),
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
              subtitle: const Text('Zum Weiterverarbeiten'),
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

      await PdfExportService.exportGuestListToPdf(widget.guests);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gästeliste erfolgreich als PDF exportiert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim PDF-Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportAsExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await ExcelExportService.exportGuestListToExcel(widget.guests);

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gästeliste erfolgreich als Excel exportiert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fehler beim Excel-Export: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalGuests = widget.guests.length;
    final confirmedGuests = widget.guests
        .where((g) => g.confirmed == 'yes')
        .length;
    final declinedGuests = widget.guests
        .where((g) => g.confirmed == 'no')
        .length;
    final pendingGuests = totalGuests - confirmedGuests - declinedGuests;

    final filteredGuests = _getFilteredGuests();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gästeliste'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _showExportDialog,
            tooltip: 'Exportieren',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Übersicht',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterStatus = null;
                      });
                    },
                    child: _buildStatCard(
                      'Gesamt',
                      '$totalGuests',
                      AppColors.primary,
                      Icons.people,
                      _filterStatus == null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterStatus = _filterStatus == 'pending'
                            ? null
                            : 'pending';
                      });
                    },
                    child: _buildStatCard(
                      'Offen',
                      '$pendingGuests',
                      Colors.orange,
                      Icons.schedule,
                      _filterStatus == 'pending',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterStatus = _filterStatus == 'yes' ? null : 'yes';
                      });
                    },
                    child: _buildStatCard(
                      'Zugesagt',
                      '$confirmedGuests',
                      Colors.green,
                      Icons.check_circle,
                      _filterStatus == 'yes',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _filterStatus = _filterStatus == 'no' ? null : 'no';
                      });
                    },
                    child: _buildStatCard(
                      'Abgesagt',
                      '$declinedGuests',
                      Colors.red,
                      Icons.cancel,
                      _filterStatus == 'no',
                    ),
                  ),
                ),
              ],
            ),
            if (_filterStatus != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_alt,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filter aktiv: ${_getStatusLabel(_filterStatus!)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filterStatus = null;
                        });
                      },
                      child: const Text('Zurücksetzen'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: filteredGuests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _filterStatus == null
                                ? 'Noch keine Gäste hinzugefügt'
                                : 'Keine Gäste mit Status "${_getStatusLabel(_filterStatus!)}"',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredGuests.length,
                      itemBuilder: (context, index) {
                        final guest = filteredGuests[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(
                              color: AppColors.cardBorder,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getStatusColor(guest.confirmed),
                              child: Text(
                                guest.firstName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text('${guest.firstName} ${guest.lastName}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(guest.email),
                                if (guest.dietaryRequirements.isNotEmpty)
                                  Text(
                                    'Besonderheiten: ${guest.dietaryRequirements}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                    _getStatusLabel(guest.confirmed),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  backgroundColor: _getStatusColor(
                                    guest.confirmed,
                                  ).withOpacity(0.2),
                                  side: BorderSide.none,
                                ),
                                PopupMenuButton(
                                  itemBuilder: (menuContext) => [
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(Icons.edit, size: 18),
                                          SizedBox(width: 8),
                                          Text('Bearbeiten'),
                                        ],
                                      ),
                                      onTap: () => Future.delayed(
                                        Duration.zero,
                                        () => _showGuestDialog(guest),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: 18,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Löschen',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                      onTap: () =>
                                          widget.onDeleteGuest(guest.id!),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGuestDialog(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Gast hinzufügen'),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isActive ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(isActive ? 0.6 : 0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 3,
              width: 30,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'yes':
        return Colors.green;
      case 'no':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dietaryController.dispose();
    super.dispose();
  }
}
