import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/wedding_models.dart';
import '../services/pdf_export_service.dart';
import '../services/excel_export_service.dart';
import '../services/guest_scoring_service.dart'; // ← Scoring Service
// Smart Validation Imports
import '../mixins/smart_form_validation_mixin.dart';
import '../widgets/forms/smart_text_field.dart';
import '../widgets/forms/smart_dropdown.dart';
import '../sync/services/sync_service.dart'; // ← NEU: Sync

class GuestPage extends StatefulWidget {
  final List<Guest> guests;
  final Function(Guest) onAddGuest;
  final Function(Guest) onUpdateGuest;
  final Function(int) onDeleteGuest;

  const GuestPage({
    super.key,
    required this.guests,
    required this.onAddGuest,
    required this.onUpdateGuest,
    required this.onDeleteGuest,
  });

  @override
  State<GuestPage> createState() => _GuestPageState();
}

class _GuestPageState extends State<GuestPage> with SmartFormValidation {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dietaryController = TextEditingController();
  final _childrenNamesController = TextEditingController();

  String _selectedStatus = 'pending';
  String? _selectedRelationship;
  bool _isVip = false;
  int _childrenCount = 0;
  int _distanceKm = 0;

  List<int> _conflictIds = [];
  List<int> _knowsIds = [];
  String? _ageGroup;
  List<String> _hobbiesList = [];

  Guest? _editingGuest;

  // Filter
  String? _filterStatus;
  String? _filterRelationship;

  // Suche
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Sortierung
  String _sortBy = 'name'; // 'name' | 'score' | 'status'

