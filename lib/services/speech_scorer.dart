import 'dart:convert';

import 'package:flutter/services.dart';

import 'model_manager.dart';

/// Outcome of analysing one attempt recording. [autoScore] is 1 for a
/// confident match, 0 for a confident mismatch, and null when the recognizer
/// was not sure — those attempts go to the parent's review inbox.
class AutoResult {
  const AutoResult({
    required this.autoScore,
    required this.confidence,
    required this.transcript,
  });

  final int? autoScore;
  final double confidence;
  final String transcript;
}

/// Pure decision table turning a raw recognition into a verdict. Constants
/// live here so tuning happens in one place; the parent override in the
/// review inbox is always authoritative regardless.
class ScoringRules {
  static const confidenceThreshold = 0.7;
  static const unknownToken = '[unk]';

  static String normalize(String text) => text.trim().toLowerCase();

  /// [confidence] < 0 means the engine reported no per-word confidences —
  /// common with grammar-constrained decoding. The transcript still had to
  /// win against the tiny grammar (expected word + distractors + unknown),
  /// so it is judged on its own in that case rather than being dumped into
  /// the review inbox wholesale.
  static AutoResult evaluate({
    required String transcript,
    required double confidence,
    required String expected,
  }) {
    final heard = normalize(transcript);
    // Silence or out-of-grammar noise is never auto-failed: the mic may be
    // at fault, so a human decides.
    if (heard.isEmpty || heard == unknownToken) {
      return AutoResult(
          autoScore: null, confidence: confidence, transcript: heard);
    }
    final hasConfidence = confidence >= 0;
    if (hasConfidence && confidence < confidenceThreshold) {
      return AutoResult(
          autoScore: null, confidence: confidence, transcript: heard);
    }
    return AutoResult(
      autoScore: heard == normalize(expected) ? 1 : 0,
      confidence: confidence,
      transcript: heard,
    );
  }
}

/// Scores an attempt recording; null when scoring is unavailable (no model
/// installed, or the engine failed) — the attempt then stays parent-graded.
abstract class SpeechScorer {
  Future<AutoResult?> score({
    required String filePath,
    required String expected,
    required List<String> distractors,
  });

  /// Why the last scoring produced no automatic result (parent-facing
  /// diagnostics), or null when the last scoring worked.
  String? get lastIssue => null;
}

/// On-device Vosk recognizer behind a thin platform channel (Android side:
/// VoskScorerChannel.kt). Recognition is constrained to a tiny grammar —
/// the expected word, the lesson's other words, and unknown — which makes
/// single-word recognition tractable and yields usable confidences.
class VoskScorer implements SpeechScorer {
  VoskScorer(this.models);

  static const _channel = MethodChannel('otterly/vosk');

  /// Null when the active pack's target language has no Vosk model — the
  /// scorer then declines and grading stays with the parent.
  final ModelManager? models;
  bool _initialized = false;
  String? _lastIssue;

  @override
  String? get lastIssue => _lastIssue;

  @override
  Future<AutoResult?> score({
    required String filePath,
    required String expected,
    required List<String> distractors,
  }) async {
    final modelPath = models?.modelPath;
    if (modelPath == null) {
      _lastIssue = models == null
          ? 'Pro tento jazyk není model rozpoznávání.'
          : 'Model rozpoznávání není stažený.';
      return null;
    }
    try {
      if (!_initialized) {
        await _channel.invokeMethod<bool>('initModel', {'path': modelPath});
        _initialized = true;
      }
      final grammar = <String>{
        ScoringRules.normalize(expected),
        ...distractors.map(ScoringRules.normalize),
        ScoringRules.unknownToken,
      }.toList();
      final raw = await _channel.invokeMapMethod<String, dynamic>('scoreFile', {
        'path': filePath,
        'grammar': jsonEncode(grammar),
      });
      if (raw == null) {
        _lastIssue = 'Rozpoznávání nevrátilo žádný výsledek.';
        return null;
      }
      _lastIssue = null;
      return ScoringRules.evaluate(
        transcript: raw['text'] as String? ?? '',
        confidence: (raw['confidence'] as num?)?.toDouble() ?? -1,
        expected: expected,
      );
    } on Object catch (e) {
      // Channel errors, missing plugin, malformed results — all mean the
      // same thing here: no automatic score, the parent grades instead.
      // The reason is kept for the parent-mode card so failures are not a
      // black box.
      _lastIssue = e.toString();
      _initialized = false; // retry initModel on the next attempt
      return null;
    }
  }
}
