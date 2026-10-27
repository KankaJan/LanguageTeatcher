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
class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final packStore = widget.packStore;
    final prefs = widget.prefs;
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
                  _FlagPair(
                    source: source,
                    target: target,
                    // Only when the parent allowed it and there is something
                    // to switch to; otherwise the flags are a plain label.
                    onTap: prefs.childCanSwitchPacks &&
                            packStore.packs.length > 1
                        ? () => _PackPickerSheet.show(context, packStore)
                        : null,
                  ),
                  const SizedBox(height: 32),
                  _PlayButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LessonScreen(
                            pack: pack,
                            prefs: prefs,
                            recordings: widget.recordings,
                            progress: widget.progress,
                            scorer: widget.scorer,
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
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ParentScreen(
                        pack: pack,
                        packStore: packStore,
                        prefs: prefs,
                        recordings: widget.recordings,
                        progress: widget.progress,
                        models: widget.models,
                        scorer: widget.scorer,
                      ),
                    ),
                  );
                  // Parent settings (e.g. whether the child may switch
                  // packs) are read at build time; pick them up on return.
                  if (mounted) setState(() {});
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

/// The active pack's flags. Tappable (with a small hint chevron) only when
/// [onTap] is set — see AppPrefs.childCanSwitchPacks.
class _FlagPair extends StatelessWidget {
  const _FlagPair({
    required this.source,
    required this.target,
    this.onTap,
    this.flagSize = 30,
  });

  final Language source;
  final Language target;
  final VoidCallback? onTap;
  final double flagSize;

  @override
  Widget build(BuildContext context) {
    final flags = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(source.flag, style: TextStyle(fontSize: flagSize)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded,
              size: flagSize * 0.8, color: Colors.brown),
        ),
        Text(target.flag, style: TextStyle(fontSize: flagSize)),
        if (onTap != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.expand_more_rounded,
                size: flagSize * 0.7,
                color: Colors.brown.withValues(alpha: 0.5)),
          ),
      ],
    );
    if (onTap == null) return flags;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: flags,
        ),
      ),
    );
  }
}

/// Text-free pack chooser for the child: one big flag pair per pack, the
/// active one outlined. Picking one activates it; ActivePackScope then
/// rebuilds the start screen for the new pack.
class _PackPickerSheet extends StatelessWidget {
  const _PackPickerSheet({required this.packStore});

  final PackStore packStore;

  static Future<void> show(BuildContext context, PackStore packStore) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFFFDF8F0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _PackPickerSheet(packStore: packStore),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeId = packStore.active.id;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final pack in packStore.packs)
              _PackChoice(
                pack: pack,
                selected: pack.id == activeId,
                onTap: () async {
                  Navigator.of(context).pop();
                  if (pack.id != activeId) {
                    await packStore.activate(pack.id);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PackChoice extends StatelessWidget {
  const _PackChoice({
    required this.pack,
    required this.selected,
    required this.onTap,
  });

  final LanguagePack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: selected ? color : Colors.transparent,
          width: 4,
        ),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: _FlagPair(
            source: languageByCode(pack.sourceCode),
            target: languageByCode(pack.targetCode),
            flagSize: 44,
          ),
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
