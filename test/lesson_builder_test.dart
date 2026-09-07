import 'package:flutter_test/flutter_test.dart';
import 'package:language_teatcher/logic/lesson_builder.dart';
import 'package:language_teatcher/models/vocabulary.dart';

List<Word> fakeWords(int count) => [
      for (var i = 0; i < count; i++)
        Word(id: 'w$i', en: 'en$i', cz: 'cz$i', categoryId: 'c', order: i),
    ];

void main() {
  test('lesson takes the next N words after the completed counter', () {
    final lesson = buildLesson(
      orderedWords: fakeWords(20),
      wordsCompleted: 5,
      wordsPerLesson: 4,
      repetitionsPerWord: 3,
    );
    expect(lesson.words.map((w) => w.id), ['w5', 'w6', 'w7', 'w8']);
  });

  test('each word appears exactly R times in the pass sequence', () {
    final lesson = buildLesson(
      orderedWords: fakeWords(20),
      wordsCompleted: 0,
      wordsPerLesson: 5,
      repetitionsPerWord: 3,
    );
    expect(lesson.passes, hasLength(15));
    for (final word in lesson.words) {
      final appearances =
          lesson.passes.where((p) => p.word.id == word.id).length;
      expect(appearances, 3, reason: word.id);
    }
  });

  test('passes are interleaved: no word twice in a row', () {
    final lesson = buildLesson(
      orderedWords: fakeWords(20),
      wordsCompleted: 0,
      wordsPerLesson: 5,
      repetitionsPerWord: 4,
    );
    for (var i = 1; i < lesson.passes.length; i++) {
      expect(lesson.passes[i].word.id,
          isNot(lesson.passes[i - 1].word.id),
          reason: 'position $i');
    }
  });

  test('wraps around to the start when the vocabulary is exhausted', () {
    final lesson = buildLesson(
      orderedWords: fakeWords(10),
      wordsCompleted: 8,
      wordsPerLesson: 5,
      repetitionsPerWord: 2,
    );
    expect(lesson.words.map((w) => w.id), ['w8', 'w9', 'w0', 'w1', 'w2']);
  });

  test('lesson is capped at the vocabulary size', () {
    final lesson = buildLesson(
      orderedWords: fakeWords(3),
      wordsCompleted: 0,
      wordsPerLesson: 10,
      repetitionsPerWord: 2,
    );
    expect(lesson.words, hasLength(3));
  });
}
