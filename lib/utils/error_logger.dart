// lib/utils/error_logger.dart

import 'package:flutter/material.dart';

class ErrorLogger {
  static final List<String> _logs = [];
  static int _errorCount = 0;

  // Fehler loggen
  static void error(String message, [dynamic error, StackTrace? stack]) {
    final log = '❌ ERROR: $message ${error ?? ""}';
    _logs.add('${DateTime.now().toString().substring(11, 19)} $log');
    _errorCount++;
    print(log); // Auch in Console falls vorhanden
  }

  // Info loggen
  static void info(String message) {
    final log = 'ℹ️ $message';
    _logs.add('${DateTime.now().toString().substring(11, 19)} $log');
    print(log);
  }

  // Success loggen
  static void success(String message) {
    final log = '✅ $message';
    _logs.add('${DateTime.now().toString().substring(11, 19)} $log');
    print(log);
  }

  // Dialog zeigen
  static void showDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Debug Logs ($_errorCount Fehler)',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: _logs.isEmpty
                  ? const Center(child: Text('Keine Logs'))
                  : ListView.builder(
                      reverse: true, // Neueste zuerst
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        final log = _logs[_logs.length - 1 - index];
                        final isError = log.contains('❌');

                        return Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isError
                                ? Colors.red.shade50
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: SelectableText(
                            log,
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: isError ? Colors.red : Colors.black87,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    _logs.clear();
                    _errorCount = 0;
                    Navigator.pop(ctx);
                  },
                  child: const Text('Löschen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
