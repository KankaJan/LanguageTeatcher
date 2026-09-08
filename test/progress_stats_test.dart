import 'package:flutter_test/flutter_test.dart';
import 'package:language_teatcher/logic/progress_stats.dart';
import 'package:language_teatcher/models/progress.dart';
import 'package:language_teatcher/models/vocabulary.dart';

Vocabulary fakeVocabulary() => Vocabulary(
      categories: const [
        WordCategory(
            id: 'a',
            order: 1,
            en: 'A',
            cz: 'A',
            emoji: '🅰️',
            suggestedLessons: '1-2'),
        WordCategory(
            id: 'b',
            order: 2,
            en: 'B',
            cz: 'B',
            emoji: '🅱️',
            suggestedLessons: '3-4'),
      ],
      words: [
        for (var i = 0; i < 4; i++)
          Word(id: 'a$i', en: 'a$i', cz: 'a$i', categoryId: 'a', order: i),
        for (var i = 0; i < 3; i++)
          Word(id: 'b$i', en: 'b$i', cz: 'b$i', categoryId: 'b', order: i),
      ],
    );

WordProgress known({double? score}) => WordProgress(
    state: WordState.known, dueLesson: 9, sourceLesson: 1, lastAvgScore: score);

WordProgress learning({double? score, int due = 2}) => WordProgress(
    state: WordState.learning,
    dueLesson: due,
    sourceLesson: 1,
    lastAvgScore: score);

void main() {
  test('fresh install: everything zero, nothing struggling', () {
    final stats = ProgressStats.compute(
      vocabulary: fakeVocabulary(),
      wordStates: const {},
      attempts: const [],
      lessonsCompleted: 0,
    );
    expect(stats.known, 0);
    expect(stats.learning, 0);
    expect(stats.totalWords, 7);
    expect(stats.unseen, 7);
    expect(stats.struggling, isEmpty);
    expect(stats.categories.map((c) => c.remaining), [4, 3]);
  });

  test('overall and per-category tallies', () {
    final stats = ProgressStats.compute(
      vocabulary: fakeVocabulary(),
      wordStates: {
        'a0': known(),
        'a1': known(),
        'a2': learning(score: 0.4),
        'b0': learning(score: 0.2),
      },
      attempts: const [],
      lessonsCompleted: 3,
    );
    expect(stats.known, 2);
    expect(stats.learning, 2);
    expect(stats.seen, 4);
    expect(stats.unseen, 3);

    final a = stats.categories[0];
    expect((a.known, a.learning, a.remaining), (2, 1, 1));
    final b = stats.categories[1];
    expect((b.known, b.learning, b.remaining), (0, 1, 2));
  });

  test('struggling words: lowest score first, unscored last', () {
    final stats = ProgressStats.compute(
      vocabulary: fakeVocabulary(),
      wordStates: {
        'a0': learning(score: 0.5),
        'a1': learning(score: null),
        'b0': learning(score: 0.0),
        'b1': known(score: 1.0),
      },
      attempts: const [],
      lessonsCompleted: 2,
    );
    expect(stats.struggling.map((s) => s.word.id), ['b0', 'a0', 'a1'],
        reason: 'known words never appear; nulls sort last');
  });

  test('struggling list is capped', () {
    final vocabulary = Vocabulary(
      categories: const [
        WordCategory(
            id: 'a',
            order: 1,
            en: 'A',
            cz: 'A',
            emoji: '🅰️',
            suggestedLessons: '1-9'),
      ],
      words: [
        for (var i = 0; i < 15; i++)
          Word(id: 'w$i', en: 'w$i', cz: 'w$i', categoryId: 'a', order: i),
      ],
    );
    final stats = ProgressStats.compute(
      vocabulary: vocabulary,
      wordStates: {
        for (var i = 0; i < 15; i++) 'w$i': learning(score: i / 15),
      },
      attempts: const [],
      lessonsCompleted: 1,
    );
    expect(stats.struggling, hasLength(ProgressStats.strugglingCap));
    expect(stats.struggling.first.word.id, 'w0');
  });

  test('attempt tallies split graded from pending', () {
    Attempt attempt(int id, {int? adult, int? auto}) => Attempt(
          id: id,
          wordId: 'a0',
          lesson: 1,
          repetition: 2,
          filePath: 'x.wav',
          createdAt: DateTime(2026),
          adultScore: adult,
          autoScore: auto,
        );
    final stats = ProgressStats.compute(
      vocabulary: fakeVocabulary(),
      wordStates: const {},
      attempts: [
        attempt(1, adult: 1),
        attempt(2, auto: 0),
        attempt(3),
      ],
      lessonsCompleted: 1,
    );
    expect(stats.gradedAttempts, 2);
    expect(stats.pendingAttempts, 1);
  });
}
