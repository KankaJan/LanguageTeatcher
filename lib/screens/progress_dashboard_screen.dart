import 'package:flutter/material.dart';

import '../logic/progress_stats.dart';
import '../models/vocabulary.dart';
import '../services/progress_store.dart';
import 'category_detail_screen.dart';

/// Parent-mode dashboard: how the child is doing, per category and per word.
/// Palette (validated for CVD separation): green = known, blue = practicing,
/// neutral track = not seen yet. Counts are always shown as text and segments
/// keep a fixed order, so meaning never rides on color alone.
class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({
    super.key,
    required this.vocabulary,
    required this.progress,
  });

  static const knownColor = Color(0xFF66BB6A);
  static const learningColor = Color(0xFF4A90D9);

  final Vocabulary vocabulary;
  final ProgressStore progress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Přehled pokroku')),
      body: ListenableBuilder(
        listenable: progress,
        builder: (context, _) {
          final stats = ProgressStats.compute(
            vocabulary: vocabulary,
            wordStates: progress.wordStates,
            attempts: progress.attempts,
            lessonsCompleted: progress.lessonsCompleted,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  _StatTile(value: '${stats.lessonsCompleted}', label: 'lekcí'),
                  const SizedBox(width: 12),
                  _StatTile(
                      value: '${stats.known}',
                      label: 'naučených',
                      color: knownColor),
                  const SizedBox(width: 12),
                  _StatTile(
                      value: '${stats.learning}',
                      label: 'v procvičování',
                      color: learningColor),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Podle témat',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Wrap(
                        spacing: 16,
                        children: [
                          _LegendDot(color: knownColor, label: 'naučená'),
                          _LegendDot(
                              color: learningColor, label: 'procvičuje se'),
                          _LegendDot(color: null, label: 'zbývá'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Klepnutím na téma zobrazíte jednotlivá slovíčka '
                        'a jejich úspěšnost.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      for (final c in stats.categories)
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => CategoryDetailScreen(
                                  vocabulary: vocabulary,
                                  category: c.category,
                                  progress: progress,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(c.category.emoji,
                                        style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(c.category.cz)),
                                    Text(
                                      '${c.known + c.learning} z ${c.total}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right,
                                        size: 18,
                                        color: Colors.brown
                                            .withValues(alpha: 0.4)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                _SegmentedBar(
                                    known: c.known,
                                    learning: c.learning,
                                    total: c.total),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Slovíčka, která zlobí',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (stats.struggling.isEmpty)
                        const Text('Žádná — všechno, co se učí, zatím jde. 🎉')
                      else
                        for (final s in stats.struggling)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Text(vocabulary.emojiFor(s.word),
                                style: const TextStyle(fontSize: 22)),
                            title: Text('${s.word.cz} — ${s.word.en}'),
                            subtitle: Text(s.lastAvgScore == null
                                ? 'čeká na ohodnocení · vrátí se v lekci ${s.dueLesson}'
                                : 'úspěšnost ${(s.lastAvgScore! * 100).round()} % '
                                    '· vrátí se v lekci ${s.dueLesson}'),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Ohodnocených odpovědí: ${stats.gradedAttempts} · '
                  'čeká na kontrolu: ${stats.pendingAttempts} · '
                  'slovíček celkem: ${stats.totalWords}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label, this.color});

  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (color != null) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(value,
                      style: Theme.of(context).textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color? color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color ?? Colors.brown.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// Thin horizontal bar: known + practicing fills on a neutral track, fixed
/// segment order, 2px gaps between fills, rounded ends.
class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.known,
    required this.learning,
    required this.total,
  });

  final int known;
  final int learning;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (known > 0)
              Expanded(
                flex: known,
                child: Container(
                    color: ProgressDashboardScreen.knownColor,
                    margin: EdgeInsets.only(right: learning > 0 ? 2 : 0)),
              ),
            if (learning > 0)
              Expanded(
                flex: learning,
                child:
                    Container(color: ProgressDashboardScreen.learningColor),
              ),
            if (total - known - learning > 0)
              Expanded(
                flex: total - known - learning,
                child: Container(
                  color: Colors.brown.withValues(alpha: 0.10),
                  margin:
                      EdgeInsets.only(left: known + learning > 0 ? 2 : 0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
