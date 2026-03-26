// lib/theme/theme_variant.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

enum ThemeVariant {
  // ── Bestehende helle Themes ─────────────────────────────────
  vintageMint,
  vintageMintDark,
  sandVintageCream,
  mintFresh,
  mintStone,
  seafoamNavy,
  champagne,
  romanticPink,
  cremeElegance,
  blackWhite,
  royalGold,
  frozenMint,

  // ── Neue Dark Themes ────────────────────────────────────────
  darkPink,
  darkPinkDark,
  blackGold,
  blackGoldDark,
  midnightMint,
  midnightMintDark,
  champagneNight,
  champagneNightDark,
  royalDark,
  royalDarkDark,
  roseCard,
  roseCardDark,
}

bool isDarkTheme(ThemeVariant v) {
  switch (v) {
    case ThemeVariant.vintageMintDark:
    case ThemeVariant.darkPink:
    case ThemeVariant.darkPinkDark:
    case ThemeVariant.blackGold:
    case ThemeVariant.blackGoldDark:
    case ThemeVariant.midnightMint:
    case ThemeVariant.midnightMintDark:
    case ThemeVariant.champagneNight:
    case ThemeVariant.champagneNightDark:
    case ThemeVariant.royalDark:
    case ThemeVariant.royalDarkDark:
    case ThemeVariant.roseCard:
    case ThemeVariant.roseCardDark:
      return true;
    default:
      return false;
  }
}

String themeDisplayName(ThemeVariant v) {
  switch (v) {
    case ThemeVariant.vintageMint:
      return 'Vintage Mint';
    case ThemeVariant.vintageMintDark:
      return 'Vintage Mint Dark';
    case ThemeVariant.sandVintageCream:
      return 'Sand Cream';
    case ThemeVariant.mintFresh:
      return 'Mint Fresh';
    case ThemeVariant.mintStone:
      return 'Mint Stone';
    case ThemeVariant.seafoamNavy:
      return 'Seafoam Navy';
    case ThemeVariant.champagne:
      return 'Champagne';
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
    case ThemeVariant.darkPink:
      return 'Dark Pink';
    case ThemeVariant.darkPinkDark:
      return 'Dark Pink (tief)';
    case ThemeVariant.blackGold:
      return 'Black & Gold';
    case ThemeVariant.blackGoldDark:
      return 'Black & Gold (tief)';
    case ThemeVariant.midnightMint:
      return 'Midnight Mint';
    case ThemeVariant.midnightMintDark:
      return 'Midnight Mint (tief)';
    case ThemeVariant.champagneNight:
      return 'Champagne Night';
    case ThemeVariant.champagneNightDark:
      return 'Champagne Night (tief)';
    case ThemeVariant.royalDark:
      return 'Royal Dark';
    case ThemeVariant.royalDarkDark:
      return 'Royal Dark (tief)';
    case ThemeVariant.roseCard:
      return 'Rose Card';
    case ThemeVariant.roseCardDark:
      return 'Rose Card (tief)';
  }
}

