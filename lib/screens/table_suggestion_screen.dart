// lib/screens/table_suggestion_screen.dart

import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../app_colors.dart';
import '../services/table_suggestion_service.dart';
import '../services/guest_scoring_service.dart';

class TableSuggestionScreen extends StatefulWidget {
  final List<Guest> guests;
  final List<TableModel> tables;
  final Future<void> Function(Map<int, int>) onApplySuggestion;

  const TableSuggestionScreen({
    super.key,
    required this.guests,
    required this.tables,
    required this.onApplySuggestion,
  });

  @override
  State<TableSuggestionScreen> createState() => _TableSuggestionScreenState();
}

class _TableSuggestionScreenState extends State<TableSuggestionScreen> {
  TableSuggestionResult? _result;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didUpdateWidget(TableSuggestionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guests.length != widget.guests.length ||
        oldWidget.tables.length != widget.tables.length) {
      _calculate();
    }
  }

  void _calculate() {
    setState(() => _isCalculating = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      final result = TableSuggestionService.suggest(
        allGuests: widget.guests,
        tables: widget.tables,
      );
      if (mounted) {
        setState(() {
          _result = result;
          _isCalculating = false;
        });
      }
    });
  }

  // ── Vorschlag übernehmen ──────────────────────────────────────
  void _applyAndClose() {
    if (_result == null) return;

    final Map<int, int> assignments = {};
    for (final assignment in _result!.assignments) {
      for (final guest in assignment.guests) {
        if (guest.id != null) {
          assignments[guest.id!] = assignment.table.tableNumber;
        }
      }
    }

    final hasConflicts = _result!.hasConflicts;

    // dialogContext verwenden damit nur der Dialog per pop geschlossen wird,
    // nicht der gesamte Screen
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          hasConflicts
              ? '⚠️ Vorschlag mit Konflikten'
              : 'Vorschlag übernehmen?',
        ),
        content: Text(
          hasConflicts
              ? 'Der Vorschlag enthält noch Konflikte. Das passiert wenn zu wenig Tische vorhanden sind um alle Konfliktpaare zu trennen.\n\nTrotzdem übernehmen?'
              : 'Die aktuelle Tischzuweisung wird überschrieben.\n'
                    '${_result!.assignments.fold(0, (s, a) => s + a.guests.length)} Gäste werden zugewiesen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext), // nur Dialog
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // nur Dialog schließen
              await widget.onApplySuggestion(assignments);
              if (!mounted) return;
              _calculate(); // Vorschau neu berechnen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Übernommen! Vorschau aktualisiert.'),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Zurück',
                    textColor: Colors.white,
                    onPressed: () => Navigator.pop(context), // Screen schließen
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasConflicts ? Colors.orange : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(hasConflicts ? 'Trotzdem übernehmen' : 'Übernehmen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tischvorschlag'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Neu berechnen',
            onPressed: _isCalculating ? null : _calculate,
          ),
        ],
      ),
      body: _isCalculating
          ? _buildLoading()
          : _result == null
          ? _buildEmpty()
          : _buildResult(),
      bottomNavigationBar: _result != null && !_isCalculating
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Berechne optimale Sitzordnung...'),
          const SizedBox(height: 8),
          Text(
            'Konflikte werden als harte Bedingung berücksichtigt',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_restaurant, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Keine Tische oder Gäste vorhanden'),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(r),
          const SizedBox(height: 16),

          if (r.hasConflicts) ...[
            _buildConflictBanner(r),
            const SizedBox(height: 16),
          ],

          if (r.hasUnassigned) ...[
            _buildUnassignedCard(r),
            const SizedBox(height: 16),
          ],

          const Text(
            'Tischzuweisung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...r.assignments.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildTableCard(a),
            ),
          ),

          // Platz für Bottom-Bar
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(TableSuggestionResult r) {
    final totalSeated = r.assignments.fold(0, (s, a) => s + a.guests.length);
    final scoreColor = r.overallScore >= 20
        ? Colors.green
        : r.overallScore >= 0
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Vorschlag-Übersicht',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                  '$totalSeated',
                  'Platziert',
                  Colors.green,
                  Icons.check_circle,
                ),
                _summaryItem(
                  '${r.unassignedGuests.length}',
                  'Unplatziert',
                  r.hasUnassigned ? Colors.orange : Colors.grey,
                  Icons.warning,
                ),
                _summaryItem(
                  '${r.totalConflicts}',
                  'Konflikte',
                  r.hasConflicts ? Colors.red : Colors.grey,
                  Icons.block,
                ),
                _summaryItem(
                  r.overallScore.toStringAsFixed(0),
                  'Ø Score',
                  scoreColor,
                  Icons.star,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ((r.overallScore + 20) / 70).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.hasConflicts
                  ? '⚠️ Konflikte konnten nicht vollständig getrennt werden'
                  : r.overallScore >= 20
                  ? '✅ Sehr gute Sitzordnung – keine Konflikte'
                  : r.overallScore >= 0
                  ? '👍 Akzeptable Sitzordnung – keine Konflikte'
                  : '✅ Keine Konflikte',
              style: TextStyle(fontSize: 12, color: scoreColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildConflictBanner(TableSuggestionResult r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 18),
              SizedBox(width: 8),
              Text(
                'Nicht trennbare Konflikte',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Zu wenig Tische oder Kapazität um alle Konfliktpaare zu trennen. '
            'Füge einen weiteren Tisch hinzu.',
            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
          ),
          const SizedBox(height: 8),
          ...r.globalConflicts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(Icons.close, size: 12, color: Colors.red),
                  const SizedBox(width: 6),
                  Text(c.message, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnassignedCard(TableSuggestionResult r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_off, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                '${r.unassignedGuests.length} Gast/Gäste nicht platzierbar',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Kein passender Tisch gefunden (voll oder Konflikt). Tischkapazität erhöhen.',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: r.unassignedGuests
                .map(
                  (g) => Chip(
                    label: Text(
                      '${g.firstName} ${g.lastName}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.orange.shade100,
                    side: BorderSide.none,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(TableAssignment a) {
    final hasConflict = a.hasConflicts;
    final borderColor = hasConflict
        ? Colors.red
        : a.compatibilityScore >= 20
        ? Colors.green.shade300
        : Colors.grey.shade300;

    final scoreColor = a.compatibilityScore >= 20
        ? Colors.green
        : a.compatibilityScore >= 0
        ? Colors.orange
        : Colors.red;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: hasConflict ? 2 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.table_restaurant,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.table.tableName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${a.totalPersons} / ${a.table.seats} Plätze'
                        '${a.isOverCapacity ? ' ⚠️ Überlastet' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: a.isOverCapacity ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scoreColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: scoreColor),
                      const SizedBox(width: 4),
                      Text(
                        a.scoreLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: scoreColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (hasConflict) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        a.conflicts.map((c) => c.message).join(' · '),
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (a.guests.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Kein Gast zugewiesen',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: a.guests.map((g) => _buildGuestChip(g, a)).toList(),
              ),
            ],

            if (a.guests.length >= 2) ...[
              const SizedBox(height: 8),
              _buildCompatBar(a.compatibilityScore, scoreColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGuestChip(Guest guest, TableAssignment a) {
    final inConflict = a.conflicts.any(
      (c) => c.guestA.id == guest.id || c.guestB.id == guest.id,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: inConflict
            ? Colors.red.shade50
            : AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: inConflict
              ? Colors.red.shade300
              : AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (guest.isVip) ...[
            const Icon(Icons.star, size: 11, color: Colors.amber),
            const SizedBox(width: 3),
          ],
          if (inConflict) ...[
            const Icon(Icons.warning, size: 11, color: Colors.red),
            const SizedBox(width: 3),
          ],
          Text(
            '${guest.firstName} ${guest.lastName}'.trim(),
            style: TextStyle(
              fontSize: 12,
              color: inConflict ? Colors.red.shade700 : AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if ((guest.childrenCount) > 0) ...[
            const SizedBox(width: 4),
            Text(
              '+${guest.childrenCount}👶',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompatBar(double score, Color color) {
    return Row(
      children: [
        Text(
          'Ø Kompatibilität: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ((score + 20) / 70).clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          score.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final r = _result!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          // Immer anklickbar — Konflikte werden im Dialog erklärt
          onPressed: _applyAndClose,
          icon: Icon(r.hasConflicts ? Icons.warning : Icons.check),
          label: Text(
            r.hasConflicts
                ? 'Übernehmen (Konflikte vorhanden)'
                : 'Vorschlag übernehmen',
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: r.hasConflicts ? Colors.orange : AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
