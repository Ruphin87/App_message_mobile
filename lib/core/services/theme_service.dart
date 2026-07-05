import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gère le mode de thème de l'application (clair / sombre / système) et le
/// persiste localement, pour qu'il survive à la fermeture de l'app.
///
/// Implémenté comme un simple `ValueNotifier` plutôt qu'un vrai provider
/// Riverpod, pour pouvoir être lu directement par `MaterialApp.router`
/// dans `main.dart` sans dépendre du `ProviderScope` à ce niveau précoce
/// du build (MaterialApp doit déjà exister avant qu'on puisse `ref.watch`
/// dans son propre `themeMode`).
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _prefsKey = 'theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// À appeler une fois au démarrage de l'app (avant runApp), pour charger
  /// la préférence sauvegardée avant le premier rendu.
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    themeMode.value = _fromString(saved) ?? ThemeMode.system;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }

  ThemeMode? _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return null;
    }
  }
}
