import 'package:shared_preferences/shared_preferences.dart';

/// Parent-controlled lesson settings, persisted on the device. Learning
/// progress itself lives in ProgressStore.
class AppPrefs {
  AppPrefs(this._prefs);

  static const _keyWordsPerLesson = 'words_per_lesson';
  static const _keyRepetitionsPerWord = 'repetitions_per_word';
  static const _keyReviewInterval = 'review_interval_lessons';
  static const _keyActivePack = 'active_pack_id';

  static const defaultWordsPerLesson = 5;
  static const defaultRepetitionsPerWord = 3;
  static const defaultReviewIntervalLessons = 5;

  final SharedPreferences _prefs;

  static Future<AppPrefs> load() async =>
      AppPrefs(await SharedPreferences.getInstance());

  int get wordsPerLesson =>
      _prefs.getInt(_keyWordsPerLesson) ?? defaultWordsPerLesson;

  int get repetitionsPerWord =>
      _prefs.getInt(_keyRepetitionsPerWord) ?? defaultRepetitionsPerWord;

  /// After how many lessons a mastered word comes back for review.
  int get reviewIntervalLessons =>
      _prefs.getInt(_keyReviewInterval) ?? defaultReviewIntervalLessons;

  Future<void> setWordsPerLesson(int value) =>
      _prefs.setInt(_keyWordsPerLesson, value);

  Future<void> setRepetitionsPerWord(int value) =>
      _prefs.setInt(_keyRepetitionsPerWord, value);

  Future<void> setReviewIntervalLessons(int value) =>
      _prefs.setInt(_keyReviewInterval, value);

  /// Which language pack the child is learning right now.
  String get activePackId => _prefs.getString(_keyActivePack) ?? 'cs_en';

  Future<void> setActivePackId(String value) =>
      _prefs.setString(_keyActivePack, value);
}
