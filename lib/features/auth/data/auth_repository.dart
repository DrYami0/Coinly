import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coinly/core/supabase/supabase_config.dart';

class AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession =>
      SupabaseConfig.isConfigured ? _client.auth.currentSession : null;

  Stream<AuthState> get authStateChanges => SupabaseConfig.isConfigured
      ? _client.auth.onAuthStateChange
      : const Stream<AuthState>.empty();

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email, {required String redirectTo}) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }
}
