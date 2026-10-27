import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parent-controlled lesson settings, persisted on the device. Learning
/// progress itself lives in ProgressStore. Notifies listeners after every
/// change so screens built earlier (the start screen behind parent mode)
/// pick settings up without being rebuilt by hand.
class AppPrefs extends ChangeNotifier {
  AppPrefs(this._prefs);

  static const _keyWordsPerLesson = 'words_per_lesson';
  static const _keyRepetitionsPerWord = 'repetitions_per_word';
  static const _keyReviewInterval = 'review_interval_lessons';
  static const _keyActivePack = 'active_pack_id';
  static const _keyChildCanSwitchPacks = 'child_can_switch_packs';

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

  Future<void> setWordsPerLesson(int value) async {
    await _prefs.setInt(_keyWordsPerLesson, value);
    notifyListeners();
  }

  Future<void> setRepetitionsPerWord(int value) async {
    await _prefs.setInt(_keyRepetitionsPerWord, value);
    notifyListeners();
  }

  Future<void> setReviewIntervalLessons(int value) async {
    await _prefs.setInt(_keyReviewInterval, value);
    notifyListeners();
  }

  /// Which language pack the child is learning right now.
  String get activePackId => _prefs.getString(_keyActivePack) ?? 'cs_en';

  Future<void> setActivePackId(String value) async {
    await _prefs.setString(_keyActivePack, value);
    notifyListeners();
  }

  /// Whether tapping the flags on the start screen lets the child switch
  /// between language packs without the parent gate. Off by default: a
  /// toddler tapping around should not end up in a different language.
  bool get childCanSwitchPacks =>
      _prefs.getBool(_keyChildCanSwitchPacks) ?? false;

  Future<void> setChildCanSwitchPacks(bool value) async {
    await _prefs.setBool(_keyChildCanSwitchPacks, value);
    notifyListeners();
  }
}
