import '../models/progress.dart';
import '../models/vocabulary.dart';

/// What a single step of the lesson does with its word.
enum PassType {
  /// Show the picture, speak Czech then English, invite the child to repeat.
  presentation,

  /// Speak Czech and prompt the child to say the English word; the answer is
  /// recorded and later scored.
  production,
}

/// One step of a lesson.
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

/// Picks the words for the next lesson, in priority order:
///
/// 1. words in `learning` state whose due lesson has arrived (failed or
///    demoted words — the carryover the whole app is about),
/// 2. `known` words due for their spaced review,
/// 3. new words in curriculum order.
///
/// When new words remain, at least one slot is kept for them so a bad week
/// never turns lessons into pure remediation. If everything is known and
/// nothing is due (end of curriculum), the words closest to their review date
/// are used so a lesson always exists.
List<Word> selectWords({
  required List<Word> orderedWords,
  required Map<String, WordProgress> progress,
  required int nextLesson,
  required int wordsPerLesson,
}) {
  final n =
      wordsPerLesson > orderedWords.length ? orderedWords.length : wordsPerLesson;

  bool due(Word w, WordState state) {
    final p = progress[w.id];
    return p != null && p.state == state && p.dueLesson <= nextLesson;
  }

  final dueLearning = orderedWords.where((w) => due(w, WordState.learning));
  final dueKnown = orderedWords.where((w) => due(w, WordState.known));
  final newWords = orderedWords.where((w) => !progress.containsKey(w.id));

  final reviewCap = newWords.isNotEmpty && n > 1 ? n - 1 : n;

  final selected = <Word>[
    ...dueLearning.take(reviewCap),
  ];
  selected.addAll(dueKnown.take(reviewCap - selected.length));
  selected.addAll(newWords.take(n - selected.length));

  if (selected.length < n) {
    // More due words than the review cap allowed, or nothing new left.
    final leftovers = [...dueLearning, ...dueKnown]
        .where((w) => !selected.contains(w));
    selected.addAll(leftovers.take(n - selected.length));
  }

  if (selected.isEmpty) {
    // Whole curriculum known and nothing due: review what comes due soonest.
    final byDue = [...orderedWords]..sort((a, b) =>
        (progress[a.id]?.dueLesson ?? 0).compareTo(progress[b.id]?.dueLesson ?? 0));
    selected.addAll(byDue.take(n));
  }

  return selected;
}

/// Builds the pass sequence for the selected [words]: each word appears
/// [repetitionsPerWord] times, interleaved Duolingo-style (pass block p is
/// the word list rotated by p) so the same word is never drilled
/// back-to-back. The first block presents each word; every later block is a
/// production pass where the child answers.
Lesson buildLesson({
  required List<Word> words,
  required int repetitionsPerWord,
}) {
  assert(repetitionsPerWord > 0);

  final passes = <LessonPass>[
    for (var pass = 0; pass < repetitionsPerWord; pass++)
      for (var i = 0; i < words.length; i++)
        LessonPass(
          word: words[(i + pass) % words.length],
          type: pass == 0 ? PassType.presentation : PassType.production,
        ),
  ];

  return Lesson(words: List.unmodifiable(words), passes: passes);
}
