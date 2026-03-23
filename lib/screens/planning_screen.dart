// lib/screens/planning_screen.dart
//
// Ersetzt tasks_screen.dart als "Planung"-Tab in der BottomNav.
//
// BottomNav-Änderung in main.dart:
//   label: 'Planung'  (war: 'Checkliste')
//   TaskPage(...)  →  PlanningScreen(...)
//
// 3 interne Tabs:
//   0 – Meilensteine  (neues Dashboard)
//   1 – Checkliste    (bestehende 86 Tasks, unverändert)
//   2 – Hochzeitstag  (neuer Stunden-Ablaufplan)

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/wedding_models.dart';
import '../app_colors.dart';
import '../data/database_helper.dart';
import '../sync/services/sync_service.dart';
import '../services/premium_service.dart';
import '../services/notification_service.dart';
import '../widgets/upgrade_bottom_sheet.dart';

// Farb-Aliasse damit der Code kürzer bleibt
const Color _rose = Color(0xFFD4607A);
const Color _rose2 = Color(0xFFE8849A);
const Color _rosePale = Color(0xFFF9E0E6);
const Color _roseLight = Color(0xFFFDF3F5);
const Color _gold = Color(0xFFC9A052);
const Color _sage = Color(0xFF6B9E72);
const Color _ink = Color(0xFF1A1625);
const Color _ink2 = Color(0xFF2D2740);
const Color _muted = Color(0xFF8A8299);
const Color _line = Color(0xFFECE8F2);
const Color _bg = Color(0xFFF8F6FB);
const Color _white = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────────────────────
// Daten-Modelle Hochzeitstag
// ─────────────────────────────────────────────────────────────

class WeddingDayBlock {
  final String id;
  final String emoji;
  final String title;
  final String timeRange;
  final Color color;
  List<WeddingDayTask> tasks;
  bool isExpanded;

  WeddingDayBlock({
    required this.id,
    required this.emoji,
    required this.title,
    required this.timeRange,
    required this.color,
    required this.tasks,
    this.isExpanded = false,
  });
}

class WeddingDayTask {
  final String id;
  String title;
  bool done;
  String? note;

  WeddingDayTask({
    required this.id,
    required this.title,
    this.done = false,
    this.note,
  });
}

// ─────────────────────────────────────────────────────────────
// Meilenstein-Daten (Dashboard)
// ─────────────────────────────────────────────────────────────

enum PhaseStatus { done, now, future }

class PlanningPhase {
  final String month; // Anzeige-Label, z.B. "12 M"
  final String name; // Phasenname
  final int monthsFrom; // Deadline-Bereich Start (Monate vor Hochzeit)
  final int monthsTo; // Deadline-Bereich Ende
  final PhaseStatus status; // Wird live berechnet

  const PlanningPhase({
    required this.month,
    required this.name,
    required this.monthsFrom,
    required this.monthsTo,
    required this.status,
  });

  // Badge-Text aus Status
  String get badge {
    switch (status) {
      case PhaseStatus.done:
        return 'Erledigt';
      case PhaseStatus.now:
        return 'Jetzt';
      case PhaseStatus.future:
        return 'Geplant';
    }
  }
}

// PhaseTask wird jetzt direkt aus widget.tasks (Task-Klasse) gelesen.
// Keine eigene Klasse mehr nötig.

// ─────────────────────────────────────────────────────────────
// PlanningScreen – Haupt-Widget
// ─────────────────────────────────────────────────────────────

class PlanningScreen extends StatefulWidget {
  final List<Task> tasks;
  final Function(Task) onAddTask;
  final Function(Task) onUpdateTask;
  final Function(int) onDeleteTask;
  final DateTime? weddingDate;
  final String brideName;
  final String groomName;
  final int? selectedTaskId;
  final VoidCallback? onClearSelectedTask;
  final VoidCallback? onNavigateToHome;

  const PlanningScreen({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onUpdateTask,
    required this.onDeleteTask,
    this.weddingDate,
    required this.brideName,
    required this.groomName,
    this.selectedTaskId,
    this.onClearSelectedTask,
    this.onNavigateToHome,
  });

  @override
  State<PlanningScreen> createState() => _PlanningScreenState();
}

