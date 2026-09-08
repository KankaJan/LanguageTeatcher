import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/models/language_pack.dart';
import 'package:otterly/models/vocabulary.dart';
import 'package:otterly/services/app_prefs.dart';
import 'package:otterly/services/pack_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      ],
    );

LanguagePack germanPack(String id) => LanguagePack(
      id: id,
      sourceCode: 'cs',
      targetCode: 'de',
      generated: true,
      vocabulary: miniBase(),
    );

void main() {
  late Directory tempRoot;
  late AppPrefs prefs;
  late PackStore store;

  Future<PackStore> makeStore() async {
    final s = PackStore(
      baseVocabulary: miniBase(),
      docsDir: tempRoot,
      prefs: prefs,
    );
    return s;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = AppPrefs(await SharedPreferences.getInstance());
    tempRoot = Directory.systemTemp.createTempSync('pack_store_test');
    store = await makeStore();
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });

  test('bundled pack is always present and active by default', () {
    expect(store.packs.map((p) => p.id), [LanguagePack.bundledId]);
    expect(store.active.id, LanguagePack.bundledId);
    expect(identical(store.active, store.active), isTrue,
        reason: 'the bundled pack must be one cached instance');
  });

  test('addPack persists, lists, and activates the new pack', () async {
    await store.addPack(germanPack('cs_de_1'));

    expect(store.active.id, 'cs_de_1');
    expect(File('${tempRoot.path}/packs/cs_de_1.json').existsSync(), isTrue);

    // A fresh store from the same directory sees it too.
    final reloaded = await makeStore();
    reloaded.migrateAndLoad();
    expect(reloaded.packs.map((p) => p.id),
        containsAll([LanguagePack.bundledId, 'cs_de_1']));
  });

  test('deletePack removes files and falls back to the bundled pack',
      () async {
    await store.addPack(germanPack('cs_de_1'));
    store.progressFileFor('cs_de_1').writeAsStringSync('{}');
    store.attemptsDirFor('cs_de_1').createSync(recursive: true);

    await store.deletePack('cs_de_1');

    expect(store.packs.map((p) => p.id), [LanguagePack.bundledId]);
    expect(store.active.id, LanguagePack.bundledId);
    expect(File('${tempRoot.path}/packs/cs_de_1.json').existsSync(), isFalse);
    expect(store.progressFileFor('cs_de_1').existsSync(), isFalse);
    expect(store.attemptsDirFor('cs_de_1').existsSync(), isFalse);
  });

  test('the bundled pack cannot be deleted', () async {
    await store.deletePack(LanguagePack.bundledId);
    expect(store.packs, hasLength(1));
  });

  test('updateWord persists the fix for a generated pack', () async {
    await store.addPack(germanPack('cs_de_1'));
    await store.updateWord('cs_de_1', 'dog', source: 'pejsek', target: 'Hund');

    final onDisk = LanguagePack.fromJson(jsonDecode(
            File('${tempRoot.path}/packs/cs_de_1.json').readAsStringSync())
        as Map<String, dynamic>);
    expect(onDisk.vocabulary.orderedWords.single.cz, 'pejsek');
    expect(onDisk.vocabulary.orderedWords.single.en, 'Hund');
    expect(store.active.vocabulary.orderedWords.single.en, 'Hund');
  });

  test('legacy single-pack data migrates under the bundled pack id', () async {
    File('${tempRoot.path}/progress.json').writeAsStringSync('{"version":2}');
    Directory('${tempRoot.path}/attempts').createSync();
    File('${tempRoot.path}/attempts/a.wav').writeAsBytesSync([1]);
    Directory('${tempRoot.path}/recordings').createSync();
    File('${tempRoot.path}/recordings/dog_cz.m4a').writeAsBytesSync([1]);

    final migrated = await makeStore();
    migrated.migrateAndLoad();

    expect(File('${tempRoot.path}/progress.json').existsSync(), isFalse);
    expect(migrated.progressFileFor(LanguagePack.bundledId).existsSync(),
        isTrue);
    expect(
        File('${migrated.attemptsDirFor(LanguagePack.bundledId).path}/a.wav')
            .existsSync(),
        isTrue);
    expect(
        File('${migrated.recordingsDirFor(LanguagePack.bundledId).path}/dog_cz.m4a')
            .existsSync(),
        isTrue);
  });
}
