import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/wedding_models.dart';

class CalendarExportService {
  /// Exportiert Tasks als ICS-Datei für Outlook/Kalender
  static Future<void> exportTasksToCalendar({
    required List<Task> tasks,
    String? brideName,
    String? groomName,
  }) async {
    try {
      // ICS-Content erstellen
      final icsContent = _generateICSContent(
        tasks: tasks,
        brideName: brideName,
        groomName: groomName,
      );

      // Datei speichern
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory.path}/hochzeit_aufgaben_$timestamp.ics';

      final file = File(filePath);
      await file.writeAsString(icsContent);

      // Datei teilen/öffnen
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Hochzeitsplanung - Aufgaben',
        text:
            'Hier sind die Aufgaben für die Hochzeitsplanung als Kalender-Datei',
      );

      if (kDebugMode) {
        print('ICS-Datei erstellt: $filePath');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fehler beim Erstellen der ICS-Datei: $e');
      }
      rethrow;
    }
  }

  /// Generiert den ICS-Content im iCalendar-Format
  static String _generateICSContent({
    required List<Task> tasks,
    String? brideName,
    String? groomName,
  }) {
    final buffer = StringBuffer();

    // ICS-Header
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//HeartPebble//Hochzeitsplanung//DE');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    final calendarName = brideName != null && groomName != null
        ? 'Hochzeit $brideName & $groomName'
        : 'Hochzeitsplanung';
    buffer.writeln('X-WR-CALNAME:$calendarName');
    buffer.writeln('X-WR-TIMEZONE:Europe/Berlin');

    // Tasks mit Deadline als Events hinzufügen
    for (final task in tasks) {
      if (task.deadline != null) {
        buffer.write(_generateEventForTask(task));
      }
    }

    // ICS-Footer
    buffer.writeln('END:VCALENDAR');

    return buffer.toString();
  }

  /// Erstellt ein VEVENT für eine einzelne Task
  static String _generateEventForTask(Task task) {
    final buffer = StringBuffer();
    final now = DateTime.now().toUtc();
    final deadline = task.deadline!;

    // UID für das Event (eindeutig)
    final uid =
        'heartpebble-task-${task.id ?? deadline.millisecondsSinceEpoch}@heartpebble.app';

    // Timestamps im iCalendar-Format (YYYYMMDDTHHMMSSZ)
    final dtstamp = _formatICalDateTime(now);
    final dtstart = _formatICalDate(deadline);

    // Priorität mapping
    final priority = _mapPriorityToICS(task.priority);

    // Status basierend auf completed
    final status = task.completed ? 'COMPLETED' : 'NEEDS-ACTION';

    // Kategorie-Label
    final categoryLabels = {
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
    final categoryLabel = categoryLabels[task.category] ?? task.category;

    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln('UID:$uid');
    buffer.writeln('DTSTAMP:$dtstamp');
    buffer.writeln('DTSTART;VALUE=DATE:$dtstart');
    buffer.writeln('SUMMARY:${_escapeICSText(task.title)}');

    if (task.description.isNotEmpty) {
      buffer.writeln('DESCRIPTION:${_escapeICSText(task.description)}');
    }

    buffer.writeln('CATEGORIES:Hochzeit,$categoryLabel');
    buffer.writeln('PRIORITY:$priority');
    buffer.writeln('STATUS:$status');

    // Wenn die Task erledigt ist, setze auch COMPLETED
    if (task.completed) {
      final completedStamp = _formatICalDateTime(now);
      buffer.writeln('COMPLETED:$completedStamp');
    }

    // Reminder 1 Tag vorher
    if (!task.completed) {
      buffer.writeln('BEGIN:VALARM');
      buffer.writeln('TRIGGER:-P1D');
      buffer.writeln('ACTION:DISPLAY');
      buffer.writeln('DESCRIPTION:Erinnerung: ${_escapeICSText(task.title)}');
      buffer.writeln('END:VALARM');
    }

    buffer.writeln('END:VEVENT');

    return buffer.toString();
  }

  /// Formatiert DateTime für iCalendar (UTC): YYYYMMDDTHHMMSSZ
  static String _formatICalDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year}${_pad(utc.month)}${_pad(utc.day)}T'
        '${_pad(utc.hour)}${_pad(utc.minute)}${_pad(utc.second)}Z';
  }

  /// Formatiert Date für iCalendar (ohne Zeit): YYYYMMDD
  static String _formatICalDate(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}';
  }

  /// Fügt führende Null hinzu wenn nötig
  static String _pad(int value) {
    return value.toString().padLeft(2, '0');
  }

  /// Escaped Sonderzeichen für ICS-Text
  static String _escapeICSText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n');
  }

  /// Mapped Flutter-Priorität zu ICS-Priorität
  /// ICS: 1 (höchste) bis 9 (niedrigste), 0 = undefiniert
  static int _mapPriorityToICS(String priority) {
    switch (priority) {
      case 'high':
        return 1;
      case 'medium':
        return 5;
      case 'low':
        return 9;
      default:
        return 0;
    }
  }
}
