import 'dart:convert';

/// A thematic word category (animals, family, ...) from content/vocabulary.json.
class WordCategory {
  const WordCategory({
    required this.id,
    required this.order,
    required this.en,
    required this.cz,
    required this.emoji,
    required this.suggestedLessons,
  });

  final String id;
  final int order;
  final String en;
  final String cz;
  final String emoji;
  final String suggestedLessons;

  factory WordCategory.fromJson(Map<String, dynamic> json) => WordCategory(
        id: json['id'] as String,
        order: json['order'] as int,
        en: json['en'] as String,
        cz: json['cz'] as String,
        emoji: json['emoji'] as String,
        suggestedLessons: json['suggested_lessons'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'order': order,
        'en': en,
        'cz': cz,
        'emoji': emoji,
        'suggested_lessons': suggestedLessons,
      };
}

/// One teachable word pair. [emoji] is the placeholder picture; when null the
/// category emoji is used instead.
class Word {
  const Word({
    required this.id,
    required this.en,
    required this.cz,
    required this.categoryId,
    required this.order,
    this.emoji,
  });

  final String id;
  final String en;
  final String cz;
  final String categoryId;
  final int order;
  final String? emoji;

  factory Word.fromJson(Map<String, dynamic> json) => Word(
        id: json['id'] as String,
        en: json['en'] as String,
        cz: json['cz'] as String,
        categoryId: json['category'] as String,
        order: json['order'] as int,
        emoji: json['emoji'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'en': en,
        'cz': cz,
        'category': categoryId,
        'order': order,
        'emoji': emoji,
      };

  Word copyWith({String? en, String? cz}) => Word(
        id: id,
        en: en ?? this.en,
        cz: cz ?? this.cz,
        categoryId: categoryId,
        order: order,
        emoji: emoji,
      );
}

/// The parsed vocabulary dataset: categories plus words in curriculum order
/// (category order, then word order within the category).
class Vocabulary {
  Vocabulary({required this.categories, required List<Word> words})
      : orderedWords = _sort(categories, words),
        _categoriesById = {for (final c in categories) c.id: c};

  final List<WordCategory> categories;

  /// All words in the order the curriculum introduces them.
  final List<Word> orderedWords;

  final Map<String, WordCategory> _categoriesById;

  WordCategory categoryOf(Word word) => _categoriesById[word.categoryId]!;

  /// Picture shown for [word]: its own emoji, or its category's as fallback.
  String emojiFor(Word word) => word.emoji ?? categoryOf(word).emoji;

  static List<Word> _sort(List<WordCategory> categories, List<Word> words) {
    final categoryOrder = {for (final c in categories) c.id: c.order};
    final sorted = [...words]..sort((a, b) {
        final byCategory =
            categoryOrder[a.categoryId]!.compareTo(categoryOrder[b.categoryId]!);
        return byCategory != 0 ? byCategory : a.order.compareTo(b.order);
      });
    return List.unmodifiable(sorted);
  }

  factory Vocabulary.fromJsonString(String jsonString) {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    final categories = (data['categories'] as List)
        .map((c) => WordCategory.fromJson(c as Map<String, dynamic>))
        .toList();
    final words = (data['words'] as List)
        .map((w) => Word.fromJson(w as Map<String, dynamic>))
        .toList();
    final categoryIds = categories.map((c) => c.id).toSet();
    for (final word in words) {
      if (!categoryIds.contains(word.categoryId)) {
        throw FormatException(
            'Word "${word.id}" references unknown category "${word.categoryId}"');
      }
    }
    return Vocabulary(categories: categories, words: words);
  }

  Map<String, dynamic> toJson() => {
        'categories': categories.map((c) => c.toJson()).toList(),
        'words': orderedWords.map((w) => w.toJson()).toList(),
      };
}
