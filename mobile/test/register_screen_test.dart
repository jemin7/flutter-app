import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:assignment_app/core/api_client.dart';
import 'package:assignment_app/core/token_store.dart';
import 'package:assignment_app/features/auth/presentation/register_screen.dart';

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
  _FakeDio();

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (path == '/api/auth/companies') {
      return Response<T>(
        data: {
          'success': true,
          'data': ['Romaguera-Crona', 'Deckow-Crist'],
        } as T,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError();
  }

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
    if (path == '/api/auth/register') {
      final body = data as Map<String, dynamic>;
      // Regression: the router used to be recreated while this request was in
      // flight (auth state -> new GoRouter -> jump to /splash), so the user
      // never saw the server's duplicate-username error. The screen must stay
      // mounted and surface the 409 field error.
      if (body['username'] == 'hemant') {
        throw DioException(
          requestOptions: RequestOptions(path: path),
          response: Response(
            data: {
              'success': false,
              'message': 'Username already taken',
              'errors': {'username': 'Username already taken'},
            },
            statusCode: 409,
            requestOptions: RequestOptions(path: path),
          ),
        );
      }
      return Response<T>(
        data: {'success': true, 'data': null, 'message': 'Registration successful. Please log in.'} as T,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

// Minimal router so context.go('/login') after success behaves like the real app.
// Fresh instance per test — a shared GoRouter leaks navigation state between tests.
Widget _wrap({_FakeDio? dio, _FakeTokenStore? store}) => ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio!),
        tokenStoreProvider.overrideWithValue(store!),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/register',
          routes: [
            GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
            GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('Login page'))),
          ],
        ),
      ),
    );

Future<void> _fillForm(WidgetTester tester) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Hemant Kumar'); // full name
  await tester.enterText(fields.at(1), 'hemant'); // username (duplicate)
  await tester.enterText(fields.at(2), 'hemant@test.com');
  await tester.enterText(fields.at(3), 'User@123x!');
  await tester.enterText(fields.at(4), 'User@123x!');
}

void main() {
  testWidgets('duplicate-username 409 stays on screen with field error (router-rebuild regression)', (tester) async {
    final dio = _FakeDio();
    await tester.pumpWidget(_wrap(dio: dio, store: _FakeTokenStore()));
    await tester.pumpAndSettle(); // let the companies dropdown load

    await _fillForm(tester);
    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();

    // Still on the Register screen — NOT bounced to splash/login mid-request.
    expect(find.text('Create account'), findsOneWidget);
    // Server field error rendered under the username field + snackbar message.
    expect(find.text('Username already taken'), findsWidgets);
  });

  testWidgets('successful registration shows confirmation snackbar then lands on login', (tester) async {
    final dio = _FakeDio();
    await tester.pumpWidget(_wrap(dio: dio, store: _FakeTokenStore()));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'New User');
    await tester.enterText(fields.at(1), 'newuser');
    await tester.enterText(fields.at(2), 'new@test.com');
    await tester.enterText(fields.at(3), 'User@123x!');
    await tester.enterText(fields.at(4), 'User@123x!');
    await tester.tap(find.text('Register'));
    await tester.pump(); // snackbar appears before navigation

    expect(find.text('Registration successful. Please log in.'), findsOneWidget);

    await tester.pumpAndSettle(); // navigation to /login completes
    expect(find.text('Login page'), findsOneWidget);
  });

  testWidgets('company dropdown lists directory companies and can be left empty', (tester) async {
    final dio = _FakeDio();
    await tester.pumpWidget(_wrap(dio: dio, store: _FakeTokenStore()));
    await tester.pumpAndSettle();

    expect(find.text('Company (optional)'), findsOneWidget);

    // Fresh username (not 'hemant', which the fake treats as duplicate).
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Companyless User');
    await tester.enterText(fields.at(1), 'companyless');
    await tester.enterText(fields.at(2), 'co@test.com');
    await tester.enterText(fields.at(3), 'User@123x!');
    await tester.enterText(fields.at(4), 'User@123x!');
    await tester.tap(find.text('Register'));
    await tester.pump();
    expect(find.text('Registration successful. Please log in.'), findsOneWidget);
  });
}
