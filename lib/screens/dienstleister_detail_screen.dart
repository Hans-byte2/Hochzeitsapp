import 'package:flutter/material.dart';
import '../models/dienstleister_models.dart';
import '../models/wedding_models.dart';
import '../data/database_helper.dart';
import '../data/dienstleister_database.dart';
import '../services/dienstleister_score_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../sync/services/sync_service.dart';

class DienstleisterDetailScreen extends StatefulWidget {
  final String dienstleisterId;

  const DienstleisterDetailScreen({super.key, required this.dienstleisterId});

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
  List<KommunikationsLogEintrag> _kommunikationsLog = [];
  List<AngebotVergleich> _angebote = [];
  DienstleisterScore? _score;
  double _gesamtBudget = 0.0;
  bool _isLoading = true;

  late TabController _tabController;

  void _syncNow() {
    SyncService.instance.syncNow().catchError(
      (e) => debugPrint('Sync-Fehler: $e'),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      final kommunikationsLog = await DatabaseHelper.instance
          .getKommunikationsLogFuer(widget.dienstleisterId);
      final angebote = await DatabaseHelper.instance.getAngeboteVergleichFuer(
        widget.dienstleisterId,
      );
      final gesamtBudget = await DatabaseHelper.instance.getTotalBudget();

      DienstleisterScore? score;
      if (dienstleister != null) {
        score = DienstleisterScoreService.berechne(
          d: dienstleister,
          zahlungen: zahlungen,
          kommunikationsLog: kommunikationsLog,
          gesamtBudget: gesamtBudget,
        );
      }

      setState(() {
        _dienstleister = dienstleister;
        _zahlungen = zahlungen;
        _notizen = notizen;
        _aufgaben = aufgaben;
        _kommunikationsLog = kommunikationsLog;
        _angebote = angebote;
        _score = score;
        _gesamtBudget = gesamtBudget;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fehler beim Laden: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(DienstleisterStatus newStatus) async {
    if (_dienstleister == null) return;
    await DienstleisterDatabase.instance.updateDienstleister(
      _dienstleister!.copyWith(status: newStatus),
    );
    _syncNow();
    _loadData();
  }

  Future<void> _toggleFavorit() async {
    if (_dienstleister == null) return;
    await DienstleisterDatabase.instance.updateDienstleister(
      _dienstleister!.copyWith(istFavorit: !_dienstleister!.istFavorit),
    );
    _syncNow();
    _loadData();
  }

  Future<void> _setBewertung(double bewertung) async {
    if (_dienstleister == null) return;
    await DienstleisterDatabase.instance.updateDienstleister(
      _dienstleister!.copyWith(bewertung: bewertung),
    );
    _syncNow();
    _loadData();
  }

  Future<void> _setVergleichsTag(VergleichsTag? tag) async {
    if (_dienstleister == null) return;
    final updated = tag == null
        ? _dienstleister!.copyWith(clearVergleichsTag: true)
        : _dienstleister!.copyWith(vergleichsTag: tag);
    await DienstleisterDatabase.instance.updateDienstleister(updated);
    _syncNow();
    _loadData();
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String _formatEuro(double betrag) {
    final formatter = NumberFormat('#,##0.00', 'de_DE');
    return formatter.format(betrag).replaceAll(',', '.');
  }

  Future<void> _addToPaymentPlan(DienstleisterZahlung zahlung) async {
    final budgetItems = await DatabaseHelper.instance.getAllBudgetItems();
    final allPlans = await DatabaseHelper.instance.getAllPaymentPlans();
    final alreadyExists = allPlans.any(
      (p) =>
          p.vendorName == _dienstleister!.name &&
          p.amount == zahlung.betrag.betrag &&
          zahlung.faelligAm != null &&
          p.dueDate.day == zahlung.faelligAm!.day &&
          p.dueDate.month == zahlung.faelligAm!.month &&
          p.dueDate.year == zahlung.faelligAm!.year,
    );

    if (alreadyExists && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('„${zahlung.bezeichnung}" ist bereits im Zahlungsplan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int? selectedBudgetItemId;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('In Zahlungsplan übernehmen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dienstleister!.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zahlung.bezeichnung,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          zahlung.faelligAm != null
                              ? '${zahlung.faelligAm!.day}.${zahlung.faelligAm!.month}.${zahlung.faelligAm!.year}'
                              : 'Kein Datum',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        Text(
                          '€${_formatEuro(zahlung.betrag.betrag)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Budget-Posten verknüpfen (optional)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              if (budgetItems.isEmpty)
                Text(
                  'Noch keine Budget-Posten',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                )
              else
                DropdownButtonFormField<int?>(
                  value: selectedBudgetItemId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  hint: const Text('Kein Budget-Posten'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Kein Budget-Posten'),
                    ),
                    ...budgetItems.map(
                      (item) => DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => selectedBudgetItemId = val),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Übernehmen'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    final plan = PaymentPlan(
      vendorName: _dienstleister!.name,
      amount: zahlung.betrag.betrag,
      dueDate:
          zahlung.faelligAm ?? DateTime.now().add(const Duration(days: 30)),
      paymentType: _guessPaymentType(zahlung.bezeichnung),
      paid: zahlung.bezahlt,
      notes: zahlung.bezeichnung,
      budgetItemId: selectedBudgetItemId,
    );
    await DatabaseHelper.instance.insertPaymentPlan(plan);
    if (zahlung.bezahlt && selectedBudgetItemId != null) {
      await DatabaseHelper.instance.recalculateBudgetActual(
        selectedBudgetItemId!,
      );
    }
    _syncNow();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '„${zahlung.bezeichnung}" hinzugefügt${selectedBudgetItemId != null ? ' + Budget verknüpft' : ''}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  PaymentType _guessPaymentType(String bezeichnung) {
    final lower = bezeichnung.toLowerCase();
    if (lower.contains('anzahl') || lower.contains('deposit'))
      return PaymentType.anzahlung;
    if (lower.contains('rest') ||
        lower.contains('schluss') ||
        lower.contains('final'))
      return PaymentType.restzahlung;
    return PaymentType.pauschale;
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(
              _dienstleister!.vergleichsTag?.icon ?? Icons.label_outline,
            ),
            tooltip: 'Vergleichs-Tag',
            onPressed: _showVergleichsTagDialog,
          ),
          IconButton(
            icon: Icon(
              _dienstleister!.istFavorit
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
            onPressed: _toggleFavorit,
          ),
          // Globaler Bearbeiten-Button in AppBar
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Stammdaten bearbeiten',
            onPressed: _showStammdatenDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(scheme),
          Container(
            color: scheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: scheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: scheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info'),
                Tab(
                  icon: Icon(Icons.compare_arrows, size: 18),
                  text: 'Angebote',
                ),
                Tab(
                  icon: Icon(Icons.chat_bubble_outline, size: 18),
                  text: 'Kontakt',
                ),
                Tab(icon: Icon(Icons.payment, size: 18), text: 'Zahlungen'),
                Tab(icon: Icon(Icons.star_outline, size: 18), text: 'Score'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildAngeboteTab(),
                _buildKommunikationTab(),
                _buildZahlungenTab(),
                _buildScoreTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HEADER
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
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
          // Name + Score-Badge + Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _dienstleister!.kategorie.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  _dienstleister!.kategorie.icon,
                  size: 20,
                  color: _dienstleister!.kategorie.color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dienstleister!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _dienstleister!.kategorie.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_score != null) ...[
                GestureDetector(
                  onTap: () => _tabController.animateTo(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _score!.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _score!.color.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 13, color: _score!.color),
                        const SizedBox(width: 3),
                        Text(
                          '${_score!.gesamt}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _score!.color,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _dienstleister!.status.color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _dienstleister!.status.label,
                  style: TextStyle(
                    color: _dienstleister!.status.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          // Status-Timeline
          const SizedBox(height: 10),
          _buildStatusTimeline(),

          // Schnellkontakt-Buttons
          if (_dienstleister!.hauptkontakt.telefon.isNotEmpty ||
              _dienstleister!.hauptkontakt.email.isNotEmpty ||
              _dienstleister!.website != null) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (_dienstleister!.hauptkontakt.telefon.isNotEmpty) ...[
                    _quickBtn(
                      Icons.phone,
                      'Anrufen',
                      Colors.green,
                      () => _launchUrl(
                        'tel:${_dienstleister!.hauptkontakt.telefon}',
                      ),
                    ),
                    const SizedBox(width: 6),
                    _quickBtn(
                      Icons.chat,
                      'WhatsApp',
                      const Color(0xFF25D366),
                      () => _launchUrl(
                        'https://wa.me/${_dienstleister!.hauptkontakt.telefon.replaceAll(RegExp(r'[^0-9]'), '')}',
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_dienstleister!.hauptkontakt.email.isNotEmpty) ...[
                    _quickBtn(
                      Icons.email,
                      'E-Mail',
                      Colors.blue,
                      () => _launchUrl(
                        'mailto:${_dienstleister!.hauptkontakt.email}',
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_dienstleister!.website != null)
                    _quickBtn(
                      Icons.language,
                      'Website',
                      Colors.purple,
                      () => _launchUrl(_dienstleister!.website!),
                    ),
                ],
              ),
            ),
          ],

          // Vergleichs-Tag
          if (_dienstleister!.vergleichsTag != null) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _dienstleister!.vergleichsTag!.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dienstleister!.vergleichsTag!.color.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _dienstleister!.vergleichsTag!.icon,
                    size: 13,
                    color: _dienstleister!.vergleichsTag!.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _dienstleister!.vergleichsTag!.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _dienstleister!.vergleichsTag!.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STATUS TIMELINE
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildStatusTimeline() {
    final statusOrder = DienstleisterStatus.values;
    final currentIndex = statusOrder.indexOf(_dienstleister!.status);

    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: statusOrder.length,
        itemBuilder: (context, index) {
          final status = statusOrder[index];
          final isDone = index < currentIndex;
          final isCurrent = index == currentIndex;
          final isNext = index == currentIndex + 1;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: isNext ? () => _updateStatus(status) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.12)
                        : isCurrent
                        ? status.color.withOpacity(0.18)
                        : isNext
                        ? Colors.grey.shade100
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDone
                          ? Colors.green.withOpacity(0.4)
                          : isCurrent
                          ? status.color
                          : Colors.grey.shade300,
                      width: isCurrent ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_circle
                            : isCurrent
                            ? Icons.radio_button_checked
                            : isNext
                            ? Icons.arrow_circle_right_outlined
                            : Icons.radio_button_unchecked,
                        size: 12,
                        color: isDone
                            ? Colors.green
                            : isCurrent
                            ? status.color
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isDone
                              ? Colors.green.shade700
                              : isCurrent
                              ? status.color
                              : isNext
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (index < statusOrder.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Icon(
                    Icons.chevron_right,
                    size: 12,
                    color: index < currentIndex
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB: INFO
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildInfoTab() {
    final scheme = Theme.of(context).colorScheme;

    Widget editBtn(VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 13, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              'Bearbeiten',
              style: TextStyle(
                fontSize: 11,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kontaktdaten ──────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Kontaktdaten',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      editBtn(_showStammdatenDialog),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_dienstleister!.hauptkontakt.name.isEmpty &&
                      _dienstleister!.hauptkontakt.email.isEmpty &&
                      _dienstleister!.hauptkontakt.telefon.isEmpty &&
                      (_dienstleister!.website == null ||
                          _dienstleister!.website!.isEmpty))
                    GestureDetector(
                      onTap: _showStammdatenDialog,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 16,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Kontaktdaten hinzufügen',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (_dienstleister!.hauptkontakt.name.isNotEmpty)
                      _infoRow(
                        Icons.person,
                        'Ansprechpartner',
                        _dienstleister!.hauptkontakt.name,
                      ),
                    if (_dienstleister!.hauptkontakt.email.isNotEmpty)
                      _infoRow(
                        Icons.email,
                        'E-Mail',
                        _dienstleister!.hauptkontakt.email,
                        onTap: () => _launchUrl(
                          'mailto:${_dienstleister!.hauptkontakt.email}',
                        ),
                      ),
                    if (_dienstleister!.hauptkontakt.telefon.isNotEmpty)
                      _infoRow(
                        Icons.phone,
                        'Telefon',
                        _dienstleister!.hauptkontakt.telefon,
                        onTap: () => _launchUrl(
                          'tel:${_dienstleister!.hauptkontakt.telefon}',
                        ),
                      ),
                    if (_dienstleister!.website != null &&
                        _dienstleister!.website!.isNotEmpty)
                      _infoRow(
                        Icons.language,
                        'Website',
                        _dienstleister!.website!,
                        onTap: () => _launchUrl(_dienstleister!.website!),
                      ),
                    if (_dienstleister!.instagram.isNotEmpty)
                      _infoRow(
                        Icons.camera_alt,
                        'Instagram',
                        _dienstleister!.instagram,
                        onTap: () => _launchUrl(
                          'https://instagram.com/${_dienstleister!.instagram.replaceAll('@', '')}',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Bewertung ─────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 17,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Bewertung',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showBewertungsDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.edit,
                                size: 12,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bewerten',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (index) => GestureDetector(
                          onTap: () => _setBewertung((index + 1).toDouble()),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Icon(
                              index < _dienstleister!.bewertung
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dienstleister!.bewertung > 0
                            ? '${_dienstleister!.bewertung.toStringAsFixed(1)} / 5'
                            : 'Noch keine Bewertung',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _dienstleister!.bewertung > 0
                              ? Colors.amber.shade700
                              : Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Angebot ───────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.euro_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Angebot',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      editBtn(_showStammdatenDialog),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Angebotssumme',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              _dienstleister!.angebotsSumme != null
                                  ? '€${_formatEuro(_dienstleister!.angebotsSumme!.betrag)}'
                                  : 'Kein Angebot',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
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
                                'Option bis',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${_dienstleister!.optionBis!.day}.${_dienstleister!.optionBis!.month}.${_dienstleister!.optionBis!.year}',
                                style: const TextStyle(
                                  fontSize: 15,
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

          // ── Termine & Logistik ────────────────────────────────────────────
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Termine & Logistik',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      editBtn(_showStammdatenDialog),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_dienstleister!.briefingDatum == null &&
                      _dienstleister!.ankunft == null &&
                      _dienstleister!.logistik.adresse.isEmpty)
                    GestureDetector(
                      onTap: _showStammdatenDialog,
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 15,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Termine & Logistik hinzufügen',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    if (_dienstleister!.briefingDatum != null)
                      _infoRow(
                        Icons.event,
                        'Briefing',
                        '${_dienstleister!.briefingDatum!.day}.${_dienstleister!.briefingDatum!.month}.${_dienstleister!.briefingDatum!.year}',
                      ),
                    if (_dienstleister!.ankunft != null)
                      _infoRow(
                        Icons.schedule,
                        'Ankunft',
                        '${_dienstleister!.ankunft!.day}.${_dienstleister!.ankunft!.month}.${_dienstleister!.ankunft!.year}',
                      ),
                    if (_dienstleister!.logistik.adresse.isNotEmpty)
                      _infoRow(
                        Icons.location_on,
                        'Adresse',
                        _dienstleister!.logistik.adresse,
                      ),
                    if (_dienstleister!.logistik.parken.isNotEmpty)
                      _infoRow(
                        Icons.local_parking,
                        'Parken',
                        _dienstleister!.logistik.parken,
                      ),
                    if (_dienstleister!.logistik.strom.isNotEmpty)
                      _infoRow(
                        Icons.power,
                        'Strom',
                        _dienstleister!.logistik.strom,
                      ),
                    if (_dienstleister!.logistik.zugangshinweise.isNotEmpty)
                      _infoRow(
                        Icons.info,
                        'Zugangshinweise',
                        _dienstleister!.logistik.zugangshinweise,
                      ),
                  ],
                ],
              ),
            ),
          ),

          // ── Notizen ───────────────────────────────────────────────────────
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notes_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'Notizen',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      editBtn(_showStammdatenDialog),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_dienstleister!.notizen.isEmpty)
                    GestureDetector(
                      onTap: _showStammdatenDialog,
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 15,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'Notiz hinzufügen',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      _dienstleister!.notizen,
                      style: const TextStyle(fontSize: 13),
                    ),
                ],
              ),
            ),
          ),

          // ── Tags ──────────────────────────────────────────────────────────
          if (_dienstleister!.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.label_outline,
              title: 'Tags',
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _dienstleister!.tags
                    .map(
                      (tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 12)),
                        deleteIcon: const Icon(Icons.close, size: 15),
                        onDeleted: () => _removeTag(tag),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB: ANGEBOTE
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildAngeboteTab() {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hauptangebot',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      _dienstleister!.angebotsSumme != null
                          ? '€${_formatEuro(_dienstleister!.angebotsSumme!.betrag)}'
                          : 'Noch kein Angebot',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_angebote.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_angebote.length} verglichen',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Günstigste: €${_formatEuro(_angebote.map((a) => a.preis).reduce((a, b) => a < b ? a : b))}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _angebote.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.compare_arrows,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Noch keine Vergleichs-Angebote',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Füge Pakete hinzu und vergleiche Preise',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _angebote.length,
                  itemBuilder: (context, index) =>
                      _buildAngebotCard(_angebote[index]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: ElevatedButton.icon(
            onPressed: _showAngebotDialog,
            icon: const Icon(Icons.add),
            label: const Text('Vergleichs-Angebot hinzufügen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAngebotCard(AngebotVergleich angebot) {
    final isGewaehlt = angebot.istGewaehlt;
    final allPreise = _angebote.map((a) => a.preis).toList();
    final minPreis = allPreise.isNotEmpty
        ? allPreise.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final isCheapest = _angebote.length > 1 && angebot.preis == minPreis;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGewaehlt
              ? Colors.green
              : isCheapest
              ? Colors.orange.shade300
              : Colors.grey.shade300,
          width: isGewaehlt ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isGewaehlt) ...[
                  const Icon(Icons.check_circle, color: Colors.green, size: 17),
                  const SizedBox(width: 5),
                ],
                if (isCheapest && !isGewaehlt) ...[
                  Icon(
                    Icons.trending_down,
                    color: Colors.orange.shade600,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                ],
                Expanded(
                  child: Text(
                    angebot.bezeichnung,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isGewaehlt
                          ? Colors.green.shade700
                          : Colors.black87,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '€${_formatEuro(angebot.preis)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isGewaehlt
                            ? Colors.green.shade700
                            : Colors.black87,
                      ),
                    ),
                    if (isCheapest)
                      Text(
                        'Günstigstes',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            if (angebot.leistungen.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enthaltene Leistungen:',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      angebot.leistungen,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            if (angebot.notizen.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                angebot.notizen,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${angebot.erstelltAm.day}.${angebot.erstelltAm.month}.${angebot.erstelltAm.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                const Spacer(),
                if (!isGewaehlt)
                  OutlinedButton.icon(
                    onPressed: () async {
                      await DatabaseHelper.instance.waehleAngebot(
                        _dienstleister!.id,
                        angebot.id,
                      );
                      _loadData();
                    },
                    icon: const Icon(Icons.check, size: 13),
                    label: const Text('Wählen', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 15),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () => _showAngebotDialog(angebot),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 15, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: () async {
                    await DatabaseHelper.instance.deleteAngebotVergleich(
                      angebot.id,
                    );
                    _loadData();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB: KOMMUNIKATION
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildKommunikationTab() {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_kommunikationsLog.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Letzter Kontakt: ${_formatDatumKurz(_kommunikationsLog.first.erstelltAm)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Schnell-Vorlagen:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 5),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      KommunikationsVorlagen.fuerStatus(_dienstleister!.status)
                          .take(4)
                          .map(
                            (vorlage) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ActionChip(
                                label: Text(
                                  vorlage.titel,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                avatar: Icon(
                                  vorlage.typ.icon,
                                  size: 13,
                                  color: Colors.blue.shade700,
                                ),
                                backgroundColor: Colors.white,
                                side: BorderSide(color: Colors.blue.shade200),
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _showLogEintragDialog(vorlage: vorlage),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: (_kommunikationsLog.isEmpty && _notizen.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Noch keine Kommunikation',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    ..._kommunikationsLog.map((e) => _buildLogEintragCard(e)),
                    ..._notizen.map((n) => _buildNotizCard(n)),
                    if (_aufgaben.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Aufgaben',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),
                      ..._aufgaben.map((a) => _buildAufgabeItem(a)),
                    ],
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showLogEintragDialog(),
                  icon: const Icon(Icons.add_comment, size: 14),
                  label: const Text('Log', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showNotizDialog,
                  icon: const Icon(Icons.note_add, size: 14),
                  label: const Text('Notiz', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showAufgabeDialog,
                  icon: const Icon(Icons.task_alt, size: 14),
                  label: const Text('Aufgabe', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogEintragCard(KommunikationsLogEintrag eintrag) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: eintrag.typ.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    eintrag.typ.icon,
                    size: 14,
                    color: eintrag.typ.color,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eintrag.typ.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: eintrag.typ.color,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDatumKurz(eintrag.erstelltAm),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 26,
                    minHeight: 26,
                  ),
                  onPressed: () async {
                    await DatabaseHelper.instance
                        .deleteKommunikationsLogEintrag(eintrag.id);
                    _loadData();
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(eintrag.text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB: ZAHLUNGEN
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildZahlungenTab() {
    final gesamt = _zahlungen.fold<double>(
      0,
      (sum, z) => sum + z.betrag.betrag,
    );
    final bezahlt = _zahlungen
        .where((z) => z.bezahlt)
        .fold<double>(0, (sum, z) => sum + z.betrag.betrag);
    final offen = gesamt - bezahlt;
    final fortschritt = gesamt > 0 ? bezahlt / gesamt : 0.0;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _zahlungsStat('Gesamt', gesamt, Colors.blue),
                  _zahlungsStat('Bezahlt', bezahlt, Colors.green),
                  _zahlungsStat('Offen', offen, Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: fortschritt,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(fortschritt * 100).toStringAsFixed(0)}% bezahlt',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        Expanded(
          child: _zahlungen.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Noch keine Zahlungen',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: _zahlungen.length,
                  itemBuilder: (context, index) =>
                      _buildZahlungsCard(_zahlungen[index]),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: ElevatedButton.icon(
            onPressed: _showZahlungDialog,
            icon: const Icon(Icons.add),
            label: const Text('Zahlung hinzufügen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(double.infinity, 46),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // TAB: SCORE
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildScoreTab() {
    if (_score == null)
      return const Center(child: Text('Score nicht verfügbar'));
    final score = _score!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: score.color.withOpacity(0.15),
                          border: Border.all(color: score.color, width: 3),
                        ),
                        child: Center(
                          child: Text(
                            '${score.gesamt}',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: score.color,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            score.label,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: score.color,
                            ),
                          ),
                          Text(
                            'Dienstleister-Score',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'von 100 Punkten',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _scoreBalken('Status', score.statusScore, 25, Colors.blue),
                  const SizedBox(height: 7),
                  _scoreBalken(
                    'Preis & Budget',
                    score.preisScore,
                    25,
                    Colors.green,
                  ),
                  const SizedBox(height: 7),
                  _scoreBalken(
                    'Aktivität',
                    score.aktivitaetScore,
                    20,
                    Colors.orange,
                  ),
                  const SizedBox(height: 7),
                  _scoreBalken(
                    'Vollständigkeit',
                    score.vollstaendigkeitScore,
                    20,
                    Colors.purple,
                  ),
                  const SizedBox(height: 7),
                  _scoreBalken(
                    'Bewertung',
                    score.bewertungScore,
                    10,
                    Colors.amber,
                  ),
                ],
              ),
            ),
          ),
          if (score.hinweise.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.lightbulb_outline,
              title: 'Handlungsempfehlungen',
              child: Column(
                children: score.hinweise
                    .map(
                      (h) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.fromLTRB(0, 5, 9, 0),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.amber,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                h,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (_dienstleister!.angebotsSumme != null && _gesamtBudget > 0) ...[
            const SizedBox(height: 12),
            _buildCard(
              icon: Icons.pie_chart_outline,
              title: 'Budget-Anteil',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${((_dienstleister!.angebotsSumme!.betrag / _gesamtBudget) * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'vom Gesamtbudget (€${NumberFormat('#,##0', 'de_DE').format(_gesamtBudget)})',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // HILFSWIDGETS
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Icon(icon, size: 17, color: Colors.grey.shade500),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: onTap != null ? scheme.primary : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.open_in_new, size: 14, color: scheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _zahlungsStat(String label, double betrag, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 3),
        Text(
          '€${_formatEuro(betrag)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _scoreBalken(String label, int wert, int max, Color farbe) {
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: max > 0 ? wert / max : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(farbe),
              minHeight: 9,
            ),
          ),
        ),
        const SizedBox(width: 7),
        SizedBox(
          width: 34,
          child: Text(
            '$wert/$max',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildZahlungsCard(DienstleisterZahlung zahlung) {
    final isOverdue =
        zahlung.faelligAm != null &&
        zahlung.faelligAm!.isBefore(DateTime.now()) &&
        !zahlung.bezahlt;
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isOverdue ? Colors.red.shade300 : Colors.transparent,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
        child: Row(
          children: [
            Checkbox(
              value: zahlung.bezahlt,
              onChanged: (value) async {
                await DienstleisterDatabase.instance.updateZahlung(
                  zahlung.copyWith(bezahlt: value ?? false),
                );
                _syncNow();
                _loadData();
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zahlung.bezeichnung,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (zahlung.faelligAm != null)
                    Row(
                      children: [
                        if (isOverdue) ...[
                          Icon(
                            Icons.warning_amber,
                            size: 12,
                            color: Colors.red.shade600,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Text(
                          'Fällig: ${zahlung.faelligAm!.day}.${zahlung.faelligAm!.month}.${zahlung.faelligAm!.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Text(
              '€${_formatEuro(zahlung.betrag.betrag)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: zahlung.bezahlt ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 3),
            Tooltip(
              message: 'In Zahlungsplan',
              child: IconButton(
                onPressed: () => _addToPaymentPlan(zahlung),
                icon: Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.indigo.shade400,
                  size: 19,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotizCard(DienstleisterNotiz notiz) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  _formatDatumKurz(notiz.erstelltAm),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, size: 14),
                  color: Colors.red,
                  onPressed: () async {
                    await DienstleisterDatabase.instance.deleteNotiz(notiz.id);
                    _loadData();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(notiz.text, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAufgabeItem(DienstleisterAufgabe aufgabe) {
    return CheckboxListTile(
      value: aufgabe.erledigt,
      onChanged: (value) async {
        await DienstleisterDatabase.instance.updateAufgabe(
          aufgabe.copyWith(erledigt: value ?? false),
        );
        _loadData();
      },
      title: Text(aufgabe.titel, style: const TextStyle(fontSize: 13)),
      subtitle: aufgabe.faelligAm != null
          ? Text(
              'Fällig: ${aufgabe.faelligAm!.day}.${aufgabe.faelligAm!.month}.${aufgabe.faelligAm!.year}',
              style: const TextStyle(fontSize: 11),
            )
          : null,
      dense: true,
    );
  }

  String _formatDatumKurz(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0)
      return 'Heute ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff == 1) return 'Gestern';
    if (diff < 7) return 'Vor $diff Tagen';
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DIALOGE
  // ════════════════════════════════════════════════════════════════════════════

  /// Vollständiger Bearbeitungs-Dialog für alle Stammdaten
  void _showStammdatenDialog() {
    final d = _dienstleister!;
    final nameCtrl = TextEditingController(text: d.name);
    final kontaktCtrl = TextEditingController(text: d.hauptkontakt.name);
    final emailCtrl = TextEditingController(text: d.hauptkontakt.email);
    final telefonCtrl = TextEditingController(text: d.hauptkontakt.telefon);
    final websiteCtrl = TextEditingController(text: d.website ?? '');
    final instagramCtrl = TextEditingController(text: d.instagram);
    final angebotCtrl = TextEditingController(
      text: d.angebotsSumme?.betrag.toStringAsFixed(0) ?? '',
    );
    final notizenCtrl = TextEditingController(text: d.notizen);
    final adresseCtrl = TextEditingController(text: d.logistik.adresse);
    final parkenCtrl = TextEditingController(text: d.logistik.parken);
    final stromCtrl = TextEditingController(text: d.logistik.strom);
    final zugangsCtrl = TextEditingController(text: d.logistik.zugangshinweise);

    DienstleisterKategorie kategorie = d.kategorie;
    DienstleisterStatus status = d.status;
    DateTime? optionBis = d.optionBis;
    DateTime? briefingDatum = d.briefingDatum;
    DateTime? ankunft = d.ankunft;
    bool istFavorit = d.istFavorit;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final scheme = Theme.of(ctx).colorScheme;

          Widget sectionHeader(String title) => Padding(
            padding: const EdgeInsets.only(top: 18, bottom: 8),
            child: Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
          );

          Widget datePicker(
            String label,
            DateTime? value,
            void Function(DateTime) onPicked,
          ) {
            return InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: ctx,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (date != null) setDialogState(() => onPicked(date));
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value != null
                                ? '${value.day}.${value.month}.${value.year}'
                                : 'Nicht gesetzt',
                            style: TextStyle(
                              fontSize: 13,
                              color: value != null
                                  ? Colors.black87
                                  : Colors.grey.shade400,
                              fontWeight: value != null
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey.shade500,
                    ),
                  ],
                ),
              ),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 560,
              constraints: const BoxConstraints(maxHeight: 720),
              child: Column(
                children: [
                  // ── Dialog-Header ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          d.kategorie.icon,
                          color: scheme.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Dienstleister bearbeiten',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: scheme.onPrimary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // ── Formular ──────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // STAMMDATEN
                          sectionHeader('STAMMDATEN'),
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name *',
                              border: OutlineInputBorder(),
                            ),
                            autofocus: true,
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<DienstleisterKategorie>(
                            value: kategorie,
                            decoration: const InputDecoration(
                              labelText: 'Kategorie',
                              border: OutlineInputBorder(),
                            ),
                            items: DienstleisterKategorie.values
                                .map(
                                  (k) => DropdownMenuItem(
                                    value: k,
                                    child: Row(
                                      children: [
                                        Icon(k.icon, size: 16, color: k.color),
                                        const SizedBox(width: 8),
                                        Text(k.label),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => kategorie = v!),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<DienstleisterStatus>(
                            value: status,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                            ),
                            items: DienstleisterStatus.values
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: s.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(s.label),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setDialogState(() => status = v!),
                          ),
                          const SizedBox(height: 4),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: const Text(
                              'Als Favorit markieren',
                              style: TextStyle(fontSize: 13),
                            ),
                            value: istFavorit,
                            onChanged: (v) =>
                                setDialogState(() => istFavorit = v ?? false),
                          ),

                          // KONTAKT
                          sectionHeader('KONTAKT'),
                          TextField(
                            controller: kontaktCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ansprechpartner',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: emailCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'E-Mail',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: telefonCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Telefon',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: websiteCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Website',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.url,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: instagramCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Instagram',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // ANGEBOT
                          sectionHeader('ANGEBOT'),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: angebotCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Angebotssumme (€)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: datePicker(
                                  'Option gültig bis',
                                  optionBis,
                                  (d) => optionBis = d,
                                ),
                              ),
                            ],
                          ),

                          // TERMINE
                          sectionHeader('TERMINE'),
                          Row(
                            children: [
                              Expanded(
                                child: datePicker(
                                  'Briefing-Datum',
                                  briefingDatum,
                                  (d) => briefingDatum = d,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: datePicker(
                                  'Ankunft',
                                  ankunft,
                                  (d) => ankunft = d,
                                ),
                              ),
                            ],
                          ),

                          // LOGISTIK
                          sectionHeader('LOGISTIK'),
                          TextField(
                            controller: adresseCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Adresse',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: parkenCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Parken',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: stromCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Strom / Technik',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: zugangsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Zugangshinweise',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),

                          // NOTIZEN
                          sectionHeader('NOTIZEN'),
                          TextField(
                            controller: notizenCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Allgemeine Notizen',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Speichern ─────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Abbrechen'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;

                            final updated = d.copyWith(
                              name: nameCtrl.text.trim(),
                              kategorie: kategorie,
                              status: status,
                              istFavorit: istFavorit,
                              hauptkontakt: Kontakt(
                                name: kontaktCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                telefon: telefonCtrl.text.trim(),
                              ),
                              website: websiteCtrl.text.trim().isEmpty
                                  ? null
                                  : websiteCtrl.text.trim(),
                              instagram: instagramCtrl.text.trim(),
                              angebotsSumme: angebotCtrl.text.trim().isNotEmpty
                                  ? Geld(
                                      betrag:
                                          double.tryParse(
                                            angebotCtrl.text.trim(),
                                          ) ??
                                          0,
                                    )
                                  : null,
                              optionBis: optionBis,
                              briefingDatum: briefingDatum,
                              ankunft: ankunft,
                              logistik: Logistik(
                                adresse: adresseCtrl.text.trim(),
                                parken: parkenCtrl.text.trim(),
                                strom: stromCtrl.text.trim(),
                                zugangshinweise: zugangsCtrl.text.trim(),
                                ankunftsfenster: d.logistik.ankunftsfenster,
                              ),
                              notizen: notizenCtrl.text.trim(),
                            );

                            await DienstleisterDatabase.instance
                                .updateDienstleister(updated);
                            _syncNow();
                            if (ctx.mounted) Navigator.pop(ctx);
                            _loadData();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gespeichert ✓'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: const Text('Speichern'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                          ),
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

  void _showBewertungsDialog() {
    double tempBewertung = _dienstleister!.bewertung;
    final kommentarCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Bewertung'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Sterne antippen:', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  5,
                  (index) => GestureDetector(
                    onTap: () => setDialogState(
                      () => tempBewertung = (index + 1).toDouble(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Icon(
                        index < tempBewertung ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 38,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tempBewertung > 0
                    ? '${tempBewertung.toInt()} von 5 Sternen'
                    : 'Noch keine Bewertung',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: kommentarCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kommentar (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'z.B. sehr professionell, pünktlich...',
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await _setBewertung(tempBewertung);
                if (kommentarCtrl.text.isNotEmpty) {
                  await DatabaseHelper.instance.createKommunikationsLogEintrag(
                    KommunikationsLogEintrag(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      dienstleisterId: widget.dienstleisterId,
                      erstelltAm: DateTime.now(),
                      typ: KommunikationsTyp.notiz,
                      text:
                          '⭐ Bewertung: ${tempBewertung.toInt()}/5 – ${kommentarCtrl.text}',
                    ),
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.save, size: 15),
              label: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showVergleichsTagDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vergleichs-Tag setzen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...VergleichsTag.values.map(
              (tag) => ListTile(
                leading: Icon(tag.icon, color: tag.color),
                title: Text(tag.label),
                selected: _dienstleister!.vergleichsTag == tag,
                selectedColor: tag.color,
                onTap: () {
                  Navigator.pop(ctx);
                  _setVergleichsTag(tag);
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.label_off_outlined, color: Colors.grey),
              title: const Text('Kein Tag'),
              onTap: () {
                Navigator.pop(ctx);
                _setVergleichsTag(null);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogEintragDialog({KommunikationsVorlage? vorlage}) {
    final controller = TextEditingController(text: vorlage?.text ?? '');
    KommunikationsTyp selectedTyp = vorlage?.typ ?? KommunikationsTyp.notiz;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kommunikation dokumentieren'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<KommunikationsTyp>(
                value: selectedTyp,
                decoration: const InputDecoration(
                  labelText: 'Typ',
                  border: OutlineInputBorder(),
                ),
                items: KommunikationsTyp.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Row(
                          children: [
                            Icon(t.icon, size: 15, color: t.color),
                            const SizedBox(width: 7),
                            Text(t.label),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedTyp = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Inhalt',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await DatabaseHelper.instance.createKommunikationsLogEintrag(
                    KommunikationsLogEintrag(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      dienstleisterId: widget.dienstleisterId,
                      erstelltAm: DateTime.now(),
                      typ: selectedTyp,
                      text: controller.text,
                      vorlageKey: vorlage?.key,
                    ),
                  );
                  _loadData();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAngebotDialog([AngebotVergleich? angebot]) {
    final bezeichnungCtrl = TextEditingController(
      text: angebot?.bezeichnung ?? '',
    );
    final preisCtrl = TextEditingController(
      text: angebot?.preis.toStringAsFixed(0) ?? '',
    );
    final leistungenCtrl = TextEditingController(
      text: angebot?.leistungen ?? '',
    );
    final notizenCtrl = TextEditingController(text: angebot?.notizen ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          angebot != null ? 'Angebot bearbeiten' : 'Neues Vergleichs-Angebot',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: bezeichnungCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bezeichnung *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 11),
              TextField(
                controller: preisCtrl,
                decoration: const InputDecoration(
                  labelText: 'Preis (€) *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 11),
              TextField(
                controller: leistungenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Enthaltene Leistungen',
                  border: OutlineInputBorder(),
                  hintText: 'z.B. 8h Shooting, 200 Fotos...',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 11),
              TextField(
                controller: notizenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notizen',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          if (angebot != null)
            TextButton(
              onPressed: () async {
                await DatabaseHelper.instance.deleteAngebotVergleich(
                  angebot.id,
                );
                _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Löschen', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (bezeichnungCtrl.text.isNotEmpty &&
                  preisCtrl.text.isNotEmpty) {
                final neu = AngebotVergleich(
                  id:
                      angebot?.id ??
                      DateTime.now().millisecondsSinceEpoch.toString(),
                  dienstleisterId: widget.dienstleisterId,
                  bezeichnung: bezeichnungCtrl.text,
                  preis: double.tryParse(preisCtrl.text) ?? 0.0,
                  leistungen: leistungenCtrl.text,
                  notizen: notizenCtrl.text,
                  erstelltAm: angebot?.erstelltAm ?? DateTime.now(),
                  istGewaehlt: angebot?.istGewaehlt ?? false,
                );
                if (angebot != null) {
                  await DatabaseHelper.instance.updateAngebotVergleich(neu);
                } else {
                  await DatabaseHelper.instance.createAngebotVergleich(neu);
                }
                _loadData();
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showZahlungDialog([DienstleisterZahlung? zahlung]) {
    showDialog(
      context: context,
      builder: (context) => _ZahlungDialog(
        dienstleisterId: widget.dienstleisterId,
        zahlung: zahlung,
        onSave: () {
          _syncNow();
          _loadData();
        },
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
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await DienstleisterDatabase.instance.createNotiz(
                  DienstleisterNotiz(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    dienstleisterId: widget.dienstleisterId,
                    erstelltAm: DateTime.now(),
                    text: controller.text,
                  ),
                );
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
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
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
                    if (date != null) setState(() => faelligAm = date);
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
                  await DienstleisterDatabase.instance.createAufgabe(
                    DienstleisterAufgabe(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      dienstleisterId: widget.dienstleisterId,
                      titel: controller.text,
                      faelligAm: faelligAm,
                    ),
                  );
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

  Future<void> _removeTag(String tag) async {
    final tags = List<String>.from(_dienstleister!.tags);
    tags.remove(tag);
    await DienstleisterDatabase.instance.updateDienstleister(
      _dienstleister!.copyWith(tags: tags),
    );
    _syncNow();
    _loadData();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ZAHLUNGS-DIALOG
// ════════════════════════════════════════════════════════════════════════════

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            autofocus: true,
          ),
          const SizedBox(height: 13),
          TextField(
            controller: _betragController,
            decoration: const InputDecoration(
              labelText: 'Betrag (€)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 13),
          ListTile(
            contentPadding: EdgeInsets.zero,
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
                if (date != null) setState(() => _faelligAm = date);
              },
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bereits bezahlt'),
            value: _bezahlt,
            onChanged: (v) => setState(() => _bezahlt = v ?? false),
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
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
          ),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