  // ── NEU: Sync-Helper ──────────────────────────────────────────────────────
  void _syncNow() {
    SyncService.instance.syncNow().catchError((e) {
      debugPrint('Sync-Fehler: $e');
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _dietaryController.dispose();
    _childrenNamesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showGuestDialog([Guest? guest]) {
    _editingGuest = guest;

    if (guest != null) {
      _firstNameController.text = guest.firstName;
      _lastNameController.text = guest.lastName;
      _emailController.text = guest.email;
      _dietaryController.text = guest.dietaryRequirements;
      _selectedStatus = guest.confirmed;
      _selectedRelationship = guest.relationshipType;
      _isVip = guest.isVip;
      _childrenCount = guest.childrenCount;
      _distanceKm = guest.distanceKm;
      _childrenNamesController.text = guest.childrenNamesList.join(', ');
      _conflictIds = List.from(guest.conflictIds);
      _knowsIds = List.from(guest.knowsIds);
      _ageGroup = guest.ageGroup;
      _hobbiesList = List.from(guest.hobbiesList);
    } else {
      _resetForm();
    }

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
          childrenNamesController: _childrenNamesController,
          selectedStatus: _selectedStatus,
          selectedRelationship: _selectedRelationship,
          isVip: _isVip,
          childrenCount: _childrenCount,
          distanceKm: _distanceKm,
          conflictIds: _conflictIds,
          knowsIds: _knowsIds,
          ageGroup: _ageGroup,
          hobbiesList: _hobbiesList,
          allGuests: widget.guests,
          editingGuestId: _editingGuest?.id,
          onConflictIdsChanged: (ids) => _conflictIds = ids,
          onKnowsIdsChanged: (ids) => _knowsIds = ids,
          onAgeGroupChanged: (ag) => _ageGroup = ag,
          onHobbiesChanged: (h) => _hobbiesList = h,
          onStatusChanged: (s) => _selectedStatus = s,
          onRelationshipChanged: (r) => _selectedRelationship = r,
          onVipChanged: (v) => _isVip = v,
          onChildrenCountChanged: (c) => _childrenCount = c,
          onDistanceChanged: (d) => _distanceKm = d,
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
    if (_firstNameController.text.isEmpty) return;

    // Kinder-Namen als JSON-Array String speichern
    String? childrenNamesJson;
    if (_childrenCount > 0 && _childrenNamesController.text.trim().isNotEmpty) {
      final names = _childrenNamesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      childrenNamesJson = '[${names.map((n) => '"$n"').join(',')}]';
    }

    // Score berechnen
    final tempGuest = Guest(
      id: _editingGuest?.id,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      confirmed: _selectedStatus,
      dietaryRequirements: _dietaryController.text,
      tableNumber: _editingGuest?.tableNumber,
      relationshipType: _selectedRelationship,
      isVip: _isVip,
      childrenCount: _childrenCount,
      childrenNames: childrenNamesJson,
      distanceKm: _distanceKm,
      conflictsJson: _conflictIds.isEmpty
          ? null
          : '[${_conflictIds.join(',')}]',
      knowsJson: _knowsIds.isEmpty ? null : '[${_knowsIds.join(',')}]',
      ageGroup: _ageGroup,
      hobbies: _hobbiesList.isEmpty ? null : _hobbiesList.join(','),
    );

    final score = GuestScoringService.calculateScore(tempGuest);

    final guest = tempGuest.copyWith(
      priorityScore: score,
      scoreUpdatedAt: DateTime.now().toIso8601String(),
    );

    if (_editingGuest != null) {
      widget.onUpdateGuest(guest);
    } else {
      widget.onAddGuest(guest);
    }

    _resetForm();
    Navigator.pop(context);

    _syncNow(); // ← NEU: Sync nach Speichern

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
    _childrenNamesController.clear();
    _selectedStatus = 'pending';
    _selectedRelationship = null;
    _isVip = false;
    _childrenCount = 0;
    _distanceKm = 0;
    _conflictIds = [];
    _knowsIds = [];
    _ageGroup = null;
    _hobbiesList = [];
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

  String _getRelationshipLabel(String? rel) {
    switch (rel) {
      case 'familie':
        return 'Familie';
      case 'freunde':
        return 'Freunde';
      case 'kollegen':
        return 'Kollegen';
      case 'bekannte':
        return 'Bekannte';
      default:
        return '';
    }
  }

  List<Guest> _getFilteredAndSortedGuests() {
    var guests = widget.guests.where((g) {
      // Status-Filter
      if (_filterStatus != null && g.confirmed != _filterStatus) return false;
      // Beziehungs-Filter
      if (_filterRelationship != null &&
          g.relationshipType != _filterRelationship)
        return false;
      // Suche
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final name = '${g.firstName} ${g.lastName}'.toLowerCase();
        if (!name.contains(q)) return false;
      }
      return true;
    }).toList();

    // Sortierung
    switch (_sortBy) {
      case 'score':
        guests.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
        break;
      case 'status':
        const order = {'yes': 0, 'pending': 1, 'no': 2};
        guests.sort(
          (a, b) =>
              (order[a.confirmed] ?? 1).compareTo(order[b.confirmed] ?? 1),
        );
        break;
      default: // name
        guests.sort(
          (a, b) => '${a.lastName}${a.firstName}'.compareTo(
            '${b.lastName}${b.firstName}',
          ),
        );
    }

    return guests;
  }

  // Export
  Future<void> _showExportDialog() async {
    if (widget.guests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Gäste zum Exportieren'),
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
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await PdfExportService.exportGuestListToPdf(widget.guests);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF erfolgreich exportiert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _exportAsExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await ExcelExportService.exportGuestListToExcel(widget.guests);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Excel erfolgreich exportiert!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
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
    final totalChildren = widget.guests.fold(
      0,
      (sum, g) => sum + g.childrenCount,
    );

    final filteredGuests = _getFilteredAndSortedGuests();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gästeliste'),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          // Sortierung
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sortieren',
            onSelected: (val) => setState(() => _sortBy = val),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 18,
                      color: _sortBy == 'name' ? scheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Nach Name'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'score',
                child: Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 18,
                      color: _sortBy == 'score' ? scheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Nach Score'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: _sortBy == 'status' ? scheme.primary : null,
                    ),
                    const SizedBox(width: 8),
                    const Text('Nach Status'),
                  ],
                ),
              ),
            ],
          ),
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
            // ── Stat-Cards ────────────────────────────────────────
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
                      _filterStatus == null && _filterRelationship == null,
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

            // ── Kinder-Info (nur wenn Kinder vorhanden) ───────────
            if (totalChildren > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.child_care, size: 16, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '$totalChildren ${totalChildren == 1 ? 'Kind' : 'Kinder'} in der Gästeliste',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${widget.guests.fold(0, (s, g) => s + g.totalPersons)} Personen gesamt',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Beziehungs-Filter ─────────────────────────────────
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildRelChip(null, 'Alle'),
                  const SizedBox(width: 6),
                  _buildRelChip('familie', '👨‍👩‍👧 Familie'),
                  const SizedBox(width: 6),
                  _buildRelChip('freunde', '👫 Freunde'),
                  const SizedBox(width: 6),
                  _buildRelChip('kollegen', '💼 Kollegen'),
                  const SizedBox(width: 6),
                  _buildRelChip('bekannte', '🤝 Bekannte'),
                ],
              ),
            ),

            // ── Suche ─────────────────────────────────────────────
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Gast suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),

            const SizedBox(height: 10),

            // ── Aktive Filter-Anzeige ─────────────────────────────
            if (_filterStatus != null || _filterRelationship != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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
                    const SizedBox(width: 6),
                    Text(
                      [
                        if (_filterStatus != null)
                          _getStatusLabel(_filterStatus!),
                        if (_filterRelationship != null)
                          _getRelationshipLabel(_filterRelationship),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        _filterStatus = null;
                        _filterRelationship = null;
                      }),
                      child: const Text('Zurücksetzen'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Gästeliste ────────────────────────────────────────
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
                            widget.guests.isEmpty
                                ? 'Noch keine Gäste hinzugefügt'
                                : 'Keine Gäste gefunden',
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
                        return _buildGuestCard(guest);
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

  // ── Gast-Karte mit Score-Badge + Kinder ──────────────────────────────────
  Widget _buildGuestCard(Guest guest) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Avatar mit Score-Farbe
            Stack(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(guest.confirmed),
                  radius: 22,
                  child: Text(
                    guest.firstName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (guest.isVip)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (guest.conflictIds.isNotEmpty)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning,
                        size: 9,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Name + Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${guest.firstName} ${guest.lastName}'.trim(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Score-Badge
                      if (guest.priorityScore > 0) _buildScoreBadge(guest),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      // Status
                      _buildMiniChip(
                        _getStatusLabel(guest.confirmed),
                        _getStatusColor(guest.confirmed),
                      ),
                      // Beziehungstyp
                      if (guest.relationshipType != null)
                        _buildMiniChip(
                          _getRelationshipLabel(guest.relationshipType),
                          Colors.blueGrey,
                        ),
                      // Kinder
                      if (guest.childrenCount > 0)
                        _buildMiniChip(
                          '${guest.childrenCount} ${guest.childrenCount == 1 ? 'Kind' : 'Kinder'}',
                          Colors.purple,
                          icon: Icons.child_care,
                        ),
                      // Diät
                      if (guest.dietaryRequirements.isNotEmpty)
                        _buildMiniChip(guest.dietaryRequirements, Colors.teal),
                    ],
                  ),
                ],
              ),
            ),

            // Menü
            PopupMenuButton(
              itemBuilder: (_) => [
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
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Löschen', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                  onTap: () {
                    widget.onDeleteGuest(guest.id!);
                    _syncNow(); // ← NEU: Sync nach Löschen
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge(Guest guest) {
    Color color;
    String label;
    switch (guest.priorityBadge) {
      case PriorityBadge.vip:
        color = Colors.amber.shade700;
        label = 'VIP';
        break;
      case PriorityBadge.hoch:
        color = Colors.green;
        label = '${guest.priorityScore.toInt()}';
        break;
      case PriorityBadge.mittel:
        color = Colors.orange;
        label = '${guest.priorityScore.toInt()}';
        break;
      case PriorityBadge.niedrig:
        color = Colors.grey;
        label = '${guest.priorityScore.toInt()}';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelChip(String? value, String label) {
    final active = _filterRelationship == value;
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => setState(() => _filterRelationship = active ? null : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? scheme.primary : scheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? scheme.primary : scheme.primary.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? scheme.onPrimary : scheme.primary,
          ),
        ),
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
      padding: const EdgeInsets.all(10),
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[700])),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 3),
              height: 3,
              width: 24,
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
      default:
        return Colors.orange;
    }
  }
}

