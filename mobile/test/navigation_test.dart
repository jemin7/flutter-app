import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:assignment_app/core/api_client.dart';
import 'package:assignment_app/core/token_store.dart';
import 'package:assignment_app/core/router.dart';
import 'package:assignment_app/features/auth/data/auth_controller.dart';
import 'package:assignment_app/features/dashboard/presentation/dashboard_screen.dart';

class _FakeTokenStore extends TokenStore {
  String? stored = 'fake-jwt';
  @override
  Future<String?> read() async => stored;
  @override
  Future<void> save(String token) async => stored = token;
  @override
  Future<void> clear() async => stored = null;
}

const _userJson = {
  'id': 1,
  'name': 'Leanne Graham',
  'username': 'Bret',
  'email': 'leanne@april.biz',
  'address': {
    'street': 'Kulas Light',
    'suite': 'Apt. 556',
    'city': 'Gwenborough',
    'zipcode': '92998-3874',
    'geo': {'lat': '-37.3159', 'lng': '81.1496'},
  },
  'phone': '1-770-736-8031 x56442',
  'website': 'hildegard.org',
  'company': {'name': 'Romaguera-Crona', 'catchPhrase': 'Multi-layered client-server neural-net', 'bs': 'harness real-time e-markets'},
};

class _FakeDio implements Dio {
  @override
  Future<Response<T>> get<T>(String path, {Object? data, Map<String, dynamic>? queryParameters, Options? options, CancelToken? cancelToken, ProgressCallback? onReceiveProgress}) async {
    if (path == '/api/auth/me') {
      return Response<T>(
        data: {
          'success': true,
          'data': {
            'user': {'id': '2', 'fullName': 'Hemant Kumar', 'username': 'hemant', 'email': 'hemant@test.com', 'role': 'USER', 'companyName': 'Romaguera-Crona'},
            'menu': ['dashboard', 'users', 'settings'],
          },
        } as T,
        requestOptions: RequestOptions(path: path),
      );
    }
    if (path == '/api/external-users') {
      return Response<T>(
        data: {'success': true, 'data': [_userJson]} as T,
        requestOptions: RequestOptions(path: path),
      );
    }
    throw UnimplementedError(path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Starts authenticated so the router lands on /dashboard (menu: users, settings).
class _AuthedController extends AuthController {
  @override
  AuthState build() {
    ref.listen(sessionExpiredProvider, (_, expired) {
      if (expired) state = const AuthState();
    });
    return const AuthState(
      user: {'id': '2', 'fullName': 'Hemant Kumar', 'username': 'hemant', 'email': 'hemant@test.com', 'role': 'USER', 'companyName': 'Romaguera-Crona'},
      menu: ['dashboard', 'users', 'settings'],
    );
  }
}

Future<ProviderContainer> _pumpApp(WidgetTester tester, {bool authenticated = true}) async {
  final container = ProviderContainer(
    overrides: [
      dioProvider.overrideWithValue(_FakeDio()),
      tokenStoreProvider.overrideWithValue(_FakeTokenStore()..stored = authenticated ? 'fake-jwt' : null),
      if (authenticated) authControllerProvider.overrideWith(_AuthedController.new),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (_, ref, __) => MaterialApp.router(routerConfig: ref.watch(routerProvider)),
      ),
    ),
  );
  await tester.pump(); // splash frame + postFrameCallback bootstrap
  await tester.pumpAndSettle(); // land on /dashboard
  return container;
}

String _topLocation(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation;

void main() {
  testWidgets('dashboard menu pushes Users onto the stack (not replace)', (tester) async {
    final container = await _pumpApp(tester);
    expect(_topLocation(container), '/dashboard');

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();

    expect(_topLocation(container), '/users');
    // The regression: go() left 1 page (nothing to pop); push() stacks 2.
    final pages = tester.widget<Navigator>(find.byType(Navigator).first).pages;
    expect(pages.length, 2, reason: 'Users must stack on top of Dashboard');
  });

  testWidgets('system back from Users returns to Dashboard instead of closing the app', (tester) async {
    final container = await _pumpApp(tester);

    await tester.tap(find.text('Users'));
    await tester.pumpAndSettle();
    expect(_topLocation(container), '/users');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(_topLocation(container), '/dashboard');
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('back from Register returns to Login instead of closing the app', (tester) async {
    final container = await _pumpApp(tester, authenticated: false);
    await tester.pump(); // splash bootstrap
    await tester.pumpAndSettle(); // land on /login
    expect(_topLocation(container), '/login');

    container.read(routerProvider).push('/register');
    await tester.pumpAndSettle();
    expect(_topLocation(container), '/register');

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(_topLocation(container), '/login');
  });

  testWidgets('logged-in user is bounced off /register by the route guard', (tester) async {
    final container = await _pumpApp(tester);
    container.read(routerProvider).push('/register');
    await tester.pumpAndSettle();
    expect(_topLocation(container), '/dashboard', reason: 'auth flow screens must not be reachable while authenticated');
  });
}
