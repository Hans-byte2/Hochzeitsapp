// lib/widgets/theme_picker_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_providers.dart';
import '../theme/theme_variant.dart';

class ThemePickerGrid extends ConsumerWidget {
  const ThemePickerGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    // Alle Varianten, die du im Enum hast
    final variants = <ThemeVariant>[
      ThemeVariant.vintageMint,
      ThemeVariant.vintageMintDark,
      ThemeVariant.sandVintageCream,
      ThemeVariant.mintFresh,
      ThemeVariant.mintStone,
      ThemeVariant.seafoamNavy,
      ThemeVariant.champagne,
      ThemeVariant.romanticPink,
      ThemeVariant.cremeElegance,
      ThemeVariant.blackWhite,
      ThemeVariant.royalGold,
      ThemeVariant.frozenMint,
    ];

    String labelFor(ThemeVariant v) {
      switch (v) {
        case ThemeVariant.vintageMint:
          return 'Vintage Mint';
        case ThemeVariant.vintageMintDark:
          return 'Vintage Mint (dunkel)';
        case ThemeVariant.sandVintageCream:
          return 'Sand / Creme';
        case ThemeVariant.mintFresh:
          return 'Mint Fresh';
        case ThemeVariant.mintStone:
          return 'Mint & Stone';
        case ThemeVariant.seafoamNavy:
          return 'Seafoam & Navy';
        case ThemeVariant.champagne:
          return 'Champagner';
        case ThemeVariant.romanticPink:
          return 'Romantic Pink';
        case ThemeVariant.cremeElegance:
          return 'Creme Elegance';
        case ThemeVariant.blackWhite:
          return 'Black & White';
        case ThemeVariant.royalGold:
          return 'Royal Gold';
        case ThemeVariant.frozenMint:
          return 'Frozen Mint';
      }
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: variants.map((variant) {
        final colors = colorsFor(variant);
        final isSelected = variant == current;

        return GestureDetector(
          onTap: () => controller.setVariant(variant),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : colors.cardBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ColorDot(color: colors.primary),
                    const SizedBox(width: 4),
                    _ColorDot(color: colors.secondary),
                    const SizedBox(width: 4),
                    _ColorDot(color: colors.homeColor),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labelFor(variant),
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 1),
      ),
    );
  }
}
