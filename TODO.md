# TODO — Otterly: fix native-library failures (handoff for local session)

Work through this top to bottom in a local checkout of branch
`claude/english-learning-toddler-app-6t0ja1` with the phone connected over
USB (USB debugging on). Everything here assumes `flutter pub get` ran and
`flutter test` is green (86 tests).

## The three reported symptoms, and why they are one bug

1. Creating a language pack fails: „překladový modul se nenačetl“
   (= MissingPluginException on the ML Kit translation channel, even after
   the app explicitly initializes ML Kit and re-registers the plugin —
   see MainActivity.kt).
2. The child gets a star even for wrongly said words.
3. The speech model fails with
   `PlatformException(init_failed, org.vosk.LibVosk, null, null)`.

**Diagnosis.** (3) means the Vosk **native** library did not load
(`org.vosk.LibVosk`'s static initializer loads `libvosk.so` via JNA; when
that fails, later accesses surface as this error). (1) is the same class of
failure in a different stack: ML Kit Translate also bundles native `.so`
libraries, and its plugin registration constructs native-backed objects
eagerly — when that throws, Flutter skips the plugin and every call becomes
MissingPluginException. (2) is purely downstream: scoring never produces a
verdict, and with no scores the lesson awards the participation star
(see `_wordEarnedStar` in lib/screens/lesson_screen.dart).

**Pattern:** every plugin with bundled native code fails (Vosk+JNA, ML Kit
Translate); every pure-platform plugin works (flutter_tts, record,
just_audio, shared_preferences). That is the signature of a **16 KB
memory-page device** (Android 16 era phones) rejecting 4 KB-aligned
prebuilt libraries: vosk-android 0.3.47 (2022) and JNA 5.13 predate the
16 KB requirement. A secondary suspect is R8 stripping JNA/Vosk classes in
release builds — cheap to rule out (task 3).

## Task 1 — confirm the diagnosis (5 minutes)

```
adb shell getconf PAGE_SIZE        # 16384 => 16 KB device, diagnosis confirmed
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
```

Then reproduce with logs:

```
flutter run --release
adb logcat -c && adb logcat | grep -iE "vosk|jna|mlkit|UnsatisfiedLink|GeneratedPluginRegistrant|PageSize"
```

Trigger: app start (watch for a "Error registering plugin
google_mlkit_translation" line), then model download + one lesson
repetition, then pack creation. Keep the stack traces.

## Task 2 — the broad fix: 16 KB compatibility mode

In `android/app/src/main/AndroidManifest.xml`, on the `<application>`
element add:

```xml
android:pageSizeCompat="enabled"
```

This is the Android 16 (API 36; compileSdk is already 36) compatibility
switch that lets 4 KB-aligned native libraries load on 16 KB devices.
It is ignored on older Android versions. Expected to fix BOTH the Vosk
init and ML Kit registration on the affected phone in one line — try this
first and re-test all three symptoms.

## Task 3 — rule out / fix R8 stripping (do regardless; harmless)

1. Create `android/app/proguard-rules.pro`:

   ```
   -keep class org.vosk.** { *; }
   -keep class com.sun.jna.** { *; }
   -dontwarn com.sun.jna.**
   ```

2. In `android/app/build.gradle.kts`, inside `buildTypes { release { ... } }`:

   ```kotlin
   proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
   ```

3. Quick R8-vs-16KB discriminator: `flutter run --debug` (debug builds skip
   R8). If Vosk/ML Kit work in debug but not release → R8 was (also) the
   culprit. If both fail in debug too → alignment/16 KB is confirmed.

## Task 4 — modernize the native deps

- In `android/app/build.gradle.kts` bump JNA:
  `implementation("net.java.dev.jna:jna:5.17.0@aar")` (16 KB-aligned
  Android libs; 5.13 is not).
- Check whether a newer `com.alphacephei:vosk-android` exists on Maven
  Central; if not and Task 2 didn't rescue Vosk on a confirmed 16 KB
  device, the options are (in order):
  a) a community 16 KB rebuild of libvosk,
  b) vendoring libvosk built with `-Wl,-z,max-page-size=16384`,
  c) swapping the scorer to Android's built-in recognizer
     (`speech_to_text` plugin + phonetic match) behind the existing
     `SpeechScorer` interface (lib/services/speech_scorer.dart) — this was
     always the documented fallback in PLAN.md.
- ML Kit: if pack creation still fails after Tasks 2–3, bump
  `google_mlkit_translation` to the newest release (a 16 KB-ready ML Kit
  underneath) and retest cs→pl creation.

## Task 5 — re-test the stars (no code expected)

The star logic is already correctness-aware (`_wordEarnedStar`): once
scoring works, wrongly said words stop earning stars. Decide one design
question while testing: currently a word with NO scores still earns the
participation star, which on a scoring-broken device means "always a
star". If that bothers you, change `_wordEarnedStar` to also return false
when `widget.scorer.lastIssue != null`.

## Task 6 — housekeeping (optional, quality of life)

- Every CI build signs with a fresh debug key, so each install needs an
  uninstall first. Commit a dedicated debug keystore (or set up your own
  release keystore per docs/RELEASE.md) so updates install over the top.
- The parent-mode speech card shows the last scoring failure
  („Poslední hodnocení selhalo: …“) — use it as the quick health check
  after any change.

## Verification checklist (all on the phone)

- [ ] Create a cs→pl pack: completes, flags switch to 🇨🇿→🇵🇱.
- [ ] Download the speech model; run a lesson; say one word wrongly on
      purpose → no star for it; inbox stays small; speech card shows no
      failure.
- [ ] Progress → category detail shows correct/wrong counts growing.
- [ ] `flutter test` still green; push and let CI produce the APK.
