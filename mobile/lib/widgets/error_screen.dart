import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets.dart';

/// Generic error screen (bad route, unexpected failure).
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Something went wrong')),
      body: ErrorView(
        message: 'This screen does not exist or failed to load.',
        onRetry: () => context.go('/dashboard'),
      ),
    );
  }
}
