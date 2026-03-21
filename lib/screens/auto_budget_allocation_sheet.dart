import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/database_helper.dart';

// ============================================================================
// AUTO BUDGET AUFTEILUNG
// Schlägt prozentuale Aufteilung des Gesamtbudgets auf Kategorien vor.
// Wird als Bottom Sheet geöffnet wenn totalBudget > 0 aber noch keine Items.
// ============================================================================

const _kBudgetPresets = [
  _CategoryPreset(
    'location',
    'Location & Catering',
    32.0,
    Icons.location_on_outlined,
  ),
  _CategoryPreset('catering', 'Verpflegung', 8.0, Icons.restaurant_outlined),
  _CategoryPreset(
    'photography',
    'Fotografie & Video',
    10.0,
    Icons.camera_alt_outlined,
  ),
  _CategoryPreset(
    'clothing',
    'Kleidung & Styling',
    9.0,
    Icons.checkroom_outlined,
  ),
  _CategoryPreset(
    'decoration',
    'Dekoration & Blumen',
    7.0,
    Icons.local_florist_outlined,
  ),
  _CategoryPreset('flowers', 'Blumen & Floristik', 4.0, Icons.spa_outlined),
  _CategoryPreset(
    'music',
    'Musik & Unterhaltung',
    6.0,
    Icons.music_note_outlined,
  ),
  _CategoryPreset('rings', 'Ringe & Schmuck', 7.0, Icons.diamond_outlined),
  _CategoryPreset('transport', 'Transport', 3.0, Icons.directions_car_outlined),
  _CategoryPreset('other', 'Sonstiges (Puffer)', 4.0, Icons.more_horiz),
];

class _CategoryPreset {
  final String key;
  final String label;
  final double defaultPct;
  final IconData icon;
  const _CategoryPreset(this.key, this.label, this.defaultPct, this.icon);
}

// ── Widget ────────────────────────────────────────────────────────────────────

class AutoBudgetAllocationSheet extends StatefulWidget {
  final double totalBudget;
  final VoidCallback onApplied;

  const AutoBudgetAllocationSheet({
    super.key,
    required this.totalBudget,
    required this.onApplied,
  });

  @override
  State<AutoBudgetAllocationSheet> createState() =>
      _AutoBudgetAllocationSheetState();
}

class _AutoBudgetAllocationSheetState extends State<AutoBudgetAllocationSheet> {
  late List<double> _percentages;

  /// Ein Controller pro Zeile – wird einmal erstellt und danach nur noch
  /// per [_syncControllers] aktualisiert, damit der Cursor stabil bleibt.
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  bool _isSaving = false;

  final _currencyFormat = NumberFormat('#,##0', 'de_DE');
  String _fmt(double v) => _currencyFormat.format(v);

