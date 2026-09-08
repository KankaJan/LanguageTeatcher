# Otterly 🦦

A mobile app (Android first, Flutter) that teaches a toddler foreign-language
vocabulary — **voice and pictures only, no written words in child mode**. Each
word is spoken in the child's language, then in the target language, and the
child repeats it aloud while the mic records; answers are scored on-device and
lessons adapt (low-scoring words return next lesson, mastered ones come back
for review later). The parent's recorded voice is preferred, free on-device
TTS covers the rest.

The bundled pack is curated Czech→English; parents can generate **new
language packs for any pair** from ~17 languages — the word list is machine-
translated on the phone (ML Kit, offline after a one-time model download),
editable afterwards, with per-pack progress, recordings, and speech
recognition, and the active pair's flags shown on the start screen.

- **[PLAN.md](PLAN.md)** — the full build plan: product spec, learning
  algorithm, technical architecture, milestones.
- **[content/vocabulary.json](content/vocabulary.json)** — the research-based
  word list (221 Czech↔English pairs in 13 categories) that drives the lesson
  selector; designed to be expanded.

**Status:** all milestones (M0–M6) of the plan are implemented — lesson
player, parent recording studio, adaptive lessons with recorded answers and a
review inbox, on-device speech scoring (optional ~40 MB model download), the
parent progress dashboard, and polish (illustrations, confetti rewards,
two-finger parent gate, app icon). Every push builds an installable APK —
download it from the latest GitHub Actions run (Artifacts →
`language-teatcher-apk`); Play Store publishing steps are in
[docs/RELEASE.md](docs/RELEASE.md).

Word illustrations are [OpenMoji](https://openmoji.org) artwork
(CC BY-SA 4.0), fetched by `tool/fetch_openmoji.py`.
