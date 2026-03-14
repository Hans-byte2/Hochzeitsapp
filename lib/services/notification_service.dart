import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';
import '../models/wedding_models.dart';

// ============================================================================
// NOTIFICATION SERVICE – kombiniert Task-Erinnerungen + Smart Notifications
//
// Notification-ID-Bereiche:
//   Task-IDs      direkt als ID (task.id)
//   100           Überfällige Zahlungen
//   200           Zahlungen in 7 Tagen fällig
//   300           Tasks in 3 Tagen (Sammel)
//   400           Budget überschritten
//   999           Tägliche Wiederholung 09:00
// ============================================================================

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  static NotificationService get instance => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ── Android Notification Channels ────────────────────────────────────────

  static const _channelTasks = AndroidNotificationChannel(
    'task_reminders',
    'Aufgaben-Erinnerungen',
    description: 'Erinnerungen für Hochzeits-Aufgaben',
    importance: Importance.high,
  );

  static const _channelPayments = AndroidNotificationChannel(
    'heartpebble_payments',
    'Zahlungen',
    description: 'Erinnerungen zu fälligen und überfälligen Zahlungen',
    importance: Importance.high,
  );

  static const _channelBudget = AndroidNotificationChannel(
    'heartpebble_budget',
    'Budget',
    description: 'Budget-Warnungen',
    importance: Importance.high,
  );

  // ── Initialisierung ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channelTasks);
    await androidPlugin?.createNotificationChannel(_channelPayments);
    await androidPlugin?.createNotificationChannel(_channelBudget);

    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
    debugPrint('✅ NotificationService initialisiert');
  }

  // ── Permission Handling ───────────────────────────────────────────────────

  Future<bool> hasPermission() async {
    if (Platform.isAndroid) return await Permission.notification.isGranted;
    return true;
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return (await Permission.notification.request()).isGranted;
    }
    if (Platform.isIOS) {
      final result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return result ?? false;
    }
    return false;
  }

  Future<bool> ensurePermission() async {
    if (await hasPermission()) return true;
    return await requestPermission();
  }

  // ── Task-Erinnerungen (bestehend) ─────────────────────────────────────────

  Future<bool> scheduleTaskNotification({
    required Task task,
    required Duration duration,
  }) async {
    if (task.deadline == null || task.id == null) return false;
    await initialize();
    if (!await ensurePermission()) {
      debugPrint('❌ Benachrichtigungsberechtigung nicht erteilt');
      return false;
    }

    final scheduledDate = task.deadline!.subtract(duration);
    if (scheduledDate.isBefore(DateTime.now())) return false;

    final DateTime notificationTime = duration == Duration.zero
        ? DateTime(
            task.deadline!.year,
            task.deadline!.month,
            task.deadline!.day,
            8,
            0,
          )
        : scheduledDate;

    final scheduledTZ = tz.TZDateTime.from(notificationTime, tz.local);

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        task.id!,
        'Aufgaben-Erinnerung: ${task.title}',
        task.description.isNotEmpty
            ? task.description
            : 'Deadline: ${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}',
        scheduledTZ,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelTasks.id,
            _channelTasks.name,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await _saveNotificationInfo(task.id!, duration);
      debugPrint('✅ Task-Notification geplant für: $notificationTime');
      return true;
    } catch (e) {
      debugPrint('❌ Fehler beim Planen der Task-Notification: $e');
      return false;
    }
  }

  Future<void> cancelTaskNotification(int taskId) async {
    await initialize();
    await flutterLocalNotificationsPlugin.cancel(taskId);
    await _removeNotificationInfo(taskId);
  }

  Future<bool> hasNotification(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('notification_${taskId}_days');
  }

  Future<Duration?> getNotificationDuration(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final days = prefs.getInt('notification_${taskId}_days');
    if (days == null) return null;
    return Duration(days: days);
  }

  Future<void> _saveNotificationInfo(int taskId, Duration duration) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_${taskId}_days', duration.inDays);
  }

  Future<void> _removeNotificationInfo(int taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_${taskId}_days');
  }

  // ── Smart Notifications: Haupt-Check ─────────────────────────────────────

  Future<void> checkAndNotify() async {
    await initialize();
    if (!await hasPermission()) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool('notif_enabled') ?? true)) return;

    await _checkOverduePayments(prefs);
    await _checkUpcomingPayments(prefs);
    await _checkUpcomingTasks(prefs);
    await _checkBudget(prefs);
    debugPrint('✅ Smart Notification-Check abgeschlossen');
  }

  // ── Tägliche geplante Notification 09:00 ─────────────────────────────────

  Future<void> scheduleDailyCheck() async {
    await initialize();
    if (!await hasPermission()) return;

    await flutterLocalNotificationsPlugin.cancel(999);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9,
      0,
    );
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await flutterLocalNotificationsPlugin.zonedSchedule(
      999,
      'HeartPebble',
      'Deine tägliche Hochzeits-Zusammenfassung',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelBudget.id,
          _channelBudget.name,
          importance: Importance.low,
          priority: Priority.low,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    debugPrint('✅ Tägliche Notification geplant für 09:00');
  }

  // ── Check-Methoden ────────────────────────────────────────────────────────

  Future<void> _checkOverduePayments(SharedPreferences prefs) async {
    if (!(prefs.getBool('notif_overdue') ?? true)) return;
    try {
      final plans = await DatabaseHelper.instance.getAllPaymentPlans();
      final overdue = plans.where((p) => p.isOverdue).toList();
      if (overdue.isEmpty) return;
      final total = overdue.fold(0.0, (s, p) => s + p.amount);
      await _show(
        id: 100,
        title:
            '🚨 ${overdue.length} überfällige ${overdue.length == 1 ? 'Zahlung' : 'Zahlungen'}',
        body: overdue.length == 1
            ? '${overdue.first.vendorName}: ${overdue.first.amount.toStringAsFixed(0)} € – fällig war ${_fmt(overdue.first.dueDate)}'
            : '${overdue.length} Zahlungen · insgesamt ${total.toStringAsFixed(0)} € überfällig',
        channelId: _channelPayments.id,
        channelName: _channelPayments.name,
        importance: Importance.high,
      );
    } catch (e) {
      debugPrint('_checkOverduePayments: $e');
    }
  }

  Future<void> _checkUpcomingPayments(SharedPreferences prefs) async {
    if (!(prefs.getBool('notif_upcoming') ?? true)) return;
    try {
      final plans = await DatabaseHelper.instance.getAllPaymentPlans();
      final upcoming = plans.where((p) {
        if (p.paid || p.isOverdue) return false;
        final diff = p.dueDate.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 7;
      }).toList();
      if (upcoming.isEmpty) return;
      upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      final next = upcoming.first;
      final diff = next.dueDate.difference(DateTime.now()).inDays;
      await _show(
        id: 200,
        title:
            '📅 ${upcoming.length == 1 ? 'Zahlung' : '${upcoming.length} Zahlungen'} bald fällig',
        body: upcoming.length == 1
            ? '${next.vendorName}: ${next.amount.toStringAsFixed(0)} € in $diff ${diff == 1 ? 'Tag' : 'Tagen'}'
            : 'Nächste: ${next.vendorName} in $diff ${diff == 1 ? 'Tag' : 'Tagen'}',
        channelId: _channelPayments.id,
        channelName: _channelPayments.name,
        importance: Importance.high,
      );
    } catch (e) {
      debugPrint('_checkUpcomingPayments: $e');
    }
  }

  Future<void> _checkUpcomingTasks(SharedPreferences prefs) async {
    if (!(prefs.getBool('notif_tasks') ?? true)) return;
    try {
      final tasks = await DatabaseHelper.instance.getAllTasks();
      final urgent = tasks.where((t) {
        if (t.completed || t.deadline == null) return false;
        final diff = t.deadline!.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 3;
      }).toList();
      if (urgent.isEmpty) return;
      urgent.sort((a, b) => a.deadline!.compareTo(b.deadline!));
      final next = urgent.first;
      final diff = next.deadline!.difference(DateTime.now()).inDays;
      await _show(
        id: 300,
        title:
            '✅ ${urgent.length == 1 ? 'Aufgabe' : '${urgent.length} Aufgaben'} bald fällig',
        body: urgent.length == 1
            ? '„${next.title}" – ${diff == 0 ? 'heute' : 'in $diff ${diff == 1 ? 'Tag' : 'Tagen'}'} fällig'
            : '${urgent.length} Aufgaben in den nächsten 3 Tagen fällig',
        channelId: _channelTasks.id,
        channelName: _channelTasks.name,
        importance: Importance.defaultImportance,
      );
    } catch (e) {
      debugPrint('_checkUpcomingTasks: $e');
    }
  }

  Future<void> _checkBudget(SharedPreferences prefs) async {
    if (!(prefs.getBool('notif_budget') ?? true)) return;
    try {
      final totalBudget = await DatabaseHelper.instance.getTotalBudget();
      if (totalBudget <= 0) return;
      final items = await DatabaseHelper.instance.getAllBudgetItems();
      final totalActual = items.fold(0.0, (s, i) => s + i.actual);
      if (totalActual <= totalBudget) return;
      final diff = totalActual - totalBudget;
      final pct = ((diff / totalBudget) * 100).toStringAsFixed(1);
      await _show(
        id: 400,
        title: '⚠️ Budget überschritten',
        body:
            'Das Hochzeitsbudget ist um ${diff.toStringAsFixed(0)} € ($pct%) überzogen',
        channelId: _channelBudget.id,
        channelName: _channelBudget.name,
        importance: Importance.high,
      );
    } catch (e) {
      debugPrint('_checkBudget: $e');
    }
  }

  // ── Alle löschen ──────────────────────────────────────────────────────────

  Future<void> cancelAllNotifications() async {
    await initialize();
    await flutterLocalNotificationsPlugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((k) => k.startsWith('notification_'))
        .toList();
    for (final key in keys) await prefs.remove(key);
  }

  // Alias für NotificationSettingsWidget
  Future<void> cancelAll() => cancelAllNotifications();

  // ── Helper ────────────────────────────────────────────────────────────────

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    Importance importance = Importance.defaultImportance,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority: importance == Importance.high
              ? Priority.high
              : Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}
