import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'wfl_boot.dart';
import 'rive_path_effect.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // >>> WFL Weekly Festival Lowdown Viewer v1.0 - Ara Listening
  print('>>> WFL Weekly Festival Lowdown Viewer v1.0 - Ara Listening');
  print('>>> Terry wink signature: 3x left eye @ 2:31 Saturday');

  // Initialize Firebase for AI Toolkit
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Rive path effects
  await RivePathEffectManager.instance.initialize();

  // Precache all static assets - never flickers again
  await _precacheStaticAssets();

  runApp(const WFLApp());
}

Future<void> _precacheStaticAssets() async {
  final assets = [
    // Backgrounds
    'assets/backgrounds/spaceship_iso.png',

    // Terry layers
    'assets/characters/terry/layers/layer_01_body.png',
    'assets/characters/terry/layers/layer_02_shades.png',

    // Nigel layers
    'assets/characters/nigel/layers/layer_01_body.png',
    'assets/characters/nigel/layers/layer_02_shades.png',
    'assets/characters/nigel/eyes/eyes_open.png',

    // Furniture
    'assets/backgrounds/table.png',
    'assets/backgrounds/buttons_panel.png',
  ];

  for (final path in assets) {
    try {
      await rootBundle.load(path);
    } catch (_) {
      // Asset doesn't exist yet, skip
    }
  }
}

class WFLApp extends StatelessWidget {
  const WFLApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WFL Animator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1a1a2e),
      ),
      home: const WFLBoot(), // Code entry first, then cockpit
    );
  }
}
