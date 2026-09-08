import 'dart:async';

import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logic/languages.dart';
import '../logic/lesson_builder.dart';
import '../models/language_pack.dart';
import '../models/progress.dart';
import '../models/vocabulary.dart';
import '../services/app_prefs.dart';
import '../services/progress_store.dart';
import '../services/recording_store.dart';
import '../services/speech_scorer.dart';
import '../services/word_audio.dart';
import '../widgets/emoji_card.dart';
import 'celebration_screen.dart';

enum _Hint { none, repeatAfterMe, listening }

/// The child-facing lesson. Words are chosen adaptively (failed words first,
/// due reviews, then new words). Every pass is the same simple rhythm: the
/// picture appears, the word is spoken in the source language, then in the
/// target language, and the child repeats it aloud while the mic records —
/// no prompts, no separate teaching phase. Tapping anywhere skips ahead.
/// No text is ever shown.
class LessonScreen extends StatefulWidget {
  const LessonScreen({
    super.key,
    required this.pack,
    required this.prefs,
    required this.recordings,
    required this.progress,
    required this.scorer,
  });

  final LanguagePack pack;
  final AppPrefs prefs;
  final RecordingStore recordings;
  final ProgressStore progress;
  final SpeechScorer scorer;

  Vocabulary get vocabulary => pack.vocabulary;

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

  static const _recordWindow = Duration(seconds: 4);

  late final int _lessonNumber = widget.progress.nextLessonNumber;
  late final Lesson _lesson;
  late final WordAudioPlayer _audio = WordAudioPlayer(
    store: widget.recordings,
    sourceLocale: languageByCode(widget.pack.sourceCode).ttsLocale,
    targetLocale: languageByCode(widget.pack.targetCode).ttsLocale,
  );
  final AudioRecorder _recorder = AudioRecorder();

  int _passIndex = 0;
  _Hint _hint = _Hint.none;
  bool? _micAllowed;
  bool _recording = false;
  bool _starBurst = false;

  /// Incremented on every skip/advance so stale awaits stop acting.
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    // The child listens hands-off; the screen must not dim or lock.
    WakelockPlus.enable();
    final words = selectWords(
      orderedWords: widget.vocabulary.orderedWords,
      progress: widget.progress.wordStates,
      nextLesson: _lessonNumber,
      wordsPerLesson: widget.prefs.wordsPerLesson,
    );
    _lesson = buildLesson(
      words: words,
      repetitionsPerWord: widget.prefs.repetitionsPerWord,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lesson.passes.isEmpty) {
        Navigator.of(context).pop();
      } else {
        _runPass();
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _recorder.dispose();
    _audio.dispose();
    super.dispose();
  }

  /// 1-based repetition number of the current pass's word.
  int _repetitionNumber(int passIndex) {
    final word = _lesson.passes[passIndex];
    var count = 0;
    for (var i = 0; i <= passIndex; i++) {
      if (_lesson.passes[i].id == word.id) count++;
    }
    return count;
  }

  bool _isLastPassOfWord(int index) {
    final id = _lesson.passes[index].id;
    for (var i = index + 1; i < _lesson.passes.length; i++) {
      if (_lesson.passes[i].id == id) return false;
    }
    return true;
  }

  Future<void> _runPass() async {
    final run = _runId;
    final word = _lesson.passes[_passIndex];

    Future<bool> interrupted(Duration pause) async {
      await Future<void>.delayed(pause);
      return !mounted || _runId != run;
    }

    bool stale() => !mounted || _runId != run;

    // The whole pass: source word → target word → child repeats (recorded).
    if (await interrupted(const Duration(milliseconds: 700))) return;
    await _audio.speak(word, WordLang.cz);
    if (await interrupted(const Duration(milliseconds: 800))) return;
    await _audio.speak(word, WordLang.en);
    if (stale()) return;
    await _captureAttempt(word, run);
    final pendingScore = _pendingScore;
    if (stale()) return;

    if (_isLastPassOfWord(_passIndex)) {
      // Give the recognizer a moment to score the last answer, then reward
      // only words that were not answered wrongly — a star for a confidently
      // wrong answer teaches the wrong thing. With no scores at all
      // (no model, mic denied) participation still earns the star.
      if (pendingScore != null) {
        await pendingScore.timeout(const Duration(milliseconds: 1500),
            onTimeout: () {});
      }
      if (stale()) return;
      if (_wordEarnedStar(word)) {
        setState(() => _starBurst = true);
        if (await interrupted(const Duration(milliseconds: 900))) return;
      }
    }
    _advance();
  }

  bool _wordEarnedStar(Word word) {
    final scores = widget.progress.attempts
        .where((a) => a.wordId == word.id && a.lesson == _lessonNumber)
        .map((a) => a.effectiveScore)
        .whereType<int>()
        .toList();
    if (scores.isEmpty) return true;
    final avg = scores.fold<int>(0, (s, v) => s + v) / scores.length;
    return avg >= ProgressStore.passThreshold;
  }

  /// In-flight scoring of the most recently captured attempt, so the reward
  /// decision can briefly wait for the verdict.
  Future<void>? _pendingScore;

