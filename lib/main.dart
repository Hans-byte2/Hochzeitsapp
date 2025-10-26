import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Core
import 'app_colors.dart';

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

// Dienstleister Screens (bereits vorhanden)
import 'screens/dienstleister_list_screen.dart';

Future<void> deleteDatabase() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'wedding_planner.db');
  await databaseFactory.deleteDatabase(path);
  print('Datenbank gelöscht: $path');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Diese Zeile löscht die Datenbank - nach dem ersten Start wieder entfernen!
  await deleteDatabase();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HeartPebble',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          background: AppColors.background,
          surface: AppColors.cardColor,
        ),
        cardTheme: const CardThemeData(
          color: AppColors.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: AppColors.cardBorder, width: 1),
          ),
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const HochzeitsApp(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HochzeitsApp extends StatefulWidget {
  const HochzeitsApp({Key? key}) : super(key: key);

  @override
  State<HochzeitsApp> createState() => _HochzeitsAppState();
}

class _HochzeitsAppState extends State<HochzeitsApp> {
  int _currentIndex = 0;

  // State
  List<Guest> _guests = [];
  List<Task> _tasks = [];
  DateTime? _weddingDate;
  String _brideName = '';
  String _groomName = '';
  bool _isLoading = true;

  // Key für Budget-Page um sie neu zu erstellen
  Key _budgetPageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Wedding data laden
      final weddingData = await DatabaseHelper.instance.getWeddingData();
      if (weddingData != null) {
        setState(() {
          _weddingDate = weddingData['wedding_date'] != null
              ? DateTime.parse(weddingData['wedding_date'])
              : null;
          _brideName = weddingData['bride_name'] ?? '';
          _groomName = weddingData['groom_name'] ?? '';
        });
      }

      // Gäste laden
      final guests = await DatabaseHelper.instance.getAllGuests();
      setState(() {
        _guests = guests;
      });

      // Tasks laden
      final tasks = await DatabaseHelper.instance.getAllTasks();
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      print('Fehler beim Laden der Daten: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Callback-Funktionen für Gäste
  Future<void> _addGuest(Guest guest) async {
    try {
      final newGuest = await DatabaseHelper.instance.createGuest(guest);
      setState(() {
        _guests.add(newGuest);
      });
    } catch (e) {
      print('Fehler beim Hinzufügen des Gastes: $e');
    }
  }

  Future<void> _updateGuest(Guest updatedGuest) async {
    try {
      await DatabaseHelper.instance.updateGuest(updatedGuest);
      final index = _guests.indexWhere((g) => g.id == updatedGuest.id);
      if (index != -1) {
        setState(() {
          // WICHTIG: Neue Liste erstellen damit Flutter die Änderung erkennt!
          _guests = [
            ..._guests.sublist(0, index),
            updatedGuest,
            ..._guests.sublist(index + 1),
          ];
        });
      }
    } catch (e) {
      print('Fehler beim Aktualisieren des Gastes: $e');
    }
  }

  Future<void> _deleteGuest(int guestId) async {
    try {
      await DatabaseHelper.instance.deleteGuest(guestId);
      setState(() {
        _guests.removeWhere((g) => g.id == guestId);
      });
    } catch (e) {
      print('Fehler beim Löschen des Gastes: $e');
    }
  }

  // Callback-Funktionen für Aufgaben
  Future<void> _addTask(Task task) async {
    try {
      final newTask = await DatabaseHelper.instance.createTask(task);
      setState(() {
        _tasks.add(newTask);
      });
    } catch (e) {
      print('Fehler beim Hinzufügen der Aufgabe: $e');
    }
  }

  Future<void> _updateTask(Task updatedTask) async {
    try {
      await DatabaseHelper.instance.updateTask(updatedTask);
      setState(() {
        final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      });
    } catch (e) {
      print('Fehler beim Aktualisieren der Aufgabe: $e');
    }
  }

  Future<void> _deleteTask(int taskId) async {
    try {
      await DatabaseHelper.instance.deleteTask(taskId);
      setState(() {
        _tasks.removeWhere((t) => t.id == taskId);
      });
    } catch (e) {
      print('Fehler beim Löschen der Aufgabe: $e');
    }
  }

  // Hochzeitsdaten-Callback
  Future<void> _updateWeddingData(
    DateTime date,
    String bride,
    String groom,
  ) async {
    try {
      await DatabaseHelper.instance.updateWeddingData(date, bride, groom);
      setState(() {
        _weddingDate = date;
        _brideName = bride;
        _groomName = groom;
      });
    } catch (e) {
      print('Fehler beim Aktualisieren der Hochzeitsdaten: $e');
    }
  }

  // Navigation Callback
  void _navigateToPage(int pageIndex) {
    setState(() {
      _currentIndex = pageIndex;
    });
  }

  Color _getNavColor(int index) {
    switch (index) {
      case 0:
        return AppColors.homeColor;
      case 1:
        return AppColors.guestColor;
      case 2:
        return AppColors.tableColor;
      case 3:
        return AppColors.budgetColor;
      case 4:
        return AppColors.taskColor;
      case 5:
        return AppColors.serviceColor;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Widget> _pages = [
      DashboardPage(
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
        tasks: _tasks,
        onAddTask: _addTask,
        onUpdateTask: _updateTask,
        onDeleteTask: _deleteTask,
        weddingDate: _weddingDate,
        brideName: _brideName,
        groomName: _groomName,
      ),
      const DienstleisterListScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
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
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: _getNavColor(_currentIndex),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          // Budget-Page neu erstellen wenn sie angezeigt wird
          if (index == 3) {
            setState(() {
              _budgetPageKey = UniqueKey();
            });
          }
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              size: 20,
              color: _currentIndex == 0 ? AppColors.homeColor : Colors.grey,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.people,
              size: 20,
              color: _currentIndex == 1 ? AppColors.guestColor : Colors.grey,
            ),
            label: 'Gäste',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.table_restaurant,
              size: 20,
              color: _currentIndex == 2 ? AppColors.tableColor : Colors.grey,
            ),
            label: 'Tisch',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.euro,
              size: 20,
              color: _currentIndex == 3 ? AppColors.budgetColor : Colors.grey,
            ),
            label: 'Budget',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.assignment,
              size: 20,
              color: _currentIndex == 4 ? AppColors.taskColor : Colors.grey,
            ),
            label: 'Checkliste',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.business,
              size: 20,
              color: _currentIndex == 5 ? AppColors.serviceColor : Colors.grey,
            ),
            label: 'Dienstleister',
          ),
        ],
      ),
    );
  }
}
