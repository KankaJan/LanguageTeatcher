import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/language_pack.dart';
import '../models/vocabulary.dart';
import '../services/pack_store.dart';
import '../services/recording_store.dart';
import '../services/word_audio.dart';

/// Parent-mode studio: record your own voice for either side of every word.
/// Words with a recording play in the parent's voice during lessons; the
/// rest fall back to device TTS. For machine-translated packs each word can
/// also be edited here (the fix persists into the pack).
class RecordingStudioScreen extends StatelessWidget {
  const RecordingStudioScreen({
    super.key,
    required this.pack,
    required this.packStore,
    required this.store,
  });

  final LanguagePack pack;
  final PackStore packStore;
  final RecordingStore store;

  Vocabulary get vocabulary => pack.vocabulary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nahrávací studio')),
      body: ListenableBuilder(
        listenable: Listenable.merge([store, packStore]),
        builder: (context, _) {
          // Re-read the pack so word edits show immediately.
          final currentPack = packStore.packs
              .firstWhere((p) => p.id == pack.id, orElse: () => pack);
          final vocabulary = currentPack.vocabulary;
          final words = vocabulary.orderedWords;
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nahráno ${store.recordedCount} z ${words.length * 2} '
                  'nahrávek (${words.length} slovíček × čeština a angličtina). '
                  'Nenahraná slovíčka čte hlas telefonu.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final category in vocabulary.categories)
                ExpansionTile(
                  leading: Text(category.emoji,
                      style: const TextStyle(fontSize: 24)),
                  title: Text(category.cz),
                  subtitle: Text(_categoryProgress(category)),
                  children: [
                    for (final word in words
                        .where((w) => w.categoryId == category.id))
                      _WordTile(
                        word: word,
                        vocabulary: vocabulary,
                        store: store,
                        onEdit: currentPack.generated
                            ? () => _editWord(context, currentPack, word)
                            : null,
                      ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editWord(
      BuildContext context, LanguagePack currentPack, Word word) async {
    final sourceController = TextEditingController(text: word.cz);
    final targetController = TextEditingController(text: word.en);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upravit slovíčko'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: sourceController,
              decoration:
                  const InputDecoration(labelText: 'Zdrojový jazyk'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: targetController,
              decoration: const InputDecoration(labelText: 'Cílový jazyk'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zrušit'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Uložit'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await packStore.updateWord(
        currentPack.id,
        word.id,
        source: sourceController.text.trim(),
        target: targetController.text.trim(),
      );
    }
    sourceController.dispose();
    targetController.dispose();
  }

  String _categoryProgress(WordCategory category) {
    final words = vocabulary.orderedWords
        .where((w) => w.categoryId == category.id)
        .toList();
    final recorded = words
        .map((w) =>
            (store.has(w.id, WordLang.cz) ? 1 : 0) +
            (store.has(w.id, WordLang.en) ? 1 : 0))
        .fold<int>(0, (a, b) => a + b);
    return 'nahráno $recorded z ${words.length * 2}';
  }
}

class _WordTile extends StatelessWidget {
  const _WordTile({
    required this.word,
    required this.vocabulary,
    required this.store,
    this.onEdit,
  });

  final Word word;
  final Vocabulary vocabulary;
  final RecordingStore store;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(vocabulary.emojiFor(word),
          style: const TextStyle(fontSize: 24)),
      title: Text('${word.cz} — ${word.en}'),
      onTap: onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Opravit překlad',
              onPressed: onEdit,
            ),
          _LangChip(word: word, lang: WordLang.cz, store: store),
          const SizedBox(width: 8),
          _LangChip(word: word, lang: WordLang.en, store: store),
        ],
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.word,
    required this.lang,
    required this.store,
  });

  final Word word;
  final WordLang lang;
  final RecordingStore store;

  @override
  Widget build(BuildContext context) {
    final recorded = store.has(word.id, lang);
    final label = lang == WordLang.cz ? 'CZ' : 'EN';
    return ActionChip(
      avatar: Icon(
        recorded ? Icons.check_circle : Icons.mic_none,
        size: 18,
        color: recorded ? Colors.green : null,
      ),
      label: Text(label),
      backgroundColor: recorded ? Colors.green.withValues(alpha: 0.12) : null,
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _RecorderSheet(word: word, lang: lang, store: store),
        );
      },
    );
  }
}

