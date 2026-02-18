import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/wedding_models.dart';
import '../data/database_helper.dart';
import '../widgets/task_donut_chart.dart';
import '../services/excel_export_service.dart';
import '../services/calendar_export_service.dart';
import '../services/notification_service.dart';
import '../utils/category_utils.dart';

class TaskPage extends StatefulWidget {
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

  const TaskPage({
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
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all';
  Task? _editingTask;
  String _searchQuery = '';

  late TabController _tabController;
  int _currentTab = 0;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  String _selectedCategory = 'other';
  String _selectedPriority = 'medium';
  DateTime? _selectedDeadline;
  List<Map<String, dynamic>> _timelineMilestones = [];

  final Map<String, String> _categoryLabels = {
    'location': 'Location',
    'catering': 'Catering',
    'decoration': 'Dekoration',
    'clothing': 'Kleidung',
    'documentation': 'Dokumente',
    'music': 'Musik',
    'photography': 'Fotografie',
    'flowers': 'Blumen',
    'timeline': 'Timeline',
    'other': 'Sonstiges',
  };

  final Map<String, String> _priorityLabels = {
    'high': 'Hoch',
    'medium': 'Mittel',
    'low': 'Niedrig',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTab = _tabController.index;
      });
    });
    _loadTimelineMilestones();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.selectedTaskId != null) {
        _openTaskById(widget.selectedTaskId!);
      }
    });
  }

  void _openTaskById(int taskId) {
    final task = widget.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => Task(
        title: '',
        category: 'other',
        priority: 'medium',
        completed: false,
        createdDate: DateTime.now(),
      ),
    );
    if (task.id != null) {
      Future.delayed(const Duration(milliseconds: 100), () => _editTask(task));
      widget.onClearSelectedTask?.call();
    }
  }

  // ═══════════════════════════════════════════════════════
  // EXPORT DIALOGE
  // ═══════════════════════════════════════════════════════

  Future<void> _showExportDialog() async {
    if (widget.tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Aufgaben zum Exportieren vorhanden'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgaben exportieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.table_chart,
                color: Colors.green,
                size: 32,
              ),
              title: const Text('Als Excel exportieren'),
              subtitle: const Text('Alle Aufgaben mit Details'),
              onTap: () {
                Navigator.pop(context);
                _exportAsExcel();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.calendar_today,
                color: Colors.blue,
                size: 32,
              ),
              title: const Text('In Kalender exportieren'),
              subtitle: const Text('Mit konfigurierbaren Erinnerungen'),
              onTap: () {
                Navigator.pop(context);
                _showCalendarExportOptionsDialog(onlyTimeline: false);
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

  Future<void> _showCalendarExportOptionsDialog({
    required bool onlyTimeline,
  }) async {
    final tasksToConsider = onlyTimeline
        ? widget.tasks.where((t) => t.category == 'timeline').toList()
        : widget.tasks;

    if (tasksToConsider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            onlyTimeline
                ? 'Keine Timeline-Aufgaben zum Exportieren vorhanden'
                : 'Keine Aufgaben zum Exportieren vorhanden',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool onlyOpenTasks = false;
    Set<String> selectedReminders = {'1day'};

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Kalender-Export konfigurieren'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aufgaben-Filter',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Nur offene Aufgaben'),
                    subtitle: const Text('Erledigte Aufgaben ausschließen'),
                    value: onlyOpenTasks,
                    onChanged: (value) {
                      setDialogState(() {
                        onlyOpenTasks = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  const Divider(height: 24),
                  const Text(
                    'Erinnerungen',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wählen Sie, wann Sie erinnert werden möchten:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('1 Tag vorher'),
                    value: selectedReminders.contains('1day'),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedReminders.add('1day');
                        } else {
                          selectedReminders.remove('1day');
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('3 Tage vorher'),
                    value: selectedReminders.contains('3days'),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedReminders.add('3days');
                        } else {
                          selectedReminders.remove('3days');
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('1 Woche vorher'),
                    value: selectedReminders.contains('1week'),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedReminders.add('1week');
                        } else {
                          selectedReminders.remove('1week');
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('2 Wochen vorher'),
                    value: selectedReminders.contains('2weeks'),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selectedReminders.add('2weeks');
                        } else {
                          selectedReminders.remove('2weeks');
                        }
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                  ),
                  if (selectedReminders.isEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Keine Erinnerungen ausgewählt',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _exportToCalendar(
                    onlyTimeline: onlyTimeline,
                    onlyOpenTasks: onlyOpenTasks,
                    reminderOptions: selectedReminders.toList(),
                  );
                },
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Exportieren'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TIMELINE CHECKLISTE
  // ═══════════════════════════════════════════════════════

  Future<void> _initializeDefaultMilestonesManually() async {
    if (widget.weddingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte legen Sie zuerst ein Hochzeitsdatum fest'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final timelineTasks = widget.tasks
        .where((t) => t.category == 'timeline')
        .toList();

    if (timelineTasks.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Warnung'),
          content: Text(
            'Es sind bereits ${timelineTasks.length} Timeline-Aufgaben vorhanden. '
            'Möchten Sie diese löschen und die Standard-Checkliste neu erstellen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Ja, neu erstellen',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      for (final task in timelineTasks) {
        if (task.id != null) {
          await DatabaseHelper.instance.deleteTask(task.id!);
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    await _initializeDefaultMilestones();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Timeline-Checkliste wurde erstellt'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _initializeDefaultMilestones() async {
    if (widget.weddingDate == null) return;

    final defaultMilestones = [
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
      {
        'title':
            'Erste Dienstleister-Anfragen (Trauredner, Kinderbetreuung, Shuttle-Service)',
        'months_before': 8,
      },
      {'title': 'Ablauf & Stil der Zeremonie grob planen', 'months_before': 7},
      {'title': 'Erste Überlegungen zu Flitterwochen', 'months_before': 7},
      {'title': 'Rechtliche Dokumente prüfen', 'months_before': 7},
      {'title': 'Versicherungen checken', 'months_before': 6},
      {'title': 'Ehe beim Standesamt anmelden', 'months_before': 6},
      {'title': 'Catering für das Fest buchen', 'months_before': 6},
      {'title': 'Fotograf, Musik / DJ buchen', 'months_before': 6},
      {'title': 'Finale Gästeliste erstellen', 'months_before': 6},
      {'title': 'Brautkleid aussuchen & bestellen', 'months_before': 6},
      {'title': 'Outfit für Bräutigam suchen', 'months_before': 6},
      {'title': 'Einladungen bestellen / drucken', 'months_before': 5},
      {'title': 'JGA / Polterabend: Termin fixieren', 'months_before': 5},
      {'title': 'Adressen der Gäste sammeln', 'months_before': 5},
      {'title': 'Hochzeitsliste / -tisch einrichten', 'months_before': 5},
      {'title': 'Hochzeitsvideo: Videograf buchen', 'months_before': 5},
      {'title': 'Unterlagen sammeln und ordnen', 'months_before': 5},
      {'title': 'Papeterie-Konzept komplett festlegen', 'months_before': 5},
      {'title': 'Hochzeitswebseite/App anlegen', 'months_before': 5},
      {
        'title': 'Kinderprogramm oder Betreuung organisieren',
        'months_before': 5,
      },
      {
        'title': 'Transport / Shuttle / Hochzeitsauto buchen',
        'months_before': 5,
      },
      {'title': 'Probeessen beim Caterer vereinbaren', 'months_before': 5},
      {'title': 'Musiker/Redner Songauswahl abstimmen', 'months_before': 5},
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
      {'title': 'Hochzeitstanz auswählen und üben', 'months_before': 3},
      {
        'title': 'Musikwünsche / "Must Play / Don\'t Play"-Liste erstellen',
        'months_before': 3,
      },
      {
        'title': 'Ablauf und Redezeiten mit Trauzeugen abstimmen',
        'months_before': 3,
      },
      {
        'title': 'Technik prüfen: Mikrofone, Beamer, Lautsprecher',
        'months_before': 3,
      },
      {'title': 'Programmheft für Gäste gestalten', 'months_before': 3},
      {'title': 'Backup-Plan für schlechtes Wetter planen', 'months_before': 3},
      {'title': 'Gastgeschenke organisieren', 'months_before': 2},
      {'title': 'Probetermin Frisur und Make-Up', 'months_before': 2},
      {'title': 'Sitzordnung für die Feier planen', 'months_before': 2},
      {'title': 'Brautkleid / Anzug probieren / ändern', 'months_before': 2},
      {'title': 'Tagesablauf festlegen', 'months_before': 2},
      {'title': 'Absprache Location / Restaurant', 'months_before': 2},
      {'title': 'JGA / Polterabend feiern', 'months_before': 2},
      {'title': 'Schuhe Probe tragen', 'months_before': 2},
      {'title': 'Eheringe abholen', 'months_before': 1},
      {
        'title': 'Notfallkörbchen für Toiletten zusammenstellen',
        'months_before': 1,
      },
      {
        'title': 'Ansprechpartner für Dienstleister am Hochzeitstag benennen',
        'months_before': 1,
      },
      {
        'title': 'Gästeliste final bestätigen (Absagen/Zusagen)',
        'months_before': 1,
      },
      {'title': 'Endgültige Sitzordnung drucken lassen', 'months_before': 1},
      {
        'title': 'Zahlungspläne / Restbeträge an Dienstleister vorbereiten',
        'months_before': 1,
      },
      {'title': 'Brautstrauß & Anstecker final bestellen', 'months_before': 1},
      {
        'title': 'Eheversprechen oder Reden schreiben / üben',
        'months_before': 1,
      },
      {'title': 'Entertainment für Kinder besorgen', 'months_before': 1},
      {'title': 'Notfallset Braut vorbereiten', 'months_before': 1},
      {'title': 'Ablaufplan finalisieren', 'months_before': 0},
      {'title': 'Maniküre / Pediküre / Massage', 'months_before': 0},
      {'title': 'Kleidung und Dokumente vorbereiten', 'months_before': 0},
      {'title': 'Location dekorationsfertig überprüfen', 'months_before': 0},
      {
        'title': 'Notfallkontakte & Ablaufplan an Trauzeugen weitergeben',
        'months_before': 0,
      },
      {
        'title': 'Trinkgelder für Dienstleister vorbereiten',
        'months_before': 0,
      },
      {
        'title': 'Letzte Abstimmungen mit Fotograf / Videograf',
        'months_before': 0,
      },
      {'title': 'Hochzeitsauto schmücken / organisieren', 'months_before': 0},
      {'title': 'Entspannungszeit einplanen', 'months_before': 0},
      {'title': 'Dankeskarten verschicken', 'months_before': -1},
      {'title': 'Hochzeitskleid reinigen / aufbewahren', 'months_before': -1},
      {'title': 'Fotos / Video auswählen & abholen', 'months_before': -1},
      {
        'title': 'Bewertungen/Feedback für Dienstleister geben',
        'months_before': -1,
      },
      {'title': 'Namensänderungen durchführen', 'months_before': -1},
      {'title': 'Gästeliste mit Adressen sichern', 'months_before': -1},
    ];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weddingDate = widget.weddingDate!;

    for (final milestone in defaultMilestones) {
      final monthsBefore = milestone['months_before'] as int;
      DateTime deadline;

      if (monthsBefore > 0) {
        final idealDate = DateTime(
          weddingDate.year,
          weddingDate.month - monthsBefore,
          weddingDate.day,
        );
        if (idealDate.isBefore(today)) {
          final daysOverdue = today.difference(idealDate).inDays;
          if (daysOverdue <= 30) {
            deadline = today.add(const Duration(days: 2));
          } else if (daysOverdue <= 90) {
            deadline = today.add(const Duration(days: 7));
          } else if (daysOverdue <= 180) {
            deadline = today.add(const Duration(days: 14));
          } else {
            deadline = today.add(const Duration(days: 30));
          }
        } else {
          deadline = idealDate;
        }
      } else if (monthsBefore < 0) {
        deadline = DateTime(
          weddingDate.year,
          weddingDate.month + (-monthsBefore),
          weddingDate.day,
        );
      } else {
        deadline = weddingDate.subtract(const Duration(days: 7));
        if (deadline.isBefore(today)) {
          deadline = today.add(const Duration(days: 1));
        }
      }

      String priority;
      if (monthsBefore >= 6) {
        priority = 'low';
      } else if (monthsBefore >= 3) {
        priority = 'medium';
      } else {
        priority = 'high';
      }

      widget.onAddTask(
        Task(
          title: milestone['title'] as String,
          description: '',
          category: 'timeline',
          priority: priority,
          deadline: deadline,
          completed: false,
          createdDate: DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadTimelineMilestones() async {
    setState(() {
      _timelineMilestones = [];
    });
  }

  // ═══════════════════════════════════════════════════════
  // KALENDER EXPORT (Einzel-Task)
  // ═══════════════════════════════════════════════════════

  Future<void> _exportSingleTaskToCalendar(Task task) async {
    if (task.deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Diese Aufgabe hat keine Deadline – Export nicht möglich',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await CalendarExportService.exportTasksToCalendar(
        tasks: [task],
        brideName: widget.brideName,
        groomName: widget.groomName,
        reminderOptions: const ['1day'],
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('"${task.title}" in Kalender exportiert')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // GOOGLE MAPS
  // ═══════════════════════════════════════════════════════

  Future<void> _openInGoogleMaps(String location) async {
    if (location.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Maps konnte nicht geöffnet werden'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // NOTIFICATION DIALOG
  // ═══════════════════════════════════════════════════════

  Future<void> _showNotificationDialog(Task task) async {
    if (task.deadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diese Aufgabe hat keine Deadline'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final notificationService = NotificationService();
    final hasPermission = await notificationService.hasPermission();

    if (!hasPermission && mounted) {
      final shouldRequest = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Benachrichtigungen'),
            ],
          ),
          content: const Text(
            'HeartPebble möchte Ihnen Erinnerungen senden.\n\nErlauben Sie Benachrichtigungen?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Nein'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Ja, erlauben'),
            ),
          ],
        ),
      );
      if (shouldRequest != true) return;
      final granted = await notificationService.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Benachrichtigungen wurden nicht erlaubt.'),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'Einstellungen',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }
    }

    final hasNotification = await notificationService.hasNotification(task.id!);
    Duration? currentDuration;
    if (hasNotification) {
      currentDuration = await notificationService.getNotificationDuration(
        task.id!,
      );
    }
    if (!mounted) return;
    Duration? selectedDuration = currentDuration;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('Erinnerung einrichten')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Deadline: ${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ...[
                {
                  'duration': Duration.zero,
                  'label': 'Am selben Tag (08:00 Uhr)',
                },
                {'duration': const Duration(days: 1), 'label': '1 Tag vorher'},
                {'duration': const Duration(days: 3), 'label': '3 Tage vorher'},
                {
                  'duration': const Duration(days: 7),
                  'label': '1 Woche vorher',
                },
                {
                  'duration': const Duration(days: 14),
                  'label': '2 Wochen vorher',
                },
              ].map(
                (r) => _buildReminderOption(
                  context: dialogContext,
                  duration: r['duration'] as Duration,
                  label: r['label'] as String,
                  isSelected: selectedDuration == r['duration'],
                  onTap: () => setDialogState(
                    () => selectedDuration = r['duration'] as Duration,
                  ),
                ),
              ),
              if (hasNotification && currentDuration != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Aktiv: ${_formatReminderDuration(currentDuration)}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (hasNotification)
              TextButton(
                onPressed: () async {
                  await notificationService.cancelTaskNotification(task.id!);
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Erinnerung entfernt'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: const Text(
                  'Entfernen',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: selectedDuration == null
                  ? null
                  : () async {
                      final success = await notificationService
                          .scheduleTaskNotification(
                            task: task,
                            duration: selectedDuration!,
                          );
                      if (mounted) {
                        Navigator.pop(dialogContext);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Erinnerung: ${_formatReminderDuration(selectedDuration!)}'
                                  : 'Fehler beim Setzen der Erinnerung',
                            ),
                            backgroundColor: success
                                ? Colors.green
                                : Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // HILFSMETHODEN
  // ═══════════════════════════════════════════════════════

  Color _getTaskTimelineColor(Task task) {
    if (task.completed) return Colors.green;
    switch (task.priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  List<Task> get _filteredTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return widget.tasks.where((task) {
      bool matchesFilter = false;
      switch (_selectedFilter) {
        case 'all':
          matchesFilter = true;
          break;
        case 'completed':
          matchesFilter = task.completed;
          break;
        case 'pending':
          matchesFilter = !task.completed;
          break;
        case 'overdue':
          matchesFilter =
              !task.completed &&
              task.deadline != null &&
              task.deadline!.isBefore(today);
          break;
        default:
          matchesFilter = task.category == _selectedFilter;
      }

      if (!matchesFilter) return false;
      if (_searchQuery.isEmpty) return true;

      final query = _searchQuery.toLowerCase();
      return task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          (_categoryLabels[task.category] ?? task.category)
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  int get _pendingTasksCount => widget.tasks.where((t) => !t.completed).length;
  int get _completedTasksCount => widget.tasks.where((t) => t.completed).length;
  int get _overdueTasksCount {
    final today = DateTime.now();
    return widget.tasks
        .where(
          (t) =>
              !t.completed && t.deadline != null && t.deadline!.isBefore(today),
        )
        .length;
  }

  void _handleSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
    });
  }

  void _showDetailedForm() {
    setState(() {
      _editingTask = null;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _selectedCategory = 'other';
      _selectedPriority = 'medium';
      _selectedDeadline = null;
    });
    _showFormDialog();
  }

  void _editTask(Task task) {
    setState(() {
      _editingTask = task;
      _titleController.text = task.title;
      _descriptionController.text = task.description;
      _locationController.text = task.location;
      _selectedCategory = task.category;
      _selectedPriority = task.priority;
      _selectedDeadline = task.deadline;
    });
    _showFormDialog();
  }

  void _showFormDialog() {
    final scheme = Theme.of(context).colorScheme;

    String localCategory = _selectedCategory;
    String localPriority = _selectedPriority;
    DateTime? localDeadline = _selectedDeadline;

    showDialog(
      context: context,
      builder: (builderContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(_editingTask != null ? 'Bearbeiten' : 'Neue Aufgabe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titel',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: localCategory,
                  decoration: InputDecoration(
                    labelText: 'Kategorie',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(
                      CategoryUtils.getCategoryIcon(localCategory),
                      color: CategoryUtils.getCategoryColor(localCategory),
                    ),
                  ),
                  items: CategoryUtils.categoryLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Row(
                            children: [
                              Icon(
                                CategoryUtils.getCategoryIcon(e.key),
                                color: CategoryUtils.getCategoryColor(e.key),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(e.value),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    localCategory = value!;
                    _selectedCategory = value;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: localPriority,
                  decoration: const InputDecoration(
                    labelText: 'Priorität',
                    border: OutlineInputBorder(),
                  ),
                  items: _priorityLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    localPriority = value!;
                    _selectedPriority = value;
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: 'Ort',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.place),
                    suffixIcon: _locationController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.map, color: Colors.blue),
                            onPressed: () =>
                                _openInGoogleMaps(_locationController.text),
                            tooltip: 'In Google Maps öffnen',
                          )
                        : null,
                  ),
                  onChanged: (v) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          'Deadline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              localDeadline != null
                                  ? '${localDeadline!.day}.${localDeadline!.month}.${localDeadline!.year}'
                                  : 'Kein Datum gesetzt',
                              style: TextStyle(
                                fontSize: 16,
                                color: localDeadline != null
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_calendar,
                              color: Colors.blue,
                            ),
                            tooltip: 'Datum ändern',
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    localDeadline ??
                                    DateTime.now().add(const Duration(days: 1)),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 1460),
                                ),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  localDeadline = date;
                                  _selectedDeadline = date;
                                });
                              }
                            },
                          ),
                          if (localDeadline != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              tooltip: 'Datum entfernen',
                              onPressed: () => setDialogState(() {
                                localDeadline = null;
                                _selectedDeadline = null;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(builderContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                _selectedCategory = localCategory;
                _selectedPriority = localPriority;
                _selectedDeadline = localDeadline;
                _handleSubmit();
                Navigator.pop(builderContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: Text(_editingTask != null ? 'Speichern' : 'Erstellen'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_titleController.text.trim().isEmpty) return;

    final taskData = Task(
      id: _editingTask?.id,
      title: _titleController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      priority: _selectedPriority,
      deadline: _selectedDeadline,
      completed: _editingTask?.completed ?? false,
      createdDate: _editingTask?.createdDate ?? DateTime.now(),
    );

    if (_editingTask != null) {
      widget.onUpdateTask(taskData);
    } else {
      widget.onAddTask(taskData);
    }
  }

  void _toggleTaskComplete(Task task) {
    widget.onUpdateTask(task.copyWith(completed: !task.completed));
  }

  Future<void> _exportAsExcel() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      await ExcelExportService.exportTasksToExcel(widget.tasks);
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Excel-Datei erfolgreich erstellt!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Erstellen: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _exportToCalendar({
    required bool onlyTimeline,
    bool onlyOpenTasks = false,
    List<String> reminderOptions = const ['1day'],
  }) async {
    try {
      List<Task> tasksToExport = onlyTimeline
          ? widget.tasks.where((t) => t.category == 'timeline').toList()
          : widget.tasks;

      if (onlyOpenTasks) {
        tasksToExport = tasksToExport.where((t) => !t.completed).toList();
      }

      final tasksWithDeadline = tasksToExport
          .where((t) => t.deadline != null)
          .toList();

      if (tasksWithDeadline.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              onlyOpenTasks
                  ? 'Keine offenen Aufgaben mit Deadlines zum Exportieren'
                  : 'Keine Aufgaben mit Deadlines zum Exportieren',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await CalendarExportService.exportTasksToCalendar(
        tasks: tasksWithDeadline,
        brideName: widget.brideName,
        groomName: widget.groomName,
        reminderOptions: reminderOptions,
      );

      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tasksWithDeadline.length} Aufgaben als Kalender-Datei exportiert',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Fehler beim Export: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onSurfaceVariant,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(icon: Icon(Icons.assignment, size: 20), text: 'Aufgaben'),
              Tab(icon: Icon(Icons.timeline, size: 20), text: 'Timeline'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildTasksTab(), _buildTimelineTab()],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // AUFGABEN TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildTasksTab() {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: dividerColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Aufgaben-Verwaltung',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _showExportDialog,
                        icon: const Icon(Icons.share, size: 20),
                        tooltip: 'Exportieren',
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.secondaryContainer,
                          foregroundColor: scheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _showDetailedForm,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Neu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: const Size(80, 80),
                              painter: TaskDonutChartPainter(
                                completed: _completedTasksCount,
                                pending: _pendingTasksCount,
                                overdue: _overdueTasksCount,
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.tasks.isNotEmpty
                                        ? '${((_completedTasksCount / widget.tasks.length) * 100).toStringAsFixed(0)}%'
                                        : '0%',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    'erledigt',
                                    style: TextStyle(fontSize: 8),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildCompactStat(
                                  'Gesamt',
                                  widget.tasks.length.toString(),
                                  Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                _buildCompactStat(
                                  'Offen',
                                  _pendingTasksCount.toString(),
                                  Colors.orange,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildCompactStat(
                                  'Erledigt',
                                  _completedTasksCount.toString(),
                                  Colors.green,
                                ),
                                const SizedBox(width: 8),
                                _buildCompactStat(
                                  'Überfällig',
                                  _overdueTasksCount.toString(),
                                  Colors.red,
                                ),
                              ],
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
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: dividerColor, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Aufgaben durchsuchen...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (value) => _handleSearch(),
                      onSubmitted: (_) => _handleSearch(),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Suche löschen',
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _handleSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                    ),
                    child: const Text('Suche', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildCompactFilter(),
          const SizedBox(height: 8),
          Expanded(
            child: _filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.assignment,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Keine Ergebnisse für "$_searchQuery"'
                              : 'Keine Aufgaben gefunden.',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.clear),
                            label: const Text('Suche zurücksetzen'),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredTasks.length,
                    itemBuilder: (context, index) {
                      return _buildCompactTaskCard(_filteredTasks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactFilter() {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 35,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('all', 'Alle', null, scheme),
          _buildFilterChip('pending', 'Offen', null, scheme),
          _buildFilterChip('completed', 'Erledigt', null, scheme),
          _buildFilterChip('overdue', 'Überfällig', null, scheme),
          ...CategoryUtils.categoryLabels.entries.map(
            (e) => _buildFilterChip(
              e.key,
              e.value,
              CategoryUtils.getCategoryColor(e.key),
              scheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String value,
    String label,
    Color? catColor,
    ColorScheme scheme,
  ) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (catColor != null) ...[
              Icon(
                CategoryUtils.getCategoryIcon(value),
                size: 13,
                color: isSelected ? Colors.white : catColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
        onSelected: (_) => setState(() => _selectedFilter = value),
        selectedColor: catColor ?? scheme.primary,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : null),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildCompactTaskCard(Task task) {
    final isOverdue =
        task.deadline != null &&
        task.deadline!.isBefore(DateTime.now()) &&
        !task.completed;
    final isTimelineTask = task.category == 'timeline';
    final categoryColor = CategoryUtils.getCategoryColor(task.category);
    final categoryLightColor = CategoryUtils.getCategoryLightColor(
      task.category,
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: task.completed
              ? Colors.green.withOpacity(0.3)
              : categoryColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.only(bottom: 6),
      color: task.completed ? Colors.green.shade50 : categoryLightColor,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: () => _toggleTaskComplete(task),
                child: Icon(
                  task.completed ? Icons.check_circle : Icons.circle_outlined,
                  color: task.completed ? Colors.green : categoryColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CategoryUtils.getCategoryIcon(task.category),
                        size: 14,
                        color: categoryColor,
                      ),
                      const SizedBox(width: 4),
                      if (isTimelineTask)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Checkliste',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: task.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.completed
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.completed
                            ? Colors.grey
                            : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (task.location.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _openInGoogleMaps(task.location),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place,
                            size: 12,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.location,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _buildCompactBadge(
                        CategoryUtils.categoryLabels[task.category] ??
                            task.category,
                        categoryColor,
                      ),
                      _buildCompactBadge(
                        _priorityLabels[task.priority] ?? task.priority,
                        _getPriorityColor(task.priority),
                      ),
                      if (task.deadline != null)
                        _buildCompactBadge(
                          '${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}',
                          isOverdue ? Colors.red : Colors.grey,
                        ),
                      FutureBuilder<bool>(
                        future: NotificationService().hasNotification(
                          task.id ?? -1,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.data == true) {
                            return _buildCompactBadge(
                              '🔔 Erinnerung',
                              Colors.blue,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (menuContext) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 10),
                      Text('Bearbeiten'),
                    ],
                  ),
                ),
                if (task.deadline != null)
                  const PopupMenuItem(
                    value: 'calendar',
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 18,
                          color: Colors.blue,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'In Kalender',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'notification',
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 18,
                        color: Colors.orange,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Erinnerung',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 10),
                      Text('Löschen', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editTask(task);
                    break;
                  case 'calendar':
                    _exportSingleTaskToCalendar(task);
                    break;
                  case 'notification':
                    _showNotificationDialog(task);
                    break;
                  case 'delete':
                    widget.onDeleteTask(task.id!);
                    break;
                }
              },
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // QUICK RESCHEDULE CHIP
  // ═══════════════════════════════════════════════════════

  Widget _buildQuickRescheduleChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
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

  // ═══════════════════════════════════════════════════════
  // TIMELINE TAB
  // ═══════════════════════════════════════════════════════

  Widget _buildTimelineTab() {
    final scheme = Theme.of(context).colorScheme;

    if (widget.weddingDate == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timeline, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 24),
              const Text(
                'Timeline nicht verfügbar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Bitte legen Sie zuerst ein Hochzeitsdatum fest',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final daysUntilWedding = widget.weddingDate!
        .difference(DateTime.now())
        .inDays;
    final groupedTimeline = _generateGroupedTimeline();
    final timelineTasksCount = widget.tasks
        .where((t) => t.category == 'timeline')
        .length;

    final overdueTimelineCount = widget.tasks
        .where(
          (t) =>
              t.category == 'timeline' &&
              !t.completed &&
              t.deadline != null &&
              t.deadline!.isBefore(DateTime.now()),
        )
        .length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                spreadRadius: 1,
                blurRadius: 3,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                widget.brideName.isNotEmpty && widget.groomName.isNotEmpty
                    ? '${widget.brideName} & ${widget.groomName}'
                    : 'Hochzeits-Timeline',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.weddingDate!.day}.${widget.weddingDate!.month}.${widget.weddingDate!.year}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                daysUntilWedding > 0
                    ? 'Noch $daysUntilWedding Tage!'
                    : daysUntilWedding == 0
                    ? 'Heute ist der große Tag!'
                    : 'Die Hochzeit war vor ${-daysUntilWedding} Tagen!',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              if (overdueTimelineCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$overdueTimelineCount überfällige Aufgabe${overdueTimelineCount > 1 ? 'n' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Timeline-Aufgaben: $timelineTasksCount',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showTaskForm(),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Aufgabe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _initializeDefaultMilestonesManually,
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: const Text('Checkliste'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showCalendarExportOptionsDialog(onlyTimeline: true),
                    icon: const Icon(Icons.calendar_month, size: 16),
                    label: const Text('Kalender'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showResetTimelineTasksDialog,
                    icon: const Icon(Icons.delete_sweep, size: 20),
                    tooltip: 'Alle Timeline-Aufgaben löschen',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: groupedTimeline.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Keine Timeline-Aufgaben',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Klicken Sie auf "Checkliste" um die Standard-Timeline zu erstellen',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: groupedTimeline.entries
                      .map((entry) => _buildTimelineSection(entry))
                      .toList(),
                ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════
  // INTELLIGENTE TIMELINE-GRUPPIERUNG
  // ═══════════════════════════════════════════════════════

  Map<String, List<Map<String, dynamic>>> _generateGroupedTimeline() {
    final timeline = _generateTimeline();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final Map<String, List<Map<String, dynamic>>> grouped = {
      '⚠️ Überfällig – sofort erledigen': [],
      '12-6 Monate vor der Hochzeit': [],
      '6-5 Monate vor der Hochzeit': [],
      '4-3 Monate vor der Hochzeit': [],
      '2-1 Monate vor der Hochzeit': [],
      '1 Woche vor der Hochzeit': [],
      'Der große Tag': [],
      'Nach der Hochzeit': [],
    };

    final weddingDate = widget.weddingDate!;

    for (final item in timeline) {
      final type = item['type'] as String;

      if (type == 'wedding_day') {
        grouped['Der große Tag']!.add(item);
        continue;
      }

      if (type == 'task') {
        final task = item['task'] as Task;
        final date = item['date'] as DateTime;
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final daysUntilWedding = weddingDate.difference(date).inDays;

        if (!task.completed && normalizedDate.isBefore(today)) {
          grouped['⚠️ Überfällig – sofort erledigen']!.add(item);
          continue;
        }

        if (date.isAfter(weddingDate)) {
          grouped['Nach der Hochzeit']!.add(item);
        } else if (daysUntilWedding >= 0 && daysUntilWedding <= 7) {
          grouped['1 Woche vor der Hochzeit']!.add(item);
        } else if (daysUntilWedding > 7 && daysUntilWedding <= 60) {
          grouped['2-1 Monate vor der Hochzeit']!.add(item);
        } else if (daysUntilWedding > 60 && daysUntilWedding <= 120) {
          grouped['4-3 Monate vor der Hochzeit']!.add(item);
        } else if (daysUntilWedding > 120 && daysUntilWedding <= 180) {
          grouped['6-5 Monate vor der Hochzeit']!.add(item);
        } else {
          grouped['12-6 Monate vor der Hochzeit']!.add(item);
        }
      }
    }

    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) {
        if (a['type'] == 'task' && b['type'] == 'task') {
          return (a['date'] as DateTime).compareTo(b['date'] as DateTime);
        }
        return 0;
      });
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  List<Map<String, dynamic>> _generateTimeline() {
    final scheme = Theme.of(context).colorScheme;
    List<Map<String, dynamic>> items = [];
    if (widget.weddingDate == null) return items;

    final weddingDate = widget.weddingDate!;

    for (final task in widget.tasks) {
      if (task.deadline != null) {
        items.add({
          'title': task.title,
          'date': task.deadline!,
          'description': task.description.isNotEmpty
              ? task.description
              : task.title,
          'color': _getTaskTimelineColor(task),
          'type': 'task',
          'task': task,
          'isCompleted': task.completed,
        });
      }
    }

    items.add({
      'title': 'Hochzeitstag',
      'date': weddingDate,
      'description': 'Der große Tag ist da! 🎉',
      'color': scheme.primary,
      'type': 'wedding_day',
      'isCompleted': false,
    });

    return items;
  }

  Color _getSectionColor(String sectionTitle) {
    if (sectionTitle.contains('Überfällig')) return Colors.red.shade700;
    if (sectionTitle.contains('12-6')) return Colors.red;
    if (sectionTitle.contains('6-5')) return Colors.orange;
    if (sectionTitle.contains('4-3')) return Colors.amber.shade700;
    if (sectionTitle.contains('2-1')) return Colors.green;
    if (sectionTitle.contains('1 Woche')) return Colors.blue;
    if (sectionTitle.contains('große Tag')) return Colors.pink;
    if (sectionTitle.contains('Nach')) return Colors.purple;
    return Colors.grey;
  }

  IconData _getSectionIcon(String sectionTitle) {
    if (sectionTitle.contains('Überfällig')) return Icons.warning_amber_rounded;
    if (sectionTitle.contains('12-6')) return Icons.calendar_today;
    if (sectionTitle.contains('6-5')) return Icons.event_note;
    if (sectionTitle.contains('4-3')) return Icons.assignment;
    if (sectionTitle.contains('2-1')) return Icons.event_available;
    if (sectionTitle.contains('1 Woche')) return Icons.alarm;
    if (sectionTitle.contains('große Tag')) return Icons.favorite;
    if (sectionTitle.contains('Nach')) return Icons.check_circle;
    return Icons.flag;
  }

  Widget _buildTimelineSection(
    MapEntry<String, List<Map<String, dynamic>>> section,
  ) {
    final sectionTitle = section.key;
    final items = section.value;

    if (items.isEmpty) return const SizedBox.shrink();

    final completedCount = items
        .where((item) => item['isCompleted'] == true)
        .length;
    final progress = items.isNotEmpty ? completedCount / items.length : 0.0;
    final isOverdueSection = sectionTitle.contains('Überfällig');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isOverdueSection ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOverdueSection
            ? BorderSide(color: Colors.red.shade300, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getSectionColor(
                sectionTitle,
              ).withOpacity(isOverdueSection ? 0.15 : 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getSectionIcon(sectionTitle),
                      color: _getSectionColor(sectionTitle),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sectionTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _getSectionColor(sectionTitle),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getSectionColor(sectionTitle),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOverdueSection
                            ? '${items.length} offen'
                            : '$completedCount/${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isOverdueSection) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Diese Aufgaben haben ihre Deadline überschritten und sollten schnellstmöglich erledigt werden.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.red.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getSectionColor(sectionTitle),
                    ),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ],
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _buildCompactTimelineItem(items[index], isOverdueSection),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TIMELINE ITEM mit PopupMenuButton (drei Punkte)
  // ═══════════════════════════════════════════════════════

  Widget _buildCompactTimelineItem(
    Map<String, dynamic> item, [
    bool isOverdueSection = false,
  ]) {
    final scheme = Theme.of(context).colorScheme;
    final task = item['task'] as Task?;
    final isCompleted = item['isCompleted'] as bool;
    final isWeddingDay = item['type'] == 'wedding_day';
    final isTimelineTask = task?.category == 'timeline';
    final date = item['date'] as DateTime?;

    return InkWell(
      onTap: () {
        if (task != null && !isWeddingDay) {
          _showTaskForm(task);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Checkbox / Hochzeits-Icon ──
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: !isWeddingDay
                  ? GestureDetector(
                      onTap: () {
                        if (task != null) {
                          widget.onUpdateTask(
                            task.copyWith(completed: !task.completed),
                          );
                        }
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? Colors.green
                              : isOverdueSection
                              ? Colors.red.shade50
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted
                                ? Colors.green
                                : isOverdueSection
                                ? Colors.red.shade400
                                : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    )
                  : Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // ── Inhalt ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titel
                  Row(
                    children: [
                      if (isTimelineTask && !isWeddingDay)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Checkliste',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          item['title'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? Colors.grey
                                : isOverdueSection
                                ? Colors.red.shade800
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Datum + "X Tage überfällig" Badge
                  if (date != null && !isWeddingDay) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 11,
                          color: isOverdueSection
                              ? Colors.red.shade600
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${date.day}.${date.month}.${date.year}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isOverdueSection
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                            fontWeight: isOverdueSection
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                        if (isOverdueSection) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${DateTime.now().difference(date).inDays} Tage überfällig',
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],

                  // Schnell-Aktionen für überfällige Aufgaben
                  if (isOverdueSection && task != null) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildQuickRescheduleChip(
                          label: '+1 Woche',
                          icon: Icons.edit_calendar,
                          color: Colors.orange,
                          onTap: () {
                            widget.onUpdateTask(
                              task.copyWith(
                                deadline: DateTime.now().add(
                                  const Duration(days: 7),
                                ),
                              ),
                            );
                          },
                        ),
                        _buildQuickRescheduleChip(
                          label: '+2 Wochen',
                          icon: Icons.edit_calendar,
                          color: Colors.blue,
                          onTap: () {
                            widget.onUpdateTask(
                              task.copyWith(
                                deadline: DateTime.now().add(
                                  const Duration(days: 14),
                                ),
                              ),
                            );
                          },
                        ),
                        _buildQuickRescheduleChip(
                          label: 'Datum wählen',
                          icon: Icons.date_range,
                          color: Colors.purple,
                          onTap: () async {
                            final newDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(
                                const Duration(days: 7),
                              ),
                              firstDate: DateTime.now(),
                              lastDate:
                                  widget.weddingDate ??
                                  DateTime.now().add(
                                    const Duration(days: 1095),
                                  ),
                            );
                            if (newDate != null) {
                              widget.onUpdateTask(
                                task.copyWith(deadline: newDate),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],

                  // Beschreibung
                  if (item['description'] != null &&
                      item['description'].toString().isNotEmpty &&
                      item['description'] != item['title']) ...[
                    const SizedBox(height: 2),
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── PopupMenuButton (drei Punkte) ──
            if (task != null && !isWeddingDay)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
                padding: EdgeInsets.zero,
                itemBuilder: (menuContext) => [
                  // Bearbeiten
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Bearbeiten'),
                      ],
                    ),
                  ),
                  // In Kalender – nur wenn Deadline vorhanden
                  if (task.deadline != null)
                    const PopupMenuItem<String>(
                      value: 'calendar',
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'In Kalender',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  // Erinnerung – nur wenn Deadline vorhanden
                  if (task.deadline != null)
                    const PopupMenuItem<String>(
                      value: 'notification',
                      child: Row(
                        children: [
                          Icon(
                            Icons.notifications_outlined,
                            size: 18,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Erinnerung',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  // Trennlinie
                  const PopupMenuDivider(),
                  // Löschen
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Löschen', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      _showTaskForm(task);
                      break;
                    case 'calendar':
                      _exportSingleTaskToCalendar(task);
                      break;
                    case 'notification':
                      _showNotificationDialog(task);
                      break;
                    case 'delete':
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Löschen bestätigen'),
                          content: const Text(
                            'Möchten Sie diese Aufgabe wirklich löschen?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Abbrechen'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text(
                                'Ja',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        widget.onDeleteTask(task.id!);
                      }
                      break;
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // TASK FORM (Timeline)
  // ═══════════════════════════════════════════════════════

  void _showTaskForm([Task? editingTask]) {
    final scheme = Theme.of(context).colorScheme;

    String title = editingTask?.title ?? '';
    String description = editingTask?.description ?? '';
    DateTime? deadline = editingTask?.deadline;
    String priority = editingTask?.priority ?? 'medium';
    String category = editingTask?.category ?? 'timeline';

    showDialog(
      context: context,
      builder: (builderContext) => StatefulBuilder(
        builder: (statefulContext, setDialogState) => AlertDialog(
          title: Text(
            editingTask != null
                ? 'Aufgabe bearbeiten'
                : 'Timeline-Aufgabe hinzufügen',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: TextEditingController(text: title),
                  decoration: const InputDecoration(
                    labelText: 'Titel',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: description),
                  decoration: const InputDecoration(
                    labelText: 'Beschreibung',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (value) => description = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Kategorie',
                    border: OutlineInputBorder(),
                  ),
                  items: _categoryLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => category = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(
                    labelText: 'Priorität',
                    border: OutlineInputBorder(),
                  ),
                  items: _priorityLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => priority = value!),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          'Deadline',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              deadline != null
                                  ? '${deadline!.day}.${deadline!.month}.${deadline!.year}'
                                  : 'Kein Datum gesetzt',
                              style: TextStyle(
                                fontSize: 16,
                                color: deadline != null
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.edit_calendar,
                              color: Colors.blue,
                            ),
                            tooltip: 'Datum ändern',
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: statefulContext,
                                initialDate:
                                    deadline ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime.now(),
                                lastDate:
                                    widget.weddingDate ??
                                    DateTime.now().add(
                                      const Duration(days: 1095),
                                    ),
                              );
                              if (date != null) {
                                setDialogState(() => deadline = date);
                              }
                            },
                          ),
                          if (deadline != null)
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.red),
                              tooltip: 'Datum entfernen',
                              onPressed: () =>
                                  setDialogState(() => deadline = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (editingTask != null)
              TextButton(
                onPressed: () {
                  widget.onDeleteTask(editingTask.id!);
                  Navigator.pop(builderContext);
                },
                child: const Text(
                  'Löschen',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(builderContext),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () {
                if (title.isNotEmpty) {
                  final taskData = Task(
                    id: editingTask?.id,
                    title: title,
                    description: description,
                    category: category,
                    priority: priority,
                    deadline: deadline,
                    completed: editingTask?.completed ?? false,
                    createdDate: editingTask?.createdDate ?? DateTime.now(),
                  );
                  if (editingTask != null) {
                    widget.onUpdateTask(taskData);
                  } else {
                    widget.onAddTask(taskData);
                  }
                  Navigator.pop(builderContext);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // RESET TIMELINE DIALOG
  // ═══════════════════════════════════════════════════════

  void _showResetTimelineTasksDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alle Timeline-Aufgaben löschen'),
        content: const Text(
          'Möchten Sie ALLE Timeline-Aufgaben unwiderruflich löschen?\n\n'
          'Dies umfasst sowohl automatisch erstellte als auch manuell '
          'hinzugefügte Timeline-Aufgaben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              final timelineTaskIds = widget.tasks
                  .where((t) => t.category == 'timeline' && t.id != null)
                  .map((t) => t.id!)
                  .toList();

              if (timelineTaskIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Keine Timeline-Aufgaben vorhanden'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              final count = timelineTaskIds.length;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingContext) => WillPopScope(
                  onWillPop: () async => false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text('Lösche $count Aufgaben...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              try {
                for (final taskId in timelineTaskIds) {
                  widget.onDeleteTask(taskId);
                  await Future.delayed(const Duration(milliseconds: 50));
                }

                await Future.delayed(const Duration(milliseconds: 500));

                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$count Timeline-Aufgaben wurden gelöscht.',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );

                  if (widget.onNavigateToHome != null) {
                    await Future.delayed(const Duration(milliseconds: 500));
                    widget.onNavigateToHome!();
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fehler beim Löschen: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'Ja, alle löschen',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  // REMINDER HELPER WIDGETS
  // ═══════════════════════════════════════════════════════

  Widget _buildReminderOption({
    required BuildContext context,
    required Duration duration,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.black87 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatReminderDuration(Duration duration) {
    if (duration == Duration.zero) return 'Am selben Tag (08:00 Uhr)';
    if (duration.inDays == 1) return '1 Tag vorher';
    if (duration.inDays == 3) return '3 Tage vorher';
    if (duration.inDays == 7) return '1 Woche vorher';
    if (duration.inDays == 14) return '2 Wochen vorher';
    return '${duration.inDays} Tage vorher';
  }
}
