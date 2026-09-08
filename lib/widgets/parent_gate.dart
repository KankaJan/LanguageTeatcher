import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// State machine for the parent gate: unlocks only while [requiredPointers]
/// fingers stay down together for [holdDuration]. Pure logic with injected
/// timestamps so it is unit-testable without timers.
class ParentGateController extends ChangeNotifier {
  ParentGateController({
    this.requiredPointers = 2,
    this.holdDuration = const Duration(seconds: 2),
  });

  final int requiredPointers;
  final Duration holdDuration;

  int _pointers = 0;
  DateTime? _holdStart;

  int get pointers => _pointers;

  void pointerDown(DateTime now) {
    _pointers++;
    _update(now);
  }

  void pointerUp(DateTime now) {
    if (_pointers > 0) _pointers--;
    _update(now);
  }

  void _update(DateTime now) {
    if (_pointers >= requiredPointers) {
      _holdStart ??= now;
    } else {
      _holdStart = null;
    }
    notifyListeners();
  }

  double progressAt(DateTime now) {
    final start = _holdStart;
    if (start == null) return 0;
    final elapsed = now.difference(start).inMilliseconds;
    return (elapsed / holdDuration.inMilliseconds).clamp(0.0, 1.0);
  }

  bool unlockedAt(DateTime now) => progressAt(now) >= 1;
}

/// Toddler-proof gate to parent mode: hold two fingers on the circle for two
/// seconds. Pops `true` when unlocked. (Text is fine here — a child who can't
/// read can't follow the instruction, which is the point.)
class ParentGateDialog extends StatefulWidget {
  const ParentGateDialog({super.key});

  static Future<bool> show(BuildContext context) async {
    final unlocked = await showDialog<bool>(
      context: context,
      builder: (_) => const ParentGateDialog(),
    );
    return unlocked ?? false;
  }

  @override
  State<ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<ParentGateDialog>
    with SingleTickerProviderStateMixin {
  final ParentGateController _controller = ParentGateController();
  late final Ticker _ticker = createTicker((_) {
    final now = DateTime.now();
    if (_controller.unlockedAt(now)) {
      _ticker.stop();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {});
  });

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = _controller.progressAt(now);
    final holding = _controller.pointers >= _controller.requiredPointers;

    return AlertDialog(
      title: const Text('Pro rodiče'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Podržte kruh dvěma prsty najednou po dobu dvou vteřin.'),
          const SizedBox(height: 20),
          Listener(
            onPointerDown: (_) => _controller.pointerDown(DateTime.now()),
            onPointerUp: (_) => _controller.pointerUp(DateTime.now()),
            onPointerCancel: (_) => _controller.pointerUp(DateTime.now()),
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: Colors.brown.withValues(alpha: 0.1),
                  ),
                  Center(
                    child: Icon(
                      holding ? Icons.lock_open : Icons.lock_outline,
                      size: 48,
                      color: holding
                          ? Theme.of(context).colorScheme.primary
                          : Colors.brown.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Zavřít'),
        ),
      ],
    );
  }
}
