import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets.dart';

/// Shown when a USER deep-links to /reports or /user-management (server enforces the real 403).
class UnauthorizedScreen extends StatelessWidget {
  const UnauthorizedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access denied')),
      body: ErrorView(
        message: 'You do not have permission to view this page.\n'
            'Ask your administrator if you need access.',
        onRetry: () => context.go('/dashboard'),
      ),
    );
  }
}
