import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/exceptions.dart';
import '../../../core/token_store.dart';

class AuthState {
  const AuthState({this.user, this.menu = const [], this.loading = false});
  final Map<String, dynamic>? user;
  final List<String> menu;
  final bool loading;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // A 401 anywhere (dio interceptor) clears storage AND the in-memory user,
    // which makes the router redirect to /login.
    ref.listen(sessionExpiredProvider, (_, expired) {
      if (expired) state = const AuthState();
    });
    return const AuthState();
  }

  Dio get _dio => ref.read(dioProvider);

  Future<String?> _token() => ref.read(tokenStoreProvider).read();

  /// True when a stored token still validates against /auth/me.
  Future<bool> restoreSession() async {
    final token = await _token();
    if (token == null || token.isEmpty) return false;
    try {
      final res = await _dio.get('/api/auth/me');
      final data = res.data['data'] as Map<String, dynamic>;
      state = AuthState(user: data['user'], menu: List<String>.from(data['menu']));
      return true;
    } on DioException catch (e) {
      final ex = toApiException(e);
      if (ex.kind == ApiErrorKind.network || ex.kind == ApiErrorKind.timeout) rethrow;
      await ref.read(tokenStoreProvider).clear();
      return false;
    }
  }

  Future<void> login(String identifier, String password) async {
    state = const AuthState(loading: true);
    try {
      final res = await _dio.post('/api/auth/login', data: {'identifier': identifier, 'password': password});
      final data = res.data['data'] as Map<String, dynamic>;
      await ref.read(tokenStoreProvider).save(data['token'] as String);
      state = AuthState(user: data['user'], menu: List<String>.from(data['menu']));
    } on DioException catch (e) {
      state = const AuthState();
      throw toApiException(e);
    }
  }

  Future<void> register(Map<String, String> payload) async {
    state = const AuthState(loading: true);
    try {
      await _dio.post('/api/auth/register', data: payload);
      state = const AuthState();
    } on DioException catch (e) {
      state = const AuthState();
      throw toApiException(e);
    }
  }

  /// Reconciles UI-visible profile fields after a settings update.
  void updateCachedUser(Map<String, dynamic> user) {
    if (state.user == null) return;
    state = AuthState(user: {...?state.user, ...user}, menu: state.menu);
  }

  Future<void> logout() async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(sessionExpiredProvider.notifier).state = false;
    state = const AuthState();
    ref.invalidate(authInvalidator);
  }
}

/// Invalidate this to wipe every cached provider on logout.
final authInvalidator = Provider<void>((ref) {});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
