import 'package:flutter/material.dart';
import '../models/wedding_models.dart';
import '../app_colors.dart';
import '../data/database_helper.dart';
import '../widgets/budget_donut_chart.dart';

class DashboardPage extends StatefulWidget {
  final DateTime? weddingDate;
  final String brideName;
  final String groomName;
  final List<Task> tasks;
  final List<Guest> guests;
  final Function(DateTime, String, String) onUpdateWeddingData;
  final Function(Task) onAddTask;
  final Function(Task) onUpdateTask;
  final Function(int) onDeleteTask;
  final Function(int) onNavigateToPage; // NEU!

  const DashboardPage({
    Key? key,
    this.weddingDate,
    required this.brideName,
    required this.groomName,
    required this.tasks,
    required this.guests,
    required this.onUpdateWeddingData,
    required this.onAddTask,
    required this.onUpdateTask,
    required this.onDeleteTask,
    required this.onNavigateToPage, // NEU!
  }) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Map<String, dynamic>> _budgetItems = [];
  bool _isLoading = true;

  Map<String, dynamic> _stats = {
    'budget': {'planned': 0.0, 'actual': 0.0, 'paid': 0.0},
    'guests': {'total': 0, 'confirmed': 0, 'declined': 0, 'pending': 0},
    'tasks': {'total': 0, 'completed': 0},
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void didUpdateWidget(DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tasks != widget.tasks || oldWidget.guests != widget.guests) {
      _calculateStats();
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final items = await DatabaseHelper.instance.getAllBudgetItems();
      setState(() {
        _budgetItems = items;
      });

      _calculateStats();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Dashboard-Daten: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _calculateStats() {
    double plannedTotal = 0.0;
    double actualTotal = 0.0;

    for (final item in _budgetItems) {
      plannedTotal += item['planned'] ?? 0.0;
      actualTotal += item['actual'] ?? 0.0;
    }

    double paidAmount = actualTotal * 0.6;

    int confirmedGuests = widget.guests
        .where((g) => g.confirmed == 'yes')
        .length;
    int declinedGuests = widget.guests.where((g) => g.confirmed == 'no').length;
    int pendingGuests = widget.guests
        .where((g) => g.confirmed == 'pending')
        .length;

    int completedTasks = widget.tasks.where((t) => t.completed).length;

    setState(() {
      _stats = {
        'budget': {
          'planned': plannedTotal,
          'actual': actualTotal,
          'paid': paidAmount,
        },
        'guests': {
          'total': widget.guests.length,
          'confirmed': confirmedGuests,
          'declined': declinedGuests,
          'pending': pendingGuests,
        },
        'tasks': {'total': widget.tasks.length, 'completed': completedTasks},
      };
    });
  }

  List<Task> get _upcomingTasks {
    final now = DateTime.now();
    return widget.tasks
        .where(
          (task) =>
              !task.completed &&
              task.deadline != null &&
              task.deadline!.isAfter(now),
        )
        .toList()
      ..sort((a, b) => a.deadline!.compareTo(b.deadline!));
  }

  int get _daysUntilWedding {
    if (widget.weddingDate == null) return -1;
    return widget.weddingDate!.difference(DateTime.now()).inDays;
  }

  void _showWeddingDataForm() {
    String brideName = widget.brideName;
    String groomName = widget.groomName;
    DateTime? weddingDate = widget.weddingDate;

    showDialog(
      context: context,
      builder: (builderContext) => AlertDialog(
        title: const Text('Hochzeitsdaten bearbeiten'),
        content: StatefulBuilder(
          builder: (statefulContext, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'Name der Braut'),
                controller: TextEditingController(text: brideName),
                onChanged: (value) => brideName = value,
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Name des Bräutigams',
                ),
                controller: TextEditingController(text: groomName),
                onChanged: (value) => groomName = value,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Hochzeitsdatum: '),
                  TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: statefulContext,
                        initialDate:
                            weddingDate ??
                            DateTime.now().add(const Duration(days: 365)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(
                          const Duration(days: 1095),
                        ),
                      );
                      if (date != null)
                        setDialogState(() => weddingDate = date);
                    },
                    child: Text(
                      weddingDate != null
                          ? '${weddingDate!.day}.${weddingDate!.month}.${weddingDate!.year}'
                          : 'Datum wählen',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(builderContext),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              if (weddingDate != null &&
                  brideName.isNotEmpty &&
                  groomName.isNotEmpty) {
                widget.onUpdateWeddingData(weddingDate!, brideName, groomName);
                Navigator.pop(builderContext);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final coupleNames =
        widget.brideName.isNotEmpty && widget.groomName.isNotEmpty
        ? '${widget.brideName} & ${widget.groomName}'
        : 'Das Hochzeitspaar';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _buildHeaderCard(coupleNames),
          const SizedBox(height: 24),
          _buildNavigationGrid(),
          const SizedBox(height: 24),
          _buildStatsGrid(),
          const SizedBox(height: 24),
          _buildUpcomingTasksCard(),
          const SizedBox(height: 24),
          _buildMilestonesCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String coupleNames) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primary.withOpacity(0.1), AppColors.secondary],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Colors.pink.shade300],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Image.asset(
                    'assets/images/heartpepple_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Text(
                coupleNames,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (_daysUntilWedding >= 0) ...[
                Text(
                  _daysUntilWedding.toString(),
                  style: TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  _daysUntilWedding == 1
                      ? 'Tag bis zur Hochzeit'
                      : _daysUntilWedding == 0
                      ? 'Heute ist der große Tag!'
                      : 'Tage bis zur Hochzeit',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
              ] else ...[
                const Text(
                  '♥',
                  style: TextStyle(fontSize: 64, color: Colors.red),
                ),
                const Text(
                  'Deine Traumhochzeit:\n Schaffe Dir Zeit zu genießen ! ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.weddingDate != null
                        ? '${widget.weddingDate!.day}.${widget.weddingDate!.month}.${widget.weddingDate!.year}'
                        : 'Datum noch nicht festgelegt',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showWeddingDataForm,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Bearbeiten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationGrid() {
    final navItems = [
      {
        'title': 'Gäste',
        'icon': Icons.people,
        'color': AppColors.guestColor,
        'page': 1,
      },
      {
        'title': 'Budget',
        'icon': Icons.euro,
        'color': AppColors.budgetColor,
        'page': 3,
      },
      {
        'title': 'Checkliste',
        'icon': Icons.assignment,
        'color': AppColors.taskColor,
        'page': 4,
      },
      {
        'title': 'Tischplan',
        'icon': Icons.table_restaurant,
        'color': AppColors.tableColor,
        'page': 2,
      },
      {
        'title': 'Dienstleister',
        'icon': Icons.business,
        'color': AppColors.serviceColor,
        'page': 5,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: navItems.length,
      itemBuilder: (context, index) {
        final item = navItems[index];
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => widget.onNavigateToPage(item['page'] as int),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (item['color'] as Color).withOpacity(0.1),
                    (item['color'] as Color).withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: item['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => widget.onNavigateToPage(3),
          child: _buildBudgetCard(),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => widget.onNavigateToPage(1),
          child: _buildGuestsCard(),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => widget.onNavigateToPage(4),
          child: _buildTasksCard(),
        ),
      ],
    );
  }

  Widget _buildBudgetCard() {
    final budgetData = _stats['budget'];
    final planned = budgetData['planned'] as double;
    final actual = budgetData['actual'] as double;
    final paid = budgetData['paid'] as double;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Budget-Übersicht',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CustomPaint(
                    painter: BudgetPieChartPainter(
                      actual: actual,
                      remaining: planned - actual,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '€${actual.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'von €${planned.toStringAsFixed(0)} geplant',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Bezahlt',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    '€${paid.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'Ausstehend',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    '€${(actual - paid).toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }

  Widget _buildGuestsCard() {
    final guestData = _stats['guests'];
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Gäste-Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${guestData['confirmed']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const Text(
                      'Zusagen',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${guestData['declined']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const Text(
                      'Absagen',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${guestData['total']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const Text(
                      'Gesamt',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksCard() {
    final taskData = _stats['tasks'];
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Checklisten-Fortschritt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Column(
                  children: [
                    Text(
                      '${taskData['completed']} / ${taskData['total']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      'Aufgaben erledigt',
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTasksCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Nächste 3 Aufgaben',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_upcomingTasks.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Keine anstehenden Aufgaben gefunden.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              Column(
                children: _upcomingTasks.take(3).map((task) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border(
                        left: BorderSide(
                          width: 4,
                          color: _getPriorityColor(task.priority),
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (task.deadline != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  '${task.deadline!.day}.${task.deadline!.month}.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildMilestonesCard() {
    final milestones = [
      {'title': 'Save the Date', 'icon': Icons.mail},
      {'title': 'Location', 'icon': Icons.location_on},
      {'title': 'Einladungen', 'icon': Icons.mail_outline},
      {'title': 'Outfit', 'icon': Icons.checkroom},
      {'title': 'Ringe', 'icon': Icons.favorite},
      {'title': 'Fotograf', 'icon': Icons.camera_alt},
      {'title': 'DJ/Band', 'icon': Icons.music_note},
      {'title': 'Blumen', 'icon': Icons.local_florist},
      {'title': 'Menü', 'icon': Icons.restaurant},
      {'title': 'Hochzeitstorte', 'icon': Icons.cake},
      {'title': 'Flitterwochen', 'icon': Icons.flight},
      {'title': 'Der große Tag', 'icon': Icons.favorite},
    ];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Wichtige Meilensteine',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: milestones.length,
              itemBuilder: (context, index) {
                final milestone = milestones[index];
                return Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Icon(
                        milestone['icon'] as IconData,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      milestone['title'] as String,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
