import 'package:flutter/material.dart';

import '../logic/open_moji.dart';

/// The child-facing "picture": bundled OpenMoji artwork (with the raw emoji
/// glyph as fallback) on a soft colored card. The child mode never shows
/// text, so this card carries all the meaning.
class EmojiCard extends StatelessWidget {
  const EmojiCard({super.key, required this.emoji, this.background});

  final String emoji;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final asset = openMojiAssetFor(emoji);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: background ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(48),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: asset != null
                ? Image.asset(asset, fit: BoxFit.contain)
                : FittedBox(
                    fit: BoxFit.contain,
                    child: Text(emoji, style: const TextStyle(fontSize: 160)),
                  ),
          ),
        ),
      ),
    );
  }
}
