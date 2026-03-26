// lib/widgets/dienstleister_checkliste_widget.dart
//
// Drop-in Widget für die Dienstleister-Detailansicht.
//
// EINBINDEN:
//   DienstleisterChecklisteWidget(
//     dienstleister: _dienstleister,
//     onChanged: () => setState(() {}),
//   )
//
// BADGE in der Listenkarte:
//   ChecklistenFortschrittBadge(
//     dienstleisterId: dienstleister.id,
//     accentColor: dienstleister.kategorie.color,
//   )

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/dienstleister_models.dart';
import '../data/database_helper.dart';

// ============================================================================
// HAUPTWIDGET
// ============================================================================

class DienstleisterChecklisteWidget extends StatefulWidget {
  final Dienstleister dienstleister;
  final VoidCallback? onChanged;

  const DienstleisterChecklisteWidget({
    super.key,
    required this.dienstleister,
    this.onChanged,
  });

  @override
  State<DienstleisterChecklisteWidget> createState() =>
      _DienstleisterChecklisteWidgetState();
}

class _DienstleisterChecklisteWidgetState
    extends State<DienstleisterChecklisteWidget> {
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  List<ChecklistenEintrag> _eintraege = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    setState(() => _isLoading = true);
    final eintraege = await _db.getChecklistenEintraege(
      widget.dienstleister.id,
    );

    if (eintraege.isEmpty) {
      await _vorlagenBefuellen();
      final neu = await _db.getChecklistenEintraege(widget.dienstleister.id);
      if (mounted)
        setState(() {
          _eintraege = neu;
          _isLoading = false;
        });
    } else {
      if (mounted)
        setState(() {
          _eintraege = eintraege;
          _isLoading = false;
        });
    }
  }

  Future<void> _vorlagenBefuellen() async {
    final punkte = ChecklistenVorlagen.fuerKategorie(
      widget.dienstleister.kategorie,
    );
    final eintraege = punkte
        .asMap()
        .entries
        .map(
          (e) => ChecklistenEintrag(
            id: _uuid.v4(),
            dienstleisterId: widget.dienstleister.id,
            text: e.value.text,
            vorlagenKey: e.value.key,
            reihenfolge: e.key,
          ),
        )
        .toList();
    await _db.saveChecklistenEintraege(eintraege);
  }

  Future<void> _toggle(ChecklistenEintrag eintrag) async {
    final neu = !eintrag.erledigt;
    await _db.toggleChecklistenEintrag(eintrag.id, neu);
    setState(() {
      final idx = _eintraege.indexWhere((e) => e.id == eintrag.id);
      if (idx != -1) _eintraege[idx] = eintrag.copyWith(erledigt: neu);
    });
    widget.onChanged?.call();
  }

  Future<void> _hinzufuegen(String text) async {
    if (text.trim().isEmpty) return;
    final neu = ChecklistenEintrag(
      id: _uuid.v4(),
      dienstleisterId: widget.dienstleister.id,
      text: text.trim(),
      reihenfolge: _eintraege.length,
    );
    await _db.saveChecklistenEintrag(neu);
    setState(() => _eintraege.add(neu));
    widget.onChanged?.call();
  }

  Future<void> _loeschen(ChecklistenEintrag eintrag) async {
    await _db.deleteChecklistenEintrag(eintrag.id);
    setState(() => _eintraege.removeWhere((e) => e.id == eintrag.id));
    widget.onChanged?.call();
  }

  Future<void> _zuruecksetzen() async {
    final confirmed = await _showResetDialog();
    if (!confirmed) return;
    await _db.deleteAllChecklistenEintraege(widget.dienstleister.id);
    await _vorlagenBefuellen();
    final neu = await _db.getChecklistenEintraege(widget.dienstleister.id);
    if (mounted) setState(() => _eintraege = neu);
    widget.onChanged?.call();
  }

  void _neuerEintragDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NeuerEintragSheet(
        controller: controller,
        onSave: (text) {
          Navigator.pop(ctx);
          _hinzufuegen(text);
        },
      ),
    );
  }

  Future<bool> _showResetDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Checkliste zurücksetzen?'),
            content: const Text(
              'Alle eigenen Einträge werden gelöscht und die Vorlage für diese Kategorie neu geladen.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Abbrechen'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Zurücksetzen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  int get _erledigt => _eintraege.where((e) => e.erledigt).length;
  int get _gesamt => _eintraege.length;
  double get _progress => _gesamt == 0 ? 0.0 : _erledigt / _gesamt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.dienstleister.kategorie.color;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(theme, color),
        const SizedBox(height: 6),
        _buildProgressBar(color),
        const SizedBox(height: 8),
        ..._eintraege.map((e) => _buildTile(e, theme, color)),
        const SizedBox(height: 4),
        _buildAddButton(theme, color),
      ],
    );
  }

  Widget _buildHeader(ThemeData theme, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.checklist_rounded, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Checkliste',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$_erledigt von $_gesamt erledigt',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            size: 20,
          ),
          onSelected: (v) {
            if (v == 'reset') _zuruecksetzen();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'reset',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 16),
                  SizedBox(width: 8),
                  Text('Vorlage neu laden'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressBar(Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _progress,
        minHeight: 5,
        backgroundColor: color.withOpacity(0.12),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildTile(ChecklistenEintrag eintrag, ThemeData theme, Color color) {
    return Dismissible(
      key: ValueKey(eintrag.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      ),
      confirmDismiss: (_) async {
        await _loeschen(eintrag);
        return false;
      },
      child: InkWell(
        onTap: () => _toggle(eintrag),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: eintrag.erledigt ? color : Colors.transparent,
                  border: Border.all(
                    color: eintrag.erledigt
                        ? color
                        : theme.colorScheme.onSurface.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: eintrag.erledigt
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  eintrag.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    decoration: eintrag.erledigt
                        ? TextDecoration.lineThrough
                        : null,
                    color: eintrag.erledigt
                        ? theme.colorScheme.onSurface.withOpacity(0.38)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (eintrag.vorlagenKey == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Eigener',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme, Color color) {
    return InkWell(
      onTap: _neuerEintragDialog,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: color.withOpacity(0.8),
            ),
            const SizedBox(width: 8),
            Text(
              'Eigenen Punkt hinzufügen',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color.withOpacity(0.8),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// BOTTOM SHEET: NEUER EINTRAG
// ============================================================================

class _NeuerEintragSheet extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSave;

  const _NeuerEintragSheet({required this.controller, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Eigenen Punkt hinzufügen',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'z.B. Hochzeitszeitung bestellen',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.4),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) onSave(v);
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) onSave(controller.text);
              },
              child: const Text('Hinzufügen'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// FORTSCHRITTS-BADGE für die Dienstleister-Listenkarte
// ============================================================================

class ChecklistenFortschrittBadge extends StatefulWidget {
  final String dienstleisterId;
  final Color accentColor;

  const ChecklistenFortschrittBadge({
    super.key,
    required this.dienstleisterId,
    required this.accentColor,
  });

  @override
  State<ChecklistenFortschrittBadge> createState() =>
      _ChecklistenFortschrittBadgeState();
}

class _ChecklistenFortschrittBadgeState
    extends State<ChecklistenFortschrittBadge> {
  final _db = DatabaseHelper.instance;
  int _erledigt = 0;
  int _gesamt = 0;

  @override
  void initState() {
    super.initState();
    _laden();
  }

  Future<void> _laden() async {
    final result = await _db.getChecklistenFortschritt(widget.dienstleisterId);
    if (mounted) {
      setState(() {
        _erledigt = result['erledigt'] ?? 0;
        _gesamt = result['gesamt'] ?? 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_gesamt == 0) return const SizedBox.shrink();

    final fertig = _erledigt == _gesamt;
    final color = fertig ? Colors.green : widget.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            fertig ? Icons.check_circle_outline : Icons.checklist_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '$_erledigt/$_gesamt',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
