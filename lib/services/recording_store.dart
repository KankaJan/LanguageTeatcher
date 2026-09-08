import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Which side of a word pair a recording (or TTS utterance) is for. The
/// codes are historical file-name suffixes: `cz` = the pack's SOURCE
/// language, `en` = its TARGET language (literally Czech/English in the
/// bundled pack). Actual TTS locales come from the active language pack.
enum WordLang {
  cz('cz'),
  en('en');

  const WordLang(this.code);

  /// File-name suffix.
  final String code;
}

/// Parent voice recordings, one file per word+language, stored in the app's
/// documents directory. Existence on disk is the source of truth; an in-memory
/// key set mirrors it so `has` is synchronous for playback decisions.
class RecordingStore extends ChangeNotifier {
  RecordingStore(this.directory);

  final Directory directory;
  final Set<String> _keys = {};

  static String keyFor(String wordId, WordLang lang) =>
      '${wordId}_${lang.code}';

  static String fileNameFor(String wordId, WordLang lang) =>
      '${keyFor(wordId, lang)}.m4a';

  /// Opens the store in `<appDocuments>/recordings` and scans existing files.
  static Future<RecordingStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final store = RecordingStore(Directory('${docs.path}/recordings'));
    await store.refresh();
    return store;
  }

  Future<void> refresh() async {
    _keys.clear();
    if (directory.existsSync()) {
      for (final entry in directory.listSync()) {
        final name = entry.uri.pathSegments.last;
        if (entry is File && name.endsWith('.m4a')) {
          _keys.add(name.substring(0, name.length - '.m4a'.length));
        }
      }
    }
    notifyListeners();
  }

  bool has(String wordId, WordLang lang) =>
      _keys.contains(keyFor(wordId, lang));

  String pathFor(String wordId, WordLang lang) =>
      '${directory.path}/${fileNameFor(wordId, lang)}';

  int get recordedCount => _keys.length;

  /// Moves a freshly captured temp file into the store.
  Future<void> saveFrom(String tempPath, String wordId, WordLang lang) async {
    directory.createSync(recursive: true);
    final temp = File(tempPath);
    await temp.copy(pathFor(wordId, lang));
    try {
      await temp.delete();
    } on FileSystemException {
      // The capture file being left behind is harmless.
    }
    _keys.add(keyFor(wordId, lang));
    notifyListeners();
  }

  Future<void> delete(String wordId, WordLang lang) async {
    final file = File(pathFor(wordId, lang));
    if (file.existsSync()) {
      await file.delete();
    }
    _keys.remove(keyFor(wordId, lang));
    notifyListeners();
  }
}