  Future<void> _captureAttempt(Word word, int run) async {
    _pendingScore = null;
    _micAllowed ??= await _recorder.hasPermission();
    if (!mounted || _runId != run) return;
    if (_micAllowed != true) {
      // Degrade to a repeat-aloud pause so the lesson still flows.
      setState(() => _hint = _Hint.repeatAfterMe);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (mounted) setState(() => _hint = _Hint.none);
      return;
    }

    widget.progress.attemptsDirectory.createSync(recursive: true);
    final path = '${widget.progress.attemptsDirectory.path}/'
        'l${_lessonNumber}_${word.id}_r${_repetitionNumber(_passIndex)}_'
        '${DateTime.now().millisecondsSinceEpoch}.wav';

    // Recorder failures must never break the lesson: degrade to the
    // repeat-aloud pause, exactly like a denied mic permission.
    try {
      // 16 kHz mono PCM WAV: what the on-device recognizer consumes.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );
    } on Exception {
      if (!mounted || _runId != run) return;
      setState(() => _hint = _Hint.repeatAfterMe);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      if (mounted) setState(() => _hint = _Hint.none);
      return;
    }
    if (!mounted || _runId != run) {
      await _cancelRecorder();
      return;
    }
    setState(() {
      _recording = true;
      _hint = _Hint.listening;
    });

    await Future<void>.delayed(_recordWindow);
    if (!mounted || _runId != run) return; // skip cancelled recording

    try {
      await _recorder.stop();
    } on Exception {
      _recording = false;
      if (mounted) setState(() => _hint = _Hint.none);
      return; // nothing usable was captured
    }
    _recording = false;
    if (mounted) setState(() => _hint = _Hint.none);
    final attempt = await widget.progress.recordAttempt(
      wordId: word.id,
      lesson: _lessonNumber,
      repetition: _repetitionNumber(_passIndex),
      filePath: path,
    );
    // Score in the background; the lesson never waits for the recognizer.
    final pending = _scoreAttempt(attempt, word);
    unawaited(pending);
    _pendingScore = pending;
  }

  Future<void> _cancelRecorder() async {
    try {
      await _recorder.cancel();
    } on Exception {
      // Cancelling a dead recorder is not worth surfacing.
    }
  }

  Future<void> _scoreAttempt(Attempt attempt, Word word) async {
    // Catch-all: this runs unawaited in the background, and any failure must
    // mean "the attempt stays in the parent's review inbox", never an error.
    try {
      final distractors = _lesson.words
          .where((w) => w.id != word.id)
          .map((w) => w.en)
          .toList();
      final result = await widget.scorer.score(
        filePath: attempt.filePath,
        expected: word.en,
        distractors: distractors,
      );
      if (result == null) return; // no model installed → parent grades
      await widget.progress.setAutoResult(
        attempt.id,
        autoScore: result.autoScore,
        confidence: result.confidence,
        transcript: result.transcript,
        reviewInterval: widget.prefs.reviewIntervalLessons,
      );
    } on Object {
      // Parent grading remains the safety net.
    }
  }

  void _advance() {
    if (!mounted) return;
    _runId++;
    if (_recording) {
      _recording = false;
      // Skipped mid-answer: the audio is ambiguous, discard it.
      _cancelRecorder();
    }
    _audio.stop();
    if (_passIndex + 1 >= _lesson.passes.length) {
      _finishLesson();
      return;
    }
    setState(() {
      _passIndex++;
      _hint = _Hint.none;
      _starBurst = false;
    });
    _runPass();
  }

  Future<void> _finishLesson() async {
    await widget.progress.completeLesson(
      lesson: _lessonNumber,
      wordIds: _lesson.words.map((w) => w.id).toList(),
      reviewInterval: widget.prefs.reviewIntervalLessons,
    );
    if (!mounted) return;
    final source = languageByCode(widget.pack.sourceCode);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CelebrationScreen(
          praise: source.praise,
          praiseLocale: source.ttsLocale,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lesson.passes.isEmpty) {
      return const Scaffold(backgroundColor: Color(0xFFFDF8F0));
    }
    final word = _lesson.passes[_passIndex];
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: EmojiCard(
                          key: ValueKey(_passIndex),
                          emoji: emoji,
                          background:
                              _cardColors[_passIndex % _cardColors.length],
                        ),
                      ),
                      IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _starBurst ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: AnimatedScale(
                            scale: _starBurst ? 1.25 : 0.4,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            child: const Text('🌟',
                                style: TextStyle(fontSize: 96)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 110,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _hint == _Hint.none ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    child: _hint == _Hint.listening
                        ? const _PulsingHint(
                            emoji: '🎤',
                            background: Color(0xFFFFCDD2),
                          )
                        : const _PulsingHint(emoji: '🗣️'),
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

/// Pulsing audio hint: "repeat after me" (🗣️) or "I'm listening" (🎤).
class _PulsingHint extends StatefulWidget {
  const _PulsingHint({required this.emoji, this.background});

  final String emoji;
  final Color? background;

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
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: widget.background == null
            ? null
            : BoxDecoration(color: widget.background, shape: BoxShape.circle),
        child: Text(widget.emoji, style: const TextStyle(fontSize: 52)),
      ),
    );
  }
}
