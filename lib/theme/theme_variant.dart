// lib/theme/theme_variant.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

enum ThemeVariant {
  vintageMint,
  vintageMintDark,
  sandVintageCream,
  mintFresh,
  mintStone,
  seafoamNavy,
  champagne,

  // 👇 NEU
  romanticPink,
  cremeElegance,
  blackWhite,
  royalGold,
  frozenMint,
}

class BrandColors {
  final Color primary, background, cardColor, cardBorder, secondary;
  final Color homeColor,
      guestColor,
      budgetColor,
      taskColor,
      tableColor,
      serviceColor;

  const BrandColors({
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
}

BrandColors colorsFor(ThemeVariant v) {
  switch (v) {
    case ThemeVariant.vintageMint:
      return const BrandColors(
        primary: AppColorsVintageMint.primary,
        background: AppColorsVintageMint.background,
        cardColor: AppColorsVintageMint.cardColor,
        cardBorder: AppColorsVintageMint.cardBorder,
        secondary: AppColorsVintageMint.secondary,
        homeColor: AppColorsVintageMint.homeColor,
        guestColor: AppColorsVintageMint.guestColor,
        budgetColor: AppColorsVintageMint.budgetColor,
        taskColor: AppColorsVintageMint.taskColor,
        tableColor: AppColorsVintageMint.tableColor,
        serviceColor: AppColorsVintageMint.serviceColor,
      );
    case ThemeVariant.vintageMintDark:
      return const BrandColors(
        primary: AppColorsVintageMintDark.primary,
        background: AppColorsVintageMintDark.background,
        cardColor: AppColorsVintageMintDark.cardColor,
        cardBorder: AppColorsVintageMintDark.cardBorder,
        secondary: AppColorsVintageMintDark.secondary,
        homeColor: AppColorsVintageMintDark.homeColor,
        guestColor: AppColorsVintageMintDark.guestColor,
        budgetColor: AppColorsVintageMintDark.budgetColor,
        taskColor: AppColorsVintageMintDark.taskColor,
        tableColor: AppColorsVintageMintDark.tableColor,
        serviceColor: AppColorsVintageMintDark.serviceColor,
      );
    case ThemeVariant.sandVintageCream:
      return const BrandColors(
        primary: AppColorsSandVintageCream.primary,
        background: AppColorsSandVintageCream.background,
        cardColor: AppColorsSandVintageCream.cardColor,
        cardBorder: AppColorsSandVintageCream.cardBorder,
        secondary: AppColorsSandVintageCream.secondary,
        homeColor: AppColorsSandVintageCream.homeColor,
        guestColor: AppColorsSandVintageCream.guestColor,
        budgetColor: AppColorsSandVintageCream.budgetColor,
        taskColor: AppColorsSandVintageCream.taskColor,
        tableColor: AppColorsSandVintageCream.tableColor,
        serviceColor: AppColorsSandVintageCream.serviceColor,
      );
    case ThemeVariant.mintFresh:
      return const BrandColors(
        primary: AppColorsMintFresh.primary,
        background: AppColorsMintFresh.background,
        cardColor: AppColorsMintFresh.cardColor,
        cardBorder: AppColorsMintFresh.cardBorder,
        secondary: AppColorsMintFresh.secondary,
        homeColor: AppColorsMintFresh.homeColor,
        guestColor: AppColorsMintFresh.guestColor,
        budgetColor: AppColorsMintFresh.budgetColor,
        taskColor: AppColorsMintFresh.taskColor,
        tableColor: AppColorsMintFresh.tableColor,
        serviceColor: AppColorsMintFresh.serviceColor,
      );
    case ThemeVariant.mintStone:
      return const BrandColors(
        primary: AppColorsMintStone.primary,
        background: AppColorsMintStone.background,
        cardColor: AppColorsMintStone.cardColor,
        cardBorder: AppColorsMintStone.cardBorder,
        secondary: AppColorsMintStone.secondary,
        homeColor: AppColorsMintStone.homeColor,
        guestColor: AppColorsMintStone.guestColor,
        budgetColor: AppColorsMintStone.budgetColor,
        taskColor: AppColorsMintStone.taskColor,
        tableColor: AppColorsMintStone.tableColor,
        serviceColor: AppColorsMintStone.serviceColor,
      );
    case ThemeVariant.seafoamNavy:
      return const BrandColors(
        primary: AppColorsSeafoamNavy.primary,
        background: AppColorsSeafoamNavy.background,
        cardColor: AppColorsSeafoamNavy.cardColor,
        cardBorder: AppColorsSeafoamNavy.cardBorder,
        secondary: AppColorsSeafoamNavy.secondary,
        homeColor: AppColorsSeafoamNavy.homeColor,
        guestColor: AppColorsSeafoamNavy.guestColor,
        budgetColor: AppColorsSeafoamNavy.budgetColor,
        taskColor: AppColorsSeafoamNavy.taskColor,
        tableColor: AppColorsSeafoamNavy.tableColor,
        serviceColor: AppColorsSeafoamNavy.serviceColor,
      );
    case ThemeVariant.champagne:
      return const BrandColors(
        primary: AppColorsChampagne.primary,
        background: AppColorsChampagne.background,
        cardColor: AppColorsChampagne.cardColor,
        cardBorder: AppColorsChampagne.cardBorder,
        secondary: AppColorsChampagne.secondary,
        homeColor: AppColorsChampagne.homeColor,
        guestColor: AppColorsChampagne.guestColor,
        budgetColor: AppColorsChampagne.budgetColor,
        taskColor: AppColorsChampagne.taskColor,
        tableColor: AppColorsChampagne.tableColor,
        serviceColor: AppColorsChampagne.serviceColor,
      );

    // 👇 NEU: Romantic Pink
    case ThemeVariant.romanticPink:
      return const BrandColors(
        primary: AppColorsRomanticPink.primary,
        background: AppColorsRomanticPink.background,
        cardColor: AppColorsRomanticPink.cardColor,
        cardBorder: AppColorsRomanticPink.cardBorder,
        secondary: AppColorsRomanticPink.secondary,
        homeColor: AppColorsRomanticPink.homeColor,
        guestColor: AppColorsRomanticPink.guestColor,
        budgetColor: AppColorsRomanticPink.budgetColor,
        taskColor: AppColorsRomanticPink.taskColor,
        tableColor: AppColorsRomanticPink.tableColor,
        serviceColor: AppColorsRomanticPink.serviceColor,
      );

    // 👇 NEU: Creme Elegance
    case ThemeVariant.cremeElegance:
      return const BrandColors(
        primary: AppColorsCremeElegance.primary,
        background: AppColorsCremeElegance.background,
        cardColor: AppColorsCremeElegance.cardColor,
        cardBorder: AppColorsCremeElegance.cardBorder,
        secondary: AppColorsCremeElegance.secondary,
        homeColor: AppColorsCremeElegance.homeColor,
        guestColor: AppColorsCremeElegance.guestColor,
        budgetColor: AppColorsCremeElegance.budgetColor,
        taskColor: AppColorsCremeElegance.taskColor,
        tableColor: AppColorsCremeElegance.tableColor,
        serviceColor: AppColorsCremeElegance.serviceColor,
      );

    // 👇 NEU: Black & White
    case ThemeVariant.blackWhite:
      return const BrandColors(
        primary: AppColorsBlackWhite.primary,
        background: AppColorsBlackWhite.background,
        cardColor: AppColorsBlackWhite.cardColor,
        cardBorder: AppColorsBlackWhite.cardBorder,
        secondary: AppColorsBlackWhite.secondary,
        homeColor: AppColorsBlackWhite.homeColor,
        guestColor: AppColorsBlackWhite.guestColor,
        budgetColor: AppColorsBlackWhite.budgetColor,
        taskColor: AppColorsBlackWhite.taskColor,
        tableColor: AppColorsBlackWhite.tableColor,
        serviceColor: AppColorsBlackWhite.serviceColor,
      );

    // 👇 NEU: Royal Gold
    case ThemeVariant.royalGold:
      return const BrandColors(
        primary: AppColorsRoyalGold.primary,
        background: AppColorsRoyalGold.background,
        cardColor: AppColorsRoyalGold.cardColor,
        cardBorder: AppColorsRoyalGold.cardBorder,
        secondary: AppColorsRoyalGold.secondary,
        homeColor: AppColorsRoyalGold.homeColor,
        guestColor: AppColorsRoyalGold.guestColor,
        budgetColor: AppColorsRoyalGold.budgetColor,
        taskColor: AppColorsRoyalGold.taskColor,
        tableColor: AppColorsRoyalGold.tableColor,
        serviceColor: AppColorsRoyalGold.serviceColor,
      );

    // 👇 NEU: Frozen Mint
    case ThemeVariant.frozenMint:
      return const BrandColors(
        primary: AppColorsFrozenMint.primary,
        background: AppColorsFrozenMint.background,
        cardColor: AppColorsFrozenMint.cardColor,
        cardBorder: AppColorsFrozenMint.cardBorder,
        secondary: AppColorsFrozenMint.secondary,
        homeColor: AppColorsFrozenMint.homeColor,
        guestColor: AppColorsFrozenMint.guestColor,
        budgetColor: AppColorsFrozenMint.budgetColor,
        taskColor: AppColorsFrozenMint.taskColor,
        tableColor: AppColorsFrozenMint.tableColor,
        serviceColor: AppColorsFrozenMint.serviceColor,
      );
  }
}

final _themeCache = <ThemeVariant, ThemeData>{};

ThemeData buildThemeFor(ThemeVariant variant) {
  if (_themeCache.containsKey(variant)) {
    return _themeCache[variant]!;
  }

  final c = colorsFor(variant);
  final isDark = variant == ThemeVariant.vintageMintDark;

  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: isDark ? Brightness.dark : Brightness.light,
    background: c.background,
  );

  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    appBarTheme: AppBarTheme(
      backgroundColor: c.cardColor,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: true,
    ),
    cardTheme: CardThemeData(
      color: c.cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.cardBorder),
      ),
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.secondary,
      shape: const StadiumBorder(),
      side: BorderSide(color: c.cardBorder),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary),
      ),
    ),
    dividerColor: c.cardBorder,
  );

  _themeCache[variant] = theme;
  return theme;
}
