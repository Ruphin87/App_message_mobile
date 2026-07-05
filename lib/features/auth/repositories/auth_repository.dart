import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/user_model.dart';

class AuthRepository {
  AuthRepository();

  final _client = SupabaseService.client;

  // ==================== REGISTER ====================
  Future<UserModel> register({
    required String email,
    required String password,
    required String nom,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'nom': nom},           // On passe le nom dans les metadata
      );

      if (response.user == null) {
        throw Exception('Erreur lors de la création du compte');
      }

      // Attendre que le Trigger crée le profil dans la table users
      await Future.delayed(const Duration(seconds: 1));

      // Récupérer le profil complet
      final user = await getCurrentUser();
      
      if (user == null) {
        throw Exception('Le profil utilisateur n\'a pas été créé correctement');
      }

      return user;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== LOGIN ====================
Future<UserModel> login({
  required String email,
  required String password,
}) async {
  final response = await _client.auth.signInWithPassword(
    email: email,
    password: password,
  );

  if (response.user == null) {
    throw Exception('Email ou mot de passe incorrect');
  }

  final currentUser = await getCurrentUser();
  if (currentUser == null) {
    throw Exception('Impossible de charger le profil utilisateur');
  }

  return currentUser;
}


  // ==================== GET CURRENT USER ====================
  Future<UserModel?> getCurrentUser() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return null;

      return UserModel.fromJson(response);
    } catch (e) {
      print('Erreur dans getCurrentUser: $e');
      return null;
    }
  }

  // ==================== AUTRES FONCTIONS ====================
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  // ==================== MOT DE PASSE OUBLIÉ (SMTP personnalisé) ====================
  // Ce flux n'utilise PAS le système d'email de Supabase Auth
  // (resetPasswordForEmail / verifyOTP), mais 3 Edge Functions dédiées
  // qui envoient elles-mêmes le code par email via un serveur SMTP
  // classique : voir supabase/functions/send-reset-code,
  // verify-reset-code et reset-password.

  // Email + jeton temporaire obtenus après vérification du code,
  // nécessaires pour pouvoir changer le mot de passe à l'étape
  // suivante (le jeton est à usage unique côté serveur).
  String? _pendingResetEmail;
  String? _pendingResetToken;

  Future<void> sendPasswordResetCode(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _client.functions.invoke(
        'send-reset-code',
        body: {'email': normalizedEmail},
      );
      if (response.data is! Map || response.data['ok'] != true) {
        throw Exception("Erreur lors de l'envoi du code");
      }
    } on FunctionException catch (e) {
      throw Exception(_functionErrorMessage(e) ?? "Erreur lors de l'envoi du code");
    }

    _pendingResetEmail = normalizedEmail;
    _pendingResetToken = null;
  }

  Future<void> verifyPasswordResetCode({
    required String email,
    required String code,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final response = await _client.functions.invoke(
        'verify-reset-code',
        body: {'email': normalizedEmail, 'code': code.trim()},
      );
      if (response.data is! Map || response.data['ok'] != true) {
        throw Exception('Code de vérification incorrect');
      }
      _pendingResetToken = response.data['reset_token'] as String;
    } on FunctionException catch (e) {
      throw Exception(_functionErrorMessage(e) ?? 'Code de vérification incorrect');
    }

    _pendingResetEmail = normalizedEmail;
  }

  Future<void> updatePassword(String password) async {
    if (_pendingResetEmail == null || _pendingResetToken == null) {
      throw Exception("Veuillez d'abord vérifier le code reçu par email");
    }

    try {
      final response = await _client.functions.invoke(
        'reset-password',
        body: {
          'email': _pendingResetEmail,
          'reset_token': _pendingResetToken,
          'password': password,
        },
      );
      if (response.data is! Map || response.data['ok'] != true) {
        throw Exception('Erreur lors du changement de mot de passe');
      }
    } on FunctionException catch (e) {
      throw Exception(_functionErrorMessage(e) ?? 'Erreur lors du changement de mot de passe');
    }

    // Jeton à usage unique déjà invalidé côté serveur : on efface
    // aussi la copie locale.
    _pendingResetEmail = null;
    _pendingResetToken = null;
  }

  Future<void> resetPassword(String email) async {
    await sendPasswordResetCode(email);
  }

  /// Extrait le message d'erreur métier renvoyé par l'Edge Function
  /// (ex: "Code expiré. Demandez un nouveau code.") depuis une
  /// FunctionException, si présent.
  String? _functionErrorMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return null;
  }

  Stream<AuthState> get authStateChanges => SupabaseService.authStateChanges;
}
