import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../models/vocabulary.dart';
import '../services/app_prefs.dart';
import '../services/model_manager.dart';
import '../services/progress_store.dart';
import '../services/recording_store.dart';
import 'progress_dashboard_screen.dart';
import 'recording_studio_screen.dart';
import 'review_inbox_screen.dart';

/// Parent mode: progress overview, pronunciation review inbox, recording
/// studio, and lesson settings. This is the one place where on-screen text is
/// allowed — it is written in Czech for the parent.
class ParentScreen extends StatefulWidget {
  const ParentScreen({
    super.key,
    required this.vocabulary,
    required this.prefs,
    required this.recordings,
    required this.progress,
    required this.models,
  });

  final Vocabulary vocabulary;
  final AppPrefs prefs;
  final RecordingStore recordings;
  final ProgressStore progress;
  final ModelManager models;

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late int _wordsPerLesson = widget.prefs.wordsPerLesson;
  late int _repetitionsPerWord = widget.prefs.repetitionsPerWord;
  late int _reviewInterval = widget.prefs.reviewIntervalLessons;

  @override
  Widget build(BuildContext context) {
    final vocabulary = widget.vocabulary;

    return Scaffold(
      appBar: AppBar(title: const Text('Rodičovská sekce')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: widget.progress,
                builder: (context, _) {
                  final states = widget.progress.wordStates;
                  final total = vocabulary.orderedWords.length;
                  final learning = states.values
                      .where((p) => p.state == WordState.learning)
                      .length;
                  final known = states.values
                      .where((p) => p.state == WordState.known)
                      .length;
                  final firstNew = vocabulary.orderedWords
                      .where((w) => !states.containsKey(w.id))
                      .firstOrNull;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pokrok',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text('Dokončených lekcí: '
                          '${widget.progress.lessonsCompleted}'),
                      const SizedBox(height: 4),
                      Text('Probraných slovíček: ${states.length} z $total '
                          '(naučených $known, procvičuje se $learning)'),
                      const SizedBox(height: 4),
                      Text(firstNew == null
                          ? 'Celý slovník už byl probrán 🎉'
                          : 'Aktuální téma: '
                              '${vocabulary.categoryOf(firstNew).emoji} '
                              '${vocabulary.categoryOf(firstNew).cz}'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.insights),
                        label: const Text('Zobrazit podrobnosti'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProgressDashboardScreen(
                                vocabulary: vocabulary,
                                progress: widget.progress,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: widget.progress,
                builder: (context, _) {
                  final pending = widget.progress.pendingAttempts.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kontrola výslovnosti',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text(pending == 0
                          ? 'Žádné odpovědi nečekají na ohodnocení.'
                          : 'Na ohodnocení čeká $pending '
                              '${pending == 1 ? 'odpověď' : pending < 5 ? 'odpovědi' : 'odpovědí'} '
                              'z lekcí. Špatně ohodnocená slovíčka se vrátí '
                              'v příští lekci.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.rule),
                        label: const Text('Otevřít kontrolu'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReviewInboxScreen(
                                vocabulary: vocabulary,
                                progress: widget.progress,
                                prefs: widget.prefs,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
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
                  Text('Nastavení lekce',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Slovíček v jedné lekci: $_wordsPerLesson'),
                  Slider(
                    value: _wordsPerLesson.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    label: '$_wordsPerLesson',
                    onChanged: (value) {
                      setState(() => _wordsPerLesson = value.round());
                      widget.prefs.setWordsPerLesson(value.round());
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Kolikrát se každé slovíčko zopakuje: '
                      '$_repetitionsPerWord'),
                  Slider(
                    value: _repetitionsPerWord.toDouble(),
                    min: 2,
                    max: 5,
                    divisions: 3,
                    label: '$_repetitionsPerWord',
                    onChanged: (value) {
                      setState(() => _repetitionsPerWord = value.round());
                      widget.prefs.setRepetitionsPerWord(value.round());
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Naučená slovíčka se vrací po: '
                      '$_reviewInterval lekcích'),
                  Slider(
                    value: _reviewInterval.toDouble(),
                    min: 3,
                    max: 10,
                    divisions: 7,
                    label: '$_reviewInterval',
                    onChanged: (value) {
                      setState(() => _reviewInterval = value.round());
                      widget.prefs.setReviewIntervalLessons(value.round());
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: widget.recordings,
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Váš hlas',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text(
                      'Nahráno ${widget.recordings.recordedCount} nahrávek. '
                      'Slovíčka s vaší nahrávkou zní v lekci vaším hlasem; '
                      'ostatní čte hlas telefonu (zkontrolujte, že máte v '
                      'telefonu nainstalovaný český i anglický hlas — sekce '
                      '„Převod textu na řeč“).',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.mic),
                      label: const Text('Otevřít nahrávací studio'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RecordingStudioScreen(
                              vocabulary: vocabulary,
                              store: widget.recordings,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListenableBuilder(
                listenable: widget.models,
                builder: (context, _) {
                  final models = widget.models;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rozpoznávání řeči',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      switch (models.status) {
                        ModelStatus.ready => const Text(
                            'Model je nainstalovaný. Jasné odpovědi se '
                            'hodnotí samy; nejisté vám dál chodí do '
                            'kontroly výslovnosti a vaše hodnocení má vždy '
                            'přednost.'),
                        ModelStatus.downloading => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Stahuji model…'),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(value: models.progress),
                            ],
                          ),
                        ModelStatus.absent => Text(
                            'Bez modelu hodnotíte všechny odpovědi ručně. '
                            'Stažením modelu '
                            '(~${ModelManager.approximateSizeMb} MB, '
                            'jednorázově) se budou jasné odpovědi hodnotit '
                            'automaticky přímo v telefonu — lekce pak '
                            'nepotřebují internet.'
                            '${models.error == null ? '' : '\n\nStahování se nepodařilo: ${models.error}'}'),
                      },
                      const SizedBox(height: 12),
                      switch (models.status) {
                        ModelStatus.ready => OutlinedButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Odebrat model'),
                            onPressed: models.delete,
                          ),
                        ModelStatus.downloading => const SizedBox.shrink(),
                        ModelStatus.absent => FilledButton.icon(
                            icon: const Icon(Icons.download),
                            label: Text('Stáhnout model '
                                '(~${ModelManager.approximateSizeMb} MB)'),
                            onPressed: models.download,
                          ),
                      },
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Začít od začátku (smazat pokrok)'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Smazat pokrok?'),
                  content: const Text(
                      'Smaže se pokrok učení i nahrané odpovědi dítěte. '
                      'Vaše nahrávky slovíček zůstanou.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Zrušit'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Smazat'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await widget.progress.reset();
              }
            },
          ),
        ],
      ),
    );
  }
}
