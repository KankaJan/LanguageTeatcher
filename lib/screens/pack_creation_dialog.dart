import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/languages.dart';
import '../logic/pack_generator.dart';
import '../services/pack_store.dart';
import '../services/translator.dart';

/// Parent dialog: pick a source and a target language and the app generates
/// the whole word list itself with on-device machine translation (ML Kit —
/// a one-time ~30 MB model download per language, then offline).
class PackCreationDialog extends StatefulWidget {
  const PackCreationDialog({
    super.key,
    required this.packStore,
    this.translatorFactory = MlKitWordTranslator.new,
  });

  final PackStore packStore;
  final TranslatorFactory translatorFactory;

  @override
  State<PackCreationDialog> createState() => _PackCreationDialogState();
}

class _PackCreationDialogState extends State<PackCreationDialog> {
  String _sourceCode = 'cs';
  String _targetCode = 'de';
  bool _generating = false;
  int _done = 0;
  int _total = 1;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _generating = true;
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
      if (mounted) Navigator.of(context).pop();
    } on MissingPluginException {
      // The ML Kit translation module failed to register when the app
      // started; a full restart re-attempts the registration (the app now
      // also self-heals this on startup).
      if (mounted) {
        setState(() {
          _generating = false;
          _error = 'Překladový modul se nenačetl. Úplně zavřete aplikaci '
              '(i z přehledu spuštěných aplikací) a otevřete ji znovu, pak '
              'to zkuste ještě jednou.';
        });
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _generating = false;
          _error = 'Vytvoření se nepodařilo (je telefon online?): $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onChanged: _generating
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
          if (_generating) ...[
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
          onPressed:
              _generating ? null : () => Navigator.of(context).pop(),
          child: const Text('Zrušit'),
        ),
        FilledButton(
          onPressed: _generating || _sourceCode == _targetCode ? null : _create,
          child: const Text('Vytvořit'),
        ),
      ],
    );
  }
}
