import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/logic/pack_generator.dart';
import 'package:otterly/models/language_pack.dart';
import 'package:otterly/models/vocabulary.dart';
import 'package:otterly/services/translator.dart';

Vocabulary miniBase() => Vocabulary(
      categories: const [
        WordCategory(
            id: 'a',
            order: 1,
            en: 'Animals',
            cz: 'Zvířata',
            emoji: '🐶',
            suggestedLessons: '1-2'),
      ],
      words: const [
        Word(id: 'dog', en: 'dog', cz: 'pes', categoryId: 'a', order: 1),
        Word(id: 'cat', en: 'cat', cz: 'kočka', categoryId: 'a', order: 2),
      ],
    );

class FakeTranslator implements WordTranslator {
  FakeTranslator(this.from, this.to);

  final String from;
  final String to;
  bool prepared = false;
  bool disposed = false;

  @override
  Future<void> prepare() async => prepared = true;

  @override
  Future<String> translate(String text) async => '$to:$text';

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  test('bundled pack maps cz to source and en to target', () {
    final pack = LanguagePack.bundled(miniBase());
    expect(pack.id, LanguagePack.bundledId);
    expect(pack.sourceCode, 'cs');
    expect(pack.targetCode, 'en');
    expect(pack.generated, isFalse);
    expect(pack.vocabulary.orderedWords.first.cz, 'pes');
  });

  test('pack JSON round-trip preserves everything', () {
    final pack = LanguagePack(
      id: 'cs_de_1',
      sourceCode: 'cs',
      targetCode: 'de',
      generated: true,
      vocabulary: miniBase(),
    );
    final restored = LanguagePack.fromJson(
        jsonDecode(jsonEncode(pack.toJson())) as Map<String, dynamic>);
    expect(restored.id, pack.id);
    expect(restored.sourceCode, 'cs');
    expect(restored.targetCode, 'de');
    expect(restored.generated, isTrue);
    expect(restored.vocabulary.orderedWords.map((w) => w.id),
        pack.vocabulary.orderedWords.map((w) => w.id));
    expect(restored.vocabulary.categories.single.emoji, '🐶');
  });

  test('withWord replaces one word\'s texts only', () {
    final pack = LanguagePack.bundled(miniBase())
        .withWord('dog', source: 'pejsek', target: 'doggo');
    final words = {for (final w in pack.vocabulary.orderedWords) w.id: w};
    expect(words['dog']!.cz, 'pejsek');
    expect(words['dog']!.en, 'doggo');
    expect(words['cat']!.cz, 'kočka');
  });

  group('generatePack', () {
    test('cs and en sides reuse curated text verbatim', () async {
      final created = <FakeTranslator>[];
      final pack = await generatePack(
        base: miniBase(),
        sourceCode: 'cs',
        targetCode: 'en',
        translatorFactory: (from, to) {
          final t = FakeTranslator(from, to);
          created.add(t);
          return t;
        },
      );
      expect(created, isEmpty, reason: 'nothing needed translating');
      expect(pack.vocabulary.orderedWords.first.cz, 'pes');
      expect(pack.vocabulary.orderedWords.first.en, 'dog');
    });

    test('other languages translate from the English pivot', () async {
      final created = <FakeTranslator>[];
      final progress = <int>[];
      final pack = await generatePack(
        base: miniBase(),
        sourceCode: 'uk',
        targetCode: 'de',
        translatorFactory: (from, to) {
          final t = FakeTranslator(from, to);
          created.add(t);
          return t;
        },
        onProgress: (done, total) => progress.add(done),
      );
      expect(created.map((t) => '${t.from}>${t.to}'), ['en>uk', 'en>de']);
      expect(created.every((t) => t.prepared && t.disposed), isTrue);
      final dog = pack.vocabulary.orderedWords.first;
      expect(dog.cz, 'uk:dog', reason: 'source side, pivoted from English');
      expect(dog.en, 'de:dog', reason: 'target side');
      expect(progress, [1, 2]);
      expect(pack.generated, isTrue);
      expect(pack.id, startsWith('uk_de_'));
    });

    test('cs source with translated target only builds one translator',
        () async {
      final created = <FakeTranslator>[];
      final pack = await generatePack(
        base: miniBase(),
        sourceCode: 'cs',
        targetCode: 'de',
        translatorFactory: (from, to) {
          final t = FakeTranslator(from, to);
          created.add(t);
          return t;
        },
      );
      expect(created.map((t) => t.to), ['de']);
      expect(pack.vocabulary.orderedWords.first.cz, 'pes');
      expect(pack.vocabulary.orderedWords.first.en, 'de:dog');
    });
  });

  test('generated pack file round-trips through disk', () async {
    final dir = Directory.systemTemp.createTempSync('pack_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pack = await generatePack(
      base: miniBase(),
      sourceCode: 'cs',
      targetCode: 'de',
      translatorFactory: FakeTranslator.new,
    );
    final file = File('${dir.path}/p.json')
      ..writeAsStringSync(jsonEncode(pack.toJson()));
    final restored = LanguagePack.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    expect(restored.vocabulary.orderedWords.first.en, 'de:dog');
  });
}
