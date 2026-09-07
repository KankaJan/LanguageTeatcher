# LanguageTeatcher — Build Plan

A mobile app that teaches a 3-year-old Czech-speaking child English vocabulary — **by voice and pictures only, no written words in front of the child**.

This document is the plan for building it. The vocabulary the app teaches lives in
[`content/vocabulary.json`](content/vocabulary.json) (221 words, 13 categories, expandable).

---

## 1. What the app does (product spec)

### Two modes

| | Child mode | Parent mode |
|---|---|---|
| **Who** | The 3-year-old | You |
| **Text on screen** | **None** — pictures, colors, animations, audio only | Normal UI with text |
| **Contains** | The daily lesson | Recording studio, review inbox, settings, progress dashboard |
| **Access** | Opens directly into today's lesson | Behind a "parent gate" (e.g. press-and-hold 3 seconds), so the child can't wander in |

### The lesson (the only child-facing flow — no separate test)

A lesson is **N words** (parent setting, e.g. 5 per day). Each word appears **R times**
(parent setting, default 3), interleaved Duolingo-style so repetitions of different
words alternate rather than drilling one word back-to-back.

- **Presentation pass** (first appearance of a word):
  picture fills the screen → voice says the word **in Czech** → short pause →
  voice says it **in English** → invitation to repeat it.
- **Production passes** (appearances 2…R):
  picture + Czech word + a recorded prompt ("A jak se to řekne anglicky?") →
  the app **records the child for ~4 seconds** → the recording is **speech-analysed**
  and scored → gentle feedback either way: the correct English audio is always
  replayed, success gets a cheer/confetti, a miss gets encouragement — never a
  sad sound or punishment.
- **After the R-th repetition** the app computes the word's **average score**:
  - **below threshold** → the word is queued into the **next lesson**;
  - **at/above threshold** → the word is marked *known* and scheduled to come back
    for review after **K lessons** (parameter, default **5**).
- Lesson ends with a small celebration and closes itself (screen-time friendly).

### Scoring and the adult fallback

Automatic speech recognition of toddler speech is genuinely hard, so scoring has
three outcomes per attempt:

1. **Confident match** with the expected English word → scored correct.
2. **Confident mismatch / silence** → scored incorrect.
3. **Unsure** → the recording goes to the **review inbox** in parent mode. You
   replay it whenever convenient and tap ✓/✗ — you don't have to sit through
   lessons. Until reviewed, an unsure attempt counts as "needs practice" (the safe
   direction: the word gets extra repetition rather than being skipped).

You can also override *any* automatic score from the inbox, which doubles as a
tuning signal for the recognition thresholds.

### Whose voice the child hears

- **Your recordings first**: parent mode has a **recording studio** listing every
  word in the vocabulary; for each you can record the Czech and/or English audio,
  play it back, re-record. Recordings are stored on the phone.
- **Free device TTS as fallback**: any word (or language side) you haven't recorded
  is spoken by the phone's built-in text-to-speech (Google TTS voices for `cs-CZ`
  and `en-US` — free, works offline once the voices are downloaded). No paid
  voice-cloning service is used.

### Parent-controllable parameters (settings screen)

| Parameter | Default | Meaning |
|---|---|---|
| Words per lesson (N) | 5 | Lesson length — "number of words per day" |
| Repetitions per word (R) | 3 | How many times each word cycles within a lesson |
| Review interval (K) | 5 lessons | How many lessons before a *known* word comes back |
| Pass threshold | 0.6 | Average score needed to mark a word *known* |
| ASR confidence bounds | tunable | Below → unsure→inbox; above → auto-scored |
| Recording window | 4 s | How long the app listens for the child's answer |

---

## 2. Vocabulary: what to teach and in what order

### What the research says

- **MacArthur-Bates CDI** (the standard parent-report inventory of early
  vocabulary, organized into semantic categories) shows toddlers' earliest words
  cluster in: **people** ("mommy" is produced by ~93 % of 16-month-olds),
  **routines/greetings** (hi, bye-bye, night-night), **animals** and **toys**
  (over-represented relative to adult speech), then **food, body parts, vehicles,
  household items and action words**.
