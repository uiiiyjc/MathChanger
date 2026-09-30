import 'package:flutter/material.dart';

import 'screens/capture_screen.dart';

void main() => runApp(const MathChangerApp());

/// MathChanger: turn a photo of handwritten maths into clean LaTeX.
class MathChangerApp extends StatelessWidget {
  const MathChangerApp({super.key});

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
