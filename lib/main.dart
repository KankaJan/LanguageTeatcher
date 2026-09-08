import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/vocabulary.dart';
import 'screens/home_screen.dart';
import 'services/app_prefs.dart';
import 'services/model_manager.dart';
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
  final recordings = await RecordingStore.open();
  final progress = await ProgressStore.open();
  final models = await ModelManager.open();
  runApp(OtterlyApp(
    vocabulary: vocabulary,
    prefs: prefs,
    recordings: recordings,
    progress: progress,
    models: models,
    scorer: VoskScorer(models),
  ));
}

class OtterlyApp extends StatelessWidget {
  const OtterlyApp({
    super.key,
    required this.vocabulary,
    required this.prefs,
    required this.recordings,
    required this.progress,
    required this.models,
    required this.scorer,
  });

  final Vocabulary vocabulary;
  final AppPrefs prefs;
  final RecordingStore recordings;
  final ProgressStore progress;
  final ModelManager models;
  final SpeechScorer scorer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Otterly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A)),
      ),
      home: HomeScreen(
        vocabulary: vocabulary,
        prefs: prefs,
        recordings: recordings,
        progress: progress,
        models: models,
        scorer: scorer,
      ),
    );
  }
}
