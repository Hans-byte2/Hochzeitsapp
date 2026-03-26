// lib/sync/screens/sync_status_widget.dart
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../models/sync_models.dart';
import 'pairing_screen.dart';
import 'package:hochzeits_planer/App_colors.dart';

class SyncStatusWidget extends StatelessWidget {
  final bool compact;
  const SyncStatusWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SyncService.instance,
      builder: (context, _) {
        final status = SyncService.instance.status;
        if (compact) return _buildCompact(context, status);
        return _buildFull(context, status);
      },
    );
  }

  Widget _buildCompact(BuildContext context, SyncStatus status) {
    final (icon, color, label) = _getStatusInfo(status, context);
    return InkWell(
      onTap: () => _handleTap(context, status),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context, SyncStatus status) {
    final (icon, color, label) = _getStatusInfo(status, context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: color.withOpacity(0.06),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Partner-Sync',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(label, style: TextStyle(color: color, fontSize: 13)),
                    ],
                  ),
                ),
                _buildActionButton(context, status),
              ],
            ),
            if (status.lastSyncAt != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.history, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Zuletzt sync: ${_formatTime(status.lastSyncAt!)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
            if (status.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                status.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, SyncStatus status) {
    switch (status.connectionState) {
      case SyncConnectionState.unpaired:
        return TextButton.icon(
          onPressed: () => _openPairingScreen(context),
          icon: const Icon(Icons.add_link, size: 16),
          label: const Text('Verbinden'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.of(context).primary,
          ),
        );
      case SyncConnectionState.connected:
        return IconButton(
          onPressed: () => SyncService.instance.syncNow(),
          icon: const Icon(Icons.sync, size: 20),
          tooltip: 'Jetzt syncen',
          color: Colors.green,
        );
      case SyncConnectionState.syncing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case SyncConnectionState.partnerOffline:
        return TextButton.icon(
          onPressed: () => SyncService.instance.syncNow(),
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('Sync'),
          style: TextButton.styleFrom(foregroundColor: Colors.orange),
        );
      case SyncConnectionState.error:
        return TextButton.icon(
          onPressed: () => SyncService.instance.initialize(),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        );
      case SyncConnectionState.connecting:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    }
  }

  (IconData, Color, String) _getStatusInfo(
    SyncStatus status,
    BuildContext context,
  ) {
    switch (status.connectionState) {
      case SyncConnectionState.unpaired:
        return (Icons.link_off, Colors.grey, 'Nicht verbunden');
      case SyncConnectionState.connecting:
        return (Icons.sync, Colors.blue, 'Verbindet...');
      case SyncConnectionState.connected:
        return (Icons.favorite, Colors.green, 'Partner online ❤️');
      case SyncConnectionState.partnerOffline:
        return (Icons.wifi_off, Colors.orange, 'Partner offline');
      case SyncConnectionState.syncing:
        return (Icons.sync, AppColors.of(context).primary, 'Synchronisiert...');
      case SyncConnectionState.error:
        return (Icons.error_outline, Colors.red, 'Sync-Fehler');
    }
  }

  // ── Tap-Handler ───────────────────────────────────────────────────────────

  void _handleTap(BuildContext context, SyncStatus status) {
    if (!status.isPaired) {
      _openPairingScreen(context);
    } else {
      _showSyncDialog(context, status);
    }
  }

  /// Dialog wenn gepairt: zeigt Status + Sync + Trennen
  void _showSyncDialog(BuildContext context, SyncStatus status) {
    final (icon, color, label) = _getStatusInfo(status, context);

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            const Text('Partner-Sync'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status-Zeile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (status.lastSyncAt != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.history, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    'Zuletzt: ${_formatTime(status.lastSyncAt!)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ],
            if (status.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                status.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          // Trennen
          TextButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _confirmUnpair(context);
            },
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('Trennen'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          // Jetzt syncen
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              SyncService.instance.syncNow();
            },
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Jetzt syncen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Bestätigungsdialog vor dem Trennen
  Future<void> _confirmUnpair(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Verbindung trennen?'),
        content: const Text(
          'Die Verbindung zum Partner wird getrennt.\n\n'
          'Deine lokalen Daten bleiben erhalten. '
          'Du kannst jederzeit neu verbinden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Trennen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await SyncService.instance.unpair();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verbindung getrennt'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _openPairingScreen(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PairingScreen()));
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'gerade eben';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std';
    return 'vor ${diff.inDays} Tagen';
  }
}
