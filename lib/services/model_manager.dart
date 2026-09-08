import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum ModelStatus { absent, downloading, ready }

/// Downloads and manages one on-device speech-recognition model (a Vosk
/// small model, ~40 MB, for the active pack's target language). The model is
/// fetched once from the official Vosk site into app-support storage;
/// lessons themselves never need the network. While no model is installed,
/// attempts simply stay parent-graded.
class ModelManager extends ChangeNotifier {
  ModelManager(this.baseDir, {required this.modelName});

  /// Model file name from the language catalog (lib/logic/languages.dart).
  final String modelName;

  String get modelUrl => 'https://alphacephei.com/vosk/models/$modelName.zip';

  /// Rough download size shown to the parent before they tap.
  static const approximateSizeMb = 40;

  final Directory baseDir;

  ModelStatus _status = ModelStatus.absent;
  double _progress = 0;
  String? _error;

  static Future<ModelManager> open({required String modelName}) async {
    final support = await getApplicationSupportDirectory();
    final manager = ModelManager(
      Directory('${support.path}/models'),
      modelName: modelName,
    );
    manager._refreshStatus();
    return manager;
  }

  ModelStatus get status => _status;

  /// Download progress 0..1 while [status] is downloading.
  double get progress => _progress;

  String? get error => _error;

  Directory get _modelDir => Directory('${baseDir.path}/$modelName');

  File get _completeMarker => File('${_modelDir.path}/.complete');

  /// Path handed to the recognizer, or null while the model isn't installed.
  String? get modelPath =>
      _status == ModelStatus.ready ? _modelDir.path : null;

  void _refreshStatus() {
    _status = _completeMarker.existsSync()
        ? ModelStatus.ready
        : ModelStatus.absent;
  }

  Future<void> download() async {
    if (_status != ModelStatus.absent) return;
    _status = ModelStatus.downloading;
    _progress = 0;
    _error = null;
    notifyListeners();

    final zipFile = File('${baseDir.path}/$modelName.zip');
    try {
      baseDir.createSync(recursive: true);
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(modelUrl));
        final response = await request.close();
        if (response.statusCode != 200) {
          throw HttpException('HTTP ${response.statusCode}',
              uri: Uri.parse(modelUrl));
        }
        final total = response.contentLength;
        var received = 0;
        final sink = zipFile.openWrite();
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final p = received / total;
            // Throttle UI updates to visible steps.
            if (p - _progress >= 0.01) {
              _progress = p;
              notifyListeners();
            }
          }
        }
        await sink.close();
      } finally {
        client.close();
      }

      // The zip contains a single top-level "<modelName>/" directory.
      await extractFileToDisk(zipFile.path, baseDir.path);
      _completeMarker.writeAsStringSync('ok');
      _status = ModelStatus.ready;
    } on Exception catch (e) {
      _error = e.toString();
      _status = ModelStatus.absent;
      if (_modelDir.existsSync()) {
        _modelDir.deleteSync(recursive: true);
      }
    } finally {
      if (zipFile.existsSync()) {
        zipFile.deleteSync();
      }
      _progress = 0;
      notifyListeners();
    }
  }

  Future<void> delete() async {
    if (_modelDir.existsSync()) {
      _modelDir.deleteSync(recursive: true);
    }
    _status = ModelStatus.absent;
    _error = null;
    notifyListeners();
  }
}
