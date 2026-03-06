// lib/screens/table_suggestion_screen.dart

import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../models/table_categories.dart';
import '../app_colors.dart';
import '../services/table_suggestion_service.dart';
import '../services/guest_scoring_service.dart';
import '../services/table_explanation.dart';

class TableSuggestionScreen extends StatefulWidget {
  final List<Guest> guests;
  final List<TableModel> tables;
  final Future<void> Function(Map<int, int>) onApplySuggestion;
  final Future<void> Function(Map<int, int?>) onUndoSuggestion;

  const TableSuggestionScreen({
    super.key,
    required this.guests,
    required this.tables,
    required this.onApplySuggestion,
    required this.onUndoSuggestion,
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

  // ── Übernehmen ────────────────────────────────────────────────

  void _applyAndStay() {
    if (_result == null) return;

    final Map<int, int> assignments = {};
    for (final assignment in _result!.assignments) {
      for (final guest in assignment.guests) {
        if (guest.id != null) {
          assignments[guest.id!] = assignment.table.tableNumber;
        }
      }
    }

    // Snapshot der aktuellen Zuweisung für Undo
    final Map<int, int?> snapshot = {};
    for (final guest in widget.guests) {
      if (guest.id != null) {
        snapshot[guest.id!] = guest.tableNumber;
      }
    }

    final hasConflicts = _result!.hasConflicts;

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
              ? 'Nicht alle Konfliktpaare konnten getrennt werden (zu wenig Tische).\n\nTrotzdem übernehmen?'
              : '${_result!.assignments.fold(0, (s, a) => s + a.guests.length)} Gäste werden zugewiesen. '
                    'Bisherige Zuweisung wird überschrieben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await widget.onApplySuggestion(assignments);
              if (!mounted) return;
              ScaffoldMessenger.of(context).clearSnackBars();
              _calculate();

              // Undo-SnackBar für 10 Sekunden anzeigen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Vorschlag übernommen'),
                  duration: const Duration(seconds: 10),
                  action: SnackBarAction(
                    label: 'Rückgängig',
                    textColor: Colors.white,
                    onPressed: () async {
                      await widget.onUndoSuggestion(snapshot);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).clearSnackBars();
                      _calculate();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Zuweisung zurückgesetzt'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  backgroundColor: hasConflicts ? Colors.orange : Colors.green,
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

  // ── Loading / Empty ───────────────────────────────────────────

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
            'Konflikte und Kategorien werden berücksichtigt',
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

  // ── Hauptinhalt ───────────────────────────────────────────────

  Widget _buildResult() {
    final r = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(r),
          const SizedBox(height: 12),

          if (r.hasConflicts) ...[
            _buildBanner(
              icon: Icons.block,
              color: Colors.red,
              title:
                  '${r.totalConflicts} Konflikt${r.totalConflicts > 1 ? 'e' : ''} nicht trennbar',
              subtitle:
                  'Füge einen weiteren Tisch hinzu um alle Paare zu trennen.',
              items: r.globalConflicts.map((c) => c.message).toList(),
            ),
            const SizedBox(height: 12),
          ],

          if (r.hasCategoryMismatches) ...[
            _buildBanner(
              icon: Icons.category,
              color: Colors.orange,
              title:
                  '${r.categoryMismatches.length} Kategorie-Hinweis${r.categoryMismatches.length > 1 ? 'e' : ''}',
              subtitle:
                  'Diese Gäste passen nicht ideal zu ihrer Tischkategorie '
                  '(kein Konflikt, aber suboptimal).',
              items: r.categoryMismatches.map((m) => m.message).toList(),
            ),
            const SizedBox(height: 12),
          ],

          if (r.hasUnassigned) ...[
            _buildBanner(
              icon: Icons.person_off,
              color: Colors.deepOrange,
              title:
                  '${r.unassignedGuests.length} Gast/Gäste nicht platzierbar',
              subtitle:
                  'Kein passender Tisch gefunden (voll, Konflikt oder Kategorie).',
              items: r.unassignedGuests
                  .map((g) => '${g.firstName} ${g.lastName}')
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],

          const Text(
            'Tischzuweisung',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...r.assignments.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildTableCard(a),
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary Card ──────────────────────────────────────────────

  Widget _buildSummaryCard(TableSuggestionResult r) {
    final totalSeated = r.assignments.fold(0, (s, a) => s + a.guests.length);
    final scoreColor = r.hasConflicts
        ? Colors.red
        : r.overallScore >= 20
        ? Colors.green
        : Colors.orange;

    String statusText;
    if (r.hasConflicts) {
      statusText = '⚠️ Konflikte konnten nicht vollständig getrennt werden';
    } else if (r.hasCategoryMismatches) {
      statusText = '💡 Gut – einige Kategorie-Hinweise vorhanden';
    } else if (r.overallScore >= 20) {
      statusText = '✅ Sehr gute Sitzordnung – keine Konflikte';
    } else {
      statusText = '👍 Akzeptable Sitzordnung – keine Konflikte';
    }

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
                  r.hasUnassigned ? Colors.deepOrange : Colors.grey,
                  Icons.person_off,
                ),
                _summaryItem(
                  '${r.totalConflicts}',
                  'Konflikte',
                  r.hasConflicts ? Colors.red : Colors.grey,
                  Icons.block,
                ),
                _summaryItem(
                  '${r.categoryMismatches.length}',
                  'Kategorie',
                  r.hasCategoryMismatches ? Colors.orange : Colors.grey,
                  Icons.category,
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
            Text(statusText, style: TextStyle(fontSize: 12, color: scoreColor)),
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

  // ── Banner (Konflikte / Kategorie / Unplatziert) ──────────────

  Widget _buildBanner({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Icon(Icons.chevron_right, size: 13, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(item, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tisch-Karte ───────────────────────────────────────────────

  Widget _buildTableCard(TableAssignment a) {
    final hasConflict = a.hasConflicts;
    final cats = a.categories;
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
            // Header
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
                        '${a.isOverCapacity ? ' ⚠️' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: a.isOverCapacity ? Colors.red : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score-Badge
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

                // Warum-Button
                if (a.guests.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _showWarumDialog(context, a),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.help_outline,
                            size: 12,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Warum?',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Kategorie-Chips
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                children: cats
                    .map(
                      (cat) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.25),
                          ),
                        ),
                        child: Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],

            // Konflikt-Hinweis
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

            // Gäste
            if (a.guests.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Kein Gast zugewiesen',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                ),
              )
            else ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: a.guests
                    .map((g) => _buildGuestChip(g, a, cats))
                    .toList(),
              ),
            ],

            // Kompatibilitäts-Balken
            if (a.guests.length >= 2) ...[
              const SizedBox(height: 8),
              _buildCompatBar(a.compatibilityScore, scoreColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGuestChip(
    Guest guest,
    TableAssignment a,
    List<TableCategory> tableCats,
  ) {
    final inConflict = a.conflicts.any(
      (c) => c.guestA.id == guest.id || c.guestB.id == guest.id,
    );

    // Kategorie-Mismatch prüfen (weich)
    final catScore = TableCategories.score(
      guestRelationship: guest.relationshipType,
      tableCategories: tableCats,
    );
    final hasCatMismatch = tableCats.isNotEmpty && catScore < 0;

    final chipColor = inConflict
        ? Colors.red
        : hasCatMismatch
        ? Colors.orange
        : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (guest.isVip) ...[
            const Icon(Icons.star, size: 11, color: Colors.amber),
            const SizedBox(width: 3),
          ],
          if (inConflict) ...[
            const Icon(Icons.block, size: 11, color: Colors.red),
            const SizedBox(width: 3),
          ] else if (hasCatMismatch) ...[
            const Icon(Icons.info_outline, size: 11, color: Colors.orange),
            const SizedBox(width: 3),
          ],
          Text(
            '${guest.firstName} ${guest.lastName}'.trim(),
            style: TextStyle(
              fontSize: 12,
              color: chipColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (guest.relationshipType != null) ...[
            const SizedBox(width: 4),
            Text(
              '· ${guest.relationshipType}',
              style: TextStyle(fontSize: 10, color: chipColor.withOpacity(0.7)),
            ),
          ],
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

  // ── Warum-Dialog ──────────────────────────────────────────────

  void _showWarumDialog(BuildContext context, TableAssignment a) {
    final explanation = TableExplanationService.explain(a);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarumSheet(explanation: explanation),
    );
  }

  // ── Bottom Bar ────────────────────────────────────────────────

  Widget _buildBottomBar() {
    final r = _result!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          onPressed: _applyAndStay,
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

// ═══════════════════════════════════════════════════════════════
// _WarumSheet — Bottom Sheet mit Scoring-Erklärung pro Tisch
// ═══════════════════════════════════════════════════════════════

class _WarumSheet extends StatelessWidget {
  final TableExplanation explanation;
  const _WarumSheet({required this.explanation});

  @override
  Widget build(BuildContext context) {
    final positive = explanation.positiveReasons;
    final negative = explanation.negativeReasons;
    final ts = explanation.totalScore;
    final scoreColor = ts >= 20
        ? Colors.green
        : ts >= 0
        ? Colors.orange
        : Colors.red;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          explanation.tableName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${explanation.guestCount} Gaeste · Score: ${ts.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: scoreColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      ts >= 20
                          ? 'Gut'
                          : ts >= 0
                          ? 'Ok'
                          : 'Schwach',
                      style: TextStyle(
                        fontSize: 12,
                        color: scoreColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(color: Colors.grey.shade200),
            // Gruende
            Expanded(
              child: explanation.reasons.isEmpty
                  ? Center(
                      child: Text(
                        'Keine Gast-Details vorhanden.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (positive.isNotEmpty) ...[
                          _sectionLabel(
                            'Warum gut zusammen',
                            Colors.green.shade700,
                          ),
                          const SizedBox(height: 6),
                          ...positive.map((r) => _reasonTile(r)),
                        ],
                        if (negative.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionLabel('Achtung', Colors.red.shade700),
                          const SizedBox(height: 6),
                          ...negative.map((r) => _reasonTile(r)),
                        ],
                        const SizedBox(height: 16),
                        _scoreLegend(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
    ),
  );

  Widget _reasonTile(ExplanationReason r) {
    final bg = r.isNegative ? Colors.red.shade50 : Colors.green.shade50;
    final borderColor = r.isNegative
        ? Colors.red.shade200
        : Colors.green.shade200;
    final scoreText = r.isNegative
        ? r.score.toStringAsFixed(0)
        : '+${r.score.toStringAsFixed(0)}';
    final scoreColor = r.isNegative
        ? Colors.red.shade700
        : Colors.green.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(r.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  r.detail,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            scoreText,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scoreColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreLegend() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score-Legende',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 6),
        _row('Kategorie-Match', '+25 pro Gast'),
        _row('Kennt sich', '+20 pro Paar'),
        _row('Gleiche Altersgruppe', '+15 pro Gast'),
        _row('Gemeinsame Hobbys', '+10 pro Hobby'),
        _row('Gleiche Gruppe', '+10 pro Gast'),
        _row('Konflikt', '-100 (dominant)'),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        Text(
          value,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    ),
  );
}
