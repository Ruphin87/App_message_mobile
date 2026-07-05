import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_model.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/local_database_service.dart';
import '../../../core/services/notification_service.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repository) : super(const AuthState()) {
    _init();
  }

  final AuthRepository _repository;

  void _init() {
    _repository.authStateChanges.listen((event) {
      if (event.session == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          user: null,
        );
        // Plus de session : on quitte le canal de présence pour ne plus
        // apparaître "en ligne" auprès des autres utilisateurs.
        PresenceService.instance.dispose();
      } else {
        _loadCurrentUser();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final user = await _repository.getCurrentUser();
    state = state.copyWith(
      status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
      user: user,
    );

    if (user != null) {
      // Session valide : on rejoint le canal de présence pour apparaître
      // "en ligne" auprès des autres utilisateurs.
      await PresenceService.instance.initialize();
      // Et on enregistre le token FCM de cet appareil pour ce compte, pour
      // pouvoir recevoir les notifications push (Phase 4).
      await NotificationService.instance.initialize();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String nom,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _repository.register(
        email: email,
        password: password,
        nom: nom,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );

      await PresenceService.instance.initialize();
      await NotificationService.instance.initialize();

      return true;
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message) {
        case 'User already registered':
          errorMessage = 'Cet email est déjà utilisé';
        default:
          errorMessage = 'Erreur lors de la création du compte';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await _repository.login(
        email: email,
        password: password,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isLoading: false,
      );

      await PresenceService.instance.initialize();
      await NotificationService.instance.initialize();

      return true;
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.message) {
        case 'Invalid login credentials':
          errorMessage = 'Email ou mot de passe incorrect';
        case 'Email not confirmed':
          errorMessage = 'Veuillez confirmer votre email';
        default:
          errorMessage = 'Erreur de connexion';
      }
      state = state.copyWith(isLoading: false, error: errorMessage);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erreur de connexion');
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);

    // On capture l'id AVANT de se déconnecter : une fois la session fermée,
    // SupabaseService.currentUserId devient null et on ne pourrait plus
    // cibler le bon cache à effacer.
    final userId = state.user?.id;

    await PresenceService.instance.dispose();
    await NotificationService.instance.unregisterDeviceToken();
    await _repository.logout();

    // On efface le cache local de cet utilisateur, pour qu'un autre compte
    // qui se connecterait ensuite sur le même appareil ne voie jamais ses
    // contacts ou ses messages (isolation entre comptes).
    if (userId != null) {
      await LocalDatabaseService.instance.clearAllForUser(userId);
    }

    state = const AuthState(
      status: AuthStatus.unauthenticated,
      user: null,
      isLoading: false,
    );
  }

  Future<bool> sendPasswordResetCode(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.sendPasswordResetCode(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de l\'envoi du code',
      );
      return false;
    }
  }

  Future<bool> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.verifyPasswordResetCode(email: email, code: code);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      // Les Edge Functions renvoient déjà un message précis en
      // français (code incorrect, expiré, trop de tentatives...).
      state = state.copyWith(
        isLoading: false,
        error: _cleanExceptionMessage(e),
      );
      return false;
    }
  }

  Future<bool> updateRecoveredPassword(String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Le mot de passe est modifié directement en base via l'Edge
      // Function reset-password (API Admin Supabase). Aucune session
      // n'a été ouverte pendant cette procédure, donc rien à fermer.
      await _repository.updatePassword(password);
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _cleanExceptionMessage(e),
      );
      return false;
    }
  }

  Future<bool> resetPassword(String email) => sendPasswordResetCode(email);

  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Transforme une Exception("message") en simple "message" pour
  /// l'affichage (les Edge Functions du reset renvoient déjà des
  /// messages prêts à afficher, en français).
  String _cleanExceptionMessage(Object e) {
    final text = e.toString();
    const prefix = 'Exception: ';
    return text.startsWith(prefix) ? text.substring(prefix.length) : 'Une erreur est survenue';
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
