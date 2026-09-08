# LanguageTeatcher

A mobile app (Android first, Flutter) that teaches a 3-year-old Czech-speaking
child English vocabulary — **voice and pictures only, no written words in child
mode**. Words are spoken in Czech, then in English, in the parent's recorded
voice where available and free on-device TTS otherwise. Lessons repeat each word
several times, score the child's spoken answers, and adapt: low-scoring words
return in the next lesson, mastered words come back for review a few lessons
later.

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
