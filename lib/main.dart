import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic/languages.dart';
import 'models/language_pack.dart';
import 'models/vocabulary.dart';
import 'screens/home_screen.dart';
import 'services/app_prefs.dart';
import 'services/model_manager.dart';
import 'services/pack_store.dart';
import 'services/progress_store.dart';
import 'services/recording_store.dart';
import 'services/speech_scorer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final vocabularyJson =
      await rootBundle.loadString('content/vocabulary.json');
  final vocabulary = Vocabulary.fromJsonString(vocabularyJson);
  final prefs = await AppPrefs.load();
  final packStore =
      await PackStore.open(baseVocabulary: vocabulary, prefs: prefs);
  runApp(OtterlyApp(prefs: prefs, packStore: packStore));
}

class OtterlyApp extends StatelessWidget {
  const OtterlyApp({
    super.key,
    required this.prefs,
    required this.packStore,
  });

  final AppPrefs prefs;
  final PackStore packStore;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Otterly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A)),
      ),
      home: ActivePackScope(prefs: prefs, packStore: packStore),
    );
  }
}

/// Everything below the start screen is scoped to the active language pack:
/// its own progress, its own parent recordings, its own speech model. This
/// widget rebuilds that service set whenever the parent switches packs.
class ActivePackScope extends StatefulWidget {
  const ActivePackScope({
    super.key,
    required this.prefs,
    required this.packStore,
  });

  final AppPrefs prefs;
  final PackStore packStore;

  @override
  State<ActivePackScope> createState() => _ActivePackScopeState();
}

class _PackServices {
  const _PackServices({
    required this.pack,
    required this.recordings,
    required this.progress,
    required this.models,
    required this.scorer,
  });

  final LanguagePack pack;
  final RecordingStore recordings;
  final ProgressStore progress;
  final ModelManager? models;
  final SpeechScorer scorer;
}

class _ActivePackScopeState extends State<ActivePackScope> {
  LanguagePack? _builtForPack;
  Future<_PackServices>? _services;

  @override
  void initState() {
    super.initState();
    widget.packStore.addListener(_onPackStoreChanged);
    _rebuildIfNeeded();
  }

  @override
  void dispose() {
    widget.packStore.removeListener(_onPackStoreChanged);
    super.dispose();
  }

  void _onPackStoreChanged() => _rebuildIfNeeded();

  void _rebuildIfNeeded() {
    final active = widget.packStore.active;
    // A word edit replaces the pack instance, so identity, not id, decides.
    if (identical(active, _builtForPack)) return;
    setState(() {
      _builtForPack = active;
      _services = _build(active);
    });
  }

  Future<_PackServices> _build(LanguagePack pack) async {
    final store = widget.packStore;
    final recordings = RecordingStore(store.recordingsDirFor(pack.id));
    await recordings.refresh();
    final progress = ProgressStore(
      store.progressFileFor(pack.id),
      store.attemptsDirFor(pack.id),
    );
    await progress.load();
    final voskModel = languageByCode(pack.targetCode).voskModel;
    final models = voskModel == null
        ? null
        : await ModelManager.open(modelName: voskModel);
    return _PackServices(
      pack: pack,
      recordings: recordings,
      progress: progress,
      models: models,
      scorer: VoskScorer(models),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PackServices>(
      future: _services,
      builder: (context, snapshot) {
        final services = snapshot.data;
        if (services == null) {
          return const Scaffold(
            backgroundColor: Color(0xFFFDF8F0),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return HomeScreen(
          key: ValueKey(services.pack.id),
          pack: services.pack,
          packStore: widget.packStore,
          prefs: widget.prefs,
          recordings: services.recordings,
          progress: services.progress,
          models: services.models,
          scorer: services.scorer,
        );
      },
    );
  }
}