String themeEmoji(ThemeVariant v) {
  switch (v) {
    case ThemeVariant.vintageMint:
      return '🌿';
    case ThemeVariant.vintageMintDark:
      return '🌿🖤';
    case ThemeVariant.sandVintageCream:
      return '🏜️';
    case ThemeVariant.mintFresh:
      return '🍃';
    case ThemeVariant.mintStone:
      return '🪨';
    case ThemeVariant.seafoamNavy:
      return '🌊';
    case ThemeVariant.champagne:
      return '🥂';
    case ThemeVariant.romanticPink:
      return '💗';
    case ThemeVariant.cremeElegance:
      return '🧁';
    case ThemeVariant.blackWhite:
      return '⚫️';
    case ThemeVariant.royalGold:
      return '✨';
    case ThemeVariant.frozenMint:
      return '❄️';
    case ThemeVariant.darkPink:
      return '🖤💗';
    case ThemeVariant.darkPinkDark:
      return '🖤💗';
    case ThemeVariant.blackGold:
      return '🖤✨';
    case ThemeVariant.blackGoldDark:
      return '🖤✨';
    case ThemeVariant.midnightMint:
      return '🌿🖤';
    case ThemeVariant.midnightMintDark:
      return '🌿🖤';
    case ThemeVariant.champagneNight:
      return '🥂🖤';
    case ThemeVariant.champagneNightDark:
      return '🥂🖤';
    case ThemeVariant.royalDark:
      return '💜🖤';
    case ThemeVariant.royalDarkDark:
      return '💜🖤';
    case ThemeVariant.roseCard:
      return '🌸🖤';
    case ThemeVariant.roseCardDark:
      return '🌸🖤';
  }
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
    case ThemeVariant.darkPink:
      return const BrandColors(
        primary: AppColorsDarkPink.primary,
        background: AppColorsDarkPink.background,
        cardColor: AppColorsDarkPink.cardColor,
        cardBorder: AppColorsDarkPink.cardBorder,
        secondary: AppColorsDarkPink.secondary,
        homeColor: AppColorsDarkPink.homeColor,
        guestColor: AppColorsDarkPink.guestColor,
        budgetColor: AppColorsDarkPink.budgetColor,
        taskColor: AppColorsDarkPink.taskColor,
        tableColor: AppColorsDarkPink.tableColor,
        serviceColor: AppColorsDarkPink.serviceColor,
      );
    case ThemeVariant.darkPinkDark:
      return const BrandColors(
        primary: AppColorsDarkPinkDark.primary,
        background: AppColorsDarkPinkDark.background,
        cardColor: AppColorsDarkPinkDark.cardColor,
        cardBorder: AppColorsDarkPinkDark.cardBorder,
        secondary: AppColorsDarkPinkDark.secondary,
        homeColor: AppColorsDarkPinkDark.homeColor,
        guestColor: AppColorsDarkPinkDark.guestColor,
        budgetColor: AppColorsDarkPinkDark.budgetColor,
        taskColor: AppColorsDarkPinkDark.taskColor,
        tableColor: AppColorsDarkPinkDark.tableColor,
        serviceColor: AppColorsDarkPinkDark.serviceColor,
      );
    case ThemeVariant.blackGold:
      return const BrandColors(
        primary: AppColorsBlackGold.primary,
        background: AppColorsBlackGold.background,
        cardColor: AppColorsBlackGold.cardColor,
        cardBorder: AppColorsBlackGold.cardBorder,
        secondary: AppColorsBlackGold.secondary,
        homeColor: AppColorsBlackGold.homeColor,
        guestColor: AppColorsBlackGold.guestColor,
        budgetColor: AppColorsBlackGold.budgetColor,
        taskColor: AppColorsBlackGold.taskColor,
        tableColor: AppColorsBlackGold.tableColor,
        serviceColor: AppColorsBlackGold.serviceColor,
      );
    case ThemeVariant.blackGoldDark:
      return const BrandColors(
        primary: AppColorsBlackGoldDark.primary,
        background: AppColorsBlackGoldDark.background,
        cardColor: AppColorsBlackGoldDark.cardColor,
        cardBorder: AppColorsBlackGoldDark.cardBorder,
        secondary: AppColorsBlackGoldDark.secondary,
        homeColor: AppColorsBlackGoldDark.homeColor,
        guestColor: AppColorsBlackGoldDark.guestColor,
        budgetColor: AppColorsBlackGoldDark.budgetColor,
        taskColor: AppColorsBlackGoldDark.taskColor,
        tableColor: AppColorsBlackGoldDark.tableColor,
        serviceColor: AppColorsBlackGoldDark.serviceColor,
      );
    case ThemeVariant.midnightMint:
      return const BrandColors(
        primary: AppColorsMidnightMint.primary,
        background: AppColorsMidnightMint.background,
        cardColor: AppColorsMidnightMint.cardColor,
        cardBorder: AppColorsMidnightMint.cardBorder,
        secondary: AppColorsMidnightMint.secondary,
        homeColor: AppColorsMidnightMint.homeColor,
        guestColor: AppColorsMidnightMint.guestColor,
        budgetColor: AppColorsMidnightMint.budgetColor,
        taskColor: AppColorsMidnightMint.taskColor,
        tableColor: AppColorsMidnightMint.tableColor,
        serviceColor: AppColorsMidnightMint.serviceColor,
      );
    case ThemeVariant.midnightMintDark:
      return const BrandColors(
        primary: AppColorsMidnightMintDark.primary,
        background: AppColorsMidnightMintDark.background,
        cardColor: AppColorsMidnightMintDark.cardColor,
        cardBorder: AppColorsMidnightMintDark.cardBorder,
        secondary: AppColorsMidnightMintDark.secondary,
        homeColor: AppColorsMidnightMintDark.homeColor,
        guestColor: AppColorsMidnightMintDark.guestColor,
        budgetColor: AppColorsMidnightMintDark.budgetColor,
        taskColor: AppColorsMidnightMintDark.taskColor,
        tableColor: AppColorsMidnightMintDark.tableColor,
        serviceColor: AppColorsMidnightMintDark.serviceColor,
      );
    case ThemeVariant.champagneNight:
      return const BrandColors(
        primary: AppColorsChampagneNight.primary,
        background: AppColorsChampagneNight.background,
        cardColor: AppColorsChampagneNight.cardColor,
        cardBorder: AppColorsChampagneNight.cardBorder,
        secondary: AppColorsChampagneNight.secondary,
        homeColor: AppColorsChampagneNight.homeColor,
        guestColor: AppColorsChampagneNight.guestColor,
        budgetColor: AppColorsChampagneNight.budgetColor,
        taskColor: AppColorsChampagneNight.taskColor,
        tableColor: AppColorsChampagneNight.tableColor,
        serviceColor: AppColorsChampagneNight.serviceColor,
      );
    case ThemeVariant.champagneNightDark:
      return const BrandColors(
        primary: AppColorsChampagneNightDark.primary,
        background: AppColorsChampagneNightDark.background,
        cardColor: AppColorsChampagneNightDark.cardColor,
        cardBorder: AppColorsChampagneNightDark.cardBorder,
        secondary: AppColorsChampagneNightDark.secondary,
        homeColor: AppColorsChampagneNightDark.homeColor,
        guestColor: AppColorsChampagneNightDark.guestColor,
        budgetColor: AppColorsChampagneNightDark.budgetColor,
        taskColor: AppColorsChampagneNightDark.taskColor,
        tableColor: AppColorsChampagneNightDark.tableColor,
        serviceColor: AppColorsChampagneNightDark.serviceColor,
      );
    case ThemeVariant.royalDark:
      return const BrandColors(
        primary: AppColorsRoyalDark.primary,
        background: AppColorsRoyalDark.background,
        cardColor: AppColorsRoyalDark.cardColor,
        cardBorder: AppColorsRoyalDark.cardBorder,
        secondary: AppColorsRoyalDark.secondary,
        homeColor: AppColorsRoyalDark.homeColor,
        guestColor: AppColorsRoyalDark.guestColor,
        budgetColor: AppColorsRoyalDark.budgetColor,
        taskColor: AppColorsRoyalDark.taskColor,
        tableColor: AppColorsRoyalDark.tableColor,
        serviceColor: AppColorsRoyalDark.serviceColor,
      );
    case ThemeVariant.royalDarkDark:
      return const BrandColors(
        primary: AppColorsRoyalDarkDark.primary,
        background: AppColorsRoyalDarkDark.background,
        cardColor: AppColorsRoyalDarkDark.cardColor,
        cardBorder: AppColorsRoyalDarkDark.cardBorder,
        secondary: AppColorsRoyalDarkDark.secondary,
        homeColor: AppColorsRoyalDarkDark.homeColor,
        guestColor: AppColorsRoyalDarkDark.guestColor,
        budgetColor: AppColorsRoyalDarkDark.budgetColor,
        taskColor: AppColorsRoyalDarkDark.taskColor,
        tableColor: AppColorsRoyalDarkDark.tableColor,
        serviceColor: AppColorsRoyalDarkDark.serviceColor,
      );
    case ThemeVariant.roseCard:
      return const BrandColors(
        primary: AppColorsRoseCard.primary,
        background: AppColorsRoseCard.background,
        cardColor: AppColorsRoseCard.cardColor,
        cardBorder: AppColorsRoseCard.cardBorder,
        secondary: AppColorsRoseCard.secondary,
        homeColor: AppColorsRoseCard.homeColor,
        guestColor: AppColorsRoseCard.guestColor,
        budgetColor: AppColorsRoseCard.budgetColor,
        taskColor: AppColorsRoseCard.taskColor,
        tableColor: AppColorsRoseCard.tableColor,
        serviceColor: AppColorsRoseCard.serviceColor,
      );
    case ThemeVariant.roseCardDark:
      return const BrandColors(
        primary: AppColorsRoseCardDark.primary,
        background: AppColorsRoseCardDark.background,
        cardColor: AppColorsRoseCardDark.cardColor,
        cardBorder: AppColorsRoseCardDark.cardBorder,
        secondary: AppColorsRoseCardDark.secondary,
        homeColor: AppColorsRoseCardDark.homeColor,
        guestColor: AppColorsRoseCardDark.guestColor,
        budgetColor: AppColorsRoseCardDark.budgetColor,
        taskColor: AppColorsRoseCardDark.taskColor,
        tableColor: AppColorsRoseCardDark.tableColor,
        serviceColor: AppColorsRoseCardDark.serviceColor,
      );
  }
}

final _themeCache = <ThemeVariant, ThemeData>{};

ThemeData buildThemeFor(ThemeVariant variant) {
  if (_themeCache.containsKey(variant)) return _themeCache[variant]!;

  final c = colorsFor(variant);
  final dark = isDarkTheme(variant);

  final scheme = ColorScheme.fromSeed(
    seedColor: c.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
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
