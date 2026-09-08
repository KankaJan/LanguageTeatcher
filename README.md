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

**Status:** milestones M0–M5 of the plan are implemented — lesson player,
parent recording studio, adaptive lessons with recorded answers and a review
inbox, on-device speech scoring (optional ~40 MB model download), and the
parent progress dashboard. Remaining: M6 polish (rewards, sturdier parent
gate, real illustrations, app icon, release). Every push builds an
installable APK — download it from the latest GitHub Actions run
(Artifacts → `language-teatcher-apk`).
