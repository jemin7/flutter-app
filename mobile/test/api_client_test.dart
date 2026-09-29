import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assignment_app/core/api_client.dart';
import 'package:assignment_app/core/exceptions.dart';
import 'package:assignment_app/core/token_store.dart';

class _FakeTokenStore extends TokenStore {
  String? stored;
  @override
  Future<String?> read() async => stored;
  @override
  Future<void> save(String token) async => stored = token;
  @override
  Future<void> clear() async => stored = null;
}

/// Serves one canned JSON response; no network.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);
  final int status;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

(ProviderContainer, _FakeTokenStore) _stack(int status, Map<String, dynamic> body) {
  final store = _FakeTokenStore()..stored = 'jwt';
  final container = ProviderContainer(overrides: [
    tokenStoreProvider.overrideWithValue(store),
  ]);
  container.read(dioProvider).httpClientAdapter = _StubAdapter(status, body);
  return (container, store);
}

/// Runs a request through the REAL dio stack and maps the failure exactly
/// like production callers do: repositories wrap with toApiException().
Future<ApiException> _call<T>(ProviderContainer c, Future<Response<T>> Function(Dio) req) async {
  try {
    await req(c.read(dioProvider));
  } on DioException catch (e) {
    return toApiException(e);
  }
  fail('expected a DioException — 4xx must throw, never resolve');
}

void main() {
  // Guards the validateStatus regression: 4xx must THROW, not resolve.
  test('401 maps to ApiException with the server message', () async {
    final (c, _) = _stack(401, {'success': false, 'message': 'Invalid username/email or password', 'errors': null});
    addTearDown(c.dispose);
    final ex = await _call(c, (dio) => dio.get('/api/auth/me'));
    expect(ex.message, 'Invalid username/email or password');
    expect(ex.kind, ApiErrorKind.unauthorized);
  });

  test('401 clears the stored token and flags session expired', () async {
    final (c, store) = _stack(401, {'success': false, 'message': 'Session expired', 'errors': null});
    addTearDown(c.dispose);
    await _call(c, (dio) => dio.get('/api/auth/me'));
    expect(store.stored, isNull);
    expect(c.read(sessionExpiredProvider), isTrue);
  });

  test('403 leaves the session intact', () async {
    final (c, store) = _stack(403, {'success': false, 'message': 'No company assigned. Contact your administrator.', 'errors': null});
    addTearDown(c.dispose);
    final ex = await _call(c, (dio) => dio.get('/api/external-users'));
    expect(ex.kind, ApiErrorKind.forbidden);
    expect(store.stored, 'jwt');
    expect(c.read(sessionExpiredProvider), isFalse);
  });

  test('409 maps to conflict with field errors', () async {
    final (c, _) = _stack(409, {'success': false, 'message': 'Email already registered', 'errors': {'email': 'Email already registered'}});
    addTearDown(c.dispose);
    final ex = await _call(c, (dio) => dio.post('/api/auth/register', data: {}));
    expect(ex.kind, ApiErrorKind.conflict);
    expect(ex.fieldErrors['email'], 'Email already registered');
  });
}
