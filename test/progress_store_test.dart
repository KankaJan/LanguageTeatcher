import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_teatcher/models/progress.dart';
import 'package:language_teatcher/services/progress_store.dart';

void main() {
  late Directory tempRoot;
  late ProgressStore store;

  ProgressStore makeStore() => ProgressStore(
        File('${tempRoot.path}/progress.json'),
        Directory('${tempRoot.path}/attempts'),
      );

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('progress_store_test');
    store = makeStore();
    await store.load();
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });

  Future<Attempt> attempt(String wordId, int lesson, int rep) =>
      store.recordAttempt(
        wordId: wordId,
        lesson: lesson,
        repetition: rep,
        filePath: '${tempRoot.path}/attempts/x.m4a',
      );

  test('fresh store is empty', () {
    expect(store.lessonsCompleted, 0);
    expect(store.nextLessonNumber, 1);
    expect(store.wordStates, isEmpty);
    expect(store.pendingAttempts, isEmpty);
  });

  test('recorded attempts are pending, oldest first', () async {
    final a1 = await attempt('dog', 1, 2);
    final a2 = await attempt('cat', 1, 2);
    expect(store.pendingAttempts.map((a) => a.id), [a1.id, a2.id]);
  });

  test('lesson with no grades gives a provisional pass with review in K',
      () async {
    await attempt('dog', 1, 2);
    await store.completeLesson(
        lesson: 1, wordIds: ['dog', 'cat'], reviewInterval: 5);

    expect(store.lessonsCompleted, 1);
    for (final id in ['dog', 'cat']) {
      final p = store.wordStates[id]!;
      expect(p.state, WordState.known, reason: id);
      expect(p.dueLesson, 6, reason: id);
    }
  });

  test('grading below threshold demotes the word to next lesson', () async {
    final a1 = await attempt('dog', 1, 2);
    final a2 = await attempt('dog', 1, 3);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);

    await store.gradeAttempt(a1.id, correct: false, reviewInterval: 5);
    var p = store.wordStates['dog']!;
    expect(p.state, WordState.learning, reason: 'avg 0.0 < 0.6');
    expect(p.dueLesson, 2, reason: 'due in the very next lesson');

    await store.gradeAttempt(a2.id, correct: true, reviewInterval: 5);
    p = store.wordStates['dog']!;
    expect(p.state, WordState.learning, reason: 'avg 0.5 still < 0.6');
  });

  test('grading at or above threshold keeps the word known', () async {
    final a1 = await attempt('dog', 1, 2);
    final a2 = await attempt('dog', 1, 3);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 4);

    await store.gradeAttempt(a1.id, correct: true, reviewInterval: 4);
    await store.gradeAttempt(a2.id, correct: true, reviewInterval: 4);

    final p = store.wordStates['dog']!;
    expect(p.state, WordState.known);
    expect(p.dueLesson, 5);
    expect(p.lastAvgScore, 1.0);
  });

  test('grades already present at lesson completion count immediately',
      () async {
    final a1 = await attempt('dog', 1, 2);
    await store.gradeAttempt(a1.id, correct: false, reviewInterval: 5);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);

    final p = store.wordStates['dog']!;
    expect(p.state, WordState.learning);
    expect(p.dueLesson, 2);
  });

  test('grading an older lesson never overwrites a newer outcome', () async {
    final old = await attempt('dog', 1, 2);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);
    await attempt('dog', 2, 2);
    await store.completeLesson(lesson: 2, wordIds: ['dog'], reviewInterval: 5);

    await store.gradeAttempt(old.id, correct: false, reviewInterval: 5);

    final p = store.wordStates['dog']!;
    expect(p.sourceLesson, 2);
    expect(p.state, WordState.known,
        reason: 'lesson 2 outcome stands despite the lesson 1 fail');
  });

  test('state survives a reload from disk', () async {
    final a1 = await attempt('dog', 1, 2);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);
    await store.gradeAttempt(a1.id, correct: false, reviewInterval: 5);

    final reloaded = makeStore();
    await reloaded.load();

    expect(reloaded.lessonsCompleted, 1);
    expect(reloaded.wordStates['dog']!.state, WordState.learning);
    expect(reloaded.attempts.single.adultScore, 0);
    expect(reloaded.pendingAttempts, isEmpty);
  });

  test('attempt ids stay unique across reloads', () async {
    final a1 = await attempt('dog', 1, 2);
    final reloaded = makeStore();
    await reloaded.load();
    final a2 = await reloaded.recordAttempt(
        wordId: 'cat', lesson: 1, repetition: 2, filePath: 'y.m4a');
    expect(a2.id, isNot(a1.id));
  });

  test('confident auto scores drive the state like adult grades', () async {
    final a1 = await attempt('dog', 1, 2);
    final a2 = await attempt('dog', 1, 3);
    await store.setAutoResult(a1.id,
        autoScore: 1, confidence: 0.9, transcript: 'dog', reviewInterval: 5);
    await store.setAutoResult(a2.id,
        autoScore: 1, confidence: 0.8, transcript: 'dog', reviewInterval: 5);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);

    final p = store.wordStates['dog']!;
    expect(p.state, WordState.known);
    expect(p.lastAvgScore, 1.0);
    expect(store.pendingAttempts, isEmpty,
        reason: 'confidently scored attempts skip the inbox');
  });

  test('an unsure auto result keeps the attempt in the inbox', () async {
    final a1 = await attempt('dog', 1, 2);
    await store.setAutoResult(a1.id,
        autoScore: null,
        confidence: 0.3,
        transcript: 'dock',
        reviewInterval: 5);

    expect(store.pendingAttempts.map((a) => a.id), [a1.id]);
    expect(store.pendingAttempts.single.wasUnsure, isTrue);
  });

  test('a late confident auto fail demotes a provisionally known word',
      () async {
    final a1 = await attempt('dog', 1, 2);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);
    expect(store.wordStates['dog']!.state, WordState.known);

    await store.setAutoResult(a1.id,
        autoScore: 0, confidence: 0.9, transcript: 'cat', reviewInterval: 5);

    final p = store.wordStates['dog']!;
    expect(p.state, WordState.learning);
    expect(p.dueLesson, 2);
  });

  test('parent grade overrides a confident auto score', () async {
    final a1 = await attempt('dog', 1, 2);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);
    await store.setAutoResult(a1.id,
        autoScore: 0, confidence: 0.9, transcript: 'cat', reviewInterval: 5);
    expect(store.wordStates['dog']!.state, WordState.learning);

    await store.gradeAttempt(a1.id, correct: true, reviewInterval: 5);

    final p = store.wordStates['dog']!;
    expect(p.state, WordState.known,
        reason: 'the human heard it right; adultScore wins over autoScore');
  });

  test('a version-1 progress file (no auto fields) still loads', () async {
    store.file.parent.createSync(recursive: true);
    store.file.writeAsStringSync('''
      {"version": 1, "lessons_completed": 3, "next_attempt_id": 2,
       "words": {"dog": {"state": "learning", "due_lesson": 4,
                          "source_lesson": 3, "last_avg_score": 0.5}},
       "attempts": [{"id": 1, "word_id": "dog", "lesson": 3, "repetition": 2,
                     "file": "x.wav", "created_at": "2026-09-01T10:00:00.000",
                     "adult_score": null}]}
    ''');
    final reloaded = makeStore();
    await reloaded.load();

    expect(reloaded.lessonsCompleted, 3);
    expect(reloaded.attempts.single.autoScore, isNull);
    expect(reloaded.pendingAttempts, hasLength(1));
  });

  test('reset wipes state and attempt recordings', () async {
    await attempt('dog', 1, 2);
    await store.completeLesson(lesson: 1, wordIds: ['dog'], reviewInterval: 5);
    store.attemptsDirectory.createSync(recursive: true);
    File('${store.attemptsDirectory.path}/a.m4a').writeAsBytesSync([1]);

    await store.reset();

    expect(store.lessonsCompleted, 0);
    expect(store.wordStates, isEmpty);
    expect(store.pendingAttempts, isEmpty);
    expect(store.attemptsDirectory.existsSync(), isFalse);
    expect(store.file.existsSync(), isFalse);
  });
}
