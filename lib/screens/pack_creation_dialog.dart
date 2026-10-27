import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/languages.dart';
import '../logic/pack_generator.dart';
import '../services/model_manager.dart';
import '../services/pack_store.dart';
import '../services/translator.dart';

/// Signature of [ModelManager.open]; injectable so tests can substitute a
/// manager on a temp directory.
typedef ModelManagerOpener = Future<ModelManager> Function(
    {required String modelName});

/// Where the dialog is in the flow. The steps run strictly in this order; a
/// failure stays on its step with an error text and lets the parent retry.
enum _Step { form, generating, offerModel, downloadingModel }

/// Parent dialog: pick a source and a target language and the app generates
/// the whole word list itself with on-device machine translation (ML Kit —
/// a one-time ~30 MB model download per language, then offline).
///
/// Once the pack exists, the same dialog offers the speech-recognition model
/// for the new target language, so the parent sets up a language in one go
/// instead of hunting for a second download in another section.
class PackCreationDialog extends StatefulWidget {
  const PackCreationDialog({
    super.key,
    required this.packStore,
    this.translatorFactory = MlKitWordTranslator.new,
    this.openModelManager = ModelManager.open,
  });

  final PackStore packStore;
  final TranslatorFactory translatorFactory;
  final ModelManagerOpener openModelManager;

  @override
  State<PackCreationDialog> createState() => _PackCreationDialogState();
}

class _PackCreationDialogState extends State<PackCreationDialog> {
  String _sourceCode = 'cs';
  String _targetCode = 'de';
  _Step _step = _Step.form;
  int _done = 0;
  int _total = 1;
  String? _error;

  /// Manager of the new pack's speech model, set once the pack exists and
  /// the target language has a model that is not installed yet.
  ModelManager? _models;

  bool get _busy =>
      _step == _Step.generating || _step == _Step.downloadingModel;

