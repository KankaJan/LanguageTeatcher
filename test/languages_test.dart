import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/logic/languages.dart';

void main() {
  test('codes are unique and lowercase ISO', () {
    final codes = languages.map((l) => l.code).toList();
    expect(codes.toSet(), hasLength(codes.length));
    for (final code in codes) {
      expect(code, matches(RegExp(r'^[a-z]{2}$')));
    }
  });

  test('every language is fully described', () {
    for (final l in languages) {
      expect(l.ttsLocale, matches(RegExp(r'^[a-z]{2}-[A-Z]{2}$')),
          reason: l.code);
      expect(l.flag, isNotEmpty, reason: l.code);
      expect(l.nameCs, isNotEmpty, reason: l.code);
      expect(l.praise, isNotEmpty, reason: l.code);
    }
  });

  test('the bundled pair exists with speech models', () {
    expect(languageByCode('cs').voskModel, isNotNull);
    expect(languageByCode('en').voskModel, 'vosk-model-small-en-us-0.15');
  });

  test('vosk model names follow the small-model convention', () {
    for (final l in languages.where((l) => l.voskModel != null)) {
      expect(l.voskModel, startsWith('vosk-model-small-'), reason: l.code);
    }
  });

  test('languageByCode throws for unknown codes', () {
    expect(() => languageByCode('xx'), throwsStateError);
  });
}
