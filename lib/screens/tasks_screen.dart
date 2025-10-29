import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../app_colors.dart';
import '../data/database_helper.dart';
import '../widgets/task_donut_chart.dart';
import '../services/excel_export_service.dart';

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
  final VoidCallback? onNavigateToHome; // NEU: Callback zum Home navigieren

  const TaskPage({
    Key? key,
    required this.tasks,
    required this.onAddTask,
    required this.onUpdateTask,
    required this.onDeleteTask,
    this.weddingDate,
    required this.brideName,
    required this.groomName,
    this.selectedTaskId,
    this.onClearSelectedTask,
    this.onNavigateToHome, // NEU
  }) : super(key: key);

  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'all';
  bool _isSubmitting = false;
  Task? _editingTask;
  String _quickAddTitle = '';

  late TabController _tabController;
  int _currentTab = 0;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
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
      Future.delayed(const Duration(milliseconds: 100), () {
        _editTask(task);
      });

      if (widget.onClearSelectedTask != null) {
        widget.onClearSelectedTask!();
      }
    }
  }

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
            'Es sind bereits ${timelineTasks.length} Timeline-Aufgaben vorhanden. Möchten Sie diese löschen und die Standard-Checkliste neu erstellen?',
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

    for (final milestone in defaultMilestones) {
      final monthsBefore = milestone['months_before'] as int;
      final weddingDate = widget.weddingDate!;

      DateTime deadline;
      if (monthsBefore > 0) {
        deadline = DateTime(
          weddingDate.year,
          weddingDate.month - monthsBefore,
          weddingDate.day,
        );
      } else if (monthsBefore < 0) {
        deadline = DateTime(
          weddingDate.year,
          weddingDate.month - monthsBefore,
          weddingDate.day,
        );
      } else {
        deadline = weddingDate.subtract(const Duration(days: 7));
      }

      String priority;
      if (monthsBefore >= 6) {
        priority = 'low';
      } else if (monthsBefore >= 3) {
        priority = 'medium';
      } else {
        priority = 'high';
      }

      final task = Task(
        title: milestone['title'] as String,
        description: '',
        category: 'timeline',
        priority: priority,
        deadline: deadline,
        completed: false,
        createdDate: DateTime.now(),
      );

      widget.onAddTask(task);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTimelineMilestones() async {
    setState(() {
      _timelineMilestones = [];
    });
  }

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
      switch (_selectedFilter) {
        case 'all':
          return true;
        case 'completed':
          return task.completed;
        case 'pending':
          return !task.completed;
        case 'overdue':
          return !task.completed &&
              task.deadline != null &&
              task.deadline!.isBefore(today);
        default:
          return task.category == _selectedFilter;
      }
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

  void _handleQuickAdd() {
    if (_quickAddTitle.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    final newTask = Task(
      title: _quickAddTitle.trim(),
      category: 'other',
      priority: 'medium',
      completed: false,
      createdDate: DateTime.now(),
    );

    widget.onAddTask(newTask);

    setState(() {
      _quickAddTitle = '';
      _isSubmitting = false;
    });
  }

  void _showDetailedForm() {
    setState(() {
      _editingTask = null;
      _titleController.clear();
      _descriptionController.clear();
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
      _selectedCategory = task.category;
      _selectedPriority = task.priority;
      _selectedDeadline = task.deadline;
    });
    _showFormDialog();
  }

  void _showFormDialog() {
    showDialog(
      context: context,
      builder: (builderContext) => AlertDialog(
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
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategorie',
                  border: OutlineInputBorder(),
                ),
                items: _categoryLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedCategory = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedPriority,
                decoration: const InputDecoration(
                  labelText: 'Priorität',
                  border: OutlineInputBorder(),
                ),
                items: _priorityLabels.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedPriority = value!),
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
              ListTile(
                title: const Text('Deadline'),
                subtitle: Text(
                  _selectedDeadline != null
                      ? '${_selectedDeadline!.day}.${_selectedDeadline!.month}.${_selectedDeadline!.year}'
                      : 'Keine Deadline',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: builderContext,
                      initialDate: _selectedDeadline ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDeadline = date;
                      });
                    }
                  },
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
              _handleSubmit();
              Navigator.pop(builderContext);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(
              _editingTask != null ? 'Speichern' : 'Erstellen',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
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
    final updatedTask = task.copyWith(completed: !task.completed);
    widget.onUpdateTask(updatedTask);
  }

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
        content: ListTile(
          leading: const Icon(Icons.table_chart, color: Colors.green, size: 32),
          title: const Text('Als Excel exportieren'),
          subtitle: const Text('Alle Aufgaben mit Details'),
          onTap: () {
            Navigator.pop(context);
            _exportAsExcel();
          },
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey.shade600,
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

  Widget _buildTasksTab() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.cardBorder, width: 1),
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
                          backgroundColor: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _showDetailedForm,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Neu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
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
              side: const BorderSide(color: AppColors.cardBorder, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Schnell hinzufügen...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) => _quickAddTitle = value,
                      onSubmitted: (_) => _handleQuickAdd(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleQuickAdd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Add',
                            style: TextStyle(color: Colors.white),
                          ),
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
                ? const Center(
                    child: Text(
                      'Keine Aufgaben gefunden.',
                      style: TextStyle(color: Colors.grey),
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
    return SizedBox(
      height: 35,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('all', 'Alle'),
          _buildFilterChip('pending', 'Offen'),
          _buildFilterChip('completed', 'Erledigt'),
          _buildFilterChip('overdue', 'Überfällig'),
          _buildFilterChip('timeline', 'Checkliste'),
          ..._categoryLabels.entries
              .where((entry) => entry.key != 'timeline')
              .take(3)
              .map((entry) => _buildFilterChip(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: isSelected,
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onSelected: (selected) => setState(() => _selectedFilter = value),
        selectedColor: AppColors.primary,
        checkmarkColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8),
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

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.cardBorder, width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 6),
      color: task.completed
          ? Colors.green.shade50
          : isTimelineTask
          ? Colors.amber.shade50
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleTaskComplete(task),
              child: Icon(
                task.completed ? Icons.check_circle : Icons.circle_outlined,
                color: task.completed ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildCompactBadge(
                        _categoryLabels[task.category] ?? task.category,
                        Colors.blue,
                      ),
                      const SizedBox(width: 4),
                      _buildCompactBadge(
                        _priorityLabels[task.priority] ?? task.priority,
                        _getPriorityColor(task.priority),
                      ),
                      if (task.deadline != null) ...[
                        const SizedBox(width: 4),
                        _buildCompactBadge(
                          '${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}',
                          isOverdue ? Colors.red : Colors.grey,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              itemBuilder: (menuContext) => [
                const PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
                const PopupMenuItem(value: 'delete', child: Text('Löschen')),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _editTask(task);
                } else if (value == 'delete') {
                  widget.onDeleteTask(task.id!);
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

  Widget _buildTimelineTab() {
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

    // KORRIGIERT: Zähle alle Tasks mit category == 'timeline'
    final timelineTasksCount = widget.tasks
        .where((t) => t.category == 'timeline')
        .length;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
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
                  color: AppColors.primary,
                ),
              ),
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
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
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

  Map<String, List<Map<String, dynamic>>> _generateGroupedTimeline() {
    final timeline = _generateTimeline();

    final Map<String, List<Map<String, dynamic>>> grouped = {
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
        final date = item['date'] as DateTime;
        final daysUntilWedding = weddingDate.difference(date).inDays;

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
        } else if (daysUntilWedding > 180) {
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
    List<Map<String, dynamic>> items = [];
    if (widget.weddingDate == null) return items;

    final weddingDate = widget.weddingDate!;

    // ALLE Tasks mit Deadline hinzufügen (auch Timeline-Tasks!)
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
      'color': AppColors.primary,
      'type': 'wedding_day',
      'isCompleted': false,
    });

    return items;
  }

  Color _getSectionColor(String sectionTitle) {
    if (sectionTitle.contains('12-6')) return Colors.red;
    if (sectionTitle.contains('6-5')) return Colors.orange;
    if (sectionTitle.contains('4-3')) return Colors.amber;
    if (sectionTitle.contains('2-1')) return Colors.green;
    if (sectionTitle.contains('1 Woche')) return Colors.blue;
    if (sectionTitle.contains('große Tag')) return AppColors.primary;
    if (sectionTitle.contains('Nach')) return Colors.purple;
    return Colors.grey;
  }

  IconData _getSectionIcon(String sectionTitle) {
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getSectionColor(sectionTitle).withOpacity(0.1),
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
                        '$completedCount/${items.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
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
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _buildCompactTimelineItem(items[index]),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTimelineItem(Map<String, dynamic> item) {
    final task = item['task'] as Task?;
    final isCompleted = item['isCompleted'] as bool;
    final isWeddingDay = item['type'] == 'wedding_day';
    final isTimelineTask = task?.category == 'timeline';
    final date = item['date'] as DateTime?; // NEU: Datum holen

    return InkWell(
      onTap: () {
        if (task != null && !isWeddingDay) {
          _showTaskForm(task);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (!isWeddingDay)
              GestureDetector(
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
                    color: isCompleted ? Colors.green : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? Colors.green : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: isCompleted
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            color: isCompleted ? Colors.grey : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // NEU: Datum anzeigen
                  if (date != null && !isWeddingDay) ...[
                    const SizedBox(height: 2),
                    Text(
                      '📅 ${date.day}.${date.month}.${date.year}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
            if (task != null && !isWeddingDay)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      _showTaskForm(task);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Bearbeiten',
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    onPressed: () async {
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
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Löschen',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showTaskForm([Task? editingTask]) {
    String title = editingTask?.title ?? '';
    String description = editingTask?.description ?? '';
    DateTime? deadline = editingTask?.deadline;
    String priority = editingTask?.priority ?? 'medium';
    String category =
        editingTask?.category ??
        'timeline'; // KORRIGIERT: Default auf 'timeline'

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
                  decoration: const InputDecoration(labelText: 'Titel'),
                  onChanged: (value) => title = value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: TextEditingController(text: description),
                  decoration: const InputDecoration(labelText: 'Beschreibung'),
                  maxLines: 2,
                  onChanged: (value) => description = value,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Kategorie'),
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
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priorität'),
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
                Row(
                  children: [
                    const Text('Deadline: '),
                    TextButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: statefulContext,
                          initialDate:
                              deadline ??
                              DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate:
                              widget.weddingDate ??
                              DateTime.now().add(const Duration(days: 1095)),
                        );
                        if (date != null) setDialogState(() => deadline = date);
                      },
                      child: Text(
                        deadline != null
                            ? '${deadline!.day}.${deadline!.month}.${deadline!.year}'
                            : 'Datum wählen',
                      ),
                    ),
                  ],
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
                backgroundColor: AppColors.primary,
              ),
              child: const Text(
                'Speichern',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetTimelineTasksDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alle Timeline-Aufgaben löschen'),
        content: const Text(
          'Möchten Sie ALLE Timeline-Aufgaben unwiderruflich löschen?\n\nDies umfasst sowohl automatisch erstellte als auch manuell hinzugefügte Timeline-Aufgaben.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Sammle alle Timeline-Task IDs
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

              // Zeige Ladeanzeige
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
                // WICHTIG: Verwende das Callback-System um das Parent-Widget zu informieren
                for (final taskId in timelineTaskIds) {
                  widget.onDeleteTask(taskId);
                  // Kurze Pause zwischen Löschungen
                  await Future.delayed(const Duration(milliseconds: 50));
                }

                // Warte bis alle gelöscht sind
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

                  // Navigiere zur Home-Seite um Daten neu zu laden
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
}
