import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';

/// End-of-lesson celebration: stars pop in, a cheer is spoken in both
/// languages, then the app returns home by itself (or on tap).
class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({super.key});

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  Timer? _autoClose;

  @override
  void initState() {
    super.initState();
    _cheer();
    _autoClose = Timer(const Duration(seconds: 5), _close);
  }

  Future<void> _cheer() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _tts.speakCzech('Hurá! Výborně!');
    if (!mounted) return;
    await _tts.speakEnglish('Great job!');
  }

  void _close() {
    _autoClose?.cancel();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _tts.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stars = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: stars,
                child: const Text('⭐⭐⭐', style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 24),
              ScaleTransition(
                scale: stars,
                child: const Text('🎉', style: TextStyle(fontSize: 120)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
