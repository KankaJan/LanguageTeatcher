import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/services/recording_store.dart';

void main() {
  late Directory tempRoot;
  late RecordingStore store;

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('recording_store_test');
    store = RecordingStore(Directory('${tempRoot.path}/recordings'));
    await store.refresh();
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });

  test('key and file name derivation', () {
    expect(RecordingStore.keyFor('dog', WordLang.cz), 'dog_cz');
    expect(RecordingStore.fileNameFor('dog', WordLang.en), 'dog_en.m4a');
    expect(store.pathFor('dog', WordLang.cz),
        '${store.directory.path}/dog_cz.m4a');
  });

  test('empty store has nothing', () {
    expect(store.has('dog', WordLang.cz), isFalse);
    expect(store.recordedCount, 0);
  });

  test('saveFrom moves the capture into the store', () async {
    final capture = File('${tempRoot.path}/capture.m4a')
      ..writeAsBytesSync([1, 2, 3]);

    await store.saveFrom(capture.path, 'dog', WordLang.cz);

    expect(store.has('dog', WordLang.cz), isTrue);
    expect(store.has('dog', WordLang.en), isFalse);
    expect(store.recordedCount, 1);
    expect(File(store.pathFor('dog', WordLang.cz)).existsSync(), isTrue);
    expect(capture.existsSync(), isFalse, reason: 'temp capture is cleaned up');
  });

  test('delete removes the recording', () async {
    final capture = File('${tempRoot.path}/capture.m4a')
      ..writeAsBytesSync([1, 2, 3]);
    await store.saveFrom(capture.path, 'cat', WordLang.en);

    await store.delete('cat', WordLang.en);

    expect(store.has('cat', WordLang.en), isFalse);
    expect(File(store.pathFor('cat', WordLang.en)).existsSync(), isFalse);
  });

  test('refresh scans files already on disk', () async {
    store.directory.createSync(recursive: true);
    File('${store.directory.path}/horse_cz.m4a').writeAsBytesSync([1]);
    File('${store.directory.path}/horse_en.m4a').writeAsBytesSync([1]);
    File('${store.directory.path}/notes.txt').writeAsBytesSync([1]);

    await store.refresh();

    expect(store.has('horse', WordLang.cz), isTrue);
    expect(store.has('horse', WordLang.en), isTrue);
    expect(store.recordedCount, 2, reason: 'non-m4a files are ignored');
  });

  test('notifies listeners on save and delete', () async {
    var notified = 0;
    store.addListener(() => notified++);
    final capture = File('${tempRoot.path}/capture.m4a')
      ..writeAsBytesSync([1]);

    await store.saveFrom(capture.path, 'dog', WordLang.cz);
    await store.delete('dog', WordLang.cz);

    expect(notified, 2);
  });
}
