import '../models/language_pack.dart';
import '../models/vocabulary.dart';
import '../services/translator.dart';

/// Generates a new language pack by machine-translating the base curriculum.
///
/// The base vocabulary's English side is the pivot (machine translation from
/// English is the strongest direction). When the chosen source/target IS
/// Czech or English, the curated text is reused verbatim — no translation,
/// no quality loss. [onProgress] reports translated words out of the total;
/// model downloads happen inside the translators' prepare() before the
/// first progress tick.
Future<LanguagePack> generatePack({
  required Vocabulary base,
  required String sourceCode,
  required String targetCode,
  required TranslatorFactory translatorFactory,
  void Function(int done, int total)? onProgress,
}) async {
  assert(sourceCode != targetCode);

  WordTranslator? sourceTranslator;
  WordTranslator? targetTranslator;
  if (sourceCode != 'cs' && sourceCode != 'en') {
    sourceTranslator = translatorFactory('en', sourceCode);
  }
  if (targetCode != 'cs' && targetCode != 'en') {
    targetTranslator = translatorFactory('en', targetCode);
  }

  String curated(Word word, String code) => code == 'cs' ? word.cz : word.en;

  try {
    await sourceTranslator?.prepare();
    await targetTranslator?.prepare();

    final total = base.orderedWords.length;
    final words = <Word>[];
    var done = 0;
    for (final word in base.orderedWords) {
      final source = sourceTranslator != null
          ? await sourceTranslator.translate(word.en)
          : curated(word, sourceCode);
      final target = targetTranslator != null
          ? await targetTranslator.translate(word.en)
          : curated(word, targetCode);
      words.add(word.copyWith(cz: source, en: target));
      done++;
      onProgress?.call(done, total);
    }

    return LanguagePack(
      id: '${sourceCode}_${targetCode}_'
          '${DateTime.now().millisecondsSinceEpoch}',
      sourceCode: sourceCode,
      targetCode: targetCode,
      generated: true,
      vocabulary: Vocabulary(categories: base.categories, words: words),
    );
  } finally {
    await sourceTranslator?.dispose();
    await targetTranslator?.dispose();
  }
}
