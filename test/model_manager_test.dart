import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/services/model_manager.dart';

void main() {
  late Directory tempRoot;
  late ModelManager manager;

  const name = 'vosk-model-small-xx-0.1';

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('model_manager_test');
    manager = ModelManager(tempRoot, modelName: name);
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });

  test('model url derives from the model name', () {
    expect(manager.modelUrl, 'https://alphacephei.com/vosk/models/$name.zip');
  });

  test('an archive with the expected top-level directory passes', () {
    final before = tempRoot.listSync().map((e) => e.path).toSet();
    Directory('${tempRoot.path}/$name').createSync();
    File('${tempRoot.path}/$name/final.mdl').writeAsBytesSync([1]);

    manager.normalizeExtraction(previousEntries: before);

    expect(Directory('${tempRoot.path}/$name').existsSync(), isTrue);
  });

  test('a differently named top-level directory is renamed to the model name',
      () {
    // Another model already installed must not confuse the detection.
    Directory('${tempRoot.path}/vosk-model-small-other-1.0').createSync();
    final before = tempRoot.listSync().map((e) => e.path).toSet();

    Directory('${tempRoot.path}/some-inner-name').createSync();
    File('${tempRoot.path}/some-inner-name/final.mdl').writeAsBytesSync([1]);

    manager.normalizeExtraction(previousEntries: before);

    expect(Directory('${tempRoot.path}/$name').existsSync(), isTrue);
    expect(File('${tempRoot.path}/$name/final.mdl').existsSync(), isTrue);
    expect(Directory('${tempRoot.path}/some-inner-name').existsSync(),
        isFalse);
  });

  test('an extraction that produced nothing usable throws', () {
    final before = tempRoot.listSync().map((e) => e.path).toSet();
    expect(
      () => manager.normalizeExtraction(previousEntries: before),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('an empty model directory throws', () {
    final before = tempRoot.listSync().map((e) => e.path).toSet();
    Directory('${tempRoot.path}/$name').createSync();
    expect(
      () => manager.normalizeExtraction(previousEntries: before),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('no model path while nothing is installed', () {
    expect(manager.status, ModelStatus.absent);
    expect(manager.modelPath, isNull);
  });
}
