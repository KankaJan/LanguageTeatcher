import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/logic/lesson_builder.dart';
import 'package:otterly/models/progress.dart';
import 'package:otterly/models/vocabulary.dart';

List<Word> fakeWords(int count) => [
      for (var i = 0; i < count; i++)
        Word(id: 'w$i', en: 'en$i', cz: 'cz$i', categoryId: 'c', order: i),
    ];

WordProgress learning({required int due}) => WordProgress(
    state: WordState.learning, dueLesson: due, sourceLesson: due - 1);

WordProgress known({required int due}) => WordProgress(
    state: WordState.known, dueLesson: due, sourceLesson: 1);

void main() {
  group('selectWords', () {
    test('fresh start picks new words in curriculum order', () {
      final selected = selectWords(
        orderedWords: fakeWords(20),
        progress: const {},
        nextLesson: 1,
        wordsPerLesson: 5,
      );
      expect(selected.map((w) => w.id), ['w0', 'w1', 'w2', 'w3', 'w4']);
    });

    test('failed words come first, then due reviews, then new', () {
      final selected = selectWords(
        orderedWords: fakeWords(20),
        progress: {
          'w7': learning(due: 4), // failed, due
          'w1': known(due: 4), // review due
          'w2': known(due: 9), // not due yet
          'w0': known(due: 9),
          'w3': known(due: 9),
          'w4': known(due: 9),
          'w5': known(due: 9),
          'w6': known(due: 9),
        },
        nextLesson: 4,
        wordsPerLesson: 4,
      );
      expect(selected.map((w) => w.id), ['w7', 'w1', 'w8', 'w9']);
    });

    test('keeps at least one slot for a new word', () {
      final selected = selectWords(
        orderedWords: fakeWords(20),
        progress: {
          for (var i = 0; i < 6; i++) 'w$i': learning(due: 2),
        },
        nextLesson: 2,
        wordsPerLesson: 5,
      );
      expect(selected.map((w) => w.id), ['w0', 'w1', 'w2', 'w3', 'w6'],
          reason: 'four failed words + one new word, not five failed');
    });

    test('fills with extra due words when nothing new is left', () {
      final words = fakeWords(4);
      final selected = selectWords(
        orderedWords: words,
        progress: {
          'w0': learning(due: 3),
          'w1': learning(due: 3),
          'w2': learning(due: 3),
          'w3': known(due: 3),
        },
        nextLesson: 3,
        wordsPerLesson: 4,
      );
      expect(selected.map((w) => w.id), ['w0', 'w1', 'w2', 'w3']);
    });

    test('all known and nothing due: reviews the soonest-due words', () {
      final selected = selectWords(
        orderedWords: fakeWords(4),
        progress: {
          'w0': known(due: 9),
          'w1': known(due: 7),
          'w2': known(due: 8),
          'w3': known(due: 12),
        },
        nextLesson: 5,
        wordsPerLesson: 2,
      );
      expect(selected.map((w) => w.id), ['w1', 'w2']);
    });

    test('caps at vocabulary size', () {
      final selected = selectWords(
        orderedWords: fakeWords(3),
        progress: const {},
        nextLesson: 1,
        wordsPerLesson: 10,
      );
      expect(selected, hasLength(3));
    });
  });

  group('buildLesson', () {
    test('pass count is words times repetitions', () {
      final lesson = buildLesson(
        words: fakeWords(4),
        repetitionsPerWord: 3,
      );
      expect(lesson.passes, hasLength(12));
    });

    test('each word appears exactly R times', () {
      final words = fakeWords(5);
      final lesson = buildLesson(words: words, repetitionsPerWord: 3);
      for (final word in words) {
        expect(lesson.passes.where((p) => p.id == word.id).length, 3,
            reason: word.id);
      }
    });

    test('passes are interleaved: no word twice in a row', () {
      final lesson = buildLesson(
        words: fakeWords(5),
        repetitionsPerWord: 4,
      );
      for (var i = 1; i < lesson.passes.length; i++) {
        expect(lesson.passes[i].id, isNot(lesson.passes[i - 1].id),
            reason: 'position $i');
      }
    });

    test('the first block covers every word once, in lesson order', () {
      final words = fakeWords(6);
      final lesson = buildLesson(words: words, repetitionsPerWord: 3);
      expect(lesson.passes.take(6).map((w) => w.id),
          words.map((w) => w.id));
    });
  });
}
