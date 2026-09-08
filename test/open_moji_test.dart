import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/logic/open_moji.dart';
import 'package:otterly/models/vocabulary.dart';

void main() {
  test('codepoint naming matches OpenMoji conventions', () {
    expect(openMojiNameFor('🐶'), '1F436');
    expect(openMojiNameFor('☀️'), '2600', reason: 'FE0F is stripped');
    expect(openMojiNameFor('1️⃣'), '0031-20E3',
        reason: 'short codepoints pad to 4 digits');
    expect(openMojiNameFor('👨‍🦱'), '1F468-200D-1F9B1',
        reason: 'ZWJ sequences keep the joiner');
  });

  test('every vocabulary emoji resolves to a bundled illustration', () {
    final json = File('content/vocabulary.json').readAsStringSync();
    final vocabulary = Vocabulary.fromJsonString(json);
    for (final word in vocabulary.orderedWords) {
      final emoji = vocabulary.emojiFor(word);
      final asset = openMojiAssetFor(emoji);
      expect(asset, isNotNull, reason: '$emoji (${word.id})');
      expect(File(asset!).existsSync(), isTrue, reason: asset);
    }
  });

  test('an unknown emoji falls back to null', () {
    expect(openMojiAssetFor('🇨🇿'), isNull);
  });
}
