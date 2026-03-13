import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';
import '../services/budget_report_pdf_service.dart';
import '../models/wedding_models.dart';

// ============================================================================
// ZAHLUNGSPLAN SCREEN
// Zeitstrahl-Ansicht nach Monaten gruppiert
// ============================================================================

class PaymentPlanScreen extends StatefulWidget {
  const PaymentPlanScreen({super.key});

  @override
  State<PaymentPlanScreen> createState() => _PaymentPlanScreenState();
}

class _PaymentPlanScreenState extends State<PaymentPlanScreen> {
  List<PaymentPlan> _plans = [];
  bool _isLoading = true;

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');
  final _monthFormat = DateFormat('MMMM yyyy', 'de_DE');
  final _dayFormat = DateFormat('dd.MM.yyyy', 'de_DE');

  String _fmt(double v) => _currencyFormat.format(v);

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    setState(() => _isLoading = true);
    final plans = await DatabaseHelper.instance.getAllPaymentPlans();
    if (mounted)
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
  }

  // ── Berechnungen ──────────────────────────────────────────────────────────

  double get _totalAmount => _plans.fold(0.0, (s, p) => s + p.amount);
  double get _totalPaid =>
      _plans.where((p) => p.paid).fold(0.0, (s, p) => s + p.amount);
  double get _totalOpen =>
      _plans.where((p) => !p.paid).fold(0.0, (s, p) => s + p.amount);
  int get _overdueCount => _plans.where((p) => p.isOverdue).length;
  int get _dueSoonCount => _plans.where((p) => p.isDueSoon).length;

  // Pläne nach Monat gruppieren
  Map<String, List<PaymentPlan>> get _groupedByMonth {
    final Map<String, List<PaymentPlan>> result = {};
    final sorted = [..._plans]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    for (final plan in sorted) {
      final key = _monthFormat.format(plan.dueDate);
      result.putIfAbsent(key, () => []).add(plan);
    }
    return result;
  }

  // ── Dialog: Neuer / Bearbeiteter Eintrag ─────────────────────────────────

  Future<void> _showAddEditDialog([PaymentPlan? existing]) async {
    final vendorCtrl = TextEditingController(text: existing?.vendorName ?? '');
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime selectedDate =
        existing?.dueDate ?? DateTime.now().add(const Duration(days: 30));
    PaymentType selectedType = existing?.paymentType ?? PaymentType.pauschale;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    existing == null ? 'Neue Zahlung' : 'Zahlung bearbeiten',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Dienstleister
                  TextField(
                    controller: vendorCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Dienstleister *',
                      hintText: 'z.B. Fotografie Schmidt',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Betrag
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Betrag (€) *',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Typ
                  const Text(
                    'Zahlungstyp',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: PaymentType.values.map((type) {
                      final isSelected = selectedType == type;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedType = type),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(
                              right: type != PaymentType.values.last ? 6 : 0,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _typeLabel(type),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Fälligkeitsdatum
                  const Text(
                    'Fälligkeitsdatum',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('de'),
                      );
                      if (picked != null)
                        setModalState(() => selectedDate = picked);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _dayFormat.format(selectedDate),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notiz
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notiz / Referenz',
                      hintText: 'z.B. Rechnungsnr. 2024-042',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Speichern
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final vendor = vendorCtrl.text.trim();
                        final amount = double.tryParse(
                          amountCtrl.text.replaceAll(',', '.'),
                        );
                        if (vendor.isEmpty || amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bitte Dienstleister und Betrag angeben',
                              ),
                            ),
                          );
                          return;
                        }
                        final plan = PaymentPlan(
                          id: existing?.id,
                          vendorName: vendor,
                          amount: amount,
                          dueDate: selectedDate,
                          paymentType: selectedType,
                          paid: existing?.paid ?? false,
                          notes: notesCtrl.text.trim(),
                        );
                        if (existing == null) {
                          await DatabaseHelper.instance.insertPaymentPlan(plan);
                        } else {
                          await DatabaseHelper.instance.updatePaymentPlan(plan);
                        }
                        if (mounted) {
                          Navigator.pop(ctx);
                          _loadPlans();
                        }
                      },
                      child: Text(
                        existing == null ? 'Hinzufügen' : 'Speichern',
                      ),
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

  String _typeLabel(PaymentType type) {
    switch (type) {
      case PaymentType.anzahlung:
        return 'Anzahlung';
      case PaymentType.restzahlung:
        return 'Restzahlung';
      case PaymentType.pauschale:
        return 'Pauschale';
    }
  }

  Color _typeColor(PaymentType type) {
    switch (type) {
      case PaymentType.anzahlung:
        return Colors.blue;
      case PaymentType.restzahlung:
        return Colors.purple;
      case PaymentType.pauschale:
        return Colors.teal;
    }
  }

  // ── Löschen ───────────────────────────────────────────────────────────────

  Future<void> _deletePlan(PaymentPlan plan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen'),
        content: Text('„${plan.vendorName}" wirklich entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deletePaymentPlan(plan.id!);
      _loadPlans();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zahlungsplan'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportReport,
            tooltip: 'Als PDF exportieren',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddEditDialog,
            tooltip: 'Zahlung hinzufügen',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plans.isEmpty
          ? _buildEmpty()
          : _buildContent(scheme),
      floatingActionButton: _plans.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showAddEditDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _exportReport() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final budgetItems = await DatabaseHelper.instance.getAllBudgetItems();
      final totalBudget = await DatabaseHelper.instance.getTotalBudget();
      final adultPrice =
          await DatabaseHelper.instance.getSetting('adult_menu_price') ?? '65';
      final childPrice =
          await DatabaseHelper.instance.getSetting('child_menu_price') ?? '28';
      final guests = await DatabaseHelper.instance.getAllGuests();
      final guestCount = guests.length;
      final childCount = guests.fold(0, (s, g) => s + g.childrenCount);
      if (!mounted) return;
      await BudgetReportPdfService.exportBudgetReport(
        budgetItems: budgetItems,
        paymentPlans: _plans,
        totalBudget: totalBudget,
        guestCount: guestCount,
        childCount: childCount,
        adultMenuPrice: double.tryParse(adultPrice) ?? 65.0,
        childMenuPrice: double.tryParse(childPrice) ?? 28.0,
        categoryLabels: const {
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
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.payment_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'Noch kein Zahlungsplan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Füge Zahlungen für deine Dienstleister hinzu.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _showAddEditDialog,
            icon: const Icon(Icons.add),
            label: const Text('Erste Zahlung hinzufügen'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ColorScheme scheme) {
    final grouped = _groupedByMonth;

    return CustomScrollView(
      slivers: [
        // ── Zusammenfassung ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                // Warnungen
                if (_overdueCount > 0)
                  _warningBanner(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                    text:
                        '$_overdueCount ${_overdueCount == 1 ? 'Zahlung ist' : 'Zahlungen sind'} überfällig!',
                  ),
                if (_dueSoonCount > 0)
                  _warningBanner(
                    icon: Icons.schedule_rounded,
                    color: Colors.orange,
                    text:
                        '$_dueSoonCount ${_dueSoonCount == 1 ? 'Zahlung fällig' : 'Zahlungen fällig'} in den nächsten 14 Tagen',
                  ),
                if (_overdueCount > 0 || _dueSoonCount > 0)
                  const SizedBox(height: 8),

                // Übersichts-Cards
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Gesamt',
                        _totalAmount,
                        Colors.grey.shade700,
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'Bezahlt',
                        _totalPaid,
                        Colors.green,
                        Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _summaryCard(
                        'Offen',
                        _totalOpen,
                        _totalOpen > 0 ? Colors.orange : Colors.green,
                        Icons.pending_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Zeitstrahl ────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate((context, sectionIndex) {
            final month = grouped.keys.elementAt(sectionIndex);
            final monthPlans = grouped[month]!;
            final monthTotal = monthPlans.fold(0.0, (s, p) => s + p.amount);
            final monthPaid = monthPlans
                .where((p) => p.paid)
                .fold(0.0, (s, p) => s + p.amount);
            final allPaid = monthPlans.every((p) => p.paid);
            final hasOverdue = monthPlans.any((p) => p.isOverdue);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Monats-Header
                  Row(
                    children: [
                      // Zeitstrahl-Linie + Kreis
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasOverdue
                                  ? Colors.red
                                  : allPaid
                                  ? Colors.green
                                  : scheme.primary,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (hasOverdue ? Colors.red : scheme.primary)
                                          .withOpacity(0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              month,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: hasOverdue
                                    ? Colors.red.shade700
                                    : Colors.black87,
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '€${_fmt(monthTotal)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (monthPaid > 0 && monthPaid < monthTotal)
                                  Text(
                                    '${_fmt(monthPaid)} € bezahlt',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Zeitstrahl-Verbindungslinie + Karten
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vertikale Linie
                      if (sectionIndex < grouped.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade200,
                            height: monthPlans.length * 88.0 + 8,
                          ),
                        )
                      else
                        const SizedBox(width: 8),
                      const SizedBox(width: 18),

                      // Zahlungs-Karten
                      Expanded(
                        child: Column(
                          children: monthPlans
                              .map((plan) => _planCard(plan))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            );
          }, childCount: grouped.length),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  Widget _warningBanner({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, double amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
          Text(
            '€${_fmt(amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard(PaymentPlan plan) {
    final isOverdue = plan.isOverdue;
    final isDueSoon = plan.isDueSoon;
    final typeColor = _typeColor(plan.paymentType);

    Color borderColor = Colors.grey.shade200;
    Color bgColor = Colors.white;
    if (plan.paid) {
      borderColor = Colors.green.shade200;
      bgColor = Colors.green.shade50;
    } else if (isOverdue) {
      borderColor = Colors.red.shade300;
      bgColor = Colors.red.shade50;
    } else if (isDueSoon) {
      borderColor = Colors.orange.shade300;
      bgColor = Colors.orange.shade50;
    }

    return Dismissible(
      key: Key('plan_${plan.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: Colors.red.shade700),
      ),
      confirmDismiss: (_) async {
        await _deletePlan(plan);
        return false; // wir machen das manuell
      },
      child: GestureDetector(
        onTap: () => _showAddEditDialog(plan),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Bezahlt-Toggle
              GestureDetector(
                onTap: () async {
                  await DatabaseHelper.instance.togglePaymentPlanPaid(
                    plan.id!,
                    !plan.paid,
                  );
                  _loadPlans();
                },
                child: Icon(
                  plan.paid ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: plan.paid ? Colors.green : Colors.grey.shade400,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),

              // Inhalt
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.vendorName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              decoration: plan.paid
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: plan.paid ? Colors.grey : Colors.black87,
                            ),
                          ),
                        ),
                        // Typ-Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            plan.paymentTypeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: isOverdue
                              ? Colors.red.shade600
                              : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _dayFormat.format(plan.dueDate),
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdue
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                            fontWeight: isOverdue
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (isOverdue) ...[
                          const SizedBox(width: 6),
                          Text(
                            'ÜBERFÄLLIG',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else if (isDueSoon) ...[
                          const SizedBox(width: 6),
                          Text(
                            'in ${plan.dueDate.difference(DateTime.now()).inDays} Tagen',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        if (plan.notes.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.notes,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Betrag
              Text(
                '€${_fmt(plan.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: plan.paid
                      ? Colors.green.shade700
                      : isOverdue
                      ? Colors.red.shade700
                      : Colors.black87,
                  decoration: plan.paid ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