class _PlanningScreenState extends State<PlanningScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  // ── Checkliste-State ────────────────────────────────────
  String _selectedFilter = 'all'; // all | open | done | week | overdue
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _timelineMilestones = [];

  // ── Meilenstein-Dashboard-State ─────────────────────────
  int _selectedPhaseIndex = 0; // wird in initState auf aktuelle Phase gesetzt
  late List<PlanningPhase> _phases;

  // ── Hochzeitstag-State ───────────────────────────────────
  late List<WeddingDayBlock> _dayBlocks;
  final _newTaskController = TextEditingController();

  void _syncNow() {
    SyncService.instance.syncNow().catchError((e) {
      debugPrint('Sync error: $e');
    });
  }

  // ── Phasen-Definitionen (zeitbasiert) ─────────────────────
  // monthsFrom / monthsTo = Monate VOR der Hochzeit
  // Aufgaben in dieser Phase: deadline zwischen (Hochzeit - monthsFrom) und (Hochzeit - monthsTo)
  List<PlanningPhase> _buildPhases(DateTime? weddingDate) {
    final now = DateTime.now();
    final diff = weddingDate != null ? weddingDate.difference(now).inDays : 999;

    PhaseStatus _status(int mFrom, int mTo) {
      // Aktiv wenn der Zeitraum jetzt läuft (Hochzeit - mFrom bis Hochzeit - mTo)
      final startDays = mFrom * 30; // z.B. 12 Monate = 360 Tage vor Hochzeit
      final endDays = mTo * 30;
      if (diff > startDays) return PhaseStatus.future; // noch nicht begonnen
      if (diff > endDays) return PhaseStatus.now; // aktuell
      return PhaseStatus.done; // Zeitraum vergangen
    }

    return [
      PlanningPhase(
        month: '12–9 M',
        name: 'Erste Schritte',
        monthsFrom: 12,
        monthsTo: 9,
        status: _status(12, 9),
      ),
      PlanningPhase(
        month: '9–6 M',
        name: 'Location & Dienstleister',
        monthsFrom: 9,
        monthsTo: 6,
        status: _status(9, 6),
      ),
      PlanningPhase(
        month: '6–3 M',
        name: 'Einladungen & Details',
        monthsFrom: 6,
        monthsTo: 3,
        status: _status(6, 3),
      ),
      PlanningPhase(
        month: '3–1 M',
        name: 'Finale Vorbereitung',
        monthsFrom: 3,
        monthsTo: 0,
        status: _status(3, 0),
      ),
      PlanningPhase(
        month: 'Tag',
        name: '🎊 Hochzeitstag',
        monthsFrom: 0,
        monthsTo: -1,
        status: _status(0, -1),
      ),
    ];
  }

  // ── Tasks einer Phase aus widget.tasks filtern ─────────────
  List<Task> _getPhaseTasks(PlanningPhase phase) {
    if (widget.weddingDate == null) return [];
    final wedding = widget.weddingDate!;
    final from = DateTime(
      wedding.year,
      wedding.month - phase.monthsFrom,
      wedding.day,
    );
    final to = phase.monthsTo < 0
        ? wedding.add(Duration(days: (-phase.monthsTo) * 30))
        : DateTime(wedding.year, wedding.month - phase.monthsTo, wedding.day);

    return widget.tasks.where((t) {
      if (t.category != 'timeline') return false;
      if (t.deleted != 0) return false;
      if (t.deadline == null) return false;
      // Task liegt in diesem Phasen-Zeitraum
      return t.deadline!.isAfter(from.subtract(const Duration(days: 1))) &&
          t.deadline!.isBefore(to.add(const Duration(days: 1)));
    }).toList();
  }

  // ── Dot-Status einer Phase (fortschrittsbasiert) ─────────
  PhaseStatus _phaseEffectiveStatus(PlanningPhase phase) {
    final tasks = _getPhaseTasks(phase);
    if (tasks.isEmpty) return phase.status; // fallback auf zeitbasiert
    final done = tasks.where((t) => t.completed).length;
    if (done == tasks.length) return PhaseStatus.done; // 100% → grün
    if (done > 0) return PhaseStatus.now; // teilweise → aktiv
    return phase.status; // 0% → zeitbasiert
  }

  // ── Fortschritt einer Phase (0–100) ─────────────────────
  int _phaseProgress(PlanningPhase phase) {
    final tasks = _getPhaseTasks(phase);
    if (tasks.isEmpty) {
      // Keine verknüpften Tasks → Zeitstatus
      return phase.status == PhaseStatus.done ? 100 : 0;
    }
    final done = tasks.where((t) => t.completed).length;
    return (done / tasks.length * 100).round();
  }

  // ── Hochzeitstag-Blöcke ──────────────────────────────────
  List<WeddingDayBlock> _buildDayBlocks() {
    return [
      WeddingDayBlock(
        id: 'morning',
        emoji: '🌅',
        title: 'Getting Ready',
        timeRange: '07:00 – 11:00',
        color: const Color(0xFFC9A052),
        isExpanded: true,
        tasks: [
          WeddingDayTask(id: 'mr1', title: 'Haare & Make-up'),
          WeddingDayTask(id: 'mr2', title: 'Kleid / Anzug anlegen'),
          WeddingDayTask(
            id: 'mr3',
            title: 'Ringe einpacken',
            note: 'Nicht vergessen!',
          ),
          WeddingDayTask(id: 'mr4', title: 'Brautstrauß abholen'),
          WeddingDayTask(id: 'mr5', title: 'Erste Fotos (Getting Ready)'),
          WeddingDayTask(id: 'mr6', title: 'Frühstück nicht vergessen'),
        ],
      ),
      WeddingDayBlock(
        id: 'ceremony',
        emoji: '💍',
        title: 'Trauung',
        timeRange: '12:00 – 14:00',
        color: const Color(0xFFD4607A),
        tasks: [
          WeddingDayTask(id: 'ce1', title: 'Standesamt / Kirche pünktlich'),
          WeddingDayTask(id: 'ce2', title: 'Eheringe bereit'),
          WeddingDayTask(id: 'ce3', title: 'Ehegelübde sprechen'),
          WeddingDayTask(id: 'ce4', title: 'Fotos nach der Trauung'),
          WeddingDayTask(id: 'ce5', title: 'Sektempfang für Gäste'),
        ],
      ),
      WeddingDayBlock(
        id: 'reception',
        emoji: '🥂',
        title: 'Empfang & Fotos',
        timeRange: '14:00 – 17:00',
        color: const Color(0xFF6B9E72),
        tasks: [
          WeddingDayTask(id: 're1', title: 'Gruppenfotos mit Familie'),
          WeddingDayTask(id: 're2', title: 'Gruppenfotos mit Freunden'),
          WeddingDayTask(id: 're3', title: 'Paarfotos (Location)'),
          WeddingDayTask(id: 're4', title: 'Gäste begrüßen'),
          WeddingDayTask(id: 're5', title: 'Catering Eingang bestätigen'),
        ],
      ),
      WeddingDayBlock(
        id: 'dinner',
        emoji: '🍽️',
        title: 'Dinner & Feier',
        timeRange: '18:00 – 23:00',
        color: const Color(0xFF9B7EC8),
        tasks: [
          WeddingDayTask(id: 'di1', title: 'Einzug ins Festzelt / Saal'),
          WeddingDayTask(id: 'di2', title: 'Begrüßungsrede'),
          WeddingDayTask(id: 'di3', title: 'Dankesreden / Toasts'),
          WeddingDayTask(id: 'di4', title: 'Erster Tanz'),
          WeddingDayTask(id: 'di5', title: 'Hochzeitstorte anschneiden'),
          WeddingDayTask(id: 'di6', title: 'Buffet / Menü Service'),
        ],
      ),
      WeddingDayBlock(
        id: 'party',
        emoji: '🎉',
        title: 'Party',
        timeRange: '23:00 – open end',
        color: const Color(0xFFD4607A),
        tasks: [
          WeddingDayTask(id: 'pa1', title: 'DJ / Band Playlist'),
          WeddingDayTask(id: 'pa2', title: 'Mitternachts-Snack'),
          WeddingDayTask(id: 'pa3', title: 'Gäste verabschieden'),
          WeddingDayTask(id: 'pa4', title: 'Blumenstrauß-Werfen'),
        ],
      ),
      WeddingDayBlock(
        id: 'contacts',
        emoji: '📞',
        title: 'Notfall-Kontakte',
        timeRange: 'Immer parat',
        color: const Color(0xFF4AADA0),
        tasks: [
          WeddingDayTask(
            id: 'co1',
            title: 'Fotograf: +49 …',
            note: 'Nummer hier eintragen',
          ),
          WeddingDayTask(
            id: 'co2',
            title: 'Caterer: +49 …',
            note: 'Nummer hier eintragen',
          ),
          WeddingDayTask(
            id: 'co3',
            title: 'DJ / Band: +49 …',
            note: 'Nummer hier eintragen',
          ),
          WeddingDayTask(
            id: 'co4',
            title: 'Location-Manager: +49 …',
            note: 'Nummer hier eintragen',
          ),
          WeddingDayTask(
            id: 'co5',
            title: 'Trauzeugen: +49 …',
            note: 'Nummer hier eintragen',
          ),
        ],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    // 3 Tabs
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTab = _tabController.index);
      }
    });

    _phases = _buildPhases(widget.weddingDate);
    _dayBlocks = _buildDayBlocks();
    _loadTimelineMilestones();
    // Aktive Phase vorauswählen
    _selectedPhaseIndex = _phases.indexWhere(
      (p) => p.status == PhaseStatus.now,
    );
    if (_selectedPhaseIndex < 0) _selectedPhaseIndex = 0;

    // Direkt zur Task navigieren (aus bestehendem Code)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedTaskId != null) {
        _tabController.animateTo(1); // zur Checkliste
        widget.onClearSelectedTask?.call();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _newTaskController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlanningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Wenn sich Tasks ändern (abhaken, neue Tasks) → Phasen neu berechnen
    if (oldWidget.tasks != widget.tasks ||
        oldWidget.weddingDate != widget.weddingDate) {
      setState(() {
        _phases = _buildPhases(widget.weddingDate);
      });
    }
  }

  Future<void> _loadTimelineMilestones() async {
    // Tasks mit category=='timeline' als Milestones nutzen
    final timelineTasks = widget.tasks
        .where((t) => t.category == 'timeline')
        .toList();
    if (timelineTasks.isEmpty) {
      await _initializeDefaultMilestonesManually();
    } else {
      if (mounted)
        setState(
          () => _timelineMilestones = timelineTasks
              .map((t) => {'task': t, 'isCompleted': t.completed})
              .toList(),
        );
    }
  }

  Future<void> _initializeDefaultMilestonesManually() async {
    // Bestehende 86-Tasks Logik aus tasks_screen.dart – unverändert übernehmen
    // (Hier nur Platzhalter – die echte Implementierung aus tasks_screen.dart einfügen)
    if (mounted) setState(() => _timelineMilestones = []);
  }

  // ─────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final daysLeft = widget.weddingDate != null
        ? widget.weddingDate!.difference(DateTime.now()).inDays
        : null;
    final completedTasks = widget.tasks.where((t) => t.completed).length;
    final totalTasks = widget.tasks.length;
    final donePercent = totalTasks > 0
        ? (completedTasks / totalTasks * 100).round()
        : 0;

    return Scaffold(
      backgroundColor: Color(0xFFF8F6FB),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Hero Banner ──────────────────────────────
            _buildHero(daysLeft, donePercent, totalTasks),

            // ── 3-Tab-Bar ─────────────────────────────
            _buildTabBar(),

            // ── Content ─────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMilestonesTab(),
                  _buildChecklistTab(),
                  _buildWeddingDayTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HERO BANNER
  // ─────────────────────────────────────────────────────────

  Widget _buildHero(int? daysLeft, int donePercent, int totalTasks) {
    final urgentCount = widget.tasks.where((t) => !t.completed).length;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D2740), Color(0xFF3D2D5E)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Rose-Glow
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                gradient: RadialGradient(
                  center: const Alignment(0.7, -0.3),
                  radius: 1.0,
                  colors: [
                    Color(0xFFD4607A).withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🌸 Planung',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.14,
                              color: Colors.white.withOpacity(0.45),
                            ),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                height: 1.1,
                              ),
                              children: [
                                TextSpan(text: '${widget.brideName} & '),
                                TextSpan(
                                  text: widget.groomName,
                                  style: const TextStyle(
                                    color: Color(0xFFE8849A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.weddingDate != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              _formatDate(widget.weddingDate!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Ring
                    if (daysLeft != null)
                      _buildRing(daysLeft, donePercent / 100),
                  ],
                ),
                const SizedBox(height: 16),
                // Stat-Tiles
                Row(
                  children: [
                    _buildStatTile('$urgentCount', 'Offen', Color(0xFFE8849A)),
                    const SizedBox(width: 8),
                    _buildStatTile(
                      '$donePercent%',
                      'Erledigt',
                      const Color(0xFFE4C07A),
                    ),
                    const SizedBox(width: 8),
                    _buildStatTile(
                      '$totalTasks',
                      'Aufgaben',
                      const Color(0xFF9ECBA4),
                    ),
                    const SizedBox(width: 8),
                    _buildStatTile(
                      daysLeft != null ? '$daysLeft' : '–',
                      'Tage noch',
                      Colors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRing(int days, double progress) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD4607A)),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$days',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
              Text(
                'TAGE',
                style: TextStyle(
                  fontSize: 8,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 0.06,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.white.withOpacity(0.45),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB BAR
  // ─────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final isPremium = PremiumService.instance.isPremium;

    final tabs = [
      (icon: Icons.flag_outlined, label: 'Meilensteine', locked: false),
      (icon: Icons.checklist_rounded, label: 'Checkliste', locked: false),
      (
        icon: Icons.celebration_outlined,
        label: 'Hochzeitstag',
        locked: !isPremium,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = i == _currentTab;
            final locked = tabs[i].locked;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (locked) {
                    _showWeddingDayUpgrade();
                  } else {
                    _tabController.animateTo(i);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? Color(0xFFD4607A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: Color(0xFFD4607A).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        locked ? Icons.lock_outline : tabs[i].icon,
                        size: 14,
                        color: active
                            ? Colors.white
                            : locked
                            ? Color(0xFFECE8F2)
                            : Color(0xFF8A8299),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        tabs[i].label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? Colors.white
                              : locked
                              ? Color(0xFFECE8F2)
                              : Color(0xFF8A8299),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 0 – MEILENSTEINE
  // ─────────────────────────────────────────────────────────

  Widget _buildMilestonesTab() {
    final isPremium = PremiumService.instance.isPremium;
    final phase = _phases[_selectedPhaseIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontale Timeline – KOSTENLOS
          _buildHorizontalTimeline(),
          const SizedBox(height: 14),
          // Phase-Detail – KOSTENLOS
          _buildPhaseDetail(phase, onToggle: () => setState(() {})),
          const SizedBox(height: 24),

          // Vertikaler Zeitstrahl – PREMIUM
          _buildPremiumSectionHeader(
            label: 'Vollständiger Zeitstrahl',
            isPremium: isPremium,
            onUpgrade: () => UpgradeBottomSheet.show(
              context,
              featureName: 'Vollständiger Zeitstrahl',
              featureDescription:
                  'Sieh alle Phasen auf einen Blick – '
                  'mit Fälligkeiten, Fortschritts­balken und direkten Aufgaben pro Meilenstein.',
            ),
          ),
          const SizedBox(height: 10),
          isPremium
              ? _buildVerticalTimeline()
              : _buildLockedPlaceholder(
                  icon: Icons.timeline,
                  title: 'Vollständiger Zeitstrahl',
                  subtitle: 'Alle Meilensteine mit Aufgaben auf einen Blick',
                  onTap: () => UpgradeBottomSheet.show(
                    context,
                    featureName: 'Vollständiger Zeitstrahl',
                    featureDescription:
                        'Sieh alle Planungs-Phasen mit Fortschritt, '
                        'Fälligkeiten und Aufgaben in einer übersichtlichen Timeline.',
                  ),
                ),

          const SizedBox(height: 24),

          // Fokus-Karten – PREMIUM
          _buildPremiumSectionHeader(
            label: 'Fokus-Karten',
            isPremium: isPremium,
            onUpgrade: () => UpgradeBottomSheet.show(
              context,
              featureName: 'Fokus-Karten',
              featureDescription:
                  'Eine Karte pro Meilenstein – '
                  'konzentriere dich immer auf genau die 2–3 Aufgaben die jetzt zählen.',
            ),
          ),
          const SizedBox(height: 10),
          isPremium
              ? _buildFocusCards()
              : _buildLockedPlaceholder(
                  icon: Icons.style_outlined,
                  title: 'Fokus-Karten',
                  subtitle: 'Die 3 wichtigsten Aufgaben pro Phase',
                  onTap: () => UpgradeBottomSheet.show(
                    context,
                    featureName: 'Fokus-Karten',
                    featureDescription:
                        'Eine Karte pro Meilenstein – '
                        'konzentriere dich immer auf genau die 2–3 Aufgaben die jetzt zählen.',
                  ),
                ),
        ],
      ),
    );
  }

  // Fokus-Karten (Simple Version, Premium)
  Widget _buildFocusCards() {
    return Column(
      children: _phases.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
        final phaseTasks = _getPhaseTasks(p);
        final urgentTasks = phaseTasks
            .where((t) => !t.completed)
            .take(3)
            .toList();
        final effStat = _phaseEffectiveStatus(p);
        final pct = _phaseProgress(p);
        if (phaseTasks.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Color(0xFFFFFFFF),
            border: Border.all(color: Color(0xFFECE8F2)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                Container(
                  height: 3,
                  color: effStat == PhaseStatus.done
                      ? Color(0xFF6B9E72)
                      : effStat == PhaseStatus.now
                      ? Color(0xFFD4607A)
                      : Color(0xFFECE8F2),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            p.month,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD4607A),
                              letterSpacing: 0.08,
                            ),
                          ),
                          const Spacer(),
                          _badgePill('$pct%', effStat),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1625),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (urgentTasks.isEmpty)
                        const Text(
                          'Alle Aufgaben erledigt ✓',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B9E72),
                          ),
                        )
                      else
                        ...urgentTasks.map((t) => _buildRealTask(t)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1625),
      ),
    );
  }

  // Horizontale Timeline
  Widget _buildHorizontalTimeline() {
    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _phases.length,
        itemBuilder: (_, i) {
          final p = _phases[i];
          final selected = i == _selectedPhaseIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedPhaseIndex = i),
            child: SizedBox(
              width: 108,
              child: Column(
                children: [
                  _buildHDot(_phaseEffectiveStatus(p)),
                  const SizedBox(height: 8),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 100,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: (selected || p.status == PhaseStatus.now)
                          ? Color(0xFFFDF3F5)
                          : Color(0xFFFFFFFF),
                      border: Border.all(
                        color: selected || p.status == PhaseStatus.now
                            ? Color(0xFFD4607A)
                            : p.status == PhaseStatus.done
                            ? Color(0xFFF9E0E6)
                            : Color(0xFFECE8F2),
                        width: selected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: Color(0xFFD4607A).withOpacity(0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          p.month,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD4607A),
                            letterSpacing: 0.06,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1625),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (ctx) {
                            final pct = _phaseProgress(p);
                            return Text(
                              '$pct%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF8A8299),
                              ),
                            );
                          },
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

  Widget _buildHDot(PhaseStatus s) {
    // Farbe nach Fortschritt: grün=fertig, rose=aktiv, grau=future
    final Color fill = s == PhaseStatus.done
        ? const Color(0xFF6B9E72)
        : s == PhaseStatus.now
        ? const Color(0xFFD4607A)
        : const Color(0xFFFFFFFF);
    final Color border = s == PhaseStatus.done
        ? const Color(0xFF6B9E72)
        : s == PhaseStatus.now
        ? const Color(0xFFD4607A)
        : const Color(0xFFECE8F2);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 2),
        boxShadow: s != PhaseStatus.future
            ? [
                BoxShadow(
                  color: fill.withOpacity(0.35),
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: s == PhaseStatus.done
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : s == PhaseStatus.now
          ? const Icon(Icons.circle, size: 7, color: Colors.white)
          : null,
    );
  }

  // Phase-Detail
  Widget _buildPhaseDetail(PlanningPhase phase, {VoidCallback? onToggle}) {
    final tasks = _getPhaseTasks(phase);
    final pct = _phaseProgress(phase);
    final effStatus = _phaseEffectiveStatus(phase);
    final hasTimeline = widget.tasks.any((t) => t.category == 'timeline');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border.all(color: Color(0xFFF9E0E6), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badgePill(tasks.isEmpty ? phase.badge : '$pct%', effStatus),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phase.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1625),
                  ),
                ),
              ),
              if (tasks.isNotEmpty)
                Text(
                  '${tasks.where((t) => t.completed).length}/${tasks.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8A8299),
                  ),
                ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Fortschrittsbalken
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 4,
                backgroundColor: Color(0xFFECE8F2),
                valueColor: AlwaysStoppedAnimation(
                  pct == 100 ? Color(0xFF6B9E72) : Color(0xFFD4607A),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Aufgaben aus der Checkliste
            ...tasks.map((t) => _buildRealTask(t)),
          ] else if (!hasTimeline) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                _tabController.animateTo(1);
                Future.delayed(
                  const Duration(milliseconds: 300),
                  () => _showCreateChecklistDialog(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFECE8F2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'Checkliste erstellen →',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFD4607A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'Keine Aufgaben in diesem Zeitraum.',
              style: TextStyle(fontSize: 13, color: Color(0xFF8A8299)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Echte Task (aus DB) in der Phase-Detail-Ansicht ──────
  Widget _buildRealTask(Task task) {
    return GestureDetector(
      onTap: () {
        widget.onUpdateTask(task.copyWith(completed: !task.completed));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: task.completed ? Color(0xFFF8F6FB) : Color(0xFFFFFFFF),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: task.completed ? Color(0xFF6B9E72) : Colors.transparent,
                border: Border.all(
                  color: task.completed ? Color(0xFF6B9E72) : Color(0xFFECE8F2),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: task.completed
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  color: task.completed ? Color(0xFF8A8299) : Color(0xFF1A1625),
                  decoration: task.completed
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
            if (task.deadline != null)
              Text(
                _shortDate(task.deadline!),
                style: TextStyle(
                  fontSize: 11,
                  color:
                      !task.completed && task.deadline!.isBefore(DateTime.now())
                      ? Color(0xFFD4607A)
                      : Color(0xFF8A8299),
                  fontWeight:
                      !task.completed && task.deadline!.isBefore(DateTime.now())
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Vertikale Milestone-Timeline
  Widget _buildVerticalTimeline() {
    return Column(
      children: _phases.asMap().entries.map((e) {
        final i = e.key;
        final p = e.value;
        final isLast = i == _phases.length - 1;
        return _buildMilestoneTile(p, isLast);
      }).toList(),
    );
  }

  Widget _buildMilestoneTile(PlanningPhase p, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                const SizedBox(height: 3),
                _buildHDot(p.status),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: p.status == PhaseStatus.done
                            ? Color(0xFFD4607A)
                            : Color(0xFFECE8F2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.month,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: p.status == PhaseStatus.done
                          ? Color(0xFFD4607A)
                          : p.status == PhaseStatus.now
                          ? Color(0xFF1A1625)
                          : Color(0xFF8A8299),
                      letterSpacing: 0.08,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1625),
                          ),
                        ),
                      ),
                      Builder(
                        builder: (_) {
                          final pct = _phaseProgress(p);
                          final eff = _phaseEffectiveStatus(p);
                          return _badgePill('$pct%', eff);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...(_getPhaseTasks(p)).take(3).map((t) => _buildRealTask(t)),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 1 – CHECKLISTE (bestehend, minimal angepasst)
  // ─────────────────────────────────────────────────────────

  Widget _buildChecklistTab() {
    final isPremium = PremiumService.instance.isPremium;

    return Column(
      children: [
        // Suchfeld
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Aufgaben suchen …',
              hintStyle: const TextStyle(
                color: Color(0xFF8A8299),
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: Color(0xFF8A8299),
                size: 20,
              ),
              filled: true,
              fillColor: Color(0xFFFFFFFF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFECE8F2)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFECE8F2)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        // ── Filter-Chips ─────────────────────────────────────
        _buildFilterChips(),
        // Fortschritt + Aktions-Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Column(
            children: [
              _buildProgressBanner(),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Checkliste verwalten (erstellen / löschen)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final hasTimeline = widget.tasks.any(
                          (t) => t.category == 'timeline' && t.deleted == 0,
                        );
                        return _buildChecklistActionButton(
                          icon: hasTimeline
                              ? Icons.playlist_remove
                              : Icons.playlist_add_check,
                          label: hasTimeline ? 'Verwalten' : 'Erstellen',
                          isPremium: true,
                          onTap: () {
                            final tl = widget.tasks
                                .where(
                                  (t) =>
                                      t.category == 'timeline' &&
                                      t.deleted == 0,
                                )
                                .toList();
                            if (tl.isEmpty) {
                              _showCreateChecklistDialog();
                            } else {
                              _showManageChecklistDialog(tl);
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // PDF-Export – Premium
                  Expanded(
                    child: _buildChecklistActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF-Export',
                      isPremium: isPremium,
                      onTap: isPremium
                          ? () => _exportChecklistPdf()
                          : () => UpgradeBottomSheet.show(
                              context,
                              featureName: 'PDF-Export',
                              featureDescription:
                                  'Exportiere deine komplette Checkliste '
                                  'als PDF – perfekt zum Ausdrucken.',
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Erinnerungen
                  Expanded(
                    child: _buildChecklistActionButton(
                      icon: Icons.notifications_outlined,
                      label: 'Erinnerungen',
                      isPremium: isPremium,
                      onTap: isPremium
                          ? () => _showReminderSettings()
                          : () => UpgradeBottomSheet.show(
                              context,
                              featureName: 'Smarte Erinnerungen',
                              featureDescription:
                                  'Erhalte Push-Benachrichtigungen '
                                  'bevor Aufgaben fällig werden.',
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Task-Liste
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              // ── Checkliste-Inhalt ──────────────────────────
              _buildChecklistContent(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistActionButton({
    required IconData icon,
    required String label,
    required bool isPremium,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isPremium ? Color(0xFFD4607A) : Color(0xFFECE8F2),
                ),
                if (!isPremium)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC9A052),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 7,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isPremium ? Color(0xFF1A1625) : Color(0xFF8A8299),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistContent() {
    final timelineTasks = widget.tasks
        .where((t) => t.category == 'timeline' && t.deleted == 0)
        .toList();
    final hasTimeline = timelineTasks.isNotEmpty;
    final done = timelineTasks.where((t) => t.completed).length;

    return Column(
      children: [
        // ── Leer-Zustand ──────────────────────────────────────
        if (!hasTimeline) ...[
          const SizedBox(height: 40),
          const Icon(
            Icons.checklist_rounded,
            size: 56,
            color: Color(0xFFECE8F2),
          ),
          const SizedBox(height: 14),
          const Text(
            'Noch keine Checkliste',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1625),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tippe auf "Checkliste erstellen" um\n70 Aufgaben automatisch anzulegen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF8A8299),
              height: 1.5,
            ),
          ),
        ],

        // ── Aufgabenliste ─────────────────────────────────────
        if (hasTimeline) ...[
          // Fortschrittsbalken
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: timelineTasks.isEmpty ? 0 : done / timelineTasks.length,
              minHeight: 5,
              backgroundColor: const Color(0xFFECE8F2),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFD4607A)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$done / ${timelineTasks.length} erledigt',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A8299)),
              ),
              Text(
                '${timelineTasks.isEmpty ? 0 : (done / timelineTasks.length * 100).round()}%',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD4607A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Neue Aufgabe hinzufügen
          GestureDetector(
            onTap: () => _showTaskForm(context),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF3F5),
                border: Border.all(
                  color: const Color(0xFFD4607A).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 18, color: Color(0xFFD4607A)),
                  SizedBox(width: 8),
                  Text(
                    'Neue Aufgabe hinzufügen',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD4607A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Überfällig-Sektion ──────────────────────────────
          ..._buildOverdueSection(timelineTasks),

          // ── Gefilterte Aufgaben-Liste ───────────────────────
          ..._buildFilteredTaskList(timelineTasks),
        ],
      ],
    );
  }

  // ── Einzelne Checklisten-Aufgabe mit Bearbeiten + Löschen ──
  Widget _buildChecklistTaskItem(Task task, {bool isOverdue = false}) {
    return Dismissible(
      key: Key('task_${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Aufgabe löschen'),
                content: Text('„${task.title}" wirklich löschen?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Abbrechen'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Löschen'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        if (task.id != null) widget.onDeleteTask(task.id!);
      },
      child: GestureDetector(
        onTap: () => _showTaskForm(context, existingTask: task),
        child: Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: task.completed
                ? const Color(0xFFF8F6FB)
                : isOverdue
                ? const Color(0xFFFDF3F5)
                : Colors.white,
            border: Border.all(
              color: isOverdue && !task.completed
                  ? const Color(0xFFD4607A).withOpacity(0.35)
                  : const Color(0xFFECE8F2),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              // Checkbox
              GestureDetector(
                onTap: () => widget.onUpdateTask(
                  task.copyWith(completed: !task.completed),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: task.completed
                        ? const Color(0xFF6B9E72)
                        : Colors.transparent,
                    border: Border.all(
                      color: task.completed
                          ? const Color(0xFF6B9E72)
                          : const Color(0xFFECE8F2),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: task.completed
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // Titel
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 13,
                    color: task.completed
                        ? const Color(0xFF8A8299)
                        : const Color(0xFF1A1625),
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              // Datum
              if (task.deadline != null) ...[
                const SizedBox(width: 6),
                Text(
                  _shortDate(task.deadline!),
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        !task.completed &&
                            task.deadline!.isBefore(DateTime.now())
                        ? const Color(0xFFD4607A)
                        : const Color(0xFF8A8299),
                    fontWeight:
                        !task.completed &&
                            task.deadline!.isBefore(DateTime.now())
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
              const SizedBox(width: 6),
              // Bearbeiten-Icon
              const Icon(
                Icons.chevron_right,
                size: 16,
                color: Color(0xFFECE8F2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Aufgabe erstellen / bearbeiten Dialog ──────────────────
  void _showTaskForm(BuildContext context, {Task? existingTask}) {
    final isEdit = existingTask != null;
    final titleCtrl = TextEditingController(text: existingTask?.title ?? '');
    final descCtrl = TextEditingController(
      text: existingTask?.description ?? '',
    );
    DateTime? deadline = existingTask?.deadline;
    String priority = existingTask?.priority ?? 'medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECE8F2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEdit ? 'Aufgabe bearbeiten' : 'Neue Aufgabe',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1625),
                ),
              ),
              const SizedBox(height: 16),

              // Titel
              TextField(
                controller: titleCtrl,
                autofocus: !isEdit,
                decoration: InputDecoration(
                  labelText: 'Titel *',
                  hintText: 'z.B. Einladungen versenden',
                  filled: true,
                  fillColor: const Color(0xFFF8F6FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFECE8F2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFECE8F2)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Beschreibung
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notiz (optional)',
                  filled: true,
                  fillColor: const Color(0xFFF8F6FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFECE8F2)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFECE8F2)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Datum + Priorität
              Row(
                children: [
                  // Datum
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: deadline ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setModalState(() => deadline = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F6FB),
                          border: Border.all(color: const Color(0xFFECE8F2)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 16,
                              color: Color(0xFF8A8299),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              deadline != null
                                  ? _shortDate(deadline!)
                                  : 'Datum wählen',
                              style: TextStyle(
                                fontSize: 13,
                                color: deadline != null
                                    ? const Color(0xFF1A1625)
                                    : const Color(0xFF8A8299),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Priorität
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F6FB),
                        border: Border.all(color: const Color(0xFFECE8F2)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: priority,
                          isExpanded: true,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1A1625),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('Hoch'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('Mittel'),
                            ),
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('Niedrig'),
                            ),
                          ],
                          onChanged: (v) =>
                              setModalState(() => priority = v ?? 'medium'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Speichern-Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    final task = Task(
                      id: existingTask?.id,
                      title: title,
                      description: descCtrl.text.trim(),
                      category: 'timeline',
                      priority: priority,
                      deadline: deadline,
                      completed: existingTask?.completed ?? false,
                      createdDate: existingTask?.createdDate ?? DateTime.now(),
                    );
                    if (isEdit) {
                      widget.onUpdateTask(task);
                    } else {
                      widget.onAddTask(task);
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4607A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isEdit ? 'Speichern' : 'Aufgabe hinzufügen',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (isEdit) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok =
                          await showDialog<bool>(
                            context: context,
                            builder: (d) => AlertDialog(
                              title: const Text('Aufgabe löschen'),
                              content: Text(
                                '„${existingTask!.title}" wirklich löschen?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Abbrechen'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(d, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Löschen'),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (ok && existingTask.id != null) {
                        widget.onDeleteTask(existingTask.id!);
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Aufgabe löschen'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Löschen-Dialog ────────────────────────────────────────────
  void _showDeleteChecklistDialog(List<Task> timelineTasks) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Checkliste löschen'),
        content: Text(
          'Möchtest du alle ${timelineTasks.length} Timeline-Aufgaben unwiderruflich löschen?\n\nAlle Aufgaben und der Erledigungsstatus gehen verloren.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // IDs vorher sammeln
              final ids = timelineTasks
                  .where((t) => t.id != null)
                  .map((t) => t.id!)
                  .toList();

              if (ids.isEmpty) return;

              // Ladeindikator
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Color(0xFFD4607A),
                          ),
                          const SizedBox(height: 16),
                          Text('${ids.length} Aufgaben werden gelöscht…'),
                        ],
                      ),
                    ),
                  ),
                );
              }

              try {
                for (final id in ids) {
                  widget.onDeleteTask(id);
                  await Future.delayed(const Duration(milliseconds: 30));
                }
                await Future.delayed(const Duration(milliseconds: 300));

                if (mounted) Navigator.of(context, rootNavigator: true).pop();
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${ids.length} Aufgaben gelöscht.'),
                      backgroundColor: const Color(0xFF6B9E72),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) Navigator.of(context, rootNavigator: true).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4607A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Ja, alles löschen'),
          ),
        ],
      ),
    );
  }

  // ── Checkliste verwalten Dialog (Erstellen / Löschen) ─────
  // ─────────────────────────────────────────────────────────
  // FILTER CHIPS
  // ─────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final now = DateTime.now();
    final allTasks = widget.tasks
        .where((t) => t.category == 'timeline' && t.deleted == 0)
        .toList();
    if (allTasks.isEmpty) return const SizedBox.shrink();

    final overdueCount = allTasks
        .where(
          (t) =>
              !t.completed && t.deadline != null && t.deadline!.isBefore(now),
        )
        .length;
    final weekEnd = now.add(const Duration(days: 7));
    final weekCount = allTasks
        .where(
          (t) =>
              !t.completed &&
              t.deadline != null &&
              !t.deadline!.isBefore(now) &&
              t.deadline!.isBefore(weekEnd),
        )
        .length;

    final chips = [
      (id: 'all', label: 'Alle', count: allTasks.length, isAlert: false),
      (
        id: 'open',
        label: 'Offen',
        count: allTasks.where((t) => !t.completed).length,
        isAlert: false,
      ),
      (
        id: 'done',
        label: 'Erledigt',
        count: allTasks.where((t) => t.completed).length,
        isAlert: false,
      ),
      (
        id: 'week',
        label: 'Diese Woche',
        count: weekCount,
        isAlert: weekCount > 0,
      ),
      (
        id: 'overdue',
        label: 'Überfällig',
        count: overdueCount,
        isAlert: overdueCount > 0,
      ),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = chips[i];
          final active = _selectedFilter == c.id;
          // Farbe
          Color bg, fg, border;
          if (c.id == 'overdue' && c.isAlert && !active) {
            bg = const Color(0xFFFDF3F5);
            fg = const Color(0xFFD4607A);
            border = const Color(0xFFD4607A);
          } else if (active) {
            bg = c.id == 'overdue'
                ? const Color(0xFFD4607A)
                : const Color(0xFF1A1625);
            fg = Colors.white;
            border = bg;
          } else {
            bg = Colors.white;
            fg = const Color(0xFF8A8299);
            border = const Color(0xFFECE8F2);
          }
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = c.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: bg,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  if (c.count > 0) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.25)
                            : (c.isAlert
                                  ? const Color(0xFFD4607A).withOpacity(0.15)
                                  : const Color(0xFFECE8F2)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${c.count}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : (c.isAlert
                                    ? const Color(0xFFD4607A)
                                    : const Color(0xFF8A8299)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ÜBERFÄLLIG-SEKTION
  // ─────────────────────────────────────────────────────────

  List<Widget> _buildOverdueSection(List<Task> allTasks) {
    // Nur anzeigen wenn kein spezieller Filter aktiv ist
    if (_selectedFilter != 'all' && _selectedFilter != 'overdue') return [];

    final now = DateTime.now();
    final overdue =
        allTasks
            .where(
              (t) =>
                  !t.completed &&
                  t.deadline != null &&
                  t.deadline!.isBefore(now) &&
                  (_searchQuery.isEmpty ||
                      t.title.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      )),
            )
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    if (overdue.isEmpty) return [];

    return [
      // Header
      Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3F5),
          border: Border.all(color: const Color(0xFFD4607A).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Color(0xFFD4607A),
            ),
            const SizedBox(width: 8),
            Text(
              '${overdue.length} überfällige Aufgabe${overdue.length == 1 ? '' : 'n'}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD4607A),
              ),
            ),
          ],
        ),
      ),
      // Überfällige Tasks
      ...overdue.map((t) => _buildChecklistTaskItem(t, isOverdue: true)),
      // Trennlinie zur normalen Liste
      if (_selectedFilter == 'all') ...[
        const SizedBox(height: 4),
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 1,
          color: const Color(0xFFECE8F2),
        ),
      ],
    ];
  }

  // ─────────────────────────────────────────────────────────
  // GEFILTERTE TASK-LISTE
  // ─────────────────────────────────────────────────────────

  List<Widget> _buildFilteredTaskList(List<Task> allTasks) {
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 7));

    // Filter anwenden
    List<Task> filtered;
    switch (_selectedFilter) {
      case 'open':
        filtered = allTasks.where((t) => !t.completed).toList();
      // Überfällige im "Offen"-Filter auch zeigen (ohne eigene Sektion)
      case 'done':
        filtered = allTasks.where((t) => t.completed).toList();
      case 'week':
        filtered = allTasks
            .where(
              (t) =>
                  !t.completed &&
                  t.deadline != null &&
                  !t.deadline!.isBefore(now) &&
                  t.deadline!.isBefore(weekEnd),
            )
            .toList();
      case 'overdue':
        // Überfällige kommen schon aus _buildOverdueSection
        return [];
      default: // 'all'
        // Nicht-überfällige anzeigen (überfällige sind oben)
        filtered = allTasks
            .where(
              (t) =>
                  t.completed ||
                  t.deadline == null ||
                  !t.deadline!.isBefore(now),
            )
            .toList();
    }

    // Suchfilter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    // Nach Deadline sortieren
    filtered.sort((a, b) {
      if (a.deadline == null && b.deadline == null) return 0;
      if (a.deadline == null) return 1;
      if (b.deadline == null) return -1;
      if (a.completed && !b.completed) return 1;
      if (!a.completed && b.completed) return -1;
      return a.deadline!.compareTo(b.deadline!);
    });

    if (filtered.isEmpty) {
      return [
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Icon(
                _selectedFilter == 'done'
                    ? Icons.check_circle_outline
                    : Icons.search_off,
                size: 40,
                color: const Color(0xFFECE8F2),
              ),
              const SizedBox(height: 10),
              Text(
                _selectedFilter == 'done'
                    ? 'Noch nichts erledigt'
                    : _selectedFilter == 'week'
                    ? 'Diese Woche nichts fällig'
                    : 'Keine Aufgaben gefunden',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A8299)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ];
    }

    return filtered.map((t) => _buildChecklistTaskItem(t)).toList();
  }

  void _showManageChecklistDialog(List<Task> timelineTasks) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkliste verwalten'),
        content: Text(
          '${timelineTasks.length} Aufgaben vorhanden · '
          '${timelineTasks.where((t) => t.completed).length} erledigt',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteChecklistDialog(timelineTasks);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Alles löschen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showCreateChecklistDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4607A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Neu erstellen'),
          ),
        ],
      ),
    );
  }

  // ── PDF-Export ──────────────────────────────────────────────
  Future<void> _exportChecklistPdf() async {
    final timelineTasks =
        widget.tasks
            .where((t) => t.category == 'timeline' && t.deleted == 0)
            .toList()
          ..sort((a, b) {
            if (a.deadline == null && b.deadline == null) return 0;
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return a.deadline!.compareTo(b.deadline!);
          });

    if (timelineTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Aufgaben zum Exportieren.')),
      );
      return;
    }

    // Ladeindikator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('PDF wird erstellt …'),
          ],
        ),
      ),
    );

    try {
      final pdf = pw.Document();
      final done = timelineTasks.where((t) => t.completed).length;
      final pct = (done / timelineTasks.length * 100).round();
      final now = DateTime.now();
      const rose = PdfColor.fromInt(0xFFD4607A);
      const sage = PdfColor.fromInt(0xFF6B9E72);
      const ink = PdfColor.fromInt(0xFF1A1625);
      const muted = PdfColor.fromInt(0xFF8A8299);
      const line = PdfColor.fromInt(0xFFECE8F2);

      // Tasks nach Phasen gruppieren
      final phases = [
        {'label': '12–9 Monate vorher', 'from': 9, 'to': 12},
        {'label': '9–6 Monate vorher', 'from': 6, 'to': 9},
        {'label': '6–3 Monate vorher', 'from': 3, 'to': 6},
        {'label': '3–0 Monate vorher', 'from': 0, 'to': 3},
        {'label': 'Nach der Hochzeit', 'from': -6, 'to': 0},
      ];

      List<Map<String, dynamic>> getPhaseItems(int mFrom, int mTo) {
        if (widget.weddingDate == null) return [];
        final w = widget.weddingDate!;
        return timelineTasks
            .where((t) {
              if (t.deadline == null) return false;
              final diff = w.difference(t.deadline!).inDays / 30;
              return diff >= mFrom && diff < mTo;
            })
            .map((t) => {'task': t})
            .toList();
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'HeartPebble',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: rose,
                        ),
                      ),
                      pw.Text(
                        'Hochzeits-Checkliste',
                        style: pw.TextStyle(fontSize: 13, color: muted),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (widget.brideName.isNotEmpty ||
                          widget.groomName.isNotEmpty)
                        pw.Text(
                          '${widget.brideName} & ${widget.groomName}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: ink,
                          ),
                        ),
                      if (widget.weddingDate != null)
                        pw.Text(
                          '${widget.weddingDate!.day}.${widget.weddingDate!.month}.${widget.weddingDate!.year}',
                          style: pw.TextStyle(fontSize: 11, color: muted),
                        ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              // Fortschrittsbalken via Stack
              pw.Stack(
                children: [
                  pw.Container(
                    height: 6,
                    decoration: pw.BoxDecoration(
                      color: line,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(3),
                      ),
                    ),
                  ),
                  pw.Container(
                    height: 6,
                    width: (514 * (done / timelineTasks.length)).clamp(0, 514),
                    decoration: pw.BoxDecoration(
                      color: pct == 100 ? sage : rose,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '$done / ${timelineTasks.length} Aufgaben erledigt',
                    style: pw.TextStyle(fontSize: 9, color: muted),
                  ),
                  pw.Text(
                    '$pct%',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: pct == 100 ? sage : rose,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: line),
              pw.SizedBox(height: 8),
            ],
          ),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Erstellt am ${now.day}.${now.month}.${now.year}',
                style: pw.TextStyle(fontSize: 8, color: muted),
              ),
              pw.Text(
                'Seite ${ctx.pageNumber} von ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 8, color: muted),
              ),
            ],
          ),
          build: (ctx) {
            final widgets = <pw.Widget>[];
            for (final phase in phases) {
              final items = getPhaseItems(
                phase['from'] as int,
                phase['to'] as int,
              );
              if (items.isEmpty) continue;
              final phaseDone = items
                  .where((i) => (i['task'] as Task).completed)
                  .length;

              widgets.add(pw.SizedBox(height: 12));
              widgets.add(
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF8F6FB),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        phase['label'] as String,
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: ink,
                        ),
                      ),
                      pw.Text(
                        '$phaseDone/${items.length}',
                        style: pw.TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));

              for (final item in items) {
                final task = item['task'] as Task;
                widgets.add(
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 3),
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: line, width: 0.5),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                      color: task.completed
                          ? const PdfColor.fromInt(0xFFF8F6FB)
                          : PdfColors.white,
                    ),
                    child: pw.Row(
                      children: [
                        // Checkbox
                        pw.Container(
                          width: 14,
                          height: 14,
                          decoration: pw.BoxDecoration(
                            color: task.completed ? sage : PdfColors.white,
                            border: pw.Border.all(
                              color: task.completed ? sage : line,
                              width: 1,
                            ),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(3),
                            ),
                          ),
                          child: task.completed
                              ? pw.Center(
                                  child: pw.Text(
                                    '✓',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColors.white,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        pw.SizedBox(width: 8),
                        // Titel
                        pw.Expanded(
                          child: pw.Text(
                            task.title,
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: task.completed ? muted : ink,
                              decoration: task.completed
                                  ? pw.TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        // Datum
                        if (task.deadline != null)
                          pw.Text(
                            '${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}',
                            style: pw.TextStyle(fontSize: 9, color: muted),
                          ),
                      ],
                    ),
                  ),
                );
              }
            }
            // Tasks ohne Deadline
            final noDate = timelineTasks
                .where((t) => t.deadline == null)
                .toList();
            if (noDate.isNotEmpty) {
              widgets.add(pw.SizedBox(height: 12));
              widgets.add(
                pw.Text(
                  'Ohne Datum',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: ink,
                  ),
                ),
              );
              widgets.add(pw.SizedBox(height: 4));
              for (final t in noDate) {
                widgets.add(
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          width: 14,
                          height: 14,
                          decoration: pw.BoxDecoration(
                            color: t.completed ? sage : PdfColors.white,
                            border: pw.Border.all(
                              color: t.completed ? sage : line,
                              width: 1,
                            ),
                            borderRadius: const pw.BorderRadius.all(
                              pw.Radius.circular(3),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Text(
                          t.title,
                          style: pw.TextStyle(fontSize: 10, color: ink),
                        ),
                      ],
                    ),
                  ),
                );
              }
            }
            return widgets;
          },
        ),
      );

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name:
            'HeartPebble-Checkliste-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler beim Export: $e')));
      }
    }
  }

  // ── Erinnerungen-Einstellungen ──────────────────────────────
  void _showReminderSettings() {
    final openTasks =
        widget.tasks
            .where(
              (t) =>
                  t.category == 'timeline' &&
                  t.deleted == 0 &&
                  !t.completed &&
                  t.deadline != null &&
                  t.deadline!.isAfter(DateTime.now()),
            )
            .toList()
          ..sort((a, b) => a.deadline!.compareTo(b.deadline!));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReminderSettingsSheet(
        openTasks: openTasks,
        onSchedule: (task, duration) async {
          await NotificationService.instance.scheduleTaskNotification(
            task: task,
            duration: duration,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erinnerung für „${task.title}" gesetzt ✓'),
                backgroundColor: const Color(0xFF6B9E72),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onCancel: (task) async {
          if (task.id != null) {
            await NotificationService.instance.cancelTaskNotification(task.id!);
          }
        },
      ),
    );
  }

  void _showCreateChecklistDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkliste erstellen'),
        content: const Text(
          'Möchtest du die vollständige Hochzeits-Checkliste mit 86 Aufgaben erstellen?\n\nDie Aufgaben werden automatisch nach deinem Hochzeitsdatum terminiert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _createDefaultChecklist();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4607A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _showResetTimelineTasksDialog() {
    final timelineTasks = widget.tasks
        .where((t) => t.category == 'timeline')
        .toList();
    if (timelineTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Checklisten-Aufgaben vorhanden.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Checkliste löschen'),
        content: Text(
          'Möchtest du alle ${timelineTasks.length} Checklisten-Aufgaben löschen?\n\n'
          'Achtung: Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Ladeindikator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checkliste wird gelöscht…'),
                    ],
                  ),
                ),
              );
              for (final task in timelineTasks) {
                if (task.id != null) {
                  await widget.onDeleteTask(task.id!);
                }
              }
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
              await _loadTimelineMilestones();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Checkliste gelöscht.'),
                    backgroundColor: Color(0xFF6B9E72),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ja, alle löschen'),
          ),
        ],
      ),
    );
  }

  Future<void> _createDefaultChecklist() async {
    if (widget.weddingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst das Hochzeitsdatum festlegen.'),
        ),
      );
      return;
    }

    final weddingDate = widget.weddingDate!;
    final today = DateTime.now();

    // Zeige Ladeindikator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checkliste wird erstellt…'),
          ],
        ),
      ),
    );

    final defaultTasks = [
      {'title': 'Standesamt, Kirche oder beides?', 'months_before': 12},
      {'title': 'Hochzeitsdatum fixieren', 'months_before': 12},
      {'title': 'Termin Standesamt / Kirche fixieren', 'months_before': 11},
      {'title': 'Erste Gästeliste erstellen', 'months_before': 11},
      {'title': 'Budget festlegen', 'months_before': 11},
      {'title': 'Hochzeitsmotto und Farben festlegen', 'months_before': 10},
      {'title': 'Angebote von Locations einholen', 'months_before': 10},
      {'title': 'Location festlegen', 'months_before': 9},
      {'title': 'Hotelzimmer für Gäste reservieren', 'months_before': 9},
      {'title': '"Save the Date" versenden', 'months_before': 8},
      {'title': 'Trauzeugen offiziell fragen', 'months_before': 8},
      {'title': 'Erste Dienstleister-Anfragen', 'months_before': 8},
      {'title': 'Ablauf & Stil der Zeremonie grob planen', 'months_before': 7},
      {'title': 'Erste Überlegungen zu Flitterwochen', 'months_before': 7},
      {'title': 'Rechtliche Dokumente prüfen', 'months_before': 7},
      {'title': 'Versicherungen checken', 'months_before': 6},
      {'title': 'Ehe beim Standesamt anmelden', 'months_before': 6},
      {'title': 'Catering für das Fest buchen', 'months_before': 6},
      {'title': 'Fotograf & DJ buchen', 'months_before': 6},
      {'title': 'Finale Gästeliste erstellen', 'months_before': 6},
      {'title': 'Brautkleid aussuchen & bestellen', 'months_before': 6},
      {'title': 'Outfit für Bräutigam suchen', 'months_before': 6},
      {'title': 'Einladungen bestellen / drucken', 'months_before': 5},
      {'title': 'JGA / Polterabend: Termin fixieren', 'months_before': 5},
      {'title': 'Adressen der Gäste sammeln', 'months_before': 5},
      {'title': 'Hochzeitsliste einrichten', 'months_before': 5},
      {'title': 'Videograf buchen', 'months_before': 5},
      {'title': 'Unterlagen sammeln und ordnen', 'months_before': 5},
      {'title': 'Papeterie-Konzept festlegen', 'months_before': 5},
      {'title': 'Kinderprogramm organisieren', 'months_before': 5},
      {'title': 'Transport / Shuttle buchen', 'months_before': 5},
      {'title': 'Probeessen beim Caterer vereinbaren', 'months_before': 5},
      {'title': 'Songauswahl mit Musiker abstimmen', 'months_before': 5},
      {'title': 'Ablaufplan für den Tag grob erstellen', 'months_before': 5},
      {'title': 'Traugespräch mit Pfarrer vereinbaren', 'months_before': 4},
      {'title': 'Menü planen und festlegen', 'months_before': 4},
      {'title': 'Mit Floristen Blumen planen', 'months_before': 4},
      {'title': 'Trauringe bestellen', 'months_before': 4},
      {'title': 'Einladungen versenden', 'months_before': 4},
      {'title': 'Drucksorten beauftragen', 'months_before': 4},
      {'title': 'Brautschuhe & Co besorgen', 'months_before': 4},
      {'title': 'Hochzeitstorte bestellen', 'months_before': 4},
      {'title': 'Tischdekoration festlegen', 'months_before': 3},
      {'title': 'Hochzeitsdeko festlegen', 'months_before': 3},
      {'title': 'Frisur & Make-up testen', 'months_before': 3},
      {'title': 'Ablaufplan für den Tag detaillieren', 'months_before': 3},
      {'title': 'Menükarten / Tischkarten drucken', 'months_before': 3},
      {'title': 'Alle Dienstleister final bestätigen', 'months_before': 3},
      {'title': 'Rückmeldungen der Gäste einholen', 'months_before': 3},
      {'title': 'Tischplan erstellen', 'months_before': 2},
      {'title': 'Reden und Texte vorbereiten', 'months_before': 2},
      {'title': 'Hochzeitsreise buchen', 'months_before': 2},
      {'title': 'Letzte Anpassungen Kleid / Anzug', 'months_before': 2},
      {'title': 'Geschenkwünsche kommunizieren', 'months_before': 2},
      {'title': 'Notfall-Kit zusammenstellen', 'months_before': 1},
      {'title': 'Alle Zahlungen prüfen', 'months_before': 1},
      {'title': 'Reisedokumente prüfen', 'months_before': 1},
      {'title': 'Endgültigen Ablaufplan an alle senden', 'months_before': 1},
      {'title': 'Trauringe einpacken', 'months_before': 0},
      {'title': 'Haare & Make-up Termin', 'months_before': 0},
      {'title': 'Frühstück nicht vergessen!', 'months_before': 0},
      {'title': 'Hochzeitskleid / Anzug anlegen', 'months_before': 0},
      {'title': 'Brautstrauß abholen', 'months_before': 0},
      {
        'title': 'Standesamt / Kirche rechtzeitig erreichen',
        'months_before': 0,
      },
      {'title': 'Ehegelübde sprechen', 'months_before': 0},
      {'title': 'Danke-Karten vorbereiten', 'months_before': -1},
      {'title': 'Fotos aussortieren und bestellen', 'months_before': -1},
      {'title': 'Hochzeitsgeschenke verwalten', 'months_before': -1},
      {'title': 'Namensänderung beim Standesamt', 'months_before': -1},
      {
        'title': 'Bank, Versicherung, Ausweise aktualisieren',
        'months_before': -2,
      },
      {'title': 'Dienstleistern Bewertungen hinterlassen', 'months_before': -2},
    ];

    for (final t in defaultTasks) {
      final monthsBefore = t['months_before'] as int;
      DateTime deadline;

      if (monthsBefore > 0) {
        final ideal = DateTime(
          weddingDate.year,
          weddingDate.month - monthsBefore,
          weddingDate.day,
        );
        if (ideal.isBefore(today)) {
          final overdue = today.difference(ideal).inDays;
          if (overdue <= 30)
            deadline = today.add(const Duration(days: 2));
          else if (overdue <= 90)
            deadline = today.add(const Duration(days: 7));
          else if (overdue <= 180)
            deadline = today.add(const Duration(days: 14));
          else
            deadline = today.add(const Duration(days: 30));
        } else {
          deadline = ideal;
        }
      } else if (monthsBefore < 0) {
        deadline = DateTime(
          weddingDate.year,
          weddingDate.month - monthsBefore,
          weddingDate.day,
        );
      } else {
        deadline = weddingDate;
      }

      final priority = monthsBefore >= 6
          ? 'low'
          : monthsBefore >= 3
          ? 'medium'
          : 'high';

      await widget.onAddTask(
        Task(
          title: t['title'] as String,
          description: '',
          category: 'timeline',
          priority: priority,
          deadline: deadline,
          completed: false,
          createdDate: DateTime.now(),
        ),
      );
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    await _loadTimelineMilestones();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ 70 Aufgaben erstellt!'),
          backgroundColor: Color(0xFF6B9E72),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Widget _buildProgressBanner() {
    final total = widget.tasks.length;
    final done = widget.tasks.where((t) => t.completed).length;
    final pct = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border.all(color: Color(0xFFECE8F2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$done / $total',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1625),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'Aufgaben erledigt',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8299)),
          ),
          const Spacer(),
          Text(
            '${(pct * 100).round()}%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFD4607A),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // TAB 2 – HOCHZEITSTAG
  // ─────────────────────────────────────────────────────────

  Widget _buildWeddingDayTab() {
    final isPremium = PremiumService.instance.isPremium;

    // Free-Nutzer: Teaser-Ansicht mit gesperrten Blöcken
    if (!isPremium) {
      return _buildWeddingDayTeaser();
    }

    // Premium: vollständiger Tab
    final allTasks = _dayBlocks.expand((b) => b.tasks).toList();
    final doneTasks = allTasks.where((t) => t.done).length;
    final pct = allTasks.isEmpty ? 0.0 : doneTasks / allTasks.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Datum-Banner
          if (widget.weddingDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D2740), Color(0xFF3D2D5E)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text('💍', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unser Hochzeitstag',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.08,
                        ),
                      ),
                      Text(
                        _formatDate(widget.weddingDate!),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$doneTasks/${allTasks.length}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE8849A),
                        ),
                      ),
                      const Text(
                        'erledigt',
                        style: TextStyle(fontSize: 10, color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Fortschrittsbalken
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Color(0xFFFFFFFF),
              border: Border.all(color: Color(0xFFECE8F2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tages-Fortschritt',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1625),
                      ),
                    ),
                    Text(
                      '${(pct * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD4607A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: Color(0xFFECE8F2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFD4607A)),
                  ),
                ),
              ],
            ),
          ),

          // Zeitblöcke
          ..._dayBlocks.map((block) => _buildDayBlock(block)),
        ],
      ),
    );
  }

  Widget _buildDayBlock(WeddingDayBlock block) {
    final doneCount = block.tasks.where((t) => t.done).length;
    final total = block.tasks.length;
    final blockPct = total > 0 ? doneCount / total : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border.all(color: Color(0xFFECE8F2)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Block-Header
            GestureDetector(
              onTap: () => setState(() => block.isExpanded = !block.isExpanded),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  children: [
                    // Farb-Indikator
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: block.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(block.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            block.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1625),
                            ),
                          ),
                          Text(
                            block.timeRange,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A8299),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mini-Fortschritt
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: doneCount == total && total > 0
                            ? const Color(0xFFEEF5EF)
                            : Color(0xFFF8F6FB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Color(0xFFECE8F2)),
                      ),
                      child: Text(
                        '$doneCount/$total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: doneCount == total && total > 0
                              ? Color(0xFF6B9E72)
                              : Color(0xFF8A8299),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      block.isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Color(0xFF8A8299),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            // Fortschrittsbalken
            LinearProgressIndicator(
              value: blockPct,
              minHeight: 2,
              backgroundColor: Color(0xFFECE8F2),
              valueColor: AlwaysStoppedAnimation(block.color),
            ),
            // Aufgaben
            if (block.isExpanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: Column(
                  children: [
                    ...block.tasks.map((task) => _buildDayTask(task, block)),
                    // Neue Aufgabe hinzufügen
                    _buildAddTaskRow(block),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDayTask(WeddingDayTask task, WeddingDayBlock block) {
    return GestureDetector(
      onTap: () => setState(() => task.done = !task.done),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: task.done ? Color(0xFFF8F6FB) : Color(0xFFFFFFFF),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: task.done ? block.color : Colors.transparent,
                border: Border.all(
                  color: task.done ? block.color : Color(0xFFECE8F2),
                  width: 1.5,
                ),
              ),
              child: task.done
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: task.done ? Color(0xFF8A8299) : Color(0xFF1A1625),
                      decoration: task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task.note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.note!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A8299),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Löschen
            GestureDetector(
              onTap: () => setState(() => block.tasks.remove(task)),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF8A8299),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTaskRow(WeddingDayBlock block) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _newTaskController,
              decoration: InputDecoration(
                hintText: 'Aufgabe hinzufügen …',
                hintStyle: const TextStyle(
                  color: Color(0xFF8A8299),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Color(0xFFF8F6FB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFECE8F2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFECE8F2)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  setState(() {
                    block.tasks.add(
                      WeddingDayTask(
                        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                        title: v.trim(),
                      ),
                    );
                    _newTaskController.clear();
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              final v = _newTaskController.text.trim();
              if (v.isNotEmpty) {
                setState(() {
                  block.tasks.add(
                    WeddingDayTask(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      title: v,
                    ),
                  );
                  _newTaskController.clear();
                });
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: block.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // HILFSMETHODEN
  // ─────────────────────────────────────────────────────────

  Widget _checkbox(bool checked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: checked ? Color(0xFFD4607A) : Colors.transparent,
        border: Border.all(
          color: checked ? Color(0xFFD4607A) : Color(0xFFECE8F2),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: checked
          ? const Icon(Icons.check, size: 11, color: Colors.white)
          : null,
    );
  }

  Widget _badgePill(String label, PhaseStatus status) {
    // done=grün, now=rose, future=grau
    Color bg, fg;
    switch (status) {
      case PhaseStatus.done:
        bg = const Color(0xFFEEF5EF);
        fg = const Color(0xFF4A7A4E);
      case PhaseStatus.now:
        bg = const Color(0xFFFDF3F5);
        fg = const Color(0xFFD4607A);
      case PhaseStatus.future:
        bg = const Color(0xFFF8F6FB);
        fg = const Color(0xFF8A8299);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: status == PhaseStatus.future
            ? Border.all(color: const Color(0xFFECE8F2))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  // Volles Datum für weddingDate
  String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    const days = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return '${days[d.weekday - 1]}., ${d.day}. ${months[d.month - 1]} ${d.year}';
  }

  // Kurzes Datum für Deadline-Anzeige in Task-Zeilen
  String _shortDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mär',
      'Apr',
      'Mai',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Okt',
      'Nov',
      'Dez',
    ];
    return '${d.day}. ${months[d.month - 1]}';
  }

  // ─────────────────────────────────────────────────────────
  // PREMIUM-HELPER
  // ─────────────────────────────────────────────────────────

  /// Zeigt den UpgradeBottomSheet für den Hochzeitstag-Tab.
  void _showWeddingDayUpgrade() {
    UpgradeBottomSheet.show(
      context,
      featureName: 'Hochzeitstag-Planer',
      featureDescription:
          'Dein persönlicher Ablaufplan für den schönsten Tag – '
          'von Getting Ready bis zur Party. Mit Checklisten, '
          'Notfall-Kontakten und Foto-Wunschliste.',
    );
  }

  /// Abschnitt-Header mit optionalem Premium-Schloss-Badge.
  Widget _buildPremiumSectionHeader({
    required String label,
    required bool isPremium,
    required VoidCallback onUpgrade,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1625),
          ),
        ),
        if (!isPremium) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Color(0xFFC9A052).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Color(0xFFC9A052).withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.workspace_premium,
                    size: 12,
                    color: Color(0xFFC9A052),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC9A052),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Gesperrter Platzhalter-Block mit Upgrade-CTA.
  Widget _buildLockedPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 40, color: Color(0xFFECE8F2)),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC9A052),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1625),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8A8299),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Color(0xFFD4607A),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFD4607A).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.workspace_premium, size: 16, color: Colors.white),
                  SizedBox(width: 7),
                  Text(
                    'Premium freischalten',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Teaser-Ansicht für den Hochzeitstag-Tab (Free-Nutzer).
  /// Zeigt alle Blöcke ausgegraut mit Schloss-Icon.
  Widget _buildWeddingDayTeaser() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium-Teaser-Banner
          GestureDetector(
            onTap: _showWeddingDayUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2D2740), Color(0xFF3D2D5E)],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('💍', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hochzeitstag-Planer',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Dein persönlicher Ablaufplan für den großen Tag',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Feature-Bullets
                  ...[
                    '⏰  Stunden-Ablaufplan von 7:00 bis open end',
                    '✅  Checklisten pro Block (Getting Ready, Trauung …)',
                    '📞  Notfall-Kontakte direkt anrufbar',
                    '📸  Foto-Wunschliste für den Fotografen',
                  ].map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        f,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFD4607A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFD4607A).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.workspace_premium,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Jetzt freischalten – 9,99 €',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Einmaliger Kauf · Kein Abo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gesperrte Block-Vorschau
          const Text(
            'Enthaltene Blöcke',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8A8299),
            ),
          ),
          const SizedBox(height: 10),
          ..._dayBlocks.map((block) => _buildLockedBlock(block)),
        ],
      ),
    );
  }

  /// Einzelner gesperrter Block in der Teaser-Ansicht.
  Widget _buildLockedBlock(WeddingDayBlock block) {
    return GestureDetector(
      onTap: _showWeddingDayUpgrade,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Color(0xFFFFFFFF),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            // Farb-Indikator (ausgegraut)
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: Color(0xFFECE8F2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              block.emoji,
              style: const TextStyle(fontSize: 18, color: Color(0xFF8A8299)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8A8299),
                    ),
                  ),
                  Text(
                    '${block.timeRange} · ${block.tasks.length} Aufgaben',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFECE8F2),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline, size: 16, color: Color(0xFFECE8F2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ERINNERUNGEN BOTTOM SHEET
// ─────────────────────────────────────────────────────────────

class _ReminderSettingsSheet extends StatefulWidget {
  final List<Task> openTasks;
  final Future<void> Function(Task task, Duration duration) onSchedule;
  final Future<void> Function(Task task) onCancel;

  const _ReminderSettingsSheet({
    required this.openTasks,
    required this.onSchedule,
    required this.onCancel,
  });

  @override
  State<_ReminderSettingsSheet> createState() => _ReminderSettingsSheetState();
}

class _ReminderSettingsSheetState extends State<_ReminderSettingsSheet> {
  // Welche Tasks haben eine Erinnerung? taskId → Duration
  final Map<int, Duration?> _reminders = {};
  bool _loading = false;

  // Optionen die der Nutzer wählen kann
  static const _options = [
    (label: '1 Tag vorher', duration: Duration(days: 1)),
    (label: '3 Tage vorher', duration: Duration(days: 3)),
    (label: '1 Woche vorher', duration: Duration(days: 7)),
    (label: '2 Wochen vorher', duration: Duration(days: 14)),
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingReminders();
  }

  Future<void> _loadExistingReminders() async {
    for (final task in widget.openTasks) {
      if (task.id == null) continue;
      final dur = await NotificationService.instance.getNotificationDuration(
        task.id!,
      );
      if (mounted) setState(() => _reminders[task.id!] = dur);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle + Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECE8F2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFD4607A),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Erinnerungen',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1625),
                            ),
                          ),
                          Text(
                            'Tippe auf eine Aufgabe um eine Erinnerung zu setzen',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF8A8299),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFECE8F2)),
              ],
            ),
          ),

          // Task-Liste
          Expanded(
            child: widget.openTasks.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Color(0xFF6B9E72),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Alle offenen Aufgaben erledigt!',
                          style: TextStyle(
                            color: Color(0xFF8A8299),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: widget.openTasks.length,
                    itemBuilder: (_, i) {
                      final task = widget.openTasks[i];
                      final existing = task.id != null
                          ? _reminders[task.id]
                          : null;
                      final hasReminder = existing != null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: hasReminder
                              ? const Color(0xFFF0F8F1)
                              : Colors.white,
                          border: Border.all(
                            color: hasReminder
                                ? const Color(0xFF6B9E72).withOpacity(0.4)
                                : const Color(0xFFECE8F2),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          leading: Icon(
                            hasReminder
                                ? Icons.notifications_active
                                : Icons.notifications_none,
                            color: hasReminder
                                ? const Color(0xFF6B9E72)
                                : const Color(0xFF8A8299),
                            size: 22,
                          ),
                          title: Text(
                            task.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1A1625),
                            ),
                          ),
                          subtitle: Text(
                            task.deadline != null
                                ? 'Fällig: ${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}'
                                      '${hasReminder ? ' · Erinnerung: ${_durationLabel(existing)}' : ''}'
                                : 'Kein Datum',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8A8299),
                            ),
                          ),
                          trailing: hasReminder
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Color(0xFF8A8299),
                                  ),
                                  onPressed: () async {
                                    await widget.onCancel(task);
                                    if (mounted) {
                                      setState(
                                        () => _reminders.remove(task.id),
                                      );
                                    }
                                  },
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFFECE8F2),
                                  size: 18,
                                ),
                          onTap: hasReminder
                              ? null
                              : () => _showPickDuration(task),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showPickDuration(Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          task.title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _options
              .map(
                (opt) => ListTile(
                  leading: const Icon(
                    Icons.alarm_outlined,
                    color: Color(0xFFD4607A),
                    size: 20,
                  ),
                  title: Text(opt.label, style: const TextStyle(fontSize: 14)),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _loading = true);
                    await widget.onSchedule(task, opt.duration);
                    if (mounted) {
                      setState(() {
                        _reminders[task.id!] = opt.duration;
                        _loading = false;
                      });
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );
  }

  String _durationLabel(Duration d) {
    if (d.inDays == 1) return '1 Tag vorher';
    if (d.inDays == 3) return '3 Tage vorher';
    if (d.inDays == 7) return '1 Woche vorher';
    if (d.inDays == 14) return '2 Wochen vorher';
    return '${d.inDays} Tage vorher';
  }
}