enum _RecorderPhase { idle, recording, recorded, busy }

/// Bottom sheet that captures one recording: tap to record (max 5 s), preview,
/// then save, re-record, or delete the stored version.
class _RecorderSheet extends StatefulWidget {
  const _RecorderSheet({
    required this.word,
    required this.lang,
    required this.store,
  });

  final Word word;
  final WordLang lang;
  final RecordingStore store;

  @override
  State<_RecorderSheet> createState() => _RecorderSheetState();
}

class _RecorderSheetState extends State<_RecorderSheet> {
  final AudioRecorder _recorder = AudioRecorder();
  final FilePlayer _player = JustAudioFilePlayer();

  _RecorderPhase _phase = _RecorderPhase.idle;
  String? _tempPath;
  Timer? _autoStop;

  static const _maxDuration = Duration(seconds: 5);

  @override
  void dispose() {
    _autoStop?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Povolte aplikaci přístup k mikrofonu v nastavení '
            'telefonu.'),
      ));
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final path = '${tempDir.path}/capture_'
        '${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _tempPath = path;
      _phase = _RecorderPhase.recording;
    });
    _autoStop = Timer(_maxDuration, _stopRecording);
  }

  Future<void> _stopRecording() async {
    _autoStop?.cancel();
    await _recorder.stop();
    if (!mounted) return;
    setState(() => _phase = _RecorderPhase.recorded);
  }

  Future<void> _preview() async {
    final path = _tempPath;
    if (path == null) return;
    setState(() => _phase = _RecorderPhase.busy);
    try {
      await _player.play(path);
    } finally {
      if (mounted) setState(() => _phase = _RecorderPhase.recorded);
    }
  }

  Future<void> _playSaved() async {
    setState(() => _phase = _RecorderPhase.busy);
    try {
      await _player.play(widget.store.pathFor(widget.word.id, widget.lang));
    } finally {
      if (mounted) setState(() => _phase = _RecorderPhase.idle);
    }
  }

  Future<void> _save() async {
    final path = _tempPath;
    if (path == null) return;
    await widget.store.saveFrom(path, widget.word.id, widget.lang);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _deleteSaved() async {
    await widget.store.delete(widget.word.id, widget.lang);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isCz = widget.lang == WordLang.cz;
    final text = isCz ? widget.word.cz : widget.word.en;
    final hasSaved = widget.store.has(widget.word.id, widget.lang);
    final recording = _phase == _RecorderPhase.recording;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isCz ? 'Nahrát česky' : 'Nahrát anglicky',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Řekněte: „$text“',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Material(
            shape: const CircleBorder(),
            color: recording ? Colors.red : Theme.of(context).colorScheme.primary,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _phase == _RecorderPhase.busy
                  ? null
                  : recording
                      ? _stopRecording
                      : _startRecording,
              child: SizedBox(
                width: 88,
                height: 88,
                child: Icon(
                  recording ? Icons.stop : Icons.mic,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recording
                ? 'Nahrávám… (max. 5 s, klepnutím zastavíte)'
                : 'Klepnutím začnete nahrávat',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: [
              if (_phase == _RecorderPhase.recorded ||
                  (_phase == _RecorderPhase.busy && _tempPath != null)) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Přehrát'),
                  onPressed: _phase == _RecorderPhase.busy ? null : _preview,
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Uložit'),
                  onPressed: _phase == _RecorderPhase.busy ? null : _save,
                ),
              ] else if (hasSaved && !recording) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Přehrát uloženou'),
                  onPressed: _phase == _RecorderPhase.busy ? null : _playSaved,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Smazat'),
                  onPressed:
                      _phase == _RecorderPhase.busy ? null : _deleteSaved,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
