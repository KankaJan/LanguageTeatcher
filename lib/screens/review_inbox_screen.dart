import 'package:flutter/material.dart';

import '../models/vocabulary.dart';
import '../services/app_prefs.dart';
import '../services/progress_store.dart';
import '../services/word_audio.dart';

/// Parent-mode inbox: the child's recorded answers waiting for a ✓/✗ grade.
/// Grading feeds the adaptive engine — a failed word returns in the next
/// lesson, a passed one rests until its review comes due.
class ReviewInboxScreen extends StatefulWidget {
  const ReviewInboxScreen({
    super.key,
    required this.vocabulary,
    required this.progress,
    required this.prefs,
  });

  final Vocabulary vocabulary;
  final ProgressStore progress;
  final AppPrefs prefs;

  @override
  State<ReviewInboxScreen> createState() => _ReviewInboxScreenState();
}

class _ReviewInboxScreenState extends State<ReviewInboxScreen> {
  final JustAudioFilePlayer _player = JustAudioFilePlayer();
  late final Map<String, Word> _wordsById = {
    for (final w in widget.vocabulary.orderedWords) w.id: w,
  };
  int? _playingAttemptId;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play(int attemptId, String path) async {
    setState(() => _playingAttemptId = attemptId);
    try {
      await _player.play(path);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nahrávku se nepodařilo přehrát.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _playingAttemptId = null);
    }
  }

  Future<void> _grade(int attemptId, bool correct) async {
    await widget.progress.gradeAttempt(
      attemptId,
      correct: correct,
      reviewInterval: widget.prefs.reviewIntervalLessons,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kontrola výslovnosti')),
      body: ListenableBuilder(
        listenable: widget.progress,
        builder: (context, _) {
          final pending = widget.progress.pendingAttempts
              .where((a) => _wordsById.containsKey(a.wordId))
              .toList();
          if (pending.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 64)),
                  const SizedBox(height: 12),
                  Text('Nic ke kontrole',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  const Text('Všechny odpovědi jsou ohodnocené.'),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Přehrajte si odpověď a ohodnoťte, zda dítě řeklo anglické '
                  'slovíčko správně. Špatně ohodnocená slovíčka se vrátí '
                  'hned v příští lekci.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final attempt in pending)
                _AttemptTile(
                  word: _wordsById[attempt.wordId]!,
                  vocabulary: widget.vocabulary,
                  lesson: attempt.lesson,
                  unsureTranscript: attempt.wasUnsure ? attempt.transcript : null,
                  isPlaying: _playingAttemptId == attempt.id,
                  onPlay: () => _play(attempt.id, attempt.filePath),
                  onGrade: (correct) => _grade(attempt.id, correct),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AttemptTile extends StatelessWidget {
  const _AttemptTile({
    required this.word,
    required this.vocabulary,
    required this.lesson,
    required this.unsureTranscript,
    required this.isPlaying,
    required this.onPlay,
    required this.onGrade,
  });

  final Word word;
  final Vocabulary vocabulary;
  final int lesson;

  /// The recognizer's uncertain guess, when it ran but couldn't decide.
  final String? unsureTranscript;

  final bool isPlaying;
  final VoidCallback onPlay;
  final ValueChanged<bool> onGrade;

  @override
  Widget build(BuildContext context) {
    final unsure = unsureTranscript;
    return ListTile(
      leading: Text(vocabulary.emojiFor(word),
          style: const TextStyle(fontSize: 24)),
      title: Text('${word.cz} — ${word.en}'),
      subtitle: Text(unsure == null
          ? 'Lekce $lesson'
          : unsure.isEmpty || unsure == '[unk]'
              ? 'Lekce $lesson · rozpoznávání si není jisté (ticho?)'
              : 'Lekce $lesson · rozpoznávání si není jisté, slyšelo „$unsure“'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.graphic_eq : Icons.play_circle,
                size: 32),
            tooltip: 'Přehrát odpověď',
            onPressed: isPlaying ? null : onPlay,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, size: 32, color: Colors.green),
            tooltip: 'Správně',
            onPressed: () => onGrade(true),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, size: 32, color: Colors.redAccent),
            tooltip: 'Špatně',
            onPressed: () => onGrade(false),
          ),
        ],
      ),
    );
  }
}
