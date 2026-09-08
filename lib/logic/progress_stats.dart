import '../models/progress.dart';
import '../models/vocabulary.dart';

/// Per-category tallies for the dashboard's segmented bars.
class CategoryStats {
  const CategoryStats({
    required this.category,
    required this.known,
    required this.learning,
    required this.total,
  });

  final WordCategory category;
  final int known;
  final int learning;
  final int total;

  int get remaining => total - known - learning;
}

/// A word the child keeps missing, with the score that put it there.
class StrugglingWord {
  const StrugglingWord({
    required this.word,
    required this.lastAvgScore,
    required this.dueLesson,
  });

  final Word word;
  final double? lastAvgScore;
  final int dueLesson;
}

/// Read-only snapshot the parent dashboard renders. Pure computation over the
/// progress store's state, so it is trivially unit-testable.
class ProgressStats {
  const ProgressStats({
    required this.lessonsCompleted,
    required this.totalWords,
    required this.known,
    required this.learning,
    required this.categories,
    required this.struggling,
    required this.gradedAttempts,
    required this.pendingAttempts,
  });

  final int lessonsCompleted;
  final int totalWords;
  final int known;
  final int learning;
  final List<CategoryStats> categories;
  final List<StrugglingWord> struggling;
  final int gradedAttempts;
  final int pendingAttempts;

  int get seen => known + learning;
  int get unseen => totalWords - seen;

  static const strugglingCap = 10;

  factory ProgressStats.compute({
    required Vocabulary vocabulary,
    required Map<String, WordProgress> wordStates,
    required List<Attempt> attempts,
    required int lessonsCompleted,
  }) {
    var known = 0;
    var learning = 0;
    for (final progress in wordStates.values) {
      if (progress.state == WordState.known) {
        known++;
      } else {
        learning++;
      }
    }

    final categories = <CategoryStats>[];
    for (final category in vocabulary.categories) {
      final words = vocabulary.orderedWords
          .where((w) => w.categoryId == category.id)
          .toList();
      var categoryKnown = 0;
      var categoryLearning = 0;
      for (final word in words) {
        final progress = wordStates[word.id];
        if (progress == null) continue;
        if (progress.state == WordState.known) {
          categoryKnown++;
        } else {
          categoryLearning++;
        }
      }
      categories.add(CategoryStats(
        category: category,
        known: categoryKnown,
        learning: categoryLearning,
        total: words.length,
      ));
    }

    // Lowest score first; never-scored (null) last; curriculum order breaks
    // ties because the source list is iterated in order and the sort is stable.
    final struggling = <StrugglingWord>[
      for (final word in vocabulary.orderedWords)
        if (wordStates[word.id]?.state == WordState.learning)
          StrugglingWord(
            word: word,
            lastAvgScore: wordStates[word.id]!.lastAvgScore,
            dueLesson: wordStates[word.id]!.dueLesson,
          ),
    ]..sort((a, b) {
        final sa = a.lastAvgScore;
        final sb = b.lastAvgScore;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa.compareTo(sb);
      });

    final graded = attempts.where((a) => a.effectiveScore != null).length;

    return ProgressStats(
      lessonsCompleted: lessonsCompleted,
      totalWords: vocabulary.orderedWords.length,
      known: known,
      learning: learning,
      categories: categories,
      struggling: struggling.take(strugglingCap).toList(),
      gradedAttempts: graded,
      pendingAttempts: attempts.length - graded,
    );
  }
}
