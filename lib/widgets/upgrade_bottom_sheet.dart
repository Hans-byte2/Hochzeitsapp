// lib/widgets/upgrade_bottom_sheet.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/premium_service.dart';
import '../data/database_helper.dart';

// ── Produkt-ID – muss exakt mit Google Play Console übereinstimmen ──────────
const String kPremiumProductId = 'heartpebble_premium';

/// Zeigt einen Premium-Upgrade Hinweis als BottomSheet.
class UpgradeBottomSheet extends StatefulWidget {
  final String featureName;
  final String featureDescription;

  const UpgradeBottomSheet({
    super.key,
    required this.featureName,
    required this.featureDescription,
  });

  static Future<void> show(
    BuildContext context, {
    required String featureName,
    required String featureDescription,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UpgradeBottomSheet(
        featureName: featureName,
        featureDescription: featureDescription,
      ),
    );
  }

  @override
  State<UpgradeBottomSheet> createState() => _UpgradeBottomSheetState();
}

class _UpgradeBottomSheetState extends State<UpgradeBottomSheet> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  ProductDetails? _product;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isAvailable = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initIAP();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initIAP() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (mounted)
        setState(() {
          _isAvailable = false;
          _isLoading = false;
        });
      return;
    }

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (e) {
        if (mounted) setState(() => _errorMessage = 'Fehler: $e');
      },
    );

    final response = await _iap.queryProductDetails({kPremiumProductId});
    if (mounted) {
      setState(() {
        _isAvailable = true;
        _isLoading = false;
        if (response.productDetails.isNotEmpty) {
          _product = response.productDetails.first;
        } else {
          _errorMessage =
              'Produkt nicht gefunden. '
              'Stelle sicher dass du die App aus dem Play Store installiert hast.';
        }
      });
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kPremiumProductId) continue;

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        final db = await DatabaseHelper.instance.database;
        await PremiumService.instance.unlock(db);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Premium erfolgreich aktiviert!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _errorMessage = purchase.error?.message ?? 'Kauf fehlgeschlagen.';
          });
        }
      } else if (purchase.status == PurchaseStatus.canceled) {
        if (mounted) setState(() => _isPurchasing = false);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _purchase() async {
    if (_product == null) return;
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });
    final purchaseParam = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });
    await _iap.restorePurchases();
    if (mounted) setState(() => _isPurchasing = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium,
              size: 40,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 16),

          // Titel
          Text(
            'Premium Feature',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // Feature-Name + Beschreibung
          Text(
            widget.featureName,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.featureDescription,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),

          // Feature-Liste
          Container(
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mit Premium bekommst du:',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _FeatureRow(
                  icon: Icons.people,
                  text: 'Unbegrenzte Gäste & Tische',
                ),
                _FeatureRow(icon: Icons.sync, text: 'Partner-Sync in Echtzeit'),
                _FeatureRow(icon: Icons.psychology, text: 'KI-Budget Analyse'),
                _FeatureRow(
                  icon: Icons.calendar_today,
                  text: 'Zahlungsplan & Zeitstrahl',
                ),
                _FeatureRow(
                  icon: Icons.picture_as_pdf,
                  text: 'Vollständiger PDF & Excel Export',
                ),
                _FeatureRow(
                  icon: Icons.notifications_active,
                  text: 'Smart Notifications',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Fehler-Meldung
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.red.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Kauf-Button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading || _isPurchasing || _product == null
                  ? null
                  : _purchase,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading || _isPurchasing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.workspace_premium, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _product != null
                              ? 'Jetzt upgraden – ${_product!.price}'
                              : 'Jetzt upgraden – 9,99 €',
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),

          // Einmalig-Hinweis
          Text(
            'Einmaliger Kauf · Kein Abo · Für immer',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurface.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 4),

          // Kauf wiederherstellen
          TextButton(
            onPressed: _isPurchasing ? null : _restorePurchases,
            child: Text(
              'Kauf wiederherstellen',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),

          // Später
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Später',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 10),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
