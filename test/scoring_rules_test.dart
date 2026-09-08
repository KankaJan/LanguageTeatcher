import 'package:flutter_test/flutter_test.dart';
import 'package:language_teatcher/services/speech_scorer.dart';

void main() {
  AutoResult eval(String transcript, double confidence,
          {String expected = 'dog'}) =>
      ScoringRules.evaluate(
          transcript: transcript, confidence: confidence, expected: expected);

  test('confident match passes', () {
    final r = eval('dog', 0.92);
    expect(r.autoScore, 1);
    expect(r.confidence, 0.92);
    expect(r.transcript, 'dog');
  });

  test('confident different word fails', () {
    expect(eval('cat', 0.9).autoScore, 0);
  });

  test('low confidence is unsure, whatever was heard', () {
    expect(eval('dog', 0.5).autoScore, isNull);
    expect(eval('cat', 0.5).autoScore, isNull);
  });

  test('silence and unknown are unsure, never auto-failed', () {
    expect(eval('', 0.0).autoScore, isNull);
    expect(eval('[unk]', 0.99).autoScore, isNull);
  });

  test('threshold boundary counts as confident', () {
    expect(eval('dog', ScoringRules.confidenceThreshold).autoScore, 1);
  });

  test('matching is case- and whitespace-insensitive', () {
    expect(eval(' Dog ', 0.9).autoScore, 1);
    expect(eval('ICE CREAM', 0.9, expected: 'ice cream').autoScore, 1);
  });
}
