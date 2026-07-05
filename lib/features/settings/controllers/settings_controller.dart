import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/theme_service.dart';
import '../../../core/services/update_service.dart';

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

// ==================== MISE À JOUR DE L'APPLICATION ====================

/// État de l'écran "Mise à jour" des Paramètres : reflète le statut renvoyé
/// par le site web (via l'API GitHub Releases, la même source que
/// apk-download-site/script.js) — en cours de vérification, à jour,
/// mise à jour disponible, ou erreur réseau.
class UpdateCheckState {
  const UpdateCheckState({
    this.isChecking = false,
    this.info,
    this.error,
    this.hasCheckedOnce = false,
  });

  final bool isChecking;
  final AppUpdateInfo? info;
  final String? error;
  final bool hasCheckedOnce;

  UpdateCheckState copyWith({
    bool? isChecking,
    AppUpdateInfo? info,
    String? error,
    bool clearInfo = false,
    bool clearError = false,
    bool? hasCheckedOnce,
  }) {
    return UpdateCheckState(
      isChecking: isChecking ?? this.isChecking,
      info: clearInfo ? null : (info ?? this.info),
      error: clearError ? null : (error ?? this.error),
      hasCheckedOnce: hasCheckedOnce ?? this.hasCheckedOnce,
    );
  }
}

class UpdateCheckNotifier extends StateNotifier<UpdateCheckState> {
  UpdateCheckNotifier(this._service) : super(const UpdateCheckState());

  final UpdateService _service;

  /// Lance (ou relance) la vérification auprès du site/GitHub. Appelé une
  /// première fois à l'ouverture de l'écran "Mise à jour", puis à nouveau
  /// via le bouton "Vérifier maintenant".
  Future<void> check() async {
    state = state.copyWith(isChecking: true, clearError: true);
    try {
      final info = await _service.checkForUpdate();
      if (!mounted) return;
      state = state.copyWith(isChecking: false, info: info, hasCheckedOnce: true);
    } on UpdateCheckException catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isChecking: false,
        hasCheckedOnce: true,
        error: 'Impossible de vérifier les mises à jour. Vérifiez votre connexion internet.',
        info: AppUpdateInfo(
          currentVersion: e.currentVersion,
          latestVersion: e.currentVersion,
          updateAvailable: false,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        isChecking: false,
        hasCheckedOnce: true,
        error: 'Impossible de vérifier les mises à jour. Vérifiez votre connexion internet.',
      );
    }
  }

  /// Ouvre le site de téléchargement — l'utilisateur y télécharge et
  /// installe lui-même la mise à jour, l'app ne fait que rediriger.
  /// Renvoie `false` si aucune application n'a pu ouvrir le lien, pour que
  /// l'écran puisse prévenir l'utilisateur au lieu de rester silencieux.
  Future<bool> openDownloadWebsite() => _service.openDownloadWebsite();
}

final updateCheckProvider =
    StateNotifierProvider<UpdateCheckNotifier, UpdateCheckState>((ref) {
  return UpdateCheckNotifier(UpdateService.instance);
});
