import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'exceptions.dart';
import 'token_store.dart';

/// Single dio instance with JWT attach + 401/403 handling + timeouts.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Content-Type': 'application/json'},
  )); // dio default: >=400 throws DioException, handled in toApiException

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await ref.read(tokenStoreProvider).read();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (err, handler) async {
      // 401 only: expired/invalid token — clear session; router redirects to login.
      // 403 stays put: authorized user, just not allowed that resource.
      // /api/auth/login is excluded: a wrong password is not a session expiry,
      // and a stale-true flag would swallow the next real expiry (StateProvider
      // does not notify when the value is unchanged).
      if (err.response?.statusCode == 401 && !err.requestOptions.path.contains('/api/auth/login')) {
        await ref.read(tokenStoreProvider).clear();
        ref.read(sessionExpiredProvider.notifier).state = true;
      }
      handler.next(err);
    },
  ));

  return dio;
});

/// Set true by the dio interceptor on 401; router listens and redirects to /login.
final sessionExpiredProvider = StateProvider<bool>((ref) => false);

ApiException toApiException(DioException e) {
  final data = e.response?.data;
  final body = data is Map<String, dynamic> ? data : const <String, dynamic>{};

  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return ApiException('Request timed out. Please try again.', kind: ApiErrorKind.timeout);
  }
  if (e.type == DioExceptionType.connectionError) {
    return ApiException('No internet connection. Check your network and try again.', kind: ApiErrorKind.network);
  }

  final status = e.response?.statusCode ?? 0;
  final message = (body['message'] as String?) ?? 'Something went wrong. Please try again.';
  final fieldErrors = (body['errors'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString()));

  final kind = switch (status) {
    400 => ApiErrorKind.validation,
    401 => ApiErrorKind.unauthorized,
    403 => ApiErrorKind.forbidden,
    404 => ApiErrorKind.notFound,
    409 => ApiErrorKind.conflict,
    500 || 502 => ApiErrorKind.server,
    _ => ApiErrorKind.unknown,
  };

  return ApiException(message, kind: kind, status: status, fieldErrors: fieldErrors ?? const {});
}
