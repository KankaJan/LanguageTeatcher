import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/language_pack.dart';
import '../models/vocabulary.dart';
import 'app_prefs.dart';

/// Owns the language packs (the bundled Czech→English one plus any generated
/// on the phone), which one is active, and where each pack's data lives:
/// progress → `progress_<packId>.json`, child attempts → `attempts/<packId>/`,
/// parent recordings → `recordings/<packId>/`.
class PackStore extends ChangeNotifier {
  PackStore({
    required this.baseVocabulary,
    required this.docsDir,
    required this.prefs,
  });

  final Vocabulary baseVocabulary;
  final Directory docsDir;
  final AppPrefs prefs;

  late final LanguagePack _bundled = LanguagePack.bundled(baseVocabulary);
  final List<LanguagePack> _generated = [];

  static Future<PackStore> open({
    required Vocabulary baseVocabulary,
    required AppPrefs prefs,
  }) async {
    final docs = await getApplicationDocumentsDirectory();
    final store = PackStore(
      baseVocabulary: baseVocabulary,
      docsDir: docs,
      prefs: prefs,
    );
    store.migrateAndLoad();
    return store;
  }

  /// Runs the legacy-data migration and loads generated packs from disk.
  /// Called by [open]; public so tests can drive it on a temp directory.
  void migrateAndLoad() {
    _migrateLegacyData();
    _loadGenerated();
  }

  Directory get _packsDir => Directory('${docsDir.path}/packs');

  File _packFile(String id) => File('${_packsDir.path}/$id.json');

  File progressFileFor(String packId) =>
      File('${docsDir.path}/progress_$packId.json');

  Directory attemptsDirFor(String packId) =>
      Directory('${docsDir.path}/attempts/$packId');

  Directory recordingsDirFor(String packId) =>
      Directory('${docsDir.path}/recordings/$packId');

  List<LanguagePack> get packs => [_bundled, ..._generated];

  LanguagePack get active {
    final id = prefs.activePackId;
    return packs.firstWhere((p) => p.id == id,
        orElse: () => packs.first);
  }

  Future<void> activate(String packId) async {
    await prefs.setActivePackId(packId);
    notifyListeners();
  }

  Future<void> addPack(LanguagePack pack) async {
    _packsDir.createSync(recursive: true);
    _packFile(pack.id)
        .writeAsStringSync(jsonEncode(pack.toJson()), flush: true);
    _generated.add(pack);
    await activate(pack.id);
  }

  Future<void> deletePack(String packId) async {
    if (packId == LanguagePack.bundledId) return;
    _generated.removeWhere((p) => p.id == packId);
    for (final entity in <FileSystemEntity>[
      _packFile(packId),
      progressFileFor(packId),
      attemptsDirFor(packId),
      recordingsDirFor(packId),
    ]) {
      if (entity.existsSync()) {
        entity.deleteSync(recursive: true);
      }
    }
    if (prefs.activePackId == packId) {
      await prefs.setActivePackId(LanguagePack.bundledId);
    }
    notifyListeners();
  }

  /// Persists the parent's fix of one machine-translated word.
  Future<void> updateWord(
    String packId,
    String wordId, {
    String? source,
    String? target,
  }) async {
    final index = _generated.indexWhere((p) => p.id == packId);
    if (index < 0) return; // the curated pack is not editable
    final updated =
        _generated[index].withWord(wordId, source: source, target: target);
    _generated[index] = updated;
    _packFile(packId)
        .writeAsStringSync(jsonEncode(updated.toJson()), flush: true);
    notifyListeners();
  }

  void _loadGenerated() {
    _generated.clear();
    if (!_packsDir.existsSync()) return;
    for (final entity in _packsDir.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          _generated.add(LanguagePack.fromJson(
              jsonDecode(entity.readAsStringSync()) as Map<String, dynamic>));
        } on FormatException {
          // A corrupt pack file is skipped rather than crashing the app.
        }
      }
    }
    _generated.sort((a, b) => a.id.compareTo(b.id));
  }

  /// Pre-pack installs kept data at fixed paths; move it under the bundled
  /// pack's id so nothing is lost on upgrade.
  void _migrateLegacyData() {
    const id = LanguagePack.bundledId;

    final legacyProgress = File('${docsDir.path}/progress.json');
    if (legacyProgress.existsSync() && !progressFileFor(id).existsSync()) {
      legacyProgress.renameSync(progressFileFor(id).path);
    }

    for (final (legacyDir, newDir) in [
      (Directory('${docsDir.path}/attempts'), attemptsDirFor(id)),
      (Directory('${docsDir.path}/recordings'), recordingsDirFor(id)),
    ]) {
      if (!legacyDir.existsSync()) continue;
      final looseFiles =
          legacyDir.listSync().whereType<File>().toList();
      if (looseFiles.isEmpty) continue;
      newDir.createSync(recursive: true);
      for (final file in looseFiles) {
        final name = file.uri.pathSegments.last;
        file.renameSync('${newDir.path}/$name');
      }
    }
  }
}
