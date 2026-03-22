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

import '../models/wedding_models.dart';
import '../app_colors.dart';
import '../data/database_helper.dart';
import '../sync/services/sync_service.dart';
import '../services/premium_service.dart';
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
  final String month;
  final String name;
  final int progressPercent;
  final PhaseStatus status;
  final String badge;
  final List<PhaseTask> tasks;

  const PlanningPhase({
    required this.month,
    required this.name,
    required this.progressPercent,
    required this.status,
    required this.badge,
    required this.tasks,
  });
}

class PhaseTask {
  final String title;
  final String due;
  final bool urgent;
  bool done;

  PhaseTask({
    required this.title,
    required this.due,
    this.urgent = false,
    this.done = false,
  });
}

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

  // ── Checkliste-State (aus bisherigem tasks_screen) ──────
  String _selectedFilter = 'all';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _timelineMilestones = [];

  // ── Meilenstein-Dashboard-State ─────────────────────────
  int _selectedPhaseIndex = 2;
  late List<PlanningPhase> _phases;

  // ── Hochzeitstag-State ───────────────────────────────────
  late List<WeddingDayBlock> _dayBlocks;
  final _newTaskController = TextEditingController();

  void _syncNow() {
    SyncService.instance.syncNow().catchError((e) {
      debugPrint('Sync error: $e');
    });
  }

  // ── Meilenstein-Phasen erzeugen ──────────────────────────
  List<PlanningPhase> _buildPhases(DateTime? weddingDate) {
    final now = DateTime.now();
    final diff = weddingDate != null ? weddingDate.difference(now).inDays : 180;

    PhaseStatus _s(int monthsBefore) {
      final threshold = diff - (monthsBefore * 30);
      if (threshold > 60) return PhaseStatus.future;
      if (threshold > -30) return PhaseStatus.now;
      return PhaseStatus.done;
    }

    return [
      PlanningPhase(
        month: '12 M',
        name: 'Erste Schritte',
        progressPercent: _s(12) == PhaseStatus.done
            ? 100
            : _s(12) == PhaseStatus.now
            ? 60
            : 0,
        status: _s(12),
        badge: _s(12) == PhaseStatus.done
            ? 'Erledigt'
            : _s(12) == PhaseStatus.now
            ? 'Jetzt'
            : 'Geplant',
        tasks: [
          PhaseTask(
            title: 'Budget festlegen',
            due: '12 M vorher',
            done: _s(12) == PhaseStatus.done,
          ),
          PhaseTask(
            title: 'Gästeliste grob erstellen',
            due: '12 M vorher',
            done: _s(12) == PhaseStatus.done,
          ),
          PhaseTask(
            title: 'Hochzeitsdatum fixieren',
            due: '12 M vorher',
            done: _s(12) == PhaseStatus.done,
          ),
        ],
      ),
      PlanningPhase(
        month: '9 M',
        name: 'Location & Foto',
        progressPercent: _s(9) == PhaseStatus.done
            ? 100
            : _s(9) == PhaseStatus.now
            ? 40
            : 0,
        status: _s(9),
        badge: _s(9) == PhaseStatus.done
            ? 'Erledigt'
            : _s(9) == PhaseStatus.now
            ? 'Jetzt'
            : 'Geplant',
        tasks: [
          PhaseTask(
            title: 'Location buchen',
            due: '9 M vorher',
            done: _s(9) == PhaseStatus.done,
          ),
          PhaseTask(
            title: 'Fotograf bestätigen',
            due: '9 M vorher',
            done: _s(9) == PhaseStatus.done,
          ),
          PhaseTask(
            title: 'Trauung anmelden',
            due: '9 M vorher',
            done: _s(9) == PhaseStatus.done,
          ),
        ],
      ),
      PlanningPhase(
        month: '6 M',
        name: 'Einladungen',
        progressPercent: _s(6) == PhaseStatus.done
            ? 100
            : _s(6) == PhaseStatus.now
            ? 33
            : 0,
        status: _s(6),
        badge: _s(6) == PhaseStatus.done
            ? 'Erledigt'
            : _s(6) == PhaseStatus.now
            ? 'Jetzt'
            : 'Geplant',
        tasks: [
          PhaseTask(title: 'Design auswählen', due: 'Erledigt', done: true),
          PhaseTask(
            title: 'Adressen sammeln',
            due: 'Diese Woche',
            urgent: _s(6) == PhaseStatus.now,
          ),
          PhaseTask(title: 'Einladungen versenden', due: '2 Wochen'),
          PhaseTask(
            title: 'Menü bestätigen',
            due: '5 Tage',
            urgent: _s(6) == PhaseStatus.now,
          ),
        ],
      ),
      PlanningPhase(
        month: '3 M',
        name: 'Details & Deko',
        progressPercent: _s(3) == PhaseStatus.done
            ? 100
            : _s(3) == PhaseStatus.now
            ? 10
            : 0,
        status: _s(3),
        badge: _s(3) == PhaseStatus.done
            ? 'Erledigt'
            : _s(3) == PhaseStatus.now
            ? 'Jetzt'
            : 'Geplant',
        tasks: [
          PhaseTask(title: 'Tischplan erstellen', due: '3 M vorher'),
          PhaseTask(title: 'Blumenschmuck finalisieren', due: '3 M vorher'),
          PhaseTask(title: 'Tischkarten drucken', due: '3 M vorher'),
        ],
      ),
      PlanningPhase(
        month: '1 M',
        name: 'Finale Vorbereitung',
        progressPercent: 0,
        status: PhaseStatus.future,
        badge: 'Geplant',
        tasks: [
          PhaseTask(title: 'Ringe abholen', due: '1 M vorher'),
          PhaseTask(title: 'Ablaufplan finalisieren', due: '1 M vorher'),
          PhaseTask(title: 'Danke-Karten vorbereiten', due: '1 M vorher'),
        ],
      ),
    ];
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
          _buildPhaseDetail(phase),
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
        final urgentTasks = p.tasks.where((t) => !t.done).take(3).toList();
        if (urgentTasks.isEmpty) return const SizedBox.shrink();
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
                  color: p.status == PhaseStatus.done
                      ? Color(0xFF6B9E72)
                      : p.status == PhaseStatus.now
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
                            '${String.fromCharCode(0x30 + i + 1).padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8A8299),
                              letterSpacing: 0.1,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          _badgePill(p.badge, p.status),
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
                      ...urgentTasks.map((t) => _buildPhaseTask(t)),
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
                  _buildHDot(p.status),
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
                        Text(
                          '${p.progressPercent}%',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF8A8299),
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

  Widget _buildHDot(PhaseStatus s) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: s != PhaseStatus.future ? Color(0xFFD4607A) : Color(0xFFFFFFFF),
        border: Border.all(
          color: s != PhaseStatus.future
              ? Color(0xFFD4607A)
              : Color(0xFFECE8F2),
          width: 2,
        ),
        boxShadow: s == PhaseStatus.now
            ? [
                BoxShadow(
                  color: Color(0xFFD4607A).withOpacity(0.4),
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
  Widget _buildPhaseDetail(PlanningPhase phase) {
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
              _badgePill(phase.badge, phase.status),
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
            ],
          ),
          const SizedBox(height: 12),
          ...phase.tasks.map((t) => _buildPhaseTask(t)),
        ],
      ),
    );
  }

  Widget _buildPhaseTask(PhaseTask task) {
    return GestureDetector(
      onTap: () => setState(() => task.done = !task.done),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Color(0xFFF8F6FB),
          border: Border.all(color: Color(0xFFECE8F2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _checkbox(task.done),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 13,
                  color: task.done ? Color(0xFF8A8299) : Color(0xFF1A1625),
                  decoration: task.done ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              task.due,
              style: TextStyle(
                fontSize: 11,
                color: task.urgent ? Color(0xFFD4607A) : Color(0xFF8A8299),
                fontWeight: task.urgent ? FontWeight.w700 : FontWeight.normal,
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
                      _badgePill(p.badge, p.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...p.tasks.map((t) => _buildPhaseTask(t)),
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
        // Fortschritt + Premium-Schnellaktionen
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Column(
            children: [
              _buildProgressBanner(),
              const SizedBox(height: 8),
              Row(
                children: [
                  // PDF-Export – Premium
                  Expanded(
                    child: _buildChecklistActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF-Export',
                      isPremium: isPremium,
                      onTap: isPremium
                          ? () {
                              /* PDF-Export starten */
                            }
                          : () => UpgradeBottomSheet.show(
                              context,
                              featureName: 'Checklisten-Export',
                              featureDescription:
                                  'Exportiere deine komplette Checkliste als PDF – '
                                  'perfekt zum Ausdrucken oder Teilen.',
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Partner-Sync – Premium
                  Expanded(
                    child: _buildChecklistActionButton(
                      icon: Icons.people_outline,
                      label: 'Partner-Sync',
                      isPremium: isPremium,
                      onTap: isPremium
                          ? () {
                              /* Partner-Sync öffnen */
                            }
                          : () => UpgradeBottomSheet.show(
                              context,
                              featureName: 'Partner-Sync',
                              featureDescription:
                                  'Plant gemeinsam mit eurem Partner – '
                                  'Aufgaben synchronisieren sich automatisch auf beiden Geräten.',
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Erinnerungen – Premium
                  Expanded(
                    child: _buildChecklistActionButton(
                      icon: Icons.notifications_outlined,
                      label: 'Erinnerungen',
                      isPremium: isPremium,
                      onTap: isPremium
                          ? () {
                              /* Erinnerungen öffnen */
                            }
                          : () => UpgradeBottomSheet.show(
                              context,
                              featureName: 'Smarte Erinnerungen',
                              featureDescription:
                                  'Bekomme Push-Benachrichtigungen bevor Aufgaben fällig werden – '
                                  'nie wieder etwas vergessen.',
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
              if (_timelineMilestones.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        Icons.checklist_rounded,
                        size: 48,
                        color: Color(0xFF8A8299),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Checkliste wird geladen …',
                        style: TextStyle(color: Color(0xFF8A8299)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadTimelineMilestones,
                        child: const Text('Neu laden'),
                      ),
                    ],
                  ),
                )
              else
                // HIER: _buildTimeline(l10n) aus tasks_screen.dart einfügen
                const SizedBox(),
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
    Color bg, fg;
    switch (status) {
      case PhaseStatus.done:
        bg = Color(0xFFFDF3F5);
        fg = Color(0xFFD4607A);
      case PhaseStatus.now:
        bg = Color(0xFF2D2740);
        fg = Colors.white;
      case PhaseStatus.future:
        bg = Color(0xFFF8F6FB);
        fg = Color(0xFF8A8299);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: status == PhaseStatus.future
            ? Border.all(color: Color(0xFFECE8F2))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

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
