import 'package:flutter/material.dart';
import '../models/dienstleister_models.dart';
import '../data/dienstleister_database.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_colors.dart';
import 'package:intl/intl.dart';

class DienstleisterDetailScreen extends StatefulWidget {
  final String dienstleisterId;

  const DienstleisterDetailScreen({Key? key, required this.dienstleisterId})
    : super(key: key);

  @override
  State<DienstleisterDetailScreen> createState() =>
      _DienstleisterDetailScreenState();
}

class _DienstleisterDetailScreenState extends State<DienstleisterDetailScreen>
    with SingleTickerProviderStateMixin {
  Dienstleister? _dienstleister;
  List<DienstleisterZahlung> _zahlungen = [];
  List<DienstleisterNotiz> _notizen = [];
  List<DienstleisterAufgabe> _aufgaben = [];
  bool _isLoading = true;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dienstleister = await DienstleisterDatabase.instance
          .getDienstleister(widget.dienstleisterId);
      final zahlungen = await DienstleisterDatabase.instance.getZahlungenFuer(
        widget.dienstleisterId,
      );
      final notizen = await DienstleisterDatabase.instance.getNotizenFuer(
        widget.dienstleisterId,
      );
      final aufgaben = await DienstleisterDatabase.instance.getAufgabenFuer(
        widget.dienstleisterId,
      );

      setState(() {
        _dienstleister = dienstleister;
        _zahlungen = zahlungen;
        _notizen = notizen;
        _aufgaben = aufgaben;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(DienstleisterStatus newStatus) async {
    if (_dienstleister == null) return;
    final updated = _dienstleister!.copyWith(status: newStatus);
    await DienstleisterDatabase.instance.updateDienstleister(updated);
    _loadData();
  }

  Future<void> _toggleFavorit() async {
    if (_dienstleister == null) return;
    final updated = _dienstleister!.copyWith(
      istFavorit: !_dienstleister!.istFavorit,
    );
    await DienstleisterDatabase.instance.updateDienstleister(updated);
    _loadData();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // Hilfsfunktion für Euro-Formatierung mit Tausendertrennzeichen
  String _formatEuro(double betrag) {
    final formatter = NumberFormat('#,##0.00', 'de_DE');
    return formatter.format(betrag).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lade...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_dienstleister == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fehler')),
        body: const Center(child: Text('Dienstleister nicht gefunden')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_dienstleister!.name),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _dienstleister!.istFavorit
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: _toggleFavorit,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header mit Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _dienstleister!.kategorie.icon,
                      size: 28,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dienstleister!.name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _dienstleister!.kategorie.label,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _dienstleister!.status.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _dienstleister!.status.label,
                        style: TextStyle(
                          color: _dienstleister!.status.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Übersicht'),
                Tab(text: 'Angebot'),
                Tab(text: 'Zahlungen'),
                Tab(text: 'Ablauf'),
                Tab(text: 'Kommunikation'),
                Tab(text: 'Dateien'),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUebersichtTab(),
                _buildAngebotTab(),
                _buildZahlungenTab(),
                _buildAblaufTab(),
                _buildKommunikationTab(),
                _buildDateienTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tab 1: Übersicht
  Widget _buildUebersichtTab() {
    final statusAktionen = _getAvailableStatusActions();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status-Aktionen
          if (statusAktionen.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status-Aktionen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: statusAktionen.map((aktion) {
                        return ElevatedButton.icon(
                          onPressed: () => _updateStatus(aktion['status']),
                          icon: Icon(aktion['icon'], size: 18),
                          label: Text(aktion['label']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Kontaktdaten
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kontaktdaten',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_dienstleister!.hauptkontakt.name.isNotEmpty)
                    _buildInfoRow(
                      Icons.person,
                      'Ansprechpartner',
                      _dienstleister!.hauptkontakt.name,
                    ),
                  if (_dienstleister!.hauptkontakt.email.isNotEmpty)
                    _buildInfoRow(
                      Icons.email,
                      'E-Mail',
                      _dienstleister!.hauptkontakt.email,
                      onTap: () => _launchUrl(
                        'mailto:${_dienstleister!.hauptkontakt.email}',
                      ),
                    ),
                  if (_dienstleister!.hauptkontakt.telefon.isNotEmpty)
                    _buildInfoRow(
                      Icons.phone,
                      'Telefon',
                      _dienstleister!.hauptkontakt.telefon,
                      onTap: () => _launchUrl(
                        'tel:${_dienstleister!.hauptkontakt.telefon}',
                      ),
                    ),
                  if (_dienstleister!.website != null)
                    _buildInfoRow(
                      Icons.language,
                      'Website',
                      _dienstleister!.website!,
                      onTap: () => _launchUrl(_dienstleister!.website!),
                    ),
                  if (_dienstleister!.instagram.isNotEmpty)
                    _buildInfoRow(
                      Icons.camera_alt,
                      'Instagram',
                      _dienstleister!.instagram,
                      onTap: () => _launchUrl(
                        'https://instagram.com/${_dienstleister!.instagram.replaceAll('@', '')}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Bewertung & Tags
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bewertung & Tags',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Bewertung:'),
                      const SizedBox(width: 8),
                      ...List.generate(5, (index) {
                        return Icon(
                          index < _dienstleister!.bewertung
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                      const SizedBox(width: 8),
                      Text(
                        _dienstleister!.bewertung.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_dienstleister!.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _dienstleister!.tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeTag(tag),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 2: Angebot
  Widget _buildAngebotTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Angebotsinformationen',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Angebotssumme',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '€${_formatEuro(_dienstleister!.angebotsSumme?.betrag ?? 0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_dienstleister!.optionBis != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Option gültig bis',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_dienstleister!.optionBis!.day}.${_dienstleister!.optionBis!.month}.${_dienstleister!.optionBis!.year}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_dienstleister!.notizen.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notizen zum Angebot',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_dienstleister!.notizen),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Tab 3: Zahlungen
  Widget _buildZahlungenTab() {
    final gesamt = _zahlungen.fold<double>(
      0,
      (sum, z) => sum + z.betrag.betrag,
    );
    final bezahlt = _zahlungen
        .where((z) => z.bezahlt)
        .fold<double>(0, (sum, z) => sum + z.betrag.betrag);
    final offen = gesamt - bezahlt;

    return Column(
      children: [
        // Zusammenfassung
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildZahlungsStat('Gesamt', gesamt, Colors.blue),
              _buildZahlungsStat('Bezahlt', bezahlt, Colors.green),
              _buildZahlungsStat('Offen', offen, Colors.orange),
            ],
          ),
        ),

        // Liste
        Expanded(
          child: _zahlungen.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Zahlungen angelegt',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _zahlungen.length,
                  itemBuilder: (context, index) {
                    return _buildZahlungsCard(_zahlungen[index]);
                  },
                ),
        ),

        // Add Button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _showZahlungDialog,
            icon: const Icon(Icons.add),
            label: const Text('Zahlung hinzufügen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  // Tab 4: Ablauf & Logistik
  Widget _buildAblaufTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Termine',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_dienstleister!.briefingDatum != null)
                    _buildInfoRow(
                      Icons.event,
                      'Briefing',
                      '${_dienstleister!.briefingDatum!.day}.${_dienstleister!.briefingDatum!.month}.${_dienstleister!.briefingDatum!.year}',
                    ),
                  if (_dienstleister!.ankunft != null)
                    _buildInfoRow(
                      Icons.schedule,
                      'Ankunft',
                      '${_dienstleister!.ankunft!.day}.${_dienstleister!.ankunft!.month}.${_dienstleister!.ankunft!.year}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logistik',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_dienstleister!.logistik.adresse.isNotEmpty)
                    _buildInfoRow(
                      Icons.location_on,
                      'Adresse',
                      _dienstleister!.logistik.adresse,
                    ),
                  if (_dienstleister!.logistik.ankunftsfenster.isNotEmpty)
                    _buildInfoRow(
                      Icons.access_time,
                      'Ankunftsfenster',
                      _dienstleister!.logistik.ankunftsfenster,
                    ),
                  if (_dienstleister!.logistik.parken.isNotEmpty)
                    _buildInfoRow(
                      Icons.local_parking,
                      'Parken',
                      _dienstleister!.logistik.parken,
                    ),
                  if (_dienstleister!.logistik.strom.isNotEmpty)
                    _buildInfoRow(
                      Icons.power,
                      'Strom',
                      _dienstleister!.logistik.strom,
                    ),
                  if (_dienstleister!.logistik.zugangshinweise.isNotEmpty)
                    _buildInfoRow(
                      Icons.info,
                      'Zugangshinweise',
                      _dienstleister!.logistik.zugangshinweise,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Tab 5: Kommunikation
  Widget _buildKommunikationTab() {
    return Column(
      children: [
        // Notizen Section
        Expanded(
          child: _notizen.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Noch keine Notizen',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notizen.length,
                  itemBuilder: (context, index) {
                    return _buildNotizCard(_notizen[index]);
                  },
                ),
        ),

        // Aufgaben Section
        if (_aufgaben.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Aufgaben',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ..._aufgaben.map((aufgabe) => _buildAufgabeItem(aufgabe)),
              ],
            ),
          ),
        ],

        // Add Buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showNotizDialog,
                  icon: const Icon(Icons.note_add),
                  label: const Text('Notiz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAufgabeDialog,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Aufgabe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 6: Dateien
  Widget _buildDateienTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Dateiverwaltung wird in Kürze verfügbar sein',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: onTap != null ? AppColors.primary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildZahlungsStat(String label, double betrag, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          '€${_formatEuro(betrag)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildZahlungsCard(DienstleisterZahlung zahlung) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Checkbox(
          value: zahlung.bezahlt,
          onChanged: (value) async {
            final updated = zahlung.copyWith(bezahlt: value ?? false);
            await DienstleisterDatabase.instance.updateZahlung(updated);
            _loadData();
          },
        ),
        title: Text(zahlung.bezeichnung),
        subtitle: zahlung.faelligAm != null
            ? Text(
                'Fällig: ${zahlung.faelligAm!.day}.${zahlung.faelligAm!.month}.${zahlung.faelligAm!.year}',
              )
            : null,
        trailing: Text(
          '€${_formatEuro(zahlung.betrag.betrag)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: zahlung.bezahlt ? Colors.green : Colors.orange,
          ),
        ),
        onLongPress: () => _showZahlungDialog(zahlung),
      ),
    );
  }

  Widget _buildNotizCard(DienstleisterNotiz notiz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${notiz.erstelltAm.day}.${notiz.erstelltAm.month}.${notiz.erstelltAm.year} ${notiz.erstelltAm.hour}:${notiz.erstelltAm.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18),
                  onPressed: () async {
                    await DienstleisterDatabase.instance.deleteNotiz(notiz.id);
                    _loadData();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notiz.text),
          ],
        ),
      ),
    );
  }

  Widget _buildAufgabeItem(DienstleisterAufgabe aufgabe) {
    return CheckboxListTile(
      value: aufgabe.erledigt,
      onChanged: (value) async {
        final updated = aufgabe.copyWith(erledigt: value ?? false);
        await DienstleisterDatabase.instance.updateAufgabe(updated);
        _loadData();
      },
      title: Text(aufgabe.titel),
      subtitle: aufgabe.faelligAm != null
          ? Text(
              'Fällig: ${aufgabe.faelligAm!.day}.${aufgabe.faelligAm!.month}.${aufgabe.faelligAm!.year}',
            )
          : null,
    );
  }

  // Dialoge
  void _showZahlungDialog([DienstleisterZahlung? zahlung]) {
    showDialog(
      context: context,
      builder: (context) => _ZahlungDialog(
        dienstleisterId: widget.dienstleisterId,
        zahlung: zahlung,
        onSave: _loadData,
      ),
    );
  }

  void _showNotizDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Notiz'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Notiz',
            border: OutlineInputBorder(),
          ),
          maxLines: 5,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final notiz = DienstleisterNotiz(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  dienstleisterId: widget.dienstleisterId,
                  erstelltAm: DateTime.now(),
                  text: controller.text,
                );
                await DienstleisterDatabase.instance.createNotiz(notiz);
                _loadData();
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showAufgabeDialog() {
    final controller = TextEditingController();
    DateTime? faelligAm;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Neue Aufgabe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Aufgabe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Fällig am'),
                subtitle: Text(
                  faelligAm != null
                      ? '${faelligAm!.day}.${faelligAm!.month}.${faelligAm!.year}'
                      : 'Nicht gesetzt',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => faelligAm = date);
                    }
                  },
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
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  final aufgabe = DienstleisterAufgabe(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    dienstleisterId: widget.dienstleisterId,
                    titel: controller.text,
                    faelligAm: faelligAm,
                  );
                  await DienstleisterDatabase.instance.createAufgabe(aufgabe);
                  _loadData();
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAvailableStatusActions() {
    final actions = <Map<String, dynamic>>[];
    switch (_dienstleister!.status) {
      case DienstleisterStatus.recherche:
        actions.add({
          'status': DienstleisterStatus.angefragt,
          'label': 'Anfragen',
          'icon': Icons.send,
        });
        break;
      case DienstleisterStatus.angefragt:
      case DienstleisterStatus.angebot:
      case DienstleisterStatus.shortlist:
        actions.add({
          'status': DienstleisterStatus.gebucht,
          'label': 'Buchen',
          'icon': Icons.check,
        });
        break;
      case DienstleisterStatus.gebucht:
        actions.add({
          'status': DienstleisterStatus.briefingFertig,
          'label': 'Briefing abschließen',
          'icon': Icons.event_available,
        });
        break;
      case DienstleisterStatus.briefingFertig:
        actions.add({
          'status': DienstleisterStatus.geliefert,
          'label': 'Als geliefert markieren',
          'icon': Icons.done,
        });
        break;
      case DienstleisterStatus.geliefert:
        actions.add({
          'status': DienstleisterStatus.abgerechnet,
          'label': 'Abrechnen',
          'icon': Icons.receipt,
        });
        break;
      case DienstleisterStatus.abgerechnet:
        actions.add({
          'status': DienstleisterStatus.bewertet,
          'label': 'Bewerten',
          'icon': Icons.star,
        });
        break;
      default:
        break;
    }
    return actions;
  }

  Future<void> _removeTag(String tag) async {
    final tags = List<String>.from(_dienstleister!.tags);
    tags.remove(tag);
    final updated = _dienstleister!.copyWith(tags: tags);
    await DienstleisterDatabase.instance.updateDienstleister(updated);
    _loadData();
  }
}

// Zahlungs-Dialog
class _ZahlungDialog extends StatefulWidget {
  final String dienstleisterId;
  final DienstleisterZahlung? zahlung;
  final VoidCallback onSave;

  const _ZahlungDialog({
    required this.dienstleisterId,
    this.zahlung,
    required this.onSave,
  });

  @override
  State<_ZahlungDialog> createState() => _ZahlungDialogState();
}

class _ZahlungDialogState extends State<_ZahlungDialog> {
  late TextEditingController _bezeichnungController;
  late TextEditingController _betragController;
  DateTime? _faelligAm;
  bool _bezahlt = false;

  @override
  void initState() {
    super.initState();
    _bezeichnungController = TextEditingController(
      text: widget.zahlung?.bezeichnung ?? '',
    );
    _betragController = TextEditingController(
      text: widget.zahlung?.betrag.betrag.toStringAsFixed(0) ?? '',
    );
    _faelligAm = widget.zahlung?.faelligAm;
    _bezahlt = widget.zahlung?.bezahlt ?? false;
  }

  @override
  void dispose() {
    _bezeichnungController.dispose();
    _betragController.dispose();
    super.dispose();
  }

  String _formatEuro(double betrag) {
    final formatter = NumberFormat('#,##0.00', 'de_DE');
    return formatter.format(betrag).replaceAll(',', '.');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.zahlung != null ? 'Zahlung bearbeiten' : 'Neue Zahlung',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bezeichnungController,
            decoration: const InputDecoration(
              labelText: 'Bezeichnung',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _betragController,
            decoration: const InputDecoration(
              labelText: 'Betrag (€)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Fällig am'),
            subtitle: Text(
              _faelligAm != null
                  ? '${_faelligAm!.day}.${_faelligAm!.month}.${_faelligAm!.year}'
                  : 'Nicht gesetzt',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _faelligAm ?? DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() => _faelligAm = date);
                }
              },
            ),
          ),
          CheckboxListTile(
            title: const Text('Bereits bezahlt'),
            value: _bezahlt,
            onChanged: (value) => setState(() => _bezahlt = value ?? false),
          ),
        ],
      ),
      actions: [
        if (widget.zahlung != null)
          TextButton(
            onPressed: () async {
              await DienstleisterDatabase.instance.deleteZahlung(
                widget.zahlung!.id,
              );
              widget.onSave();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_bezeichnungController.text.isNotEmpty &&
                _betragController.text.isNotEmpty) {
              final zahlung = DienstleisterZahlung(
                id:
                    widget.zahlung?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                dienstleisterId: widget.dienstleisterId,
                bezeichnung: _bezeichnungController.text,
                betrag: Geld(betrag: double.parse(_betragController.text)),
                faelligAm: _faelligAm,
                bezahlt: _bezahlt,
              );

              if (widget.zahlung != null) {
                await DienstleisterDatabase.instance.updateZahlung(zahlung);
              } else {
                await DienstleisterDatabase.instance.createZahlung(zahlung);
              }

              widget.onSave();
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
