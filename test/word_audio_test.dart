import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otterly/models/vocabulary.dart';
import 'package:otterly/services/recording_store.dart';
import 'package:otterly/services/tts_service.dart';
import 'package:otterly/services/word_audio.dart';

class FakeSynth implements SpeechSynthesizer {
  final List<(String, String)> spoken = [];

  @override
  Future<void> speak(String text, String language) async {
    spoken.add((text, language));
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class FakeFilePlayer implements FilePlayer {
  FakeFilePlayer({this.failing = false});

  final bool failing;
  final List<String> played = [];

  @override
  Future<void> play(String path) async {
    if (failing) throw Exception('broken file');
    played.add(path);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

void main() {
  const word = Word(id: 'dog', en: 'dog', cz: 'pes', categoryId: 'c', order: 1);

  late Directory tempRoot;
  late RecordingStore store;
  late FakeSynth tts;

  setUp(() async {
    tempRoot = Directory.systemTemp.createTempSync('word_audio_test');
    store = RecordingStore(Directory('${tempRoot.path}/recordings'));
    await store.refresh();
    tts = FakeSynth();
  });

  tearDown(() {
    tempRoot.deleteSync(recursive: true);
  });

  Future<void> addRecording(String wordId, WordLang lang) async {
    final capture = File('${tempRoot.path}/c.m4a')..writeAsBytesSync([1]);
    await store.saveFrom(capture.path, wordId, lang);
  }

  test('unrecorded word falls back to TTS with the right text and locale',
      () async {
    final filePlayer = FakeFilePlayer();
    final audio =
        WordAudioPlayer(store: store, tts: tts, filePlayer: filePlayer);

    await audio.speak(word, WordLang.cz);
    await audio.speak(word, WordLang.en);

    expect(filePlayer.played, isEmpty);
    expect(tts.spoken, [('pes', 'cs-CZ'), ('dog', 'en-US')]);
  });

  test('recorded word plays the parent recording, not TTS', () async {
    await addRecording('dog', WordLang.cz);
    final filePlayer = FakeFilePlayer();
    final audio =
        WordAudioPlayer(store: store, tts: tts, filePlayer: filePlayer);

    await audio.speak(word, WordLang.cz);
    await audio.speak(word, WordLang.en);

    expect(filePlayer.played, [store.pathFor('dog', WordLang.cz)]);
    expect(tts.spoken, [('dog', 'en-US')],
        reason: 'only the unrecorded English side uses TTS');
  });

  test('a broken recording falls back to TTS instead of silence', () async {
    await addRecording('dog', WordLang.cz);
    final audio = WordAudioPlayer(
      store: store,
      tts: tts,
      filePlayer: FakeFilePlayer(failing: true),
    );

    await audio.speak(word, WordLang.cz);

    expect(tts.spoken, [('pes', 'cs-CZ')]);
  });
}
