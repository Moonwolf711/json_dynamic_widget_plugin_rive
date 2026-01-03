import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'wfl_animator.dart';
import 'wfl_uploader.dart';

/// WFL Boot Screen - Code entry, no splash, no loading bar
/// Code: 0711 (7-Eleven opens all week)
/// NOTE: In release mode, skip pin code - Windows UAC blocks stdin if run as admin
class WFLBoot extends StatefulWidget {
  const WFLBoot({super.key});

  @override
  State<WFLBoot> createState() => _WFLBootState();
}

class _WFLBootState extends State<WFLBoot> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  String _error = '';
  bool _loading = false;

  static const _validCode = '0711'; // 7-Eleven opens all week

  @override
  void initState() {
    super.initState();

    // In release mode, skip pin code entirely - UAC blocks stdin if admin
    // Producers won't see it anyway, and it prevents UAC stdin freeze
    if (kReleaseMode) {
      _autoLaunch();
    } else {
      // Request focus after layout to avoid RenderBox assertion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  /// Auto-launch in release mode (no pin dialog)
  Future<void> _autoLaunch() async {
    await WFLUploader.init();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WFLAnimator(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() async {
    final code = _codeController.text.trim();

    if (code != _validCode) {
      setState(() => _error = 'Wrong code');
      _codeController.clear();
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    // Init uploader silently
    await WFLUploader.init();

    // Go to cockpit - no splash, no loading bar
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const WFLAnimator(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a12),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // WFL Logo text
            const Text(
              'WFL',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 72,
                fontWeight: FontWeight.w100,
                letterSpacing: 20,
              ),
            ),
            const SizedBox(height: 40),

            // Code input
            SizedBox(
              width: 200,
              child: TextField(
                controller: _codeController,
                focusNode: _focusNode,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.white12),
                  border: InputBorder.none,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white54),
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onSubmitted: (_) => _submit(),
              ),
            ),

            const SizedBox(height: 20),

            // Error or loading
            if (_error.isNotEmpty)
              Text(_error, style: const TextStyle(color: Colors.red, fontSize: 12)),

            if (_loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }
}