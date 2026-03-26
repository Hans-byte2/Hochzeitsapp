// lib/widgets/theme_picker_grid.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/theme_variant.dart';
import '../services/theme_providers.dart';

class ThemePickerGrid extends ConsumerWidget {
  const ThemePickerGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeControllerProvider);
    final controller = ref.read(themeControllerProvider.notifier);

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: ThemeVariant.values.map((variant) {
        final colors = colorsFor(variant);
        final isActive = variant == current;
        final label = themeDisplayName(variant);
        final emoji = themeEmoji(variant);

        return GestureDetector(
          onTap: () => controller.setVariant(variant),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: colors.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive ? colors.primary : colors.cardBorder,
                width: isActive ? 2.5 : 1,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: colors.primary.withOpacity(0.3),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Farbvorschau — 4 Segmente
                Row(
                  children: [
                    Expanded(child: _seg(colors.background, isLeft: true)),
                    Expanded(child: _seg(colors.primary)),
                    Expanded(child: _seg(colors.secondary)),
                    Expanded(child: _seg(colors.cardColor, isRight: true)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$emoji $label',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? colors.primary : colors.homeColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isActive)
                  Icon(Icons.check_circle, size: 12, color: colors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _seg(Color color, {bool isLeft = false, bool isRight = false}) {
    return Container(
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? const Radius.circular(4) : Radius.zero,
          right: isRight ? const Radius.circular(4) : Radius.zero,
        ),
      ),
    );
  }
}
