import 'package:shared_preferences/shared_preferences.dart';

/// Parent-controlled settings and learning progress, persisted on the device.
class AppPrefs {
  AppPrefs(this._prefs);

  static const _keyWordsPerLesson = 'words_per_lesson';
  static const _keyRepetitionsPerWord = 'repetitions_per_word';
  static const _keyWordsCompleted = 'words_completed';
  static const _keyLessonsCompleted = 'lessons_completed';

  static const defaultWordsPerLesson = 5;
  static const defaultRepetitionsPerWord = 3;

  final SharedPreferences _prefs;

  static Future<AppPrefs> load() async =>
      AppPrefs(await SharedPreferences.getInstance());

  int get wordsPerLesson =>
      _prefs.getInt(_keyWordsPerLesson) ?? defaultWordsPerLesson;

  int get repetitionsPerWord =>
      _prefs.getInt(_keyRepetitionsPerWord) ?? defaultRepetitionsPerWord;

  int get wordsCompleted => _prefs.getInt(_keyWordsCompleted) ?? 0;

  int get lessonsCompleted => _prefs.getInt(_keyLessonsCompleted) ?? 0;

  Future<void> setWordsPerLesson(int value) =>
      _prefs.setInt(_keyWordsPerLesson, value);

  Future<void> setRepetitionsPerWord(int value) =>
      _prefs.setInt(_keyRepetitionsPerWord, value);

  Future<void> recordLessonCompleted(int wordsInLesson) async {
    await _prefs.setInt(_keyWordsCompleted, wordsCompleted + wordsInLesson);
    await _prefs.setInt(_keyLessonsCompleted, lessonsCompleted + 1);
  }

  Future<void> resetProgress() async {
    await _prefs.remove(_keyWordsCompleted);
    await _prefs.remove(_keyLessonsCompleted);
  }
}
