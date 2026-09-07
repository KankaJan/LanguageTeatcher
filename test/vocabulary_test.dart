import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_teatcher/models/vocabulary.dart';

void main() {
  late Vocabulary vocabulary;

  setUpAll(() {
    final json = File('content/vocabulary.json').readAsStringSync();
    vocabulary = Vocabulary.fromJsonString(json);
  });

  test('dataset parses with expected size', () {
    expect(vocabulary.categories, hasLength(13));
    expect(vocabulary.orderedWords, hasLength(221));
  });

  test('word ids are unique', () {
    final ids = vocabulary.orderedWords.map((w) => w.id).toSet();
    expect(ids, hasLength(vocabulary.orderedWords.length));
  });

  test('every word has Czech and English text', () {
    for (final word in vocabulary.orderedWords) {
      expect(word.cz, isNotEmpty, reason: word.id);
      expect(word.en, isNotEmpty, reason: word.id);
    }
  });

  test('orderedWords follows category order, then word order', () {
    final categoryOrder = {
      for (final c in vocabulary.categories) c.id: c.order,
    };
    for (var i = 1; i < vocabulary.orderedWords.length; i++) {
      final prev = vocabulary.orderedWords[i - 1];
      final curr = vocabulary.orderedWords[i];
      final prevKey = categoryOrder[prev.categoryId]! * 1000 + prev.order;
      final currKey = categoryOrder[curr.categoryId]! * 1000 + curr.order;
      expect(currKey, greaterThan(prevKey),
          reason: '${prev.id} should come before ${curr.id}');
    }
  });

  test('curriculum starts with first words, then animals', () {
    expect(vocabulary.orderedWords.first.id, 'hello');
    expect(vocabulary.orderedWords[10].categoryId, 'animals');
  });

  test('every word resolves to a picture emoji', () {
    for (final word in vocabulary.orderedWords) {
      expect(vocabulary.emojiFor(word), isNotEmpty, reason: word.id);
    }
  });

  test('unknown category in a word is rejected', () {
    expect(
      () => Vocabulary.fromJsonString('''
        {
          "categories": [
            {"id": "a", "order": 1, "en": "A", "cz": "A", "emoji": "🅰️",
             "suggested_lessons": "1-1"}
          ],
          "words": [
            {"id": "w", "en": "w", "cz": "w", "category": "missing", "order": 1,
             "emoji": null}
          ]
        }
      '''),
      throwsFormatException,
    );
  });
}
