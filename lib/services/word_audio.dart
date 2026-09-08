import 'package:just_audio/just_audio.dart';

import '../models/vocabulary.dart';
import 'recording_store.dart';
import 'tts_service.dart';

/// Plays a local audio file to completion. Abstract so tests can fake it.
abstract class FilePlayer {
  Future<void> play(String path);
  Future<void> stop();
  void dispose();
}

class JustAudioFilePlayer implements FilePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String path) async {
    await _player.stop();
    await _player.setFilePath(path);
    // play() completes when playback finishes (or is stopped).
    await _player.play();
    await _player.stop();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  void dispose() {
    _player.dispose();
  }
}

/// Speaks a word in the requested language: the parent's recording when one
/// exists, otherwise the device TTS voice. This is the only audio path the
/// lesson uses, so recorded words automatically sound like the parent.
/// [sourceLocale]/[targetLocale] come from the active language pack.
class WordAudioPlayer {
  WordAudioPlayer({
    required this.store,
    required this.sourceLocale,
    required this.targetLocale,
    SpeechSynthesizer? tts,
    FilePlayer? filePlayer,
  })  : tts = tts ?? TtsService(),
        filePlayer = filePlayer ?? JustAudioFilePlayer();

  final RecordingStore store;
  final String sourceLocale;
  final String targetLocale;
  final SpeechSynthesizer tts;
  final FilePlayer filePlayer;

  Future<void> speak(Word word, WordLang lang) async {
    if (store.has(word.id, lang)) {
      try {
        await filePlayer.play(store.pathFor(word.id, lang));
        return;
      } on Exception {
        // A broken recording file must not silence the lesson.
      }
    }
    final text = lang == WordLang.cz ? word.cz : word.en;
    await tts.speak(
        text, lang == WordLang.cz ? sourceLocale : targetLocale);
  }

  Future<void> stop() async {
    await filePlayer.stop();
    await tts.stop();
  }

  void dispose() {
    filePlayer.dispose();
    tts.dispose();
  }
}
