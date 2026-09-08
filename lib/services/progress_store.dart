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

  /// Average graded score a word needs to count as known for its lesson.
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

  /// Ungraded attempts, oldest first, for the review inbox.
  List<Attempt> get pendingAttempts =>
      _attempts.where((a) => a.isPending).toList()
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
      'version': 1,
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

  /// Parent grades one attempt from the inbox. The word's state is then
  /// recomputed from the graded attempts of its most recent lesson — so an
  /// ungraded word that was provisionally marked known gets demoted as soon
  /// as its grades average below the threshold, and grading an old lesson
  /// never overwrites a newer outcome.
  Future<void> gradeAttempt(
    int attemptId, {
    required bool correct,
    required int reviewInterval,
  }) async {
    final attempt = _attempts.firstWhere((a) => a.id == attemptId);
    attempt.adultScore = correct ? 1 : 0;

    final progress = _words[attempt.wordId];
    if (progress != null && attempt.lesson == progress.sourceLesson) {
      final graded = _attempts
          .where((a) =>
              a.wordId == attempt.wordId &&
              a.lesson == attempt.lesson &&
              !a.isPending)
          .toList();
      final avg = graded.map((a) => a.adultScore!).fold<int>(0, (s, v) => s + v) /
          graded.length;
      _words[attempt.wordId] = avg >= passThreshold
          ? WordProgress(
              state: WordState.known,
              dueLesson: attempt.lesson + reviewInterval,
              sourceLesson: attempt.lesson,
              lastAvgScore: avg,
            )
          : WordProgress(
              state: WordState.learning,
              dueLesson: nextLessonNumber,
              sourceLesson: attempt.lesson,
              lastAvgScore: avg,
            );
    }
    await _save();
    notifyListeners();
  }

  /// Applies lesson results: for each word, the average of its graded
  /// attempts in this lesson decides. No graded attempts yet means a
  /// provisional pass — grading later (see [gradeAttempt]) can demote it.
  Future<void> completeLesson({
    required int lesson,
    required List<String> wordIds,
    required int reviewInterval,
  }) async {
    for (final wordId in wordIds) {
      final graded = _attempts
          .where((a) => a.wordId == wordId && a.lesson == lesson && !a.isPending)
          .toList();
      final double? avg = graded.isEmpty
          ? null
          : graded.map((a) => a.adultScore!).fold<int>(0, (s, v) => s + v) /
              graded.length;
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
