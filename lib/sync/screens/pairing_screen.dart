// lib/sync/screens/pairing_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/sync_service.dart';
import '../../app_colors.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();

  String? _generatedCode;
  bool _isWaiting = false;
  bool _isJoining = false;
  String? _errorMessage;
  bool _isPaired = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkPairingStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _checkPairingStatus() async {
    final status = SyncService.instance.status;
    setState(() => _isPaired = status.isPaired);
  }

  // ── Pairing aufheben ─────────────────────────────────────────────────────
  Future<void> _unpair() async {
    final confirmed = await showDialog<bool>(
      context: context,
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

    if (confirmed != true) return;

    try {
      await SyncService.instance.unpair();
      setState(() {
        _isPaired = false;
        _generatedCode = null;
        _isWaiting = false;
        _errorMessage = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verbindung getrennt'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.of(context).pop(false);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Fehler beim Trennen: $e');
    }
  }
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _createCode() async {
    setState(() {
      _isWaiting = true;
      _errorMessage = null;
    });

    try {
      final code = await SyncService.instance.createPairingCode();
      setState(() => _generatedCode = code);

      final pairInfo = await SyncService.instance.waitForPartner(code);

      if (!mounted) return;

      if (pairInfo != null) {
        _showSuccess('Partner verbunden! Sync startet...');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Zeitüberschreitung – Code abgelaufen.';
          _generatedCode = null;
          _isWaiting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler: $e';
        _isWaiting = false;
      });
    }
  }

  Future<void> _joinWithCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Bitte 6-stelligen Code eingeben.');
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final pairInfo = await SyncService.instance.joinWithCode(code);

      if (!mounted) return;

      if (pairInfo != null) {
        _showSuccess('Verbunden! Sync startet...');
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = 'Code nicht gefunden oder abgelaufen.';
          _isJoining = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Fehler: $e';
        _isJoining = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Partner verbinden'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'Code erstellen'),
            Tab(icon: Icon(Icons.keyboard), text: 'Code eingeben'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Aktueller Status + Trennen-Button ──────────────────────────
          _buildStatusBanner(),
          // ── Tab-Inhalt ─────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildCreateTab(), _buildJoinTab()],
            ),
          ),
        ],
      ),
    );
  }

  /// Zeigt den aktuellen Verbindungsstatus und den Trennen-Button wenn gepairt.
  Widget _buildStatusBanner() {
    final status = SyncService.instance.status;
    final isPaired = status.isPaired;

    if (!isPaired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: Colors.grey.shade100,
        child: Row(
          children: [
            Icon(Icons.link_off, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Kein Partner verbunden',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.green.shade50,
      child: Row(
        children: [
          Icon(Icons.link, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Partner verbunden',
              style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _unpair,
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('Trennen', style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.favorite,
            title: 'Gemeinsam planen',
            text:
                'Erstelle einen Code und lass deinen Partner ihn eingeben. '
                'Eure Daten bleiben auf euren Geräten.',
          ),
          const SizedBox(height: 32),

          if (_generatedCode == null && !_isWaiting) ...[
            ElevatedButton.icon(
              onPressed: _createCode,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Code erstellen'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],

          if (_generatedCode != null) ...[
            Text(
              'Zeig deinem Partner diesen Code:',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _generatedCode!,
                version: QrVersions.auto,
                size: 200,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _generatedCode!));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Code kopiert!')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _generatedCode!,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.copy, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isWaiting) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Warte auf Partner...',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _generatedCode = null;
                    _isWaiting = false;
                  });
                },
                child: const Text('Abbrechen'),
              ),
            ],
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(_errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildInfoCard(
            icon: Icons.link,
            title: 'Partner beitreten',
            text:
                'Gib den 6-stelligen Code ein, den dein Partner erstellt hat.',
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            maxLength: 6,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: 'XXXXXX',
              hintStyle: TextStyle(
                fontSize: 32,
                color: Colors.grey[400],
                letterSpacing: 8,
              ),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.length == 6) _joinWithCode();
            },
          ),
          const SizedBox(height: 24),
          if (_isJoining) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text('Verbinde...', style: TextStyle(color: Colors.grey[600])),
          ] else ...[
            ElevatedButton.icon(
              onPressed: _joinWithCode,
              icon: const Icon(Icons.link),
              label: const Text('Verbinden'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _buildErrorCard(_errorMessage!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
