import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/user_management/presentation/user_management_screen.dart';
import '../features/users/presentation/user_details_screen.dart';
import '../features/users/presentation/users_screen.dart';
import '../widgets/error_screen.dart';
import '../widgets/unauthorized_screen.dart';

// Built ONCE. Auth changes bump the ValueNotifier, which re-runs the redirect —
// recreating the GoRouter instead would restart navigation at /splash mid-request
// (e.g. leaving the Register screen before its server error could be shown).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider); // read: never rebuild the router
      final loc = state.matchedLocation;
      final loggedIn = auth.user != null;
      final onAuthFlow = loc == '/splash' || loc == '/login' || loc == '/register';

      if (!loggedIn && !onAuthFlow) return '/login';
      if (loggedIn && (loc == '/login' || loc == '/register' || loc == '/splash')) return '/dashboard';

      // Role guard (UX only — the server enforces the real rules).
      if (loggedIn) {
        final isSuperAdmin = auth.menu.contains('user_management');
        if (!isSuperAdmin && (loc == '/reports' || loc == '/user-management')) return '/unauthorized';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/users', builder: (_, __) => const UsersScreen()),
      GoRoute(path: '/users/:id', builder: (_, s) => UserDetailsScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/user-management', builder: (_, __) => const UserManagementScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/unauthorized', builder: (_, __) => const UnauthorizedScreen()),
    ],
    errorBuilder: (_, __) => const ErrorScreen(),
  );
});
