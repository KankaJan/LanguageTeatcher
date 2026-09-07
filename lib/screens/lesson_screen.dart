import 'package:flutter/material.dart';

import '../logic/lesson_builder.dart';
import '../models/vocabulary.dart';
import '../services/app_prefs.dart';
import '../services/tts_service.dart';
import '../widgets/emoji_card.dart';
import 'celebration_screen.dart';

/// The child-facing lesson: for each pass the picture fills the screen, the
/// word is spoken in Czech, then in English, then a short "now you say it"
/// pause with a pulsing hint. Tapping anywhere skips ahead to the next pass.
/// No text is ever shown.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.vocabulary,
    required this.prefs,
  });

  final Vocabulary vocabulary;
  final AppPrefs prefs;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  static const _cardColors = [
    Color(0xFFFFF3D6),
    Color(0xFFDDF2E4),
    Color(0xFFE1ECFB),
    Color(0xFFFCE4EC),
    Color(0xFFF3E8FD),
  ];

  late final Lesson _lesson;
  final TtsService _tts = TtsService();

  int _passIndex = 0;
  bool _repeatHintVisible = false;

  /// Incremented on every skip/advance so stale awaits stop acting.
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    _lesson = buildLesson(
      orderedWords: widget.vocabulary.orderedWords,
      wordsCompleted: widget.prefs.wordsCompleted,
      wordsPerLesson: widget.prefs.wordsPerLesson,
      repetitionsPerWord: widget.prefs.repetitionsPerWord,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPass());
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _runPass() async {
    final run = _runId;
    final word = _lesson.passes[_passIndex].word;

    Future<bool> interrupted(Duration pause) async {
      await Future<void>.delayed(pause);
      return !mounted || _runId != run;
    }

    if (await interrupted(const Duration(milliseconds: 700))) return;
    await _tts.speakCzech(word.cz);
    if (await interrupted(const Duration(milliseconds: 900))) return;
    await _tts.speakEnglish(word.en);
    if (!mounted || _runId != run) return;

    setState(() => _repeatHintVisible = true);
    if (await interrupted(const Duration(milliseconds: 2600))) return;
    _advance();
  }

  void _advance() {
    if (!mounted) return;
    _runId++;
    _tts.stop();
    if (_passIndex + 1 >= _lesson.passes.length) {
      _finishLesson();
      return;
    }
    setState(() {
      _passIndex++;
      _repeatHintVisible = false;
    });
    _runPass();
  }

  Future<void> _finishLesson() async {
    await widget.prefs.recordLessonCompleted(_lesson.words.length);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CelebrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final word = _lesson.passes[_passIndex].word;
    final emoji = widget.vocabulary.emojiFor(word);
    final progress = (_passIndex + 1) / _lesson.passes.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advance,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    // Exit is long-press only, so the child can't leave by
                    // tapping around.
                    GestureDetector(
                      onLongPress: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.close_rounded,
                        size: 28,
                        color: Colors.brown.withValues(alpha: 0.25),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          backgroundColor: Colors.brown.withValues(alpha: 0.1),
                          color: const Color(0xFF66BB6A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: EmojiCard(
                      key: ValueKey(_passIndex),
                      emoji: emoji,
                      background: _cardColors[_passIndex % _cardColors.length],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 96,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _repeatHintVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: const _PulsingHint(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pulsing "now you say it" hint shown after the English word is played.
class _PulsingHint extends StatefulWidget {
  const _PulsingHint();

  @override
  State<_PulsingHint> createState() => _PulsingHintState();
}

class _PulsingHintState extends State<_PulsingHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    lowerBound: 0.85,
    upperBound: 1.15,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: const Text('🗣️', style: TextStyle(fontSize: 56)),
    );
  }
}
