import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/widgets/parent_gate.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12, 0, 0);

  test('two sustained pointers unlock after the hold duration', () {
    final gate = ParentGateController();
    gate.pointerDown(t0);
    gate.pointerDown(t0.add(const Duration(milliseconds: 100)));

    final almost = t0.add(const Duration(milliseconds: 2000));
    expect(gate.unlockedAt(almost), isFalse,
        reason: 'hold starts when the SECOND finger lands');
    final done = t0.add(const Duration(milliseconds: 2100));
    expect(gate.unlockedAt(done), isTrue);
    expect(gate.progressAt(done), 1.0);
  });

  test('a single pointer never unlocks', () {
    final gate = ParentGateController();
    gate.pointerDown(t0);
    expect(gate.unlockedAt(t0.add(const Duration(minutes: 1))), isFalse);
    expect(gate.progressAt(t0.add(const Duration(seconds: 5))), 0);
  });

  test('lifting a finger resets the hold', () {
    final gate = ParentGateController();
    gate.pointerDown(t0);
    gate.pointerDown(t0);
    gate.pointerUp(t0.add(const Duration(milliseconds: 1500)));
    // Second finger returns; the clock restarts from here.
    final back = t0.add(const Duration(milliseconds: 1600));
    gate.pointerDown(back);
    expect(gate.unlockedAt(t0.add(const Duration(milliseconds: 2100))), isFalse,
        reason: 'old hold time does not carry over');
    expect(gate.unlockedAt(back.add(const Duration(seconds: 2))), isTrue);
  });

  test('three fingers work too (only a minimum is required)', () {
    final gate = ParentGateController();
    gate.pointerDown(t0);
    gate.pointerDown(t0);
    gate.pointerDown(t0);
    gate.pointerUp(t0.add(const Duration(seconds: 1)));
    expect(gate.unlockedAt(t0.add(const Duration(seconds: 2))), isTrue,
        reason: 'still two fingers down after one lifted');
  });
}