- **First-100-words guidance** from speech-language practice: a healthy early
  vocabulary is *not* nouns only — it needs **verbs, descriptive words and
  location words** (up/down, big/small) so the child can start combining.
- **Cambridge Pre-A1 Starters** (the youngest-learner EFL standard, ~500 words)
  organizes vocabulary into the same familiar themes: my body, animals/zoo,
  clothes, food, home, transport — confirming the category structure works for
  English-as-a-foreign-language learning, not just native acquisition.

Sources:
[CDI: Words and Gestures (Hanen)](https://hanen.org/shop/cdi-words-and-gestures) ·
[CDI Words & Gestures form (U. of Houston)](https://www.uh.edu/class/psychology/dcbn/research/cognitive-development/_docs/mcdigestures.pdf) ·
[Multiplex lexical networks in early word acquisition (arXiv)](https://arxiv.org/pdf/1609.03207) ·
[Cambridge Pre-A1/A1/A2 official wordlist (PDF)](https://www.cambridgeenglish.org/Images/506166-starters-movers-flyers-word-list-2025.pdf) ·
[Starters vocabulary topics](https://flyer.us/cambridge-starters-vocabulary/) ·
[First 100 words (Teach Me To Talk)](https://teachmetotalk.com/2008/02/12/first-100-words-advancing-your-toddlers-vocabulary-with-words-and-signs/) ·
[First 100 words list (Kids SLT)](https://kidssltessentials.com/wp-content/uploads/2022/02/First-100-words-List.pdf) ·
[Vocabulary development (Wikipedia)](https://en.wikipedia.org/wiki/Vocabulary_development)

### The word list — `content/vocabulary.json`

221 Czech↔English word pairs in 13 categories, ordered by the acquisition research
above. Lesson ranges below assume the default 5 new words/lesson (they shift when
failed words carry over or settings change — the ranges are guidance for the
selector, not hard boundaries):

| # | Category | Words | Suggested lessons |
|---|---|---|---|
| 1 | First words & greetings (ahoj, pá pá, děkuji, kuk…) | 10 | 1–2 |
| 2 | Animals | 30 | 3–8 |
| 3 | Family & people | 12 | 9–11 |
| 4 | My body | 15 | 12–14 |
| 5 | Food & drink | 28 | 15–20 |
| 6 | Colors | 10 | 21–22 |
| 7 | Numbers 1–10 | 10 | 23–24 |
| 8 | Home & toys | 22 | 25–29 |
| 9 | Clothes | 10 | 30–31 |
| 10 | Vehicles | 12 | 32–34 |
| 11 | Outside & nature | 18 | 35–38 |
| 12 | Actions (verbs) | 26 | 39–44 |
| 13 | Opposites & feelings | 18 | 45–48 |

**Format** (designed to be expanded): each word is one JSON entry —
`{id, en, cz, category, order, emoji}` — and each category carries an `order` and a
`suggested_lessons` range. Adding vocabulary later = appending entries; nothing else
changes. The `emoji` is a placeholder picture hint until real illustrations are
added (a few words have `null` where no fitting emoji exists).

**Translation notes** (flagged deliberately):
- Czech color names use the feminine form (červená, modrá) — how Czechs actually name colors.
- *leg* = "noha", *foot* = "chodidlo" — Czech kids often say "noha" for both; the picture disambiguates.
- Verbs are stored as infinitives (jíst, spát); recorded prompts in the app can use imperatives naturally.
- *stop* is stored as cz "stůj" (Czech also uses "stop", which would make the CZ→EN task trivial).
- Duplicated English forms get distinct ids: `orange_fruit` vs `orange_color`.

---

## 3. Technical architecture

**Stack: Flutter + Dart, Android first.** One codebase that can later target iOS;
strong animation/audio support for a picture-only kids UI. Everything runs
**offline on the phone — no backend, no accounts, no child data leaving the
device** (recordings of the child stay local; that's a privacy feature, not just a
simplification).

### Key packages

| Concern | Package | Notes |
|---|---|---|
| Audio playback | `just_audio` | Parent recordings + pre-cached TTS |
| Microphone recording | `record` | Child attempts + parent studio |
| Text-to-speech | `flutter_tts` | Free on-device Google TTS, `cs-CZ` + `en-US`, offline once voices downloaded |
| Speech analysis | `vosk_flutter` | Offline ASR, small English model (~40 MB) bundled |
| Local database | `drift` (SQLite) | Progress, attempts, settings |
| State management | `riverpod` | Simple, testable |

### Speech analysis design (the hard part)

- Vosk is run with a **constrained-vocabulary grammar**: for each attempt the
  recognizer only chooses between the *expected word*, a handful of *distractors*
  (other lesson words), and *unknown*. Single-word recognition against ~10
  candidates is far more reliable than open dictation, and yields a confidence
  score.
- Confidence above the upper bound → auto-score (match=1, mismatch=0). Between
  bounds → **unsure → review inbox**. Silence/too short → scored 0 but also shown
  in the inbox.
- **Fallback plan** if Vosk proves too unreliable for toddler speech: Android's
  built-in recognizer via `speech_to_text`, its transcript fuzzy-matched
  phonetically (e.g. double-metaphone + edit distance) against the expected word.
  The three-outcome scoring and inbox stay identical, so the analyser is swappable.
- Honest expectation: a 3-year-old's "elephant" may defeat any recognizer. The
  system is designed so that ASR mistakes only ever cost *extra practice or a
  quick parent review* — never a wrongly "mastered" word.

### Word selector algorithm

Next lesson = take up to N words, in priority order:

1. **Failed words** from the previous lesson (average score below threshold);
2. **Due reviews** — known words whose K-lesson timer just expired;
3. **New words** — next unseen words following `vocabulary.json` category/word order.

A known word that fails its review is demoted back into rotation. If failed words
alone exceed N, they are capped so at least one new word appears (keeps lessons
from becoming pure remediation).

### Data model (SQLite via drift)

- `words` — imported from `vocabulary.json` + paths to parent recordings (cz/en) if made
- `word_progress` — per word: state (`new` / `learning` / `known`), rolling average score, `due_lesson`
- `lessons` — lesson number, date, word ids, completed flag
- `attempts` — word id, lesson id, repetition #, recording path, ASR confidence, auto score, adult override
- `settings` — N, R, K, thresholds, recording window

---

## 4. Milestones

Each milestone is a working app you can put in front of your son.

| # | Deliverable | You get |
|---|---|---|
| **M0** | Flutter project scaffold, CI (`flutter analyze` + tests), runs on an Android emulator | A skeleton that builds |
| **M1** | Lesson player: presentation passes only, vocabulary.json + emoji pictures + device TTS, fixed word order, N configurable | **Usable app** — he hears Czech→English with pictures from day one |
| **M2** | Parent mode + recording studio (record/re-record cz+en per word, playback preference: parent recording ▸ TTS) | Lessons in **your voice** |
| **M3** | Production passes: child recording + review inbox with manual ✓/✗ scoring (no ASR yet), average-score carryover into next lesson | The **full adaptive loop**, you grade from the inbox |
| **M4** | Vosk auto-scoring with unsure→inbox fallback, threshold settings | Grading becomes mostly automatic |
| **M5** | Full selector (K-lesson review scheduling, demotion on failed review) + progress dashboard (words known / learning / struggling) | **Complete learning engine** |
| **M6** | Polish: rewards/animations, parent gate, app icon, real illustrations replacing emoji, signed release APK / Play internal testing | Installable, kid-proof app |

Suggested build order rationale: M1 delivers value immediately; M3 proves the
pedagogical loop with a human grader *before* investing in ASR (M4), so the risky
part is de-risked last.

### Verification per milestone

- `flutter analyze` and `flutter test` green (unit tests for the selector
  algorithm and scoring math are the critical ones — they're pure Dart and easy to test).
- Manual script on emulator/phone per milestone (e.g. M3: complete a lesson,
  check failed word appears in next lesson; grade an unsure attempt from the
  inbox and watch the score update).
- Install path for your phone: `flutter build apk` → sideload; later Play Store
  internal testing track if you want painless updates.

---

## 5. Out of scope (for now)

- iOS build (kept possible by Flutter; revisit after M6)
- Voice cloning of the parent's voice (decided against — free TTS covers unrecorded words)
- Multiple child profiles, cloud sync/backup, phrases & sentences beyond single words
- In-app editing of the vocabulary list (edit the JSON for now; a UI can come later)
