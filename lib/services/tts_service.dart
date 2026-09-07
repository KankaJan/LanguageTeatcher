import 'package:flutter_tts/flutter_tts.dart';

/// Speaks words via the device's text-to-speech voices.
///
/// This is the "free generic TTS" layer from the plan. From milestone M2 on,
/// playback will first look for a parent recording of the word and only fall
/// back to TTS when none exists.
class TtsService {
  TtsService() {
    _tts.awaitSpeakCompletion(true);
  }

  static const czech = 'cs-CZ';
  static const english = 'en-US';

  /// Slower than default so a toddler can follow.
  static const _speechRate = 0.42;

  final FlutterTts _tts = FlutterTts();

  Future<void> speak(String text, String language) async {
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(_speechRate);
    await _tts.speak(text);
  }

  Future<void> speakCzech(String text) => speak(text, czech);

  Future<void> speakEnglish(String text) => speak(text, english);

  Future<void> stop() => _tts.stop();

  void dispose() {
    _tts.stop();
  }
}