// ============================================================================
// GUEST FORM DIALOG
// ============================================================================

class _GuestFormDialog extends StatefulWidget {
  final Guest? editingGuest;
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController emailController;
  final TextEditingController dietaryController;
  final TextEditingController childrenNamesController;
  final String selectedStatus;
  final String? selectedRelationship;
  final bool isVip;
  final int childrenCount;
  final int distanceKm;
  final Function(String) onStatusChanged;
  final Function(String?) onRelationshipChanged;
  final Function(bool) onVipChanged;
  final Function(int) onChildrenCountChanged;
  final Function(int) onDistanceChanged;
  final List<int> conflictIds;
  final List<int> knowsIds;
  final String? ageGroup;
  final List<String> hobbiesList;
  final List<Guest> allGuests;
  final int? editingGuestId;
  final Function(List<int>) onConflictIdsChanged;
  final Function(List<int>) onKnowsIdsChanged;
  final Function(String?) onAgeGroupChanged;
  final Function(List<String>) onHobbiesChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _GuestFormDialog({
    required this.editingGuest,
    required this.firstNameController,
    required this.lastNameController,
    required this.emailController,
    required this.dietaryController,
    required this.childrenNamesController,
    required this.selectedStatus,
    required this.selectedRelationship,
    required this.isVip,
    required this.childrenCount,
    required this.distanceKm,
    required this.onStatusChanged,
    required this.onRelationshipChanged,
    required this.onVipChanged,
    required this.onChildrenCountChanged,
    required this.onDistanceChanged,
    required this.conflictIds,
    required this.knowsIds,
    required this.ageGroup,
    required this.hobbiesList,
    required this.allGuests,
    required this.editingGuestId,
    required this.onConflictIdsChanged,
    required this.onKnowsIdsChanged,
    required this.onAgeGroupChanged,
    required this.onHobbiesChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_GuestFormDialog> createState() => _GuestFormDialogState();
}

class _GuestFormDialogState extends State<_GuestFormDialog> {
  final Map<String, bool> _fieldValidation = {};
  late String _status;
  late String? _relationship;
  late bool _vip;
  late int _children;
  late int _distance;
  late List<int> _conflictIds;
  late List<int> _knowsIds;
  late String? _ageGroup;
  late List<String> _hobbiesList;
  final _hobbiesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _status = widget.selectedStatus;
    _relationship = widget.selectedRelationship;
    _vip = widget.isVip;
    _children = widget.childrenCount;
    _distance = widget.distanceKm;
    _conflictIds = List.from(widget.conflictIds);
    _knowsIds = List.from(widget.knowsIds);
    _ageGroup = widget.ageGroup;
    _hobbiesList = List.from(widget.hobbiesList);
    _hobbiesController.text = _hobbiesList.join(', ');
  }

  @override
  void dispose() {
    _hobbiesController.dispose();
    super.dispose();
  }

  void _updateFieldValidation(String fieldKey, bool isValid) {
    if (mounted) setState(() => _fieldValidation[fieldKey] = isValid);
  }

  bool get _isValid => (_fieldValidation['first_name'] ?? false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(
        widget.editingGuest != null
            ? 'Gast bearbeiten'
            : 'Neuen Gast hinzufügen',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Basis-Felder ──────────────────────────────────────
              SmartTextField(
                label: 'Vorname *',
                fieldKey: 'first_name',
                isRequired: true,
                controller: widget.firstNameController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Mindestens 2 Zeichen'
                    : null,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SmartTextField(
                label: 'Nachname',
                fieldKey: 'last_name',
                isRequired: false,
                controller: widget.lastNameController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              SmartTextField(
                label: 'E-Mail',
                fieldKey: 'email',
                isRequired: false,
                controller: widget.emailController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),

              // ── Status ────────────────────────────────────────────
              SmartDropdown<String>(
                label: 'Status *',
                fieldKey: 'status',
                isRequired: true,
                value: _status,
                items: const ['pending', 'yes', 'no'],
                itemLabel: (s) => s == 'pending'
                    ? 'Offen'
                    : s == 'yes'
                    ? 'Zugesagt'
                    : 'Abgesagt',
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _status = v);
                    widget.onStatusChanged(v);
                  }
                },
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                hintText: 'Bitte wählen...',
              ),
              const SizedBox(height: 16),

              // ── Beziehungstyp ─────────────────────────────────────
              const Text(
                'Beziehung zum Brautpaar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _relChip(null, 'Keine Angabe', scheme),
                  _relChip('familie', '👨‍👩‍👧 Familie', scheme),
                  _relChip('freunde', '👫 Freunde', scheme),
                  _relChip('kollegen', '💼 Kollegen', scheme),
                  _relChip('bekannte', '🤝 Bekannte', scheme),
                ],
              ),
              const SizedBox(height: 16),

              // ── VIP + Entfernung ──────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _vip = !_vip);
                        widget.onVipChanged(_vip);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _vip
                              ? Colors.amber.withOpacity(0.15)
                              : Colors.grey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _vip
                                ? Colors.amber
                                : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: _vip ? Colors.amber : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VIP',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _vip
                                    ? Colors.amber.shade800
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anreise (km)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _distanceBtn(Icons.remove, () {
                              if (_distance > 0) {
                                setState(
                                  () => _distance = (_distance - 50).clamp(
                                    0,
                                    9999,
                                  ),
                                );
                                widget.onDistanceChanged(_distance);
                              }
                            }),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$_distance km',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _distanceBtn(Icons.add, () {
                              setState(
                                () =>
                                    _distance = (_distance + 50).clamp(0, 9999),
                              );
                              widget.onDistanceChanged(_distance);
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Kinder ────────────────────────────────────────────
              const Text(
                'Kinder',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _distanceBtn(Icons.remove, () {
                    if (_children > 0) {
                      setState(() => _children--);
                      widget.onChildrenCountChanged(_children);
                    }
                  }),
                  const SizedBox(width: 16),
                  Text(
                    '$_children ${_children == 1 ? 'Kind' : 'Kinder'}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _distanceBtn(Icons.add, () {
                    setState(() => _children++);
                    widget.onChildrenCountChanged(_children);
                  }),
                ],
              ),
              if (_children > 0) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: widget.childrenNamesController,
                  decoration: InputDecoration(
                    labelText: 'Namen der Kinder (kommagetrennt)',
                    hintText: 'z.B. Lena, Max',
                    prefixIcon: const Icon(Icons.child_care, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Altersgruppe ─────────────────────────────────────
              const Text(
                'Altersgruppe',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ageChip(null, 'Keine Angabe', scheme),
                  _ageChip('kind', '👶 Kind', scheme),
                  _ageChip('jugendlich', '🧒 Jugendlich', scheme),
                  _ageChip('erwachsen', '👤 Erwachsen', scheme),
                  _ageChip('senior', '👴 Senior', scheme),
                ],
              ),
              const SizedBox(height: 16),

              // ── Hobbys ────────────────────────────────────────────
              const Text(
                'Hobbys / Interessen',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hobbiesController,
                decoration: InputDecoration(
                  hintText: 'z.B. Sport, Musik, Reisen, Kochen',
                  prefixIcon: const Icon(Icons.interests, size: 18),
                  helperText: 'Kommagetrennt eingeben',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                onChanged: (val) {
                  _hobbiesList = val
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  widget.onHobbiesChanged(_hobbiesList);
                },
              ),
              const SizedBox(height: 16),

              // ── Kennt sich mit ────────────────────────────────────
              if (widget.allGuests.isNotEmpty) ...[
                const Text(
                  'Kennt sich mit',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gäste die sich kennen werden bevorzugt zusammengesetzt',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                _buildGuestSelector(
                  selectedIds: _knowsIds,
                  excludeId: widget.editingGuestId,
                  color: Colors.green,
                  icon: Icons.people,
                  onChanged: (ids) {
                    setState(() => _knowsIds = ids);
                    widget.onKnowsIdsChanged(ids);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── Konflikte ─────────────────────────────────────────
              if (widget.allGuests.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    const Text(
                      'Konflikte',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Diese Gäste werden NIE an denselben Tisch gesetzt',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 8),
                _buildGuestSelector(
                  selectedIds: _conflictIds,
                  excludeId: widget.editingGuestId,
                  color: Colors.red,
                  icon: Icons.block,
                  onChanged: (ids) {
                    setState(() => _conflictIds = ids);
                    widget.onConflictIdsChanged(ids);
                  },
                ),
                const SizedBox(height: 16),
              ],

              // ── Besonderheiten ────────────────────────────────────
              SmartTextField(
                label: 'Besonderheiten (z.B. Diätwünsche)',
                fieldKey: 'dietary',
                isRequired: false,
                controller: widget.dietaryController,
                onValidationChanged: _updateFieldValidation,
                isDisabled: false,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: widget.onCancel, child: const Text('Abbrechen')),
        ElevatedButton(
          onPressed: _isValid ? widget.onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isValid ? scheme.primary : Colors.grey[300],
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isValid ? Icons.save : Icons.save_outlined),
              const SizedBox(width: 8),
              const Text('Speichern'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _relChip(String? value, String label, ColorScheme scheme) {
    final active = _relationship == value;
    return GestureDetector(
      onTap: () {
        setState(() => _relationship = active ? null : value);
        widget.onRelationshipChanged(_relationship);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? scheme.primary.withOpacity(0.15)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? scheme.primary : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? scheme.primary : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _distanceBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 18, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _ageChip(String? value, String label, ColorScheme scheme) {
    final active = _ageGroup == value;
    return GestureDetector(
      onTap: () {
        setState(() => _ageGroup = active ? null : value);
        widget.onAgeGroupChanged(_ageGroup);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.purple.withOpacity(0.15)
              : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? Colors.purple : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? Colors.purple.shade700 : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildGuestSelector({
    required List<int> selectedIds,
    required int? excludeId,
    required Color color,
    required IconData icon,
    required Function(List<int>) onChanged,
  }) {
    final selectableGuests = widget.allGuests
        .where((g) => g.id != null && g.id != excludeId)
        .toList();

    if (selectableGuests.isEmpty) {
      return Text(
        'Noch keine anderen Gäste vorhanden',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: selectableGuests.map((g) {
        final selected = selectedIds.contains(g.id);
        final name = '${g.firstName} ${g.lastName}'.trim();
        return GestureDetector(
          onTap: () {
            final updated = List<int>.from(selectedIds);
            if (selected) {
              updated.remove(g.id);
            } else {
              updated.add(g.id!);
            }
            onChanged(updated);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: selected
                  ? color.withOpacity(0.15)
                  : Colors.grey.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? color : Colors.grey.withOpacity(0.3),
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? icon : Icons.person_outline,
                  size: 13,
                  color: selected ? color : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? color : Colors.grey.shade700,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
