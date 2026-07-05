import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    await dotenv.load();

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
      debug: false,
    );

    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static User? get currentUser => auth.currentUser;

  static String? get currentUserId => currentUser?.id;

  static Session? get currentSession => auth.currentSession;

  static bool get isAuthenticated => currentSession != null;

  static Stream<AuthState> get authStateChanges => auth.onAuthStateChange;
}
