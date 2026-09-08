import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/progress.dart';

/// Learning progress and the child's recorded attempts, persisted as a
/// schema-versioned JSON file with atomic write-and-rename. Deliberately not
/// a database yet: one child produces a few hundred small records (see
/// PLAN.md); this stays trivially testable and has no codegen.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this.file, this.attemptsDirectory);

  /// Average effective score a word needs to count as known for its lesson.
  static const passThreshold = 0.6;

  final File file;

  /// Where lesson_screen saves the child's attempt recordings; cleared on
  /// [reset] together with the state file.
  final Directory attemptsDirectory;

  int _lessonsCompleted = 0;
  int _nextAttemptId = 1;
  final Map<String, WordProgress> _words = {};
  final List<Attempt> _attempts = [];

  static Future<ProgressStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final store = ProgressStore(
      File('${docs.path}/progress.json'),
      Directory('${docs.path}/attempts'),
    );
    await store.load();
    return store;
  }

  int get lessonsCompleted => _lessonsCompleted;

  /// Number of the lesson the child would play next (1-based).
  int get nextLessonNumber => _lessonsCompleted + 1;

  Map<String, WordProgress> get wordStates => Map.unmodifiable(_words);

  List<Attempt> get attempts => List.unmodifiable(_attempts);

  /// Attempts needing a human grade (no parent grade, no confident auto
  /// score), oldest first, for the review inbox.
  List<Attempt> get pendingAttempts =>
      _attempts.where((a) => a.needsReview).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  Future<void> load() async {
    _words.clear();
    _attempts.clear();
    _lessonsCompleted = 0;
    _nextAttemptId = 1;
    if (file.existsSync()) {
      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      _lessonsCompleted = data['lessons_completed'] as int? ?? 0;
      _nextAttemptId = data['next_attempt_id'] as int? ?? 1;
      final words = data['words'] as Map<String, dynamic>? ?? {};
      words.forEach((id, json) {
        _words[id] = WordProgress.fromJson(json as Map<String, dynamic>);
      });
      for (final json in data['attempts'] as List? ?? const []) {
        _attempts.add(Attempt.fromJson(json as Map<String, dynamic>));
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final data = <String, dynamic>{
      'version': 2,
      'lessons_completed': _lessonsCompleted,
      'next_attempt_id': _nextAttemptId,
      'words': _words.map((id, wp) => MapEntry(id, wp.toJson())),
      'attempts': _attempts.map((a) => a.toJson()).toList(),
    };
    file.parent.createSync(recursive: true);
    final temp = File('${file.path}.tmp');
    temp.writeAsStringSync(jsonEncode(data), flush: true);
    temp.renameSync(file.path);
  }

  Future<Attempt> recordAttempt({
    required String wordId,
    required int lesson,
    required int repetition,
    required String filePath,
  }) async {
    final attempt = Attempt(
      id: _nextAttemptId++,
      wordId: wordId,
      lesson: lesson,
      repetition: repetition,
      filePath: filePath,
      createdAt: DateTime.now(),
    );
    _attempts.add(attempt);
    await _save();
    notifyListeners();
    return attempt;
  }

  /// Parent grades one attempt from the inbox. The parent's grade always
  /// outranks any automatic score (see Attempt.effectiveScore).
  Future<void> gradeAttempt(
    int attemptId, {
    required bool correct,
    required int reviewInterval,
  }) async {
    final attempt = _attempts.firstWhere((a) => a.id == attemptId);
    attempt.adultScore = correct ? 1 : 0;
    _recomputeWord(attempt.wordId, attempt.lesson, reviewInterval);
    await _save();
    notifyListeners();
  }

  /// Stores the speech recognizer's result for an attempt. A confident
  /// verdict carries an [autoScore]; an unsure one leaves it null (the
  /// attempt stays in the inbox) but keeps the transcript for the badge.
  Future<void> setAutoResult(
    int attemptId, {
    required int? autoScore,
    required double confidence,
    required String transcript,
    required int reviewInterval,
  }) async {
    final attempt = _attempts.firstWhere((a) => a.id == attemptId);
    attempt.autoScore = autoScore;
    attempt.confidence = confidence;
    attempt.transcript = transcript;
    if (autoScore != null) {
      _recomputeWord(attempt.wordId, attempt.lesson, reviewInterval);
    }
    await _save();
    notifyListeners();
  }

  /// Re-derives a word's state from the effective scores of [lesson] — but
  /// only when that lesson is the one that produced the word's current state,
  /// so a late grade for an old lesson can never overwrite a newer outcome.
  /// (Scores arriving before the lesson completes are picked up by
  /// [completeLesson] instead.)
  void _recomputeWord(String wordId, int lesson, int reviewInterval) {
    final progress = _words[wordId];
    if (progress == null || lesson != progress.sourceLesson) return;

    final scores = _attempts
        .where((a) => a.wordId == wordId && a.lesson == lesson)
        .map((a) => a.effectiveScore)
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return;
    final avg = scores.fold<int>(0, (s, v) => s + v) / scores.length;
    _words[wordId] = avg >= passThreshold
        ? WordProgress(
            state: WordState.known,
            dueLesson: lesson + reviewInterval,
            sourceLesson: lesson,
            lastAvgScore: avg,
          )
        : WordProgress(
            state: WordState.learning,
            dueLesson: nextLessonNumber,
            sourceLesson: lesson,
            lastAvgScore: avg,
          );
  }

  /// Applies lesson results: for each word, the average of its effective
  /// scores in this lesson decides. No scores yet means a provisional pass —
  /// grades or auto scores arriving later (see [gradeAttempt] and
  /// [setAutoResult]) can demote it.
  Future<void> completeLesson({
    required int lesson,
    required List<String> wordIds,
    required int reviewInterval,
  }) async {
    for (final wordId in wordIds) {
      final scores = _attempts
          .where((a) => a.wordId == wordId && a.lesson == lesson)
          .map((a) => a.effectiveScore)
          .whereType<int>()
          .toList();
      final double? avg = scores.isEmpty
          ? null
          : scores.fold<int>(0, (s, v) => s + v) / scores.length;
      final passed = avg == null || avg >= passThreshold;
      _words[wordId] = WordProgress(
        state: passed ? WordState.known : WordState.learning,
        dueLesson: passed ? lesson + reviewInterval : lesson + 1,
        sourceLesson: lesson,
        lastAvgScore: avg,
      );
    }
    if (lesson > _lessonsCompleted) {
      _lessonsCompleted = lesson;
    }
    await _save();
    notifyListeners();
  }

  /// Wipes all progress, attempts, and their recordings.
  Future<void> reset() async {
    _words.clear();
    _attempts.clear();
    _lessonsCompleted = 0;
    _nextAttemptId = 1;
    if (file.existsSync()) {
      file.deleteSync();
    }
    if (attemptsDirectory.existsSync()) {
      attemptsDirectory.deleteSync(recursive: true);
    }
    notifyListeners();
  }
}
