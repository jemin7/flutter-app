import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:assignment_app/core/api_client.dart';
import 'package:assignment_app/core/token_store.dart';
import 'package:assignment_app/features/auth/presentation/login_screen.dart';

class _FakeTokenStore extends TokenStore {
  String? stored;
  @override
  Future<String?> read() async => stored;
  @override
  Future<void> save(String token) async => stored = token;
  @override
  Future<void> clear() async => stored = null;
}

class _FakeDio implements Dio {
  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path == '/api/auth/login') {
      final body = data as Map<String, dynamic>;
      if (body['identifier'] == 'hemant' && body['password'] == 'User@123') {
        return Response<T>(
          data: {
            'success': true,
            'data': {
              'token': 'fake-jwt',
              'user': {'id': '1', 'fullName': 'Hemant Kumar', 'username': 'hemant', 'email': 'hemant@test.com', 'role': 'USER', 'companyName': 'Romaguera-Crona'},
              'menu': ['dashboard', 'users', 'settings'],
            },
          } as T,
          requestOptions: RequestOptions(path: path),
        );
      }
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response(
          data: {'success': false, 'message': 'Invalid username/email or password', 'errors': null},
          statusCode: 401,
          requestOptions: RequestOptions(path: path),
        ),
      );
    }
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _wrap(Widget child, {_FakeDio? dio, _FakeTokenStore? store}) => ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio!),
        tokenStoreProvider.overrideWithValue(store!),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('shows validation errors on empty submit', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen(), dio: _FakeDio(), store: _FakeTokenStore()));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.text('Username or email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('shows snackbar on invalid credentials', (tester) async {
    final dio = _FakeDio();
    await tester.pumpWidget(_wrap(const LoginScreen(), dio: dio, store: _FakeTokenStore()));
    await tester.enterText(find.byType(TextFormField).at(0), 'hemant');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Invalid username/email or password'), findsWidgets); // inline + snackbar
  });
}
