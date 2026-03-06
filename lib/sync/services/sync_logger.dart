// lib/sync/services/sync_logger.dart

import '../../config/sync_config.dart';

class SyncLogger {
  static void info(String message) {
    if (SyncConfig.enableDebugLogs) {
      print('[SYNC ℹ️] $message');
    }
  }

  static void success(String message) {
    if (SyncConfig.enableDebugLogs) {
      print('[SYNC ✅] $message');
    }
  }

  static void error(String message, [Object? error]) {
    print('[SYNC ❌] $message${error != null ? ": $error" : ""}');
  }

  static void debug(String message) {
    if (SyncConfig.enableDebugLogs) {
      print('[SYNC 🔍] $message');
    }
  }
}
