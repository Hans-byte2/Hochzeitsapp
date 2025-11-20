import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme_variant.dart';

const _kThemeKey = 'theme_variant';

class ThemeController extends StateNotifier<ThemeVariant> {
  ThemeController(this._prefs, ThemeVariant initial) : super(initial);

  final SharedPreferences _prefs;

  Future<void> setVariant(ThemeVariant v) async {
    if (state == v) return;
    state = v;
    await _prefs.setInt(_kThemeKey, v.index);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeVariant>((ref) {
      throw UnimplementedError('override in main()');
    });

final themeDataProvider = Provider<ThemeData>((ref) {
  final variant = ref.watch(themeControllerProvider);
  return buildThemeFor(variant);
});

Future<ThemeVariant> resolveInitialVariant(SharedPreferences prefs) async {
  final idx = prefs.getInt(_kThemeKey);
  if (idx != null && idx >= 0 && idx < ThemeVariant.values.length) {
    return ThemeVariant.values[idx];
  }

  final brightness =
      SchedulerBinding.instance.platformDispatcher.platformBrightness;

  return brightness == Brightness.dark
      ? ThemeVariant.vintageMintDark
      : ThemeVariant.vintageMint;
}
