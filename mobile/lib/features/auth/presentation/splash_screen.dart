import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/exceptions.dart';
import '../data/auth_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      // ponytail: 6s soft deadline — a sleeping/cold backend must not hold the
      // user on the splash; they land on login and retry there instead.
      final ok = await restoreSessionWrapper().timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );
      if (!mounted) return;
      context.go(ok ? '/dashboard' : '/login');
    } on ApiException {
      // Offline at startup: still land somewhere useful.
      if (mounted) context.go('/login');
    }
  }

  Future<bool> restoreSessionWrapper() =>
      ref.read(authControllerProvider.notifier).restoreSession();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.groups_rounded, size: 52, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text('StaffHub', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
