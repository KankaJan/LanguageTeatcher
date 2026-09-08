import 'package:flutter/material.dart';

import '../logic/progress_stats.dart';
import '../models/progress.dart';
import '../models/vocabulary.dart';
import '../services/progress_store.dart';

/// Parent-mode drill-down for one category: every word with how many times
/// the child said it correctly, wrongly, and how many answers still await a
/// grade.
class CategoryDetailScreen extends StatelessWidget {
  const CategoryDetailScreen({
    super.key,
    required this.vocabulary,
    required this.category,
    required this.progress,
  });

  final Vocabulary vocabulary;
  final WordCategory category;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${category.emoji} ${category.cz}')),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final counts = attemptCountsByWord(progress.attempts);
          final states = progress.wordStates;
          final words = vocabulary.orderedWords
              .where((w) => w.categoryId == category.id)
              .toList();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              final count = counts[word.id] ?? const WordAttemptCounts();
              final state = states[word.id];
              return ListTile(
                leading: Text(vocabulary.emojiFor(word),
                    style: const TextStyle(fontSize: 24)),
                title: Text('${word.cz} — ${word.en}'),
                subtitle: Text(count.total == 0
                    ? 'zatím nezkoušeno'
                    : [
                        'správně ${count.correct}×',
                        'špatně ${count.wrong}×',
                        if (count.pending > 0)
                          'čeká na ohodnocení ${count.pending}×',
                      ].join(' · ')),
                trailing: _StateChip(state: state),
              );
            },
          );
        },
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final WordProgress? state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state?.state) {
      WordState.known => ('naučené', const Color(0xFF66BB6A)),
      WordState.learning => ('procvičuje se', const Color(0xFF4A90D9)),
      null => ('nové', Colors.brown),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color.withValues(alpha: 0.9))),
    );
  }
}
