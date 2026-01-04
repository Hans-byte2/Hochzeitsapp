import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
// Smart Validation Imports
import '../mixins/smart_form_validation_mixin.dart';
import '../widgets/forms/smart_text_field.dart';
import '../widgets/forms/smart_dropdown.dart';

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

class _GuestPageState extends State<GuestPage> with SmartFormValidation {
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

    // Reset validation state
    resetFormValidation();

    showDialog(
      context: context,
      builder: (builderContext) {
        return _GuestFormDialog(
          editingGuest: _editingGuest,
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          emailController: _emailController,
          dietaryController: _dietaryController,
          selectedStatus: _selectedStatus,
          onStatusChanged: (status) => _selectedStatus = status,
          onSave: _saveGuest,
          onCancel: () {
            _resetForm();
            Navigator.pop(builderContext);
          },
        );
      },
    );
  }

  void _saveGuest() {
    // NUR Vorname prüfen! Nachname ist optional
    if (_firstNameController.text.isEmpty) {
      return;
    }

    final guest = Guest(
      id: _editingGuest?.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text, // Kann leer sein
      email: _emailController.text, // Kann leer sein
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

    // Erfolgs-Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              _editingGuest != null
                  ? 'Gast aktualisiert! ✓'
                  : 'Gast hinzugefügt! ✓',
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
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

  List<Guest> _getFilteredGuests() {
    if (_filterStatus == null) {
      return widget.guests;
    }
    return widget.guests.where((g) => g.confirmed == _filterStatus).toList();
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
    final scheme = Theme.of(context).colorScheme;

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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
                    onTap: () => setState(() => _filterStatus = null),
                    child: _buildStatCard(
                      'Gesamt',
                      '$totalGuests',
                      scheme.primary,
                      Icons.people,
                      _filterStatus == null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _filterStatus = _filterStatus == 'pending'
                          ? null
                          : 'pending',
                    ),
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
                    onTap: () => setState(
                      () =>
                          _filterStatus = _filterStatus == 'yes' ? null : 'yes',
                    ),
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
                    onTap: () => setState(
                      () => _filterStatus = _filterStatus == 'no' ? null : 'no',
                    ),
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
                      onPressed: () => setState(() => _filterStatus = null),
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
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
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
                                if (guest.email.isNotEmpty) Text(guest.email),
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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

// ============================================================================
// GUEST FORM DIALOG - Mit Smart Validation
// ============================================================================

class _GuestFormDialog extends StatefulWidget {
  final Guest? editingGuest;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController dietaryController;
  final String selectedStatus;
  final Function(String) onStatusChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _GuestFormDialog({
    required this.editingGuest,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.dietaryController,
    required this.selectedStatus,
    required this.onStatusChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_GuestFormDialog> createState() => _GuestFormDialogState();
}

class _GuestFormDialogState extends State<_GuestFormDialog> {
  final Map<String, bool> _fieldValidation = {};
  // NUR Vorname und Status sind Pflicht!
  final List<String> _requiredFields = ['first_name', 'status'];

  void _updateFieldValidation(String fieldKey, bool isValid) {
    if (mounted) {
      setState(() {
        _fieldValidation[fieldKey] = isValid;
      });
    }
  }

  bool get _areAllFieldsValid {
    return _requiredFields.every((field) => _fieldValidation[field] ?? false);
  }

  int get _validFieldsCount {
    return _requiredFields
        .where((field) => _fieldValidation[field] ?? false)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.editingGuest != null
            ? 'Gast bearbeiten'
            : 'Neuen Gast hinzufügen',
      ),
      content: Container(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fortschrittsanzeige
              LinearProgressIndicator(
                value: _validFieldsCount / _requiredFields.length,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _areAllFieldsValid
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_validFieldsCount von ${_requiredFields.length} Pflichtfeldern ausgefüllt',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // Vorname - PFLICHT
              SmartTextField(
                label: 'Vorname',
                fieldKey: 'first_name',
                isRequired: true,
                controller: widget.firstNameController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vorname ist erforderlich';
                  }
                  if (value.trim().length < 2) {
                    return 'Mindestens 2 Zeichen';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 16),

              // Nachname - OPTIONAL
              SmartTextField(
                label: 'Nachname',
                fieldKey: 'last_name',
                isRequired: false,
                controller: widget.lastNameController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                validator: (value) {
                  // Optional, aber wenn angegeben min. 2 Zeichen
                  if (value != null &&
                      value.trim().isNotEmpty &&
                      value.trim().length < 2) {
                    return 'Mindestens 2 Zeichen';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 16),

              // E-Mail - OPTIONAL
              SmartTextField(
                label: 'E-Mail',
                fieldKey: 'email',
                isRequired: false,
                controller: widget.emailController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  // Optional, aber wenn angegeben muss Format stimmen
                  if (value != null && value.trim().isNotEmpty) {
                    final emailRegex = RegExp(
                      r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Ungültige E-Mail-Adresse';
                    }
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 16),

              // RSVP Status - PFLICHT
              SmartDropdown<String>(
                label: 'Status',
                fieldKey: 'status',
                isRequired: true,
                value: widget.selectedStatus,
                items: const ['pending', 'yes', 'no'],
                itemLabel: (status) {
                  switch (status) {
                    case 'pending':
                      return 'Offen';
                    case 'yes':
                      return 'Zugesagt';
                    case 'no':
                      return 'Abgesagt';
                    default:
                      return status;
                  }
                },
                onChanged: (value) {
                  if (value != null) {
                    widget.onStatusChanged(value);
                  }
                },
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                hintText: 'Bitte wählen...',
              ),

              const SizedBox(height: 16),

              // Besonderheiten - OPTIONAL
              SmartTextField(
                label: 'Besonderheiten (z.B. Diätwünsche)',
                fieldKey: 'dietary',
                isRequired: false,
                controller: widget.dietaryController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.multiline,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: _areAllFieldsValid ? widget.onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _areAllFieldsValid
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300],
            foregroundColor: Colors.white, // ← WEIßE SCHRIFT!
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_areAllFieldsValid ? Icons.save : Icons.save_outlined),
              const SizedBox(width: 8),
              const Text('Speichern'),
            ],
          ),
        ),
      ],
    );
  }
}
