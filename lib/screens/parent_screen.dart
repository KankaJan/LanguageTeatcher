import 'package:flutter/material.dart';

import '../models/vocabulary.dart';
import '../services/app_prefs.dart';

/// Parent mode: progress overview and lesson settings. This is the one place
/// where on-screen text is allowed — it is written in Czech for the parent.
class ParentScreen extends StatefulWidget {
  const ParentScreen({
    super.key,
    required this.vocabulary,
    required this.prefs,
  });

  final Vocabulary vocabulary;
  final AppPrefs prefs;

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  late int _wordsPerLesson = widget.prefs.wordsPerLesson;
  late int _repetitionsPerWord = widget.prefs.repetitionsPerWord;

  @override
  Widget build(BuildContext context) {
    final vocabulary = widget.vocabulary;
    final prefs = widget.prefs;
    final total = vocabulary.orderedWords.length;
    final completed = prefs.wordsCompleted;
    final position = completed % total;
    final nextWord = vocabulary.orderedWords[position];
    final nextCategory = vocabulary.categoryOf(nextWord);

    return Scaffold(
      appBar: AppBar(title: const Text('Rodičovská sekce')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pokrok',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Text('Dokončených lekcí: ${prefs.lessonsCompleted}'),
                  const SizedBox(height: 4),
                  Text('Probraných slovíček: $completed'
                      '${completed > total ? ' (slovník už proběhl celý)' : ' z $total'}'),
                  const SizedBox(height: 4),
                  Text(
                      'Aktuální téma: ${nextCategory.emoji} ${nextCategory.cz}'),
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
                      prefs.setWordsPerLesson(value.round());
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
                      prefs.setRepetitionsPerWord(value.round());
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hlas', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  const Text(
                    'Slovíčka zatím čte hlas telefonu (čeština a angličtina). '
                    'Zkontrolujte v nastavení telefonu, že jsou oba hlasy '
                    'nainstalované — obvykle v sekci „Převod textu na řeč“. '
                    'Nahrávání slovíček vlastním hlasem přibude v další verzi.',
                  ),
                ],
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
                      'Počítadlo lekcí a probraných slovíček se vynuluje.'),
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
                await widget.prefs.resetProgress();
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
