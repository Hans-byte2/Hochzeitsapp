// lib/App_colors.dart
import 'package:flutter/material.dart';
import 'theme/theme_variant.dart';

class AppColors {
  final Color primary;
  final Color background;
  final Color cardColor;
  final Color cardBorder;
  final Color secondary;
  final Color homeColor;
  final Color guestColor;
  final Color budgetColor;
  final Color taskColor;
  final Color tableColor;
  final Color serviceColor;

  const AppColors._({
    required this.primary,
    required this.background,
    required this.cardColor,
    required this.cardBorder,
    required this.secondary,
    required this.homeColor,
    required this.guestColor,
    required this.budgetColor,
    required this.taskColor,
    required this.tableColor,
    required this.serviceColor,
  });

  factory AppColors._fromBrand(BrandColors c) => AppColors._(
    primary: c.primary,
    background: c.background,
    cardColor: c.cardColor,
    cardBorder: c.cardBorder,
    secondary: c.secondary,
    homeColor: c.homeColor,
    guestColor: c.guestColor,
    budgetColor: c.budgetColor,
    taskColor: c.taskColor,
    tableColor: c.tableColor,
    serviceColor: c.serviceColor,
  );

  static AppColors of(BuildContext context) {
    final ext = Theme.of(context).extension<AppColorsExtension>();
    return ext?.colors ?? _fallback;
  }

  static final _fallback = AppColors._fromBrand(
    colorsFor(ThemeVariant.darkPink),
  );
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final AppColors colors;
  const AppColorsExtension(this.colors);

  @override
  AppColorsExtension copyWith({AppColors? colors}) =>
      AppColorsExtension(colors ?? this.colors);

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return t < 0.5 ? this : other;
  }
}

ThemeData buildThemeWithColors(ThemeVariant variant) {
  final base = buildThemeFor(variant);
  final appColors = AppColors._fromBrand(colorsFor(variant));
  // Bestehende Extensions beibehalten + neue hinzufügen
  final existing = base.extensions.values.toList();
  return base.copyWith(
    extensions: [...existing, AppColorsExtension(appColors)],
  );
}

extension AppColorsContext on BuildContext {
  AppColors get colors => AppColors.of(this);
}
