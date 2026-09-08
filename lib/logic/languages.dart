/// The languages a pack can use. Every entry is supported by ML Kit
/// on-device translation; [voskModel] names the small offline speech model
/// on https://alphacephei.com/vosk/models when one exists (null → answers in
/// that target language are graded by the parent via the review inbox).
class Language {
  const Language({
    required this.code,
    required this.ttsLocale,
    required this.flag,
    required this.nameCs,
    required this.praise,
    this.voskModel,
  });

  /// ISO 639-1 code; also what ML Kit's TranslateLanguage uses (BCP-47).
  final String code;

  final String ttsLocale;
  final String flag;

  /// Display name in Czech (the parent UI language).
  final String nameCs;

  /// End-of-lesson cheer in this language (spoken in the pack's source
  /// language, per parent feedback).
  final String praise;

  final String? voskModel;
}

const languages = <Language>[
  Language(
      code: 'cs',
      ttsLocale: 'cs-CZ',
      flag: '🇨🇿',
      nameCs: 'Čeština',
      praise: 'Hurá! Výborně!',
      voskModel: 'vosk-model-small-cs-0.4-rhasspy'),
  Language(
      code: 'en',
      ttsLocale: 'en-US',
      flag: '🇬🇧',
      nameCs: 'Angličtina',
      praise: 'Hooray! Great job!',
      voskModel: 'vosk-model-small-en-us-0.15'),
  Language(
      code: 'de',
      ttsLocale: 'de-DE',
      flag: '🇩🇪',
      nameCs: 'Němčina',
      praise: 'Hurra! Super gemacht!',
      voskModel: 'vosk-model-small-de-0.15'),
  Language(
      code: 'es',
      ttsLocale: 'es-ES',
      flag: '🇪🇸',
      nameCs: 'Španělština',
      praise: '¡Bravo! ¡Muy bien!',
      voskModel: 'vosk-model-small-es-0.42'),
  Language(
      code: 'fr',
      ttsLocale: 'fr-FR',
      flag: '🇫🇷',
      nameCs: 'Francouzština',
      praise: 'Bravo ! Très bien !',
      voskModel: 'vosk-model-small-fr-0.22'),
  Language(
      code: 'it',
      ttsLocale: 'it-IT',
      flag: '🇮🇹',
      nameCs: 'Italština',
      praise: 'Evviva! Bravissimo!',
      voskModel: 'vosk-model-small-it-0.22'),
  Language(
      code: 'nl',
      ttsLocale: 'nl-NL',
      flag: '🇳🇱',
      nameCs: 'Nizozemština',
      praise: 'Hoera! Goed gedaan!',
      voskModel: 'vosk-model-small-nl-0.22'),
  Language(
      code: 'pl',
      ttsLocale: 'pl-PL',
      flag: '🇵🇱',
      nameCs: 'Polština',
      praise: 'Hura! Świetnie!',
      voskModel: 'vosk-model-small-pl-0.22'),
  Language(
      code: 'pt',
      ttsLocale: 'pt-PT',
      flag: '🇵🇹',
      nameCs: 'Portugalština',
      praise: 'Viva! Muito bem!',
      voskModel: 'vosk-model-small-pt-0.3'),
  Language(
      code: 'ru',
      ttsLocale: 'ru-RU',
      flag: '🇷🇺',
      nameCs: 'Ruština',
      praise: 'Ура! Молодец!',
      voskModel: 'vosk-model-small-ru-0.22'),
  Language(
      code: 'uk',
      ttsLocale: 'uk-UA',
      flag: '🇺🇦',
      nameCs: 'Ukrajinština',
      praise: 'Ура! Молодець!',
      voskModel: 'vosk-model-small-uk-v3-small'),
  Language(
      code: 'sk',
      ttsLocale: 'sk-SK',
      flag: '🇸🇰',
      nameCs: 'Slovenština',
      praise: 'Hurá! Výborne!'),
  Language(
      code: 'hu',
      ttsLocale: 'hu-HU',
      flag: '🇭🇺',
      nameCs: 'Maďarština',
      praise: 'Hurrá! Ügyes vagy!'),
  Language(
      code: 'ro',
      ttsLocale: 'ro-RO',
      flag: '🇷🇴',
      nameCs: 'Rumunština',
      praise: 'Ura! Bravo!'),
  Language(
      code: 'hr',
      ttsLocale: 'hr-HR',
      flag: '🇭🇷',
      nameCs: 'Chorvatština',
      praise: 'Hura! Bravo!'),
  Language(
      code: 'sv',
      ttsLocale: 'sv-SE',
      flag: '🇸🇪',
      nameCs: 'Švédština',
      praise: 'Hurra! Bra jobbat!'),
  Language(
      code: 'da',
      ttsLocale: 'da-DK',
      flag: '🇩🇰',
      nameCs: 'Dánština',
      praise: 'Hurra! Godt gået!'),
];

Language languageByCode(String code) =>
    languages.firstWhere((l) => l.code == code);
