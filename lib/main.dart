// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Core / Theme
import 'services/theme_providers.dart';
import 'services/profile_providers.dart';
import 'theme/theme_variant.dart';

// Models
import 'models/wedding_models.dart';

// Data
import 'data/database_helper.dart';

// Screens
import 'screens/dashboard_screen.dart';
import 'screens/guests_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/table_planning_screen.dart';
import 'screens/dienstleister_list_screen.dart';
import 'screens/settings_page.dart';
import 'screens/onboarding_screen.dart'; // ← NEU

// Debug
import 'utils/error_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final initialTheme = await resolveInitialVariant(prefs);

  // ── NEU: Onboarding-Status prüfen ────────────────────────
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
  // ─────────────────────────────────────────────────────────

  runApp(
    ProviderScope(
      overrides: [
        themeControllerProvider.overrideWith(
          (ref) => ThemeController(prefs, initialTheme),
        ),
        profileControllerProvider.overrideWith((ref) => ProfileController()),
      ],
      child: WeddingApp(showOnboarding: !onboardingCompleted), // ← NEU
    ),
  );
}

class WeddingApp extends ConsumerWidget {
  final bool showOnboarding; // ← NEU

  const WeddingApp({super.key, required this.showOnboarding}); // ← NEU

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeDataProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeartPebble',
      theme: theme,
      // ── NEU: Onboarding oder Hauptapp ────────────────────
      home: showOnboarding ? const OnboardingWrapper() : const HochzeitsApp(),
      // ─────────────────────────────────────────────────────
    );
  }
}

// ── NEU: Wrapper – wechselt nach Onboarding zur Hauptapp ─────────────────────
class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return const HochzeitsApp();

    return OnboardingScreen(onFinished: () => setState(() => _done = true));
  }
}
// ─────────────────────────────────────────────────────────────────────────────

class HochzeitsApp extends ConsumerStatefulWidget {
  const HochzeitsApp({super.key});

  @override
  ConsumerState<HochzeitsApp> createState() => _HochzeitsAppState();
}

class _HochzeitsAppState extends ConsumerState<HochzeitsApp> {
  int _currentIndex = 0;

  List<Guest> _guests = [];
  List<Task> _tasks = [];
  DateTime? _weddingDate;
  String _brideName = '';
  String _groomName = '';
  bool _isLoading = true;

  Key _budgetPageKey = UniqueKey();
  int? _selectedTaskId;
  Key _taskPageKey = UniqueKey();

  // ✅ GlobalKey für direkten Zugriff auf DashboardPageState.reload()
  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();

