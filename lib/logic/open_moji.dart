import '../generated/openmoji_assets.dart';

/// Canonical OpenMoji name for an emoji: FE0F variation selectors stripped,
/// uppercase hex codepoints padded to 4 digits, dash-joined. Mirrors
/// tool/fetch_openmoji.py.
String openMojiNameFor(String emoji) => emoji.runes
    .where((r) => r != 0xFE0F)
    .map((r) => r.toRadixString(16).toUpperCase().padLeft(4, '0'))
    .join('-');

/// Asset path of the bundled OpenMoji illustration for [emoji], or null when
/// none is bundled (the caller then renders the emoji glyph itself).
String? openMojiAssetFor(String emoji) {
  final name = openMojiNameFor(emoji);
  return openMojiAvailable.contains(name) ? 'assets/openmoji/$name.png' : null;
}
