// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';

// Core / Theme
import 'services/theme_providers.dart';
import 'services/profile_providers.dart';
import 'theme/theme_variant.dart';
import 'sync/services/supabase_signaling.dart';
// Models
import 'models/wedding_models.dart';

// Data
import 'data/database_helper.dart';
import 'data/dienstleister_database.dart';

// Screens
import 'screens/dashboard_screen.dart';
import 'screens/guests_screen.dart';
import 'screens/budget_screen.dart';
import 'screens/planning_screen.dart'; // ← NEU (ersetzt tasks_screen.dart)
import 'screens/table_planning_screen.dart';
import 'screens/dienstleister_list_screen.dart';
import 'screens/settings_page.dart';
import 'screens/onboarding_screen.dart';

// Services
import 'sync/services/sync_service.dart';
import 'services/notification_service.dart';
import 'services/premium_service.dart';

// Utils
import 'utils/error_logger.dart';

// ─────────────────────────────────────────────────────────────
// ENTRY POINT
// ─────────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Locale-Daten für Datumsformatierung (de_DE)
  await initializeDateFormatting('de_DE', null);

  final prefs = await SharedPreferences.getInstance();
  final initialTheme = await resolveInitialVariant(prefs);
  final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

  // DB initialisieren
  final db = await DatabaseHelper.instance.database;

  // PremiumService initialisieren (muss vor dem ersten Build passieren)
  await PremiumService.instance.init(db);
  // Partner-Sync initialisieren
  await SupabaseSignaling.instance.initialize();

  // Dienstleister-Sync-Spalten migrieren
  await DienstleisterDatabase.migrateAddSyncColumns(db);

  // Bestehende Free-Nutzer migrieren
  await _migrateExistingUsers(prefs, db);

  // ── FIX 1: initialize() statt init() ──────────────────────
  await NotificationService.instance.initialize();

  runApp(
    ProviderScope(
      // ── FIX 2: korrektes Override-Pattern (wie in deiner App) ─
      overrides: [
        themeControllerProvider.overrideWith(
          (ref) => ThemeController(prefs, initialTheme),
        ),
        profileControllerProvider.overrideWith((ref) => ProfileController()),
      ],
      child: onboardingCompleted
          ? const HeartPebbleApp()
          : const OnboardingWrapper(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// MIGRATION HELPER
// ─────────────────────────────────────────────────────────────

Future<void> _migrateExistingUsers(SharedPreferences prefs, dynamic db) async {
  final migrated = prefs.getBool('premium_migrated_v1') ?? false;
  if (migrated) return;

  // Bestehende Nutzer die vor dem Premium-System installiert haben
  // bekommen keine automatischen Premium-Rechte – sie bleiben Free.
  // (Hier ggf. Logik für Early-Adopter-Bonus eintragen)

  await prefs.setBool('premium_migrated_v1', true);
  ErrorLogger.info('Nutzer-Migration v1 abgeschlossen');
}

// ─────────────────────────────────────────────────────────────
// ONBOARDING WRAPPER
// ─────────────────────────────────────────────────────────────

class OnboardingWrapper extends StatefulWidget {
  const OnboardingWrapper({super.key});

  @override
  State<OnboardingWrapper> createState() => _OnboardingWrapperState();
}

class _OnboardingWrapperState extends State<OnboardingWrapper> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    if (_done) return const HeartPebbleApp();
    return OnboardingScreen(onFinished: () => setState(() => _done = true));
  }
}

// ─────────────────────────────────────────────────────────────
// ROOT APP
// ─────────────────────────────────────────────────────────────

class HeartPebbleApp extends ConsumerWidget {
  const HeartPebbleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeDataProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HeartPebble',
      theme: theme,
      localizationsDelegates: const [
        // AppLocalizations.delegate,
        // GlobalMaterialLocalizations.delegate,
        // GlobalWidgetsLocalizations.delegate,
        // GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('de'), Locale('en')],
      home: const HochzeitsApp(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HAUPT-APP
// ─────────────────────────────────────────────────────────────

class HochzeitsApp extends ConsumerStatefulWidget {
  const HochzeitsApp({super.key});

  @override
  ConsumerState<HochzeitsApp> createState() => _HochzeitsAppState();
}

class _HochzeitsAppState extends ConsumerState<HochzeitsApp> {
  // ── Navigation ──────────────────────────────────────────────
  int _currentIndex = 0;

  // ── App-State ────────────────────────────────────────────────
  List<Guest> _guests = [];
  List<Task> _tasks = [];
  DateTime? _weddingDate;
  String _brideName = '';
  String _groomName = '';
  bool _isLoading = true;

  // ── Page Keys (für gezieltes Rebuild nach Import / Sync) ─────
  Key _budgetPageKey = UniqueKey();
  Key _tablePageKey = UniqueKey();
  Key _planningPageKey = UniqueKey(); // ← war _taskPageKey

  // ── Task-Navigation vom Dashboard ───────────────────────────
  int? _selectedTaskId;

  // ── GlobalKeys für gezieltes Reload ohne Flackern ────────────
  final GlobalKey<DashboardPageState> _dashboardKey =
      GlobalKey<DashboardPageState>();
  final GlobalKey<EnhancedBudgetPageState> _budgetKey =
      GlobalKey<EnhancedBudgetPageState>();
  final GlobalKey<TischplanungPageState> _tableKey =
      GlobalKey<TischplanungPageState>();

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    ErrorLogger.info('HochzeitsApp gestartet');
    _loadData();
    SyncService.instance.addListener(_onSyncDataReceived);
  }

  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncDataReceived);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // SYNC CALLBACK
  // ─────────────────────────────────────────────────────────────

  void _onSyncDataReceived() {
    debugPrint('🔄 Sync-Event empfangen → gezieltes Reload');
    _loadData();
    _budgetKey.currentState?.reload();
    _tableKey.currentState?.reload();
    _dashboardKey.currentState?.reload();
  }

  // ─────────────────────────────────────────────────────────────
  // DATA LOADING
  // ─────────────────────────────────────────────────────────────

  Future<void> _loadData() async {
    try {
      ErrorLogger.info('Lade App-Daten …');

      final weddingData = await DatabaseHelper.instance.getWeddingData();
      if (weddingData != null && mounted) {
        setState(() {
          _weddingDate = weddingData['wedding_date'] != null
              ? DateTime.parse(weddingData['wedding_date'])
              : null;
          _brideName = weddingData['bride_name'] ?? '';
          _groomName = weddingData['groom_name'] ?? '';
        });
      }

      final guests = await DatabaseHelper.instance.getAllGuests();
      final tasks = await DatabaseHelper.instance.getAllTasks();

      if (mounted) {
        setState(() {
          _guests = guests;
          _tasks = tasks;
          _isLoading = false;
        });
      }
      ErrorLogger.info(
        'Daten geladen – ${_guests.length} Gäste, ${_tasks.length} Tasks',
      );
    } catch (e, st) {
      ErrorLogger.error('Fehler beim Laden der Daten', e, st);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reloadAllData() async {
    debugPrint('🔄 Vollständiger Reload nach Import …');
    setState(() {
      _isLoading = true;
      _budgetPageKey = UniqueKey();
      _tablePageKey = UniqueKey();
      _planningPageKey = UniqueKey();
    });
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daten erfolgreich aktualisiert ✓'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CRUD CALLBACKS
  // ─────────────────────────────────────────────────────────────

  // ── FIX 3: Alle CRUD-Methoden exakt passend zu deinen DB-Signaturen ──

  Future<void> _updateWeddingData(
    DateTime? date,
    String bride,
    String groom,
  ) async {
    // DB erwartet DateTime (nicht nullable) – nur aufrufen wenn date gesetzt
    if (date != null) {
      await DatabaseHelper.instance.updateWeddingData(date, bride, groom);
    }
    if (mounted) {
      setState(() {
        _weddingDate = date;
        _brideName = bride;
        _groomName = groom;
      });
    }
  }

  // ── Tasks ────────────────────────────────────────────────────

  Future<void> _addTask(Task task) async {
    // insertTask erwartet Map<String, dynamic>
    await DatabaseHelper.instance.insertTask(task.toMap());
    final tasks = await DatabaseHelper.instance.getAllTasks();
    if (mounted) setState(() => _tasks = tasks);
    _syncNow();
  }

  Future<void> _updateTask(Task task) async {
    await DatabaseHelper.instance.updateTask(task);
    if (mounted) {
      setState(() {
        final idx = _tasks.indexWhere((t) => t.id == task.id);
        if (idx != -1) _tasks[idx] = task;
      });
    }
    _syncNow();
  }

  Future<void> _deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    if (mounted) setState(() => _tasks.removeWhere((t) => t.id == id));
    _syncNow();
  }

  void _clearSelectedTask() => setState(() => _selectedTaskId = null);

  // ── Guests ───────────────────────────────────────────────────

  Future<void> _addGuest(Guest guest) async {
    await DatabaseHelper.instance.createGuest(guest);
    final guests = await DatabaseHelper.instance.getAllGuests();
    if (mounted) setState(() => _guests = guests);
    _syncNow();
  }

  Future<void> _updateGuest(Guest guest) async {
    await DatabaseHelper.instance.updateGuest(guest);
    if (mounted) {
      setState(() {
        final idx = _guests.indexWhere((g) => g.id == guest.id);
        if (idx != -1) _guests[idx] = guest;
      });
    }
    _syncNow();
  }

  Future<void> _deleteGuest(int id) async {
    await DatabaseHelper.instance.deleteGuest(id);
    if (mounted) setState(() => _guests.removeWhere((g) => g.id == id));
    _syncNow();
  }

  // ── Navigation ───────────────────────────────────────────────

  void _navigateToPage(int index) => setState(() => _currentIndex = index);

  void _navigateToTaskWithId(int taskId) {
    setState(() {
      _selectedTaskId = taskId;
      _currentIndex = 4; // Index 4 = Planung
    });
  }

  // ── Sync ─────────────────────────────────────────────────────

  void _syncNow() {
    SyncService.instance.syncNow().catchError((e) {
      ErrorLogger.error('Sync-Fehler', e);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // NAV COLOR HELPER
  // ─────────────────────────────────────────────────────────────

  Color _getNavColor(int index, dynamic brand) {
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

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final variant = ref.watch(themeControllerProvider);
    final brand = colorsFor(variant);

    // ── Pages ────────────────────────────────────────────────
    final List<Widget> pages = [
      // 0 – Dashboard
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

      // 1 – Gäste
      GuestPage(
        guests: _guests,
        onAddGuest: _addGuest,
        onUpdateGuest: _updateGuest,
        onDeleteGuest: _deleteGuest,
      ),

      // 2 – Tischplanung
      TischplanungPage(
        key: _tableKey,
        guests: _guests,
        onUpdateGuest: _updateGuest,
      ),

      // 3 – Budget
      EnhancedBudgetPage(key: _budgetKey),

      // 4 – Planung  ← war: TaskPage
      PlanningScreen(
        key: _planningPageKey,
        tasks: _tasks,
        onAddTask: _addTask,
        onUpdateTask: _updateTask,
        onDeleteTask: _deleteTask,
        weddingDate: _weddingDate,
        brideName: _brideName,
        groomName: _groomName,
        selectedTaskId: _selectedTaskId,
        onClearSelectedTask: _clearSelectedTask,
        onNavigateToHome: () => setState(() => _currentIndex = 0),
      ),

      // 5 – Dienstleister
      const DienstleisterListScreen(),
    ];

    // ── Scaffold ─────────────────────────────────────────────
    return Scaffold(
      // ── AppBar ─────────────────────────────────────────────
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              height: 22,
              width: 22,
              child: Image.asset(
                'assets/images/heartpepple_logo.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const Text('HeartPebble', style: TextStyle(fontSize: 22)),
          ],
        ),
        backgroundColor: brand.primary,
        foregroundColor: Colors.white,
      ),

      // ── Drawer ────────────────────────────────────────────
      drawer: _buildDrawer(brand),

      // ── Body ──────────────────────────────────────────────
      body: IndexedStack(index: _currentIndex, children: pages),

      // ── BottomNavigationBar ───────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: _getNavColor(_currentIndex, brand),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          if (index == 3) {
            setState(() => _budgetPageKey = UniqueKey());
          }
          if (index == 4) {
            setState(() => _selectedTaskId = null);
          }
          setState(() => _currentIndex = index);
        },
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
              Icons.flag_outlined,
              size: 20,
              color: _currentIndex == 4 ? _getNavColor(4, brand) : Colors.grey,
            ),
            label: 'Planung',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.business,
              size: 20,
              color: _currentIndex == 5 ? _getNavColor(5, brand) : Colors.grey,
            ),
            label: 'Dienst.',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DRAWER
  // ─────────────────────────────────────────────────────────────

  Widget _buildDrawer(dynamic brand) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: brand.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 48,
                  width: 48,
                  child: Image.asset(
                    'assets/images/heartpepple_logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _brideName.isNotEmpty && _groomName.isNotEmpty
                      ? '$_brideName & $_groomName'
                      : 'HeartPebble',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_weddingDate != null)
                  Text(
                    '${_weddingDate!.day.toString().padLeft(2, '0')}.'
                    '${_weddingDate!.month.toString().padLeft(2, '0')}.'
                    '${_weddingDate!.year}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          _drawerItem(Icons.home, 'Home', 0),
          _drawerItem(Icons.people, 'Gäste', 1),
          _drawerItem(Icons.table_restaurant, 'Tischplanung', 2),
          _drawerItem(Icons.euro, 'Budget', 3),
          _drawerItem(Icons.flag_outlined, 'Planung', 4),
          _drawerItem(Icons.business, 'Dienstleister', 5),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Einstellungen'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsPage(onDataReloaded: _reloadAllData),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  ListTile _drawerItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: _currentIndex == index,
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }
}
