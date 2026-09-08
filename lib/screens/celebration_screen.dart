import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';

/// End-of-lesson celebration: confetti rains, stars pop in, a cheer is
/// spoken in the child's own language, then the app returns home by itself
/// (or on tap).
class CelebrationScreen extends StatefulWidget {
  const CelebrationScreen({
    super.key,
    required this.praise,
    required this.praiseLocale,
  });

  final String praise;
  final String praiseLocale;

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with TickerProviderStateMixin {
  final TtsService _tts = TtsService();
  late final AnimationController _stars = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
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
    // Praise is spoken in the child's own language only (parent feedback).
    await _tts.speak(widget.praise, widget.praiseLocale);
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
    _stars.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final starScale = CurvedAnimation(
      parent: _stars,
      curve: Curves.elasticOut,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _confetti,
              builder: (context, _) => CustomPaint(
                painter: _ConfettiPainter(progress: _confetti.value),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: starScale,
                    child: const Text('⭐⭐⭐', style: TextStyle(fontSize: 72)),
                  ),
                  const SizedBox(height: 24),
                  ScaleTransition(
                    scale: starScale,
                    child: const Text('🎉', style: TextStyle(fontSize: 120)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colored pieces falling and drifting; deterministic layout from a fixed
/// seed so every rebuild draws the same shower.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static const _colors = [
    Color(0xFF66BB6A),
    Color(0xFF4A90D9),
    Color(0xFFFFB300),
    Color(0xFFE57373),
    Color(0xFFBA68C8),
  ];

  static final List<_ConfettiPiece> _pieces = () {
    final random = Random(42);
    return List.generate(60, (i) {
      return _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.4,
        speed: 0.7 + random.nextDouble() * 0.6,
        sway: 8 + random.nextDouble() * 24,
        swayPhase: random.nextDouble() * 2 * pi,
        rotation: random.nextDouble() * 2 * pi,
        spin: (random.nextDouble() - 0.5) * 10,
        size: 6 + random.nextDouble() * 6,
        color: _colors[i % _colors.length],
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in _pieces) {
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = t * p.speed * (size.height + 40) - 20;
      final x = p.x * size.width + sin(t * 6 + p.swayPhase) * p.sway;
      paint.color = p.color.withValues(alpha: (1.4 - t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + t * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.swayPhase,
    required this.rotation,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double delay;
  final double speed;
  final double sway;
  final double swayPhase;
  final double rotation;
  final double spin;
  final double size;
  final Color color;
}