  @override
  void initState() {
    super.initState();
    _percentages = _kBudgetPresets.map((p) => p.defaultPct).toList();
    _controllers = List.generate(
      _kBudgetPresets.length,
      (i) => TextEditingController(text: _percentages[i].toStringAsFixed(1)),
    );
    _focusNodes = List.generate(_kBudgetPresets.length, (_) => FocusNode());

    // Wenn ein Feld den Fokus verliert → Wert bereinigen & Controller syncen
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (!_focusNodes[i].hasFocus) {
          _commitTextField(i);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  /// Parst den Rohtext des TextField[i] und schreibt einen validen Wert
  /// zurück, ohne den Controller neu zu erstellen.
  void _commitTextField(int i) {
    final parsed = double.tryParse(_controllers[i].text.replaceAll(',', '.'));
    final clamped = (parsed != null && parsed >= 0 && parsed <= 100)
        ? parsed
        : _percentages[i];
    setState(() => _percentages[i] = clamped);
    // Text auf 1 Nachkommastelle normalisieren, Cursor ans Ende
    _controllers[i].value = TextEditingValue(
      text: clamped.toStringAsFixed(1),
      selection: TextSelection.collapsed(
        offset: clamped.toStringAsFixed(1).length,
      ),
    );
  }

  /// Synchronisiert alle Controller auf den aktuellen [_percentages]-Stand,
  /// OHNE die Controller zu ersetzen (Cursor bleibt stabil).
  void _syncControllers() {
    for (int i = 0; i < _percentages.length; i++) {
      // Nur updaten wenn das Feld gerade keinen Fokus hat
      if (!_focusNodes[i].hasFocus) {
        final text = _percentages[i].toStringAsFixed(1);
        if (_controllers[i].text != text) {
          _controllers[i].value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
      }
    }
  }

  double get _totalPct => _percentages.fold(0.0, (s, v) => s + v);
  bool get _isValid => (_totalPct - 100.0).abs() < 0.5;

  double _amountFor(int index) =>
      widget.totalBudget * (_percentages[index] / 100.0);

  Color _totalColor() {
    final diff = _totalPct - 100.0;
    if (diff.abs() < 0.5) return Colors.green;
    if (diff > 0) return Colors.red;
    return Colors.orange;
  }

  void _resetToDefaults() {
    setState(() {
      for (int i = 0; i < _percentages.length; i++) {
        _percentages[i] = _kBudgetPresets[i].defaultPct;
      }
    });
    _syncControllers();
  }

  Future<void> _applyAllocation() async {
    if (!_isValid) return;
    // Alle offenen Textfelder erst committen
    for (int i = 0; i < _percentages.length; i++) {
      _commitTextField(i);
    }
    if (!_isValid) return;

    setState(() => _isSaving = true);
    try {
      for (int i = 0; i < _kBudgetPresets.length; i++) {
        final preset = _kBudgetPresets[i];
        final amount = _amountFor(i);
        if (amount <= 0) continue;
        await DatabaseHelper.instance.insertBudgetItem(
          _makeBudgetItem(
            name: preset.label,
            planned: amount,
            category: preset.key,
          ),
        );
      }
      if (mounted) {
        Navigator.pop(context);
        widget.onApplied();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Map<String, dynamic> _makeBudgetItem({
    required String name,
    required double planned,
    required String category,
  }) {
    return {
      'name': name,
      'planned': planned,
      'actual': 0.0,
      'category': category,
      'notes': 'Auto-Budget-Aufteilung',
      'paid': 0,
      'updated_at': DateTime.now().toIso8601String(),
      'deleted': 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalPct = _totalPct;
    final diff = totalPct - 100.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.pie_chart_outline_rounded,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Budget aufteilen',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gesamtbudget: ${_fmt(widget.totalBudget)} €',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _resetToDefaults,
                  child: Text(
                    'Zurücksetzen',
                    style: TextStyle(fontSize: 12, color: scheme.primary),
                  ),
                ),
              ],
            ),
          ),

          // ── Summen-Indikator ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _totalColor().withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _totalColor().withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isValid
                        ? '✅ Aufteilung vollständig (100%)'
                        : diff > 0
                        ? '⚠️ ${diff.toStringAsFixed(1)}% zu viel verteilt'
                        : '⚠️ Noch ${(-diff).toStringAsFixed(1)}% zu verteilen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _totalColor(),
                    ),
                  ),
                  Text(
                    '${totalPct.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _totalColor(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Slider-Liste ──────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              itemCount: _kBudgetPresets.length,
              itemBuilder: (context, i) {
                final preset = _kBudgetPresets[i];
                final pct = _percentages[i];
                final amount = _amountFor(i);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(preset.icon, size: 16, color: scheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              preset.label,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // ── Prozent-Eingabe (stabiler Controller) ────────
                          SizedBox(
                            width: 62,
                            child: TextField(
                              controller: _controllers[i],
                              focusNode: _focusNodes[i],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                suffixText: '%',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              onChanged: (v) {
                                // Sofort den internen Wert aktualisieren
                                // (kein Controller-Replace → Cursor bleibt)
                                final parsed = double.tryParse(
                                  v.replaceAll(',', '.'),
                                );
                                if (parsed != null &&
                                    parsed >= 0 &&
                                    parsed <= 100) {
                                  setState(() => _percentages[i] = parsed);
                                }
                              },
                              onEditingComplete: () {
                                _commitTextField(i);
                                FocusScope.of(context).unfocus();
                              },
                            ),
                          ),

                          const SizedBox(width: 8),
                          SizedBox(
                            width: 72,
                            child: Text(
                              '${_fmt(amount)} €',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Slider ────────────────────────────────────────────
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14,
                          ),
                        ),
                        child: Slider(
                          value: pct.clamp(0.0, 60.0),
                          min: 0,
                          max: 60,
                          divisions: 120,
                          onChanged: (v) {
                            setState(() => _percentages[i] = v);
                            // Controller aktualisieren wenn kein Fokus
                            if (!_focusNodes[i].hasFocus) {
                              final text = v.toStringAsFixed(1);
                              _controllers[i].value = TextEditingValue(
                                text: text,
                                selection: TextSelection.collapsed(
                                  offset: text.length,
                                ),
                              );
                            }
                          },
                          activeColor: scheme.primary,
                          inactiveColor: scheme.primary.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Übernehmen-Button ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isValid && !_isSaving ? _applyAllocation : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _isValid
                      ? 'Budgetposten anlegen (${_kBudgetPresets.length} Kategorien)'
                      : 'Bitte genau 100% verteilen',
                  style: const TextStyle(fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _isValid
                      ? scheme.primary
                      : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
