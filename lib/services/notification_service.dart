import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wedding_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (Platform.isIOS) {
      final result = await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      // Ignoriere result, da wir nur prüfen ob die Permissions angefragt wurden
    }

    _initialized = true;
  }

  Future<bool> scheduleTaskNotification({
    required Task task,
    required Duration duration,
  }) async {
    if (task.deadline == null || task.id == null) return false;

    await initialize();

    final scheduledDate = task.deadline!.subtract(duration);

    // Wenn die Erinnerung in der Vergangenheit liegt, nicht planen
    if (scheduledDate.isBefore(DateTime.now())) {
      return false;
    }

    // Bei "Am selben Tag" setze auf 08:00 Uhr
    DateTime notificationTime;
    if (duration == Duration.zero) {
      notificationTime = DateTime(
        task.deadline!.year,
        task.deadline!.month,
        task.deadline!.day,
        8,
        0,
      );
    } else {
      notificationTime = scheduledDate;
    }

    final tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
      notificationTime,
      tz.local,
    );

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'task_reminders',
          'Aufgaben-Erinnerungen',
          channelDescription: 'Erinnerungen für Hochzeits-Aufgaben',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        task.id!,
        'Aufgaben-Erinnerung: ${task.title}',
        task.description.isNotEmpty
            ? task.description
            : 'Deadline: ${task.deadline!.day}.${task.deadline!.month}.${task.deadline!.year}',
        scheduledTZ,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      // Speichere die Notification-Info in SharedPreferences
      await _saveNotificationInfo(task.id!, duration);

      return true;
    } catch (e) {
      print('Fehler beim Planen der Notification: $e');
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
    return prefs.containsKey('notification_$taskId');
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

  Future<void> cancelAllNotifications() async {
    await initialize();
    await flutterLocalNotificationsPlugin.cancelAll();

    // Lösche alle gespeicherten Notification-Infos
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where(
      (key) => key.startsWith('notification_'),
    );
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