  @override
  void dispose() {
    _models?.removeListener(_onModelChanged);
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _step = _Step.generating;
      _error = null;
      _done = 0;
    });
    try {
      final pack = await generatePack(
        base: widget.packStore.baseVocabulary,
        sourceCode: _sourceCode,
        targetCode: _targetCode,
        translatorFactory: widget.translatorFactory,
        onProgress: (done, total) {
          if (mounted) {
            setState(() {
              _done = done;
              _total = total;
            });
          }
        },
      );
      await widget.packStore.addPack(pack);
      if (!mounted) return;
      await _offerSpeechModel();
    } on MissingPluginException catch (e) {
      // The ML Kit translation module failed to register when the app
      // started; a full restart re-attempts the registration. The message
      // names the method and channel that was missing — keep it visible, it
      // is the only clue about which call failed without a logcat session.
      if (mounted) {
        setState(() {
          _step = _Step.form;
          _error = 'Překladový modul se nenačetl. Úplně zavřete aplikaci '
              '(i z přehledu spuštěných aplikací) a otevřete ji znovu, pak '
              'to zkuste ještě jednou.\n\n(technicky: ${e.message})';
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.form;
          _error = 'Vytvoření se nepodařilo (je telefon online?): $e';
        });
      }
    }
  }

  /// Second step: the pack is saved and active. Offer the speech model when
  /// the target language has one and it is not installed; otherwise close.
  Future<void> _offerSpeechModel() async {
    final modelName = languageByCode(_targetCode).voskModel;
    if (modelName == null) {
      Navigator.of(context).pop();
      return;
    }
    final manager = await widget.openModelManager(modelName: modelName);
    if (!mounted) return;
    if (manager.status == ModelStatus.ready) {
      Navigator.of(context).pop();
      return;
    }
    manager.addListener(_onModelChanged);
    setState(() {
      _models = manager;
      _step = manager.status == ModelStatus.downloading
          ? _Step.downloadingModel
          : _Step.offerModel;
      _error = null;
    });
  }

  void _onModelChanged() {
    final manager = _models;
    if (!mounted || manager == null) return;
    switch (manager.status) {
      case ModelStatus.ready:
        Navigator.of(context).pop();
      case ModelStatus.downloading:
        setState(() => _step = _Step.downloadingModel);
      case ModelStatus.absent:
        // Either the download failed (error set) or was never started.
        setState(() {
          _step = _Step.offerModel;
          _error = manager.error == null
              ? null
              : 'Stahování modelu se nepodařilo: ${manager.error}';
        });
    }
  }

  void _downloadModel() {
    final manager = _models;
    if (manager == null) return;
    setState(() {
      _step = _Step.downloadingModel;
      _error = null;
    });
    // Progress and completion arrive through the listener. The download
    // itself keeps running inside the shared manager even if the parent
    // closes this dialog, and the parent-mode speech card shows it too.
    manager.download();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_step) {
      _Step.form || _Step.generating => _buildPackStep(context),
      _Step.offerModel || _Step.downloadingModel => _buildModelStep(context),
    };
  }

  Widget _buildPackStep(BuildContext context) {
    final generating = _step == _Step.generating;

    DropdownButtonFormField<String> languageField({
      required String label,
      required String value,
      required ValueChanged<String> onChanged,
    }) {
      return DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final l in languages)
            DropdownMenuItem(value: l.code, child: Text('${l.flag} ${l.nameCs}')),
        ],
        onChanged: generating
            ? null
            : (code) {
                if (code != null) onChanged(code);
              },
      );
    }

    return AlertDialog(
      title: const Text('Nový jazykový balíček'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          languageField(
            label: 'Jazyk dítěte (zdrojový)',
            value: _sourceCode,
            onChanged: (code) => setState(() => _sourceCode = code),
          ),
          const SizedBox(height: 12),
          languageField(
            label: 'Jazyk, který se učí (cílový)',
            value: _targetCode,
            onChanged: (code) => setState(() => _targetCode = code),
          ),
          const SizedBox(height: 16),
          if (generating) ...[
            LinearProgressIndicator(value: _done == 0 ? null : _done / _total),
            const SizedBox(height: 8),
            Text(_done == 0
                ? 'Stahuji překladové modely…'
                : 'Překládám slovíčka: $_done z $_total'),
          ] else
            const Text(
              'Slovíčka se přeloží strojově přímo v telefonu (jednorázové '
              'stažení ~30 MB na jazyk). Případné nepřesné překlady pak '
              'můžete opravit v nahrávacím studiu.',
              style: TextStyle(fontSize: 13),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        FilledButton(
          onPressed: _busy || _sourceCode == _targetCode ? null : _create,
          child: const Text('Vytvořit'),
        ),
      ],
    );
  }

  Widget _buildModelStep(BuildContext context) {
    final manager = _models!;
    final target = languageByCode(_targetCode);
    final downloading = _step == _Step.downloadingModel;
    return AlertDialog(
      title: const Text('Balíček je hotový'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balíček ${languageByCode(_sourceCode).flag} → ${target.flag} '
            'je vytvořený a aktivní.',
          ),
          const SizedBox(height: 12),
          if (downloading) ...[
            const Text('Stahuji model rozpoznávání řeči…'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: manager.progress == 0 ? null : manager.progress),
          ] else
            Text(
              'Chcete rovnou stáhnout i model rozpoznávání řeči pro jazyk '
              '${target.nameCs.toLowerCase()} '
              '(~${ModelManager.approximateSizeMb} MB, jednorázově)? '
              'S modelem se jasné odpovědi dítěte hodnotí samy přímo v '
              'telefonu; bez něj hodnotíte všechny odpovědi ručně. '
              'Stáhnout ho můžete i později v sekci Rozpoznávání řeči.',
              style: const TextStyle(fontSize: 13),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ],
      ),
      actions: [
        TextButton(
          // While downloading, closing just hides the dialog; the shared
          // manager finishes in the background.
          onPressed: () => Navigator.of(context).pop(),
          child: Text(downloading ? 'Zavřít' : 'Později'),
        ),
        if (!downloading)
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: Text('Stáhnout (~${ModelManager.approximateSizeMb} MB)'),
            onPressed: _downloadModel,
          ),
      ],
    );
  }
}
