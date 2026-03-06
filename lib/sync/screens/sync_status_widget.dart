// lib/sync/screens/sync_status_widget.dart
import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../models/sync_models.dart';
import 'pairing_screen.dart';
import '../../app_colors.dart';

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
    final (icon, color, label) = _getStatusInfo(status);
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
    final (icon, color, label) = _getStatusInfo(status);
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
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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

  (IconData, Color, String) _getStatusInfo(SyncStatus status) {
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
        return (Icons.sync, AppColors.primary, 'Synchronisiert...');
      case SyncConnectionState.error:
        return (Icons.error_outline, Colors.red, 'Sync-Fehler');
    }
  }

  void _handleTap(BuildContext context, SyncStatus status) {
    if (!status.isPaired) {
      _openPairingScreen(context);
    } else {
      SyncService.instance.syncNow();
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
