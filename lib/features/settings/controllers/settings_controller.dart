import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/theme_service.dart';

/// Expose le ThemeMode courant à l'UI (Paramètres) sous forme de provider
/// Riverpod, en restant synchronisé avec le ValueNotifier de ThemeService.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeService.instance.themeMode.value) {
    ThemeService.instance.themeMode.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    state = ThemeService.instance.themeMode.value;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ThemeService.instance.setThemeMode(mode);
  }

  @override
  void dispose() {
    ThemeService.instance.themeMode.removeListener(_onThemeChanged);
    super.dispose();
  }
}

/// Préférence locale "notifications activées" — un interrupteur simple côté
/// app, distinct de la permission système Android (qui se gère depuis les
/// réglages du téléphone). Quand désactivé, on n'affiche plus les
/// notifications locales au premier plan (voir notification_service.dart).
class NotificationSettingsState {
  const NotificationSettingsState({this.enabled = true});
  final bool enabled;
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  NotificationSettingsNotifier() : super(const NotificationSettingsState()) {
    _load();
  }

  static const _prefsKey = 'notifications_enabled';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefsKey) ?? true;
    state = NotificationSettingsState(enabled: enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    state = NotificationSettingsState(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>((ref) {
  return NotificationSettingsNotifier();
});

/// Langue de l'application — pour l'instant, seul le français est implémenté
/// dans l'app (toutes les chaînes UI sont déjà en dur en français dans
/// app_strings.dart). Ce sélecteur prépare le terrain pour une vraie
/// internationalisation future (ex: avec le package `intl` + fichiers .arb),
/// mais ne traduit rien de réel tant que ce travail n'est pas fait — il
/// stocke seulement la préférence choisie.
class LanguageSettingsNotifier extends StateNotifier<String> {
  LanguageSettingsNotifier() : super('fr') {
    _load();
  }

  static const _prefsKey = 'app_language';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_prefsKey) ?? 'fr';
  }

  Future<void> setLanguage(String languageCode) async {
    state = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, languageCode);
  }
}

final languageSettingsProvider =
    StateNotifierProvider<LanguageSettingsNotifier, String>((ref) {
  return LanguageSettingsNotifier();
});
