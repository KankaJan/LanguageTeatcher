import 'dart:convert';

import 'vocabulary.dart';

/// One teachable language pair. The pack reuses the base curriculum's
/// structure (word ids, categories, order, pictures); only the two text
/// sides differ. By convention the [Word.cz] field holds the *source*
/// (child's) language text and [Word.en] the *target* language text —
/// for the bundled Czech→English pack that is literally true, for
/// generated packs it is the mapping.
class LanguagePack {
  const LanguagePack({
    required this.id,
    required this.sourceCode,
    required this.targetCode,
    required this.generated,
    required this.vocabulary,
  });

  final String id;
  final String sourceCode;
  final String targetCode;

  /// Machine-translated pack (editable/deletable) vs the curated bundled one.
  final bool generated;

  final Vocabulary vocabulary;

  static const bundledId = 'cs_en';

  /// The curated Czech→English pack from content/vocabulary.json.
  factory LanguagePack.bundled(Vocabulary base) => LanguagePack(
        id: bundledId,
        sourceCode: 'cs',
        targetCode: 'en',
        generated: false,
        vocabulary: base,
      );

  Map<String, dynamic> toJson() => {
        'version': 1,
        'id': id,
        'source': sourceCode,
        'target': targetCode,
        'vocabulary': vocabulary.toJson(),
      };

  factory LanguagePack.fromJson(Map<String, dynamic> json) => LanguagePack(
        id: json['id'] as String,
        sourceCode: json['source'] as String,
        targetCode: json['target'] as String,
        generated: true,
        vocabulary: Vocabulary.fromJsonString(
            jsonEncode(json['vocabulary'] as Map<String, dynamic>)),
      );

  /// A copy with one word's texts replaced (the parent's fix for an
  /// imperfect machine translation).
  LanguagePack withWord(String wordId, {String? source, String? target}) {
    final words = [
      for (final w in vocabulary.orderedWords)
        w.id == wordId ? w.copyWith(cz: source, en: target) : w,
    ];
    return LanguagePack(
      id: id,
      sourceCode: sourceCode,
      targetCode: targetCode,
      generated: generated,
      vocabulary:
          Vocabulary(categories: vocabulary.categories, words: words),
    );
  }
}
