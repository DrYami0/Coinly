import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:coinly/core/supabase/supabase_config.dart';
import 'package:coinly/features/auth/data/auth_repository.dart';

enum AuthStatus { localOnly, loading, authenticated, unauthenticated, error }

class AuthStateModel {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthStateModel({required this.status, this.user, this.errorMessage});

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthStateModel>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthStateModel> {
  final AuthRepository _repository;
  StreamSubscription<AuthState>? _subscription;

  AuthNotifier(this._repository)
    : super(
        AuthStateModel(
          status: SupabaseConfig.isConfigured
              ? AuthStatus.loading
              : AuthStatus.localOnly,
        ),
      ) {
    if (SupabaseConfig.isConfigured) {
      _restoreSession();
    }
  }

  Future<void> _restoreSession() async {
    state = AuthStateModel(
      status: _repository.currentSession == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated,
      user: _repository.currentSession?.user,
    );
    _subscription = _repository.authStateChanges.listen((authState) {
      state = AuthStateModel(
        status: authState.session == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: authState.session?.user,
      );
    });
  }

  Future<void> signIn(String email, String password) async {
    await _run(() => _repository.signIn(email: email, password: password));
  }

  Future<void> signUp(String email, String password) async {
    await _run(() => _repository.signUp(email: email, password: password));
  }

  Future<void> resetPassword(String email, {required String redirectTo}) async {
    try {
      await _repository.resetPassword(email, redirectTo: redirectTo);
      state = const AuthStateModel(status: AuthStatus.unauthenticated);
    } catch (error) {
      state = AuthStateModel(
        status: AuthStatus.error,
        errorMessage: _message(error),
      );
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<void> _run(Future<AuthResponse> Function() action) async {
    state = const AuthStateModel(status: AuthStatus.loading);
    try {
      final response = await action();
      state = AuthStateModel(
        status: response.session == null
            ? AuthStatus.unauthenticated
            : AuthStatus.authenticated,
        user: response.user,
      );
    } catch (error) {
      state = AuthStateModel(
        status: AuthStatus.error,
        errorMessage: _message(error),
      );
      rethrow;
    }
  }

  String _message(Object error) {
    if (error is AuthException) return error.message;
    return 'Authentication failed. Check your connection and try again.';
  }




  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthStateModel>(authProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final goRouterRefreshProvider = Provider<GoRouterRefreshNotifier>((ref) {
  return GoRouterRefreshNotifier(ref);
});
