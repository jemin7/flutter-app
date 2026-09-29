import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  // Global error handler: framework errors AND uncaught zone errors never crash the app silently.
  FlutterError.onError = (details) => FlutterError.presentError(details);

  runZonedGuarded(
    () => runApp(const ProviderScope(child: AssignmentApp())),
    (error, stackTrace) => FlutterError.presentError(
      FlutterErrorDetails(exception: error, stack: stackTrace, library: 'uncaught zone error'),
    ),
  );
}
