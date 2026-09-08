import 'package:flutter/material.dart';

import '../logic/languages.dart';
import '../logic/open_moji.dart';
import '../models/language_pack.dart';
import '../services/app_prefs.dart';
import '../services/model_manager.dart';
import '../services/pack_store.dart';
import '../services/progress_store.dart';
import '../services/recording_store.dart';
import '../services/speech_scorer.dart';
import '../widgets/parent_gate.dart';
import 'lesson_screen.dart';
import 'parent_screen.dart';

/// Child-facing start screen: the otter, the active pack's flags, and one
/// giant play button — no text. The parent section hides behind the
/// two-finger gate on the corner icon.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.pack,
    required this.packStore,
    required this.prefs,
    required this.recordings,
    required this.progress,
    required this.models,
    required this.scorer,
  });

  final LanguagePack pack;
  final PackStore packStore;
  final AppPrefs prefs;
  final RecordingStore recordings;
  final ProgressStore progress;
  final ModelManager? models;
  final SpeechScorer scorer;

  @override
  Widget build(BuildContext context) {
    final source = languageByCode(pack.sourceCode);
    final target = languageByCode(pack.targetCode);
    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F0),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _OtterMascot(),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(source.flag, style: const TextStyle(fontSize: 30)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward_rounded,
                            size: 24, color: Colors.brown),
                      ),
                      Text(target.flag, style: const TextStyle(fontSize: 30)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _PlayButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LessonScreen(
                            pack: pack,
                            prefs: prefs,
                            recordings: recordings,
                            progress: progress,
                            scorer: scorer,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              // Parent mode sits behind a two-finger-hold gate a toddler
              // can't pass by tapping around.
              child: GestureDetector(
                onTap: () async {
                  final unlocked = await ParentGateDialog.show(context);
                  if (!unlocked || !context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ParentScreen(
                        pack: pack,
                        packStore: packStore,
                        prefs: prefs,
                        recordings: recordings,
                        progress: progress,
                        models: models,
                        scorer: scorer,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.settings,
                    size: 26,
                    color: Colors.brown.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtterMascot extends StatelessWidget {
  const _OtterMascot();

  @override
  Widget build(BuildContext context) {
    final asset = openMojiAssetFor('🦦');
    return SizedBox(
      width: 140,
      height: 140,
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.contain)
          : const FittedBox(child: Text('🦦', style: TextStyle(fontSize: 96))),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.94,
    upperBound: 1.06,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: Material(
        shape: const CircleBorder(),
        color: const Color(0xFF66BB6A),
        elevation: 8,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: widget.onPressed,
          child: const SizedBox(
            width: 168,
            height: 168,
            child: Icon(Icons.play_arrow_rounded, size: 110, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
