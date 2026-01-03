// main_terry_test.dart — Test entry point for TerryLiveViewer
// Run: flutter run -d windows -t lib/main_terry_test.dart

import 'package:flutter/material.dart';
import 'terry_live_viewer.dart';

void main() {
  runApp(const TerryTestApp());
}

class TerryTestApp extends StatelessWidget {
  const TerryTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Terry Live Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        backgroundColor: Color(0xFF1a1a2e),
        body: Center(
          child: TerryLiveViewer(
            host: 'localhost',
            port: 3001,
          ),
        ),
      ),
    );
  }
}
