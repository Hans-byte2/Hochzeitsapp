import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/wedding_models.dart';

class CalendarExportService {
  /// Exportiert Tasks als ICS-Datei (iCalendar-Format)
  /// mit konfigurierbaren Erinnerungen
  static Future<void> exportTasksToCalendar({
    required List<Task> tasks,
    required String brideName,
    required String groomName,
    List<String> reminderOptions = const ['1day'],
  }) async {
    try {
      // Nur Tasks mit Deadline
      final tasksWithDeadline = tasks.where((t) => t.deadline != null).toList();

      if (tasksWithDeadline.isEmpty) {
        throw Exception('Keine Aufgaben mit Deadlines gefunden');
      }

      // ICS-Datei erstellen
      final icsContent = _generateICSContent(
        tasks: tasksWithDeadline,
        brideName: brideName,
        groomName: groomName,
        reminderOptions: reminderOptions,
      );

      // Speichern
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'HeartPebble_Aufgaben_$timestamp.ics';
      final file = File('${directory.path}/$fileName');

      await file.writeAsString(icsContent);

      // Teilen mit share_plus
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/calendar')],
        subject: 'HeartPebble Aufgaben - $brideName & $groomName',
        text: 'Hochzeitsplanung für $brideName & $groomName',
      );
    } catch (e) {
      throw Exception('Fehler beim Exportieren: $e');
    }
  }

  /// Generiert den ICS-Content
  static String _generateICSContent({
    required List<Task> tasks,
    required String brideName,
    required String groomName,
    required List<String> reminderOptions,
  }) {
    final now = DateTime.now().toUtc();
    final StringBuffer ics = StringBuffer();

    // ICS Header
    ics.writeln('BEGIN:VCALENDAR');
    ics.writeln('VERSION:2.0');
    ics.writeln('PRODID:-//HeartPebble//Hochzeitsplaner//DE');
    ics.writeln('CALSCALE:GREGORIAN');
    ics.writeln('METHOD:PUBLISH');
    ics.writeln('X-WR-CALNAME:HeartPebble - $brideName & $groomName');
    ics.writeln('X-WR-TIMEZONE:Europe/Berlin');
    ics.writeln('X-WR-CALDESC:Hochzeitsplanung für $brideName & $groomName');

    // Tasks als VEVENT
    for (final task in tasks) {
      if (task.deadline == null) continue;

      final deadline = task.deadline!;
      final uid =
          'task-${task.id ?? now.millisecondsSinceEpoch}-${task.title.hashCode}@heartpebble.app';

      ics.writeln('BEGIN:VEVENT');
      ics.writeln('UID:$uid');
      ics.writeln('DTSTAMP:${_formatDateTime(now)}');
      ics.writeln('DTSTART;VALUE=DATE:${_formatDate(deadline)}');
      ics.writeln('DTEND;VALUE=DATE:${_formatDate(deadline)}');
      ics.writeln('SUMMARY:${_escapeText(task.title)}');

      // Beschreibung
      final description = _buildDescription(task);
      if (description.isNotEmpty) {
        ics.writeln('DESCRIPTION:${_escapeText(description)}');
      }

      // Kategorie
      final categoryLabel = _getCategoryLabel(task.category);
      ics.writeln('CATEGORIES:$categoryLabel');

      // Priorität (1=Hoch, 5=Mittel, 9=Niedrig)
      final priority = _getPriorityValue(task.priority);
      ics.writeln('PRIORITY:$priority');

      // Status
      ics.writeln('STATUS:${task.completed ? "COMPLETED" : "NEEDS-ACTION"}');

      // Erinnerungen (VALARM) basierend auf reminderOptions
      for (final reminder in reminderOptions) {
        ics.writeln(_generateAlarm(reminder));
      }

      ics.writeln('END:VEVENT');
    }

    // ICS Footer
    ics.writeln('END:VCALENDAR');

    return ics.toString();
  }

  /// Generiert einen VALARM-Block basierend auf der Option
  static String _generateAlarm(String reminderOption) {
    final StringBuffer alarm = StringBuffer();

    String trigger;
    String description;

    switch (reminderOption) {
      case '1day':
        trigger = '-P1D'; // 1 Tag vorher
        description = 'Erinnerung: 1 Tag vorher';
        break;
      case '3days':
        trigger = '-P3D'; // 3 Tage vorher
        description = 'Erinnerung: 3 Tage vorher';
        break;
      case '1week':
        trigger = '-P1W'; // 1 Woche vorher
        description = 'Erinnerung: 1 Woche vorher';
        break;
      case '2weeks':
        trigger = '-P2W'; // 2 Wochen vorher
        description = 'Erinnerung: 2 Wochen vorher';
        break;
      default:
        trigger = '-P1D';
        description = 'Erinnerung';
    }

    alarm.writeln('BEGIN:VALARM');
    alarm.writeln('ACTION:DISPLAY');
    alarm.writeln('DESCRIPTION:$description');
    alarm.writeln('TRIGGER:$trigger');
    alarm.writeln('END:VALARM');

    return alarm.toString();
  }

  /// Erstellt eine Beschreibung für die Aufgabe
  static String _buildDescription(Task task) {
    final parts = <String>[];

    if (task.description.isNotEmpty) {
      parts.add(task.description);
    }

    parts.add('\nKategorie: ${_getCategoryLabel(task.category)}');
    parts.add('Priorität: ${_getPriorityLabel(task.priority)}');

    if (task.completed) {
      parts.add('Status: ✓ Erledigt');
    } else {
      parts.add('Status: ○ Offen');
    }

    parts.add('\n📱 Erstellt mit HeartPebble');

    return parts.join('\n');
  }

  /// Formatiert DateTime für ICS (UTC)
  static String _formatDateTime(DateTime dt) {
    final utc = dt.toUtc();
    return '${utc.year}'
        '${utc.month.toString().padLeft(2, '0')}'
        '${utc.day.toString().padLeft(2, '0')}'
        'T'
        '${utc.hour.toString().padLeft(2, '0')}'
        '${utc.minute.toString().padLeft(2, '0')}'
        '${utc.second.toString().padLeft(2, '0')}'
        'Z';
  }

  /// Formatiert Datum für ICS (nur Datum, kein Zeit)
  static String _formatDate(DateTime dt) {
    return '${dt.year}'
        '${dt.month.toString().padLeft(2, '0')}'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  /// Escaped Sonderzeichen für ICS
  static String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;')
        .replaceAll('\n', '\\n');
  }

  /// Kategorie-Label
  static String _getCategoryLabel(String category) {
    const labels = {
      'location': 'Location',
      'catering': 'Catering',
      'decoration': 'Dekoration',
      'clothing': 'Kleidung',
      'documentation': 'Dokumente',
      'music': 'Musik',
      'photography': 'Fotografie',
      'flowers': 'Blumen',
      'timeline': 'Timeline/Checkliste',
      'other': 'Sonstiges',
    };
    return labels[category] ?? category;
  }

  /// Priorität-Label
  static String _getPriorityLabel(String priority) {
    const labels = {'high': 'Hoch', 'medium': 'Mittel', 'low': 'Niedrig'};
    return labels[priority] ?? priority;
  }

  /// Priorität-Wert für ICS (1=Hoch, 5=Mittel, 9=Niedrig)
  static int _getPriorityValue(String priority) {
    switch (priority) {
      case 'high':
        return 1;
      case 'medium':
        return 5;
      case 'low':
        return 9;
      default:
        return 5;
    }
  }
}