  @override
  void initState() {
    super.initState();
    ErrorLogger.info('App gestartet');
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      ErrorLogger.info('Lade Daten...');

      final weddingData = await DatabaseHelper.instance.getWeddingData();
      if (weddingData != null) {
        setState(() {
          _weddingDate = weddingData['wedding_date'] != null
              ? DateTime.parse(weddingData['wedding_date'])
              : null;
          _brideName = weddingData['bride_name'] ?? '';
          _groomName = weddingData['groom_name'] ?? '';
        });
        ErrorLogger.success('Hochzeitsdaten geladen');
      }

      final guests = await DatabaseHelper.instance.getAllGuests();
      setState(() {
        _guests = guests;
      });
      ErrorLogger.success('${guests.length} Gäste geladen');

      final tasks = await DatabaseHelper.instance.getAllTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
      ErrorLogger.success('${tasks.length} Tasks geladen');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Laden der Daten', e, stack);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _reloadAllData() async {
    setState(() {
      _isLoading = true;
    });

    await _loadData();

    setState(() {
      _budgetPageKey = UniqueKey();
      _taskPageKey = UniqueKey();
    });

    // ✅ Dashboard nach globalem Reload ebenfalls aktualisieren
    _dashboardKey.currentState?.reload();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daten erfolgreich aktualisiert! ✅'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // ✅ Tab-Wechsel: Dashboard wird neu geladen wenn Tab 0 aktiv wird
  void _onTabChanged(int index) {
    if (index == 3) {
      setState(() {
        _budgetPageKey = UniqueKey();
      });
    }
    if (index == 4) {
      setState(() {
        _selectedTaskId = null;
      });
    }
    // ✅ Wenn zurück zum Dashboard → Budget aus DB neu laden
    if (index == 0 && _currentIndex != 0) {
      _dashboardKey.currentState?.reload();
    }
    setState(() {
      _currentIndex = index;
    });
  }

  // Callback-Funktionen für Gäste
  Future<void> _addGuest(Guest guest) async {
    try {
      ErrorLogger.info('Füge Gast hinzu: ${guest.firstName} ${guest.lastName}');
      final newGuest = await DatabaseHelper.instance.createGuest(guest);
      setState(() {
        _guests.add(newGuest);
      });
      ErrorLogger.success('Gast hinzugefügt');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Hinzufügen des Gastes', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateGuest(Guest updatedGuest) async {
    try {
      ErrorLogger.info('Aktualisiere Gast: ${updatedGuest.firstName}');
      await DatabaseHelper.instance.updateGuest(updatedGuest);
      final index = _guests.indexWhere((g) => g.id == updatedGuest.id);
      if (index != -1) {
        setState(() {
          _guests = [
            ..._guests.sublist(0, index),
            updatedGuest,
            ..._guests.sublist(index + 1),
          ];
        });
      }
      ErrorLogger.success('Gast aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Aktualisieren des Gastes', e, stack);
    }
  }

  Future<void> _deleteGuest(int guestId) async {
    try {
      ErrorLogger.info('Lösche Gast: $guestId');
      await DatabaseHelper.instance.deleteGuest(guestId);
      setState(() {
        _guests.removeWhere((g) => g.id == guestId);
      });
      ErrorLogger.success('Gast gelöscht');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Löschen des Gastes', e, stack);
    }
  }

  // Callback-Funktionen für Aufgaben
  Future<void> _addTask(Task task) async {
    try {
      ErrorLogger.info('Füge Task hinzu: ${task.title}');
      final newTask = await DatabaseHelper.instance.createTask(task);
      setState(() {
        _tasks.add(newTask);
      });
      ErrorLogger.success('Task hinzugefügt');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Hinzufügen der Aufgabe', e, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateTask(Task updatedTask) async {
    try {
      ErrorLogger.info('Aktualisiere Task: ${updatedTask.title}');
      await DatabaseHelper.instance.updateTask(updatedTask);
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      });
      ErrorLogger.success('Task aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Aktualisieren der Aufgabe', e, stack);
    }
  }

  Future<void> _deleteTask(int taskId) async {
    try {
      ErrorLogger.info('Lösche Task: $taskId');
      await DatabaseHelper.instance.deleteTask(taskId);
      setState(() {
        _tasks.removeWhere((t) => t.id == taskId);
      });
      ErrorLogger.success('Task gelöscht');
    } catch (e, stack) {
      ErrorLogger.error('Fehler beim Löschen der Aufgabe', e, stack);
    }
  }

  Future<void> _updateWeddingData(
    DateTime date,
    String bride,
    String groom,
  ) async {
    try {
      ErrorLogger.info('Aktualisiere Hochzeitsdaten');
      await DatabaseHelper.instance.updateWeddingData(date, bride, groom);
      setState(() {
        _weddingDate = date;
        _brideName = bride;
        _groomName = groom;
      });
      ErrorLogger.success('Hochzeitsdaten aktualisiert');
    } catch (e, stack) {
      ErrorLogger.error(
        'Fehler beim Aktualisieren der Hochzeitsdaten',
        e,
        stack,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _navigateToPage(int pageIndex) {
    _onTabChanged(pageIndex);
  }

  void _navigateToTaskWithId(int taskId) {
    setState(() {
      _selectedTaskId = taskId;
      _taskPageKey = UniqueKey();
      _currentIndex = 4;
    });
  }

  void _clearSelectedTask() {
    setState(() {
      _selectedTaskId = null;
    });
  }

  Color _getNavColor(int index, BrandColors brand) {
    switch (index) {
      case 0:
        return brand.homeColor;
      case 1:
        return brand.guestColor;
      case 2:
        return brand.tableColor;
      case 3:
        return brand.budgetColor;
      case 4:
        return brand.taskColor;
      case 5:
        return brand.serviceColor;
      default:
        return brand.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final variant = ref.watch(themeControllerProvider);
    final brand = colorsFor(variant);
    final scheme = Theme.of(context).colorScheme;

    final List<Widget> pages = [
      // ✅ GlobalKey hier übergeben
      DashboardPage(
        key: _dashboardKey,
        weddingDate: _weddingDate,
        brideName: _brideName,
        groomName: _groomName,
        tasks: _tasks,
        guests: _guests,
        onUpdateWeddingData: _updateWeddingData,
        onAddTask: _addTask,
        onUpdateTask: _updateTask,
        onDeleteTask: _deleteTask,
        onNavigateToPage: _navigateToPage,
        onNavigateToTaskWithId: _navigateToTaskWithId,
      ),
      GuestPage(
        guests: _guests,
        onAddGuest: _addGuest,
        onUpdateGuest: _updateGuest,
        onDeleteGuest: _deleteGuest,
      ),
      TischplanungPage(guests: _guests, onUpdateGuest: _updateGuest),
      EnhancedBudgetPage(key: _budgetPageKey),
      TaskPage(
        key: _taskPageKey,
        tasks: _tasks,
        onAddTask: _addTask,
        onUpdateTask: _updateTask,
        onDeleteTask: _deleteTask,
        weddingDate: _weddingDate,
        brideName: _brideName,
        groomName: _groomName,
        selectedTaskId: _selectedTaskId,
        onClearSelectedTask: _clearSelectedTask,
        onNavigateToHome: () {
          setState(() {
            _currentIndex = 0;
          });
        },
      ),
      const DienstleisterListScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              height: 36,
              width: 36,
              child: Image.asset(
                'assets/images/heartpepple_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'HeartPebble',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: brand.primary,
        foregroundColor: scheme.onPrimary,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: brand.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'HeartPebble',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_brideName.isNotEmpty || _groomName.isNotEmpty)
                    Text(
                      '$_brideName & $_groomName',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  if (_weddingDate != null)
                    Text(
                      '${_weddingDate!.day.toString().padLeft(2, '0')}.'
                      '${_weddingDate!.month.toString().padLeft(2, '0')}.'
                      '${_weddingDate!.year}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _currentIndex == 0,
              onTap: () {
                _onTabChanged(0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Gäste'),
              selected: _currentIndex == 1,
              onTap: () {
                _onTabChanged(1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_restaurant),
              title: const Text('Tischplanung'),
              selected: _currentIndex == 2,
              onTap: () {
                _onTabChanged(2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.euro),
              title: const Text('Budget'),
              selected: _currentIndex == 3,
              onTap: () {
                _onTabChanged(3);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text('Checkliste'),
              selected: _currentIndex == 4,
              onTap: () {
                _onTabChanged(4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Dienstleister'),
              selected: _currentIndex == 5,
              onTap: () {
                _onTabChanged(5);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Einstellungen'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsPage(onDataReloaded: _reloadAllData),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: _getNavColor(_currentIndex, brand),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        backgroundColor: Colors.white,
        elevation: 8,
        // ✅ Alle Tab-Wechsel laufen über _onTabChanged
        onTap: _onTabChanged,
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              size: 20,
              color: _currentIndex == 0 ? _getNavColor(0, brand) : Colors.grey,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.people,
              size: 20,
              color: _currentIndex == 1 ? _getNavColor(1, brand) : Colors.grey,
            ),
            label: 'Gäste',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.table_restaurant,
              size: 20,
              color: _currentIndex == 2 ? _getNavColor(2, brand) : Colors.grey,
            ),
            label: 'Tisch',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.euro,
              size: 20,
              color: _currentIndex == 3 ? _getNavColor(3, brand) : Colors.grey,
            ),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.assignment,
              size: 20,
              color: _currentIndex == 4 ? _getNavColor(4, brand) : Colors.grey,
            ),
            label: 'Checkliste',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.business,
              size: 20,
              color: _currentIndex == 5 ? _getNavColor(5, brand) : Colors.grey,
            ),
            label: 'Dienstleister',
          ),
        ],
      ),
    );
  }
}
