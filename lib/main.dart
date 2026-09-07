import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/vocabulary.dart';
import 'screens/home_screen.dart';
import 'services/app_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  final vocabularyJson =
      await rootBundle.loadString('content/vocabulary.json');
  final vocabulary = Vocabulary.fromJsonString(vocabularyJson);
  final prefs = await AppPrefs.load();
  runApp(LanguageTeatcherApp(vocabulary: vocabulary, prefs: prefs));
}

class LanguageTeatcherApp extends StatelessWidget {
  const LanguageTeatcherApp({
    super.key,
    required this.vocabulary,
    required this.prefs,
  });

  final Vocabulary vocabulary;
  final AppPrefs prefs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanguageTeatcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF66BB6A)),
      ),
      home: HomeScreen(vocabulary: vocabulary, prefs: prefs),
    );
  }
}
