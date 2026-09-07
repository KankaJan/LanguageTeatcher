import '../models/vocabulary.dart';

/// What a single step of the lesson does with its word. M1 only presents;
/// production (child speaks, app scores) arrives with milestone M3.
enum PassType { presentation }

/// One step of a lesson: show [word], speak Czech then English.
class LessonPass {
  const LessonPass({required this.word, required this.type});

  final Word word;
  final PassType type;
}

/// A day's lesson: [words] are the vocabulary items covered, [passes] is the
/// exact sequence of steps the child goes through.
class Lesson {
  const Lesson({required this.words, required this.passes});

  final List<Word> words;
  final List<LessonPass> passes;
}

/// Builds lessons from the curriculum order.
///
/// M1 behaviour: the lesson is the next [wordsPerLesson] words after
/// [wordsCompleted], cycling back to the start once the whole vocabulary has
/// been covered. Each word appears [repetitionsPerWord] times, interleaved
/// Duolingo-style (pass p is the word list rotated by p) so the same word is
/// never drilled back-to-back. The adaptive selector (failed-word carryover,
/// review scheduling) replaces the plain counter in milestone M5.
Lesson buildLesson({
  required List<Word> orderedWords,
  required int wordsCompleted,
  required int wordsPerLesson,
  required int repetitionsPerWord,
}) {
  assert(orderedWords.isNotEmpty);
  assert(wordsPerLesson > 0);
  assert(repetitionsPerWord > 0);

  final total = orderedWords.length;
  final count = wordsPerLesson > total ? total : wordsPerLesson;
  final start = wordsCompleted % total;
  final words = [
    for (var i = 0; i < count; i++) orderedWords[(start + i) % total],
  ];

  final passes = <LessonPass>[
    for (var pass = 0; pass < repetitionsPerWord; pass++)
      for (var i = 0; i < words.length; i++)
        LessonPass(
          word: words[(i + pass) % words.length],
          type: PassType.presentation,
        ),
  ];

  return Lesson(words: words, passes: passes);
}
