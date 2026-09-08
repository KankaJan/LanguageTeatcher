import 'package:flutter_tts/flutter_tts.dart';

/// Minimal speech interface so playback logic can be tested with fakes.
abstract class SpeechSynthesizer {
  Future<void> speak(String text, String language);
  Future<void> stop();
  void dispose();
}

/// Speaks words via the device's text-to-speech voices.
///
/// This is the "free generic TTS" layer from the plan: playback prefers a
/// parent recording (see WordAudioPlayer) and only falls back here.
class TtsService implements SpeechSynthesizer {
  TtsService() {
    _tts.awaitSpeakCompletion(true);
  }

  static const czech = 'cs-CZ';
  static const english = 'en-US';

  /// Slower than default so a toddler can follow.
  static const _speechRate = 0.42;

  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> speak(String text, String language) async {
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(text);
  }

  Future<void> speakCzech(String text) => speak(text, czech);

  Future<void> speakEnglish(String text) => speak(text, english);

  @override
  Future<void> stop() => _tts.stop();

  @override
  void dispose() {
    _tts.stop();
  }
}
