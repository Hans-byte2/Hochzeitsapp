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

    final items = <_ThemeChoice>[
      _ThemeChoice(ThemeVariant.vintageMint, 'Vintage Mint'),
      _ThemeChoice(ThemeVariant.sandVintageCream, 'Sand Vintage Cream'),
      _ThemeChoice(ThemeVariant.mintFresh, 'Fresh Mint & Sand'),
      _ThemeChoice(ThemeVariant.mintStone, 'Soft Mint & Stone'),
      _ThemeChoice(ThemeVariant.seafoamNavy, 'Seafoam & Navy'),
      _ThemeChoice(ThemeVariant.champagne, 'Champagne + Midnight'),
      _ThemeChoice(ThemeVariant.vintageMintDark, 'Vintage Mint (Dark)'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final c = colorsFor(item.variant);
        final selected = current == item.variant;

        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => ref
              .read(themeControllerProvider.notifier)
              .setVariant(item.variant),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Theme.of(ctx).colorScheme.primary
                    : c.cardBorder,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Container(color: c.primary)),
                        Expanded(child: Container(color: c.secondary)),
                        Expanded(child: Container(color: c.homeColor)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      if (selected)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeChoice {
  final ThemeVariant variant;
  final String label;
  const _ThemeChoice(this.variant, this.label);
}
