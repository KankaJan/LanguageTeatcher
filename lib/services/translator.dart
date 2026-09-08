import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Translates single words for pack generation. Abstract so the generation
/// pipeline is testable with a fake.
abstract class WordTranslator {
  /// Ensures the language models are present (downloads once, ~30 MB per
  /// language, then everything is offline).
  Future<void> prepare();

  Future<String> translate(String text);

  Future<void> dispose();
}

/// Factory signature: builds a translator for one direction, using ISO codes
/// from the language catalog.
typedef TranslatorFactory = WordTranslator Function(String from, String to);

/// ML Kit on-device translation (free, offline after the one-time model
/// download).
class MlKitWordTranslator implements WordTranslator {
  MlKitWordTranslator(this.from, this.to)
      : _translator = OnDeviceTranslator(
          sourceLanguage: _language(from),
          targetLanguage: _language(to),
        );

  final String from;
  final String to;
  final OnDeviceTranslator _translator;

  static TranslateLanguage _language(String code) =>
      TranslateLanguage.values.firstWhere((l) => l.bcpCode == code);

  @override
  Future<void> prepare() async {
    final manager = OnDeviceTranslatorModelManager();
    for (final code in [from, to]) {
      final bcp = _language(code).bcpCode;
      if (!await manager.isModelDownloaded(bcp)) {
        await manager.downloadModel(bcp);
      }
    }
  }

  @override
  Future<String> translate(String text) => _translator.translateText(text);

  @override
  Future<void> dispose() async {
    // Closing is best-effort cleanup of a one-shot job. Some plugin/device
    // combinations throw MissingPluginException from close even though
    // translation itself worked — that must never fail pack generation.
    try {
      await _translator.close();
    } on Object {
      // Nothing to do; the OS reclaims the resources with the isolate.
    }
  }
}
