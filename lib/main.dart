import 'dart:async';

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/capture_screen.dart';
import 'services/cleanup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final services = AppServices.bootstrap();

  // Retention is enforced on every cold start. Fire-and-forget so a slow first
  // launch never blocks the UI; failure here is not worth interrupting anyone.
  unawaited(
    services.cleanup.runAutomatic().catchError((Object _) {
      // Swallowed on purpose: cleanup is best-effort housekeeping.
      return const CleanupReport();
    }),
  );

  runApp(MathChangerApp(services: services));
}

/// MathChanger: turn a photo of handwritten maths into clean LaTeX.
class MathChangerApp extends StatelessWidget {
  const MathChangerApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MathChanger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4C6EF5)),
      ),
      home: const CaptureScreen(),
    );
  }
}
