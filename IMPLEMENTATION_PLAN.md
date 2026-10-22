# Otterly — native-library failures: TODO summary and implementation plan

Branch: `claude/english-learning-toddler-app-6t0ja1`. Source of truth for the
problem statement: `TODO.md` in the repo root. This file is the execution plan
for the model doing the work. Read `TODO.md` once, then follow this file top to
bottom. Every step says what to do, what output to expect, and what to do when
the output differs.

Hard rules for the implementer:

- Never claim a step is done without the command output or the file diff.
- Do not skip a "GATE" step; the later steps depend on its outcome.
- Do not edit Dart logic in `lib/` except where this plan names the file,
  function and exact change.
- Run `flutter test` after every code change; 86 tests must stay green.
- Commit after each task with the task number in the message.

---

## 1. TODO.md in headlines

1. **Three symptoms, one suspected cause** — pack creation says the
   translation module did not load (MissingPluginException on the ML Kit
   channel); children get a star for wrong words; Vosk fails with
   `PlatformException(init_failed, org.vosk.LibVosk, null, null)`.
2. **Suspected root cause: 16 KB page-size device** — prebuilt
   `libvosk.so` (vosk-android 0.3.47, 2022) and JNA 5.13 are 4 KB-aligned;
   newer phones reject them. The star bug is only downstream: no score → the
   lesson awards the participation star.
3. **Secondary suspect: R8** stripping/renaming JNA and Vosk classes in
   release builds.
4. **Task 1 — confirm on the phone**: `getconf PAGE_SIZE`, then logcat while
   reproducing all three symptoms.
5. **Task 2 — one-line compat switch**: `android:pageSizeCompat="enabled"`
   on `<application>`.
6. **Task 3 — ProGuard keep rules** for `org.vosk.**` and `com.sun.jna.**`;
   debug-vs-release build as the R8 discriminator.
7. **Task 4 — modernize native deps**: bump JNA, look for a newer
   vosk-android, fall back to a rebuilt libvosk or to Android's built-in
   recognizer (`speech_to_text`) behind the existing `SpeechScorer`
   interface; bump `google_mlkit_translation` if packs still fail.
8. **Task 5 — re-test stars**; optional design change: no star when
   `scorer.lastIssue != null`.
9. **Task 6 — housekeeping**: stable debug keystore so CI APKs install over
   each other; use the parent-mode speech card as the health check.
10. **Verification checklist** — cs→pl pack, wrong word earns no star,
    progress counts grow, tests green, CI APK.

---

## 2. Corrections to TODO.md (verified 2026-10-22, before starting)

The TODO was written without the phone. Four of its assumptions do not hold
and change the order of work.

1. **`android:pageSizeCompat="enabled"` is not a fix switch.** Per Google's
   page-size documentation, on a 16 KB device the package manager turns
   backcompat mode on *automatically* when an APK contains 4 KB-aligned
   `.so` files, and shows a one-time "running in compatibility mode"
   warning. The manifest attribute only overrides/suppresses that. So:
   - if the phone has shown that warning for Otterly, compat mode is already
     on and the libraries still fail → the attribute changes nothing;
   - if the phone never showed it, either the libraries are already aligned
     (then the TODO diagnosis is wrong) or the OEM build has no backcompat.
   Add the attribute anyway (it is harmless), but do not expect it to fix
   anything and do not stop there.
2. **ML Kit Translate is already 16 KB-ready.** `google_mlkit_translation`
   0.15.1 (latest, Aug 2026) pins `com.google.mlkit:translate:17.0.3`;
   Google's ML Kit release notes of 2024-08-07 list 17.0.3 among the SDKs
   updated for 16 KB pages. Symptom 1 is therefore most likely a *different*
   bug from symptom 3, and bumping the plugin changes nothing (same 17.0.3
   underneath). It needs its own stack trace (step 3.3).
3. **A newer vosk-android exists: 0.3.75** on Maven Central (published
   roughly Dec 2025). Whether its `libvosk.so` is 16 KB-aligned is not
   documented — check it with `llvm-objdump` (step 3.2) instead of guessing.
4. **JNA:** the 16 KB fixes shipped in 5.16.0 and 5.17.0 ("part 2"); the
   newest release is 5.19.1, which also restored support for older Android.
   Use 5.19.1, not 5.17.0.
5. **The error text `org.vosk.LibVosk` is a symptom of lost information.**
   On Android, that bare class name is the `NoClassDefFoundError` you get
   when a class's static initializer *already failed earlier*. The first
   failure (the one with the real `dlopen`/`UnsatisfiedLinkError` text) was
   thrown as `ExceptionInInitializerError`, whose `message` is null, and
   `VoskScorerChannel.kt` only forwards `e.message`. Fixing the bridge to
   forward the cause chain (step 3.1) turns every later failure into a
   readable one on the parent-mode card. Do this first; it costs ten lines
   and makes all other steps diagnosable without logcat.

Alignment can be checked **without the phone**, on the CI APK. That is the
real Task 1, and it decides whether the 16 KB theory is right at all.

---

## 3. Implementation plan

### Task 0 — environment (no code)

```
flutter --version            # need >= 3.27 (Flutter engine 16 KB support)
flutter pub get
flutter test                 # expect: 86 passed
flutter analyze              # expect: No issues found
```

If `flutter test` is not green, stop and report; nothing below is valid on a
broken baseline.

### Task 1 — make failures readable (`android/app/src/main/kotlin/cz/kankajan/otterly/VoskScorerChannel.kt`)

Add a helper and use it in both `catch (e: Throwable)` blocks:

```kotlin
/** Class name + message of a throwable and its whole cause chain; the
 *  Vosk/JNA bridge hides the real reason (dlopen text) one or two causes
 *  deep, and ExceptionInInitializerError has a null message. */
private fun describe(t: Throwable): String {
    val parts = mutableListOf<String>()
    var cur: Throwable? = t
    var depth = 0
    while (cur != null && depth < 6) {
        parts += "${cur.javaClass.name}: ${cur.message ?: "(no message)"}"
        cur = cur.cause
        depth++
    }
    return parts.joinToString(" <- ")
}
```

Change `result.error("init_failed", e.message, null)` to
`result.error("init_failed", describe(e), null)` and
`result.error("score_failed", e.message, null)` to
`result.error("score_failed", describe(e), null)`.

Also log it so logcat has it even when the parent card is not open:
`android.util.Log.e("VoskScorer", "initModel failed", e)` before posting.

No Dart change: `VoskScorer` already stores `e.toString()` in `lastIssue`
and `parent_screen.dart` shows it. Build must still compile:
`flutter build apk --debug`.

### Task 2 — GATE: is the APK 16 KB-aligned? (no phone needed)

Build and inspect the release APK:

```
flutter build apk --release
mkdir -p /tmp/apk && unzip -o -q build/app/outputs/flutter-apk/app-release.apk -d /tmp/apk
ls /tmp/apk/lib/arm64-v8a/
```

Expect at least `libvosk.so`, `libjnidispatch.so`, `libflutter.so`,
`libapp.so`, and the ML Kit translate libraries.

For every `.so` in `lib/arm64-v8a/` run (NDK path: `$ANDROID_HOME/ndk/<version>/toolchains/llvm/prebuilt/linux-x86_64/bin/`):

```
llvm-objdump -p <file>.so | grep LOAD
```

Read the `align` column: `2**14` (= 16 KB) is aligned; `2**12` is 4 KB
(not aligned). Alternatively Google's `check_elf_alignment.sh` script prints
ALIGNED/UNALIGNED per library. Also run
`$ANDROID_HOME/build-tools/35.0.0/zipalign -c -P 16 -v 4 app-release.apk`
and expect "Verification successful" (AGP 9.1 should already do this).

Record the result in a table in your report. Then branch:

- **A. `libvosk.so` or `libjnidispatch.so` is 2**12** → 16 KB theory is
  plausible for symptom 3. Continue with Task 3, then Task 4.
- **B. everything is 2**14** → the 16 KB theory is wrong. Skip Task 4's
  native-dep hunt as a *fix* (still do the version bumps, they are cheap)
  and treat R8 (Task 4) and the ML Kit registration (Task 6) as the live
  suspects.

Also check the phone, once it is attached:

```
adb shell getconf PAGE_SIZE                 # 16384 or 4096
adb shell getprop ro.product.model
adb shell getprop ro.build.version.release
```

A 4096 result with branch A means the alignment is a latent problem but not
today's bug — say so in the report and keep looking (Task 4, Task 6).

### Task 3 — compat attribute (TODO Task 2)

`android/app/src/main/AndroidManifest.xml`, on `<application>`, add
`android:pageSizeCompat="enabled"`. Keep the other attributes. Commit.
This only suppresses the warning / forces compat where the OEM supports it;
see section 2 item 1. Note for the test on the phone: if the app previously
showed the compat-mode warning dialog, say so in the report.

### Task 4 — R8 rules + GATE: debug vs release (TODO Task 3)

1. Create `android/app/proguard-rules.pro`:

   ```
   # Vosk uses JNA direct mapping; R8 must not rename or strip either side.
   -keep class org.vosk.** { *; }
   -keep class com.sun.jna.** { *; }
   -keep class * extends com.sun.jna.** { *; }
   -keep class * implements com.sun.jna.** { *; }
   -dontwarn com.sun.jna.**
   -dontwarn java.awt.**
   ```

2. `android/app/build.gradle.kts`, inside `buildTypes { release { ... } }`,
   after the `signingConfig` line:

   ```kotlin
   proguardFiles(
       getDefaultProguardFile("proguard-android-optimize.txt"),
       "proguard-rules.pro",
   )
   ```

   Flutter's Gradle plugin enables R8 for release builds by itself; do not
   add `isMinifyEnabled` lines.

3. GATE on the phone: `flutter run --debug` (no R8), download the speech
   model (parent mode), run one lesson repetition, open the parent speech
   card.
   - Vosk works in debug but failed in release before → R8 was (part of)
     the cause; the rules above are the fix. Verify with
     `flutter run --release` after the rules.
   - Vosk fails in debug too → read the new `lastIssue` text (Task 1). It
     now contains the real reason: `dlopen failed ... page size` or similar
     text means alignment (go to Task 5); a `ClassNotFoundException` means
     packaging; anything about the model directory means the download, not
     the library.

### Task 5 — native dependency bumps (TODO Task 4)

In `android/app/build.gradle.kts` `dependencies {}`:

```kotlin
implementation("com.alphacephei:vosk-android:0.3.75")
implementation("net.java.dev.jna:jna:5.19.1@aar")
```

Then repeat Task 2's `llvm-objdump` check on the new APK. Expected: JNA's
`libjnidispatch.so` now `2**14`. `libvosk.so` from 0.3.75: unknown — this
check is the answer. Record both.

- If both are `2**14` → rebuild, re-test on the phone (debug and release).
  If Vosk works, Task 5 is done; go to Task 6.
- If `libvosk.so` is still `2**12` and the phone is a 16 KB device →
  escalate to Jan with the three options from TODO Task 4 (community
  rebuild, vendoring a libvosk linked with `-Wl,-z,max-page-size=16384`, or
  the `speech_to_text` fallback behind `SpeechScorer`). Do **not** start the
  `speech_to_text` rewrite on your own; it is a product decision (the
  built-in recognizer needs the Google app / network on many phones, which
  contradicts the offline design in PLAN.md).

`google_mlkit_translation`: already at the latest (0.15.1 → translate
17.0.3). No bump available; do not touch `pubspec.yaml` for it.

### Task 6 — the ML Kit registration failure (symptom 1, separate bug)

Treat independently of Vosk. Evidence first:

```
adb logcat -c
flutter run --release      # or install the CI APK and open it
adb logcat | grep -iE "GeneratedPluginRegistrant|mlkit|MlKit|translation"
```

Look for `Error registering plugin google_mlkit_translation` followed by a
stack trace. Save the full trace in the report. Then, by cause:

- `MlKitContext ... not initialized` / `IllegalStateException` → the
  `MlKitInitProvider` content provider did not run. Check the merged
  manifest: `build/app/intermediates/merged_manifests/release/AndroidManifest.xml`
  must contain a `<provider>` whose name contains `MlKitInitProvider`
  (or `MlKitComponentDiscoveryService`). If it is missing, something in the
  build removed it; report it. If present, `MainActivity.initializeMlKit`'s
  reflection must be hitting a different class name — print the caught
  throwable in `initializeMlKit` (currently swallowed) and read it.
- `UnsatisfiedLinkError` / `dlopen` → an alignment problem after all; check
  the ML Kit `.so` files in Task 2's table.
- `NoClassDefFoundError` / `ClassNotFoundException` on a `com.google.mlkit`
  class → R8; add `-keep class com.google.mlkit.** { *; }` to
  `proguard-rules.pro` and retest.
- No "Error registering plugin" line at all, but the Dart side still gets
  `MissingPluginException` → the exception comes from a specific call. In
  `lib/screens/pack_creation_dialog.dart` the `on MissingPluginException`
  branch hides which call failed; temporarily log `e.message` (it names the
  method and channel) and report it.

Minimal diagnostic change allowed in Kotlin: in `MainActivity.initializeMlKit`
and the plugin re-registration `catch (_: Throwable)`, replace with
`catch (t: Throwable) { android.util.Log.e("Otterly", "...", t) }`. Keep
the swallow; just log.

### Task 7 — stars (TODO Task 5)

`lib/screens/lesson_screen.dart`, `_wordEarnedStar`: no change by default.
Once scoring works, correctness already drives the star (`avg >=
ProgressStore.passThreshold`).

DECISION FOR JAN, not for the implementer: should a word with *no* score
(scorer failed, no model, no mic) still earn the participation star? If Jan
says no, the change is exactly:

```dart
if (scores.isEmpty) return widget.scorer.lastIssue == null;
```

and add a test in `test/` with a fake `SpeechScorer` whose `lastIssue` is
non-null. Note the side effect: phones without a downloaded model would
award no stars at all until the model is installed. Default: leave as is.

### Task 8 — stable debug keystore (TODO Task 6)

Goal: CI APKs install over the previous install instead of requiring an
uninstall.

1. Generate once, locally:

   ```
   keytool -genkey -v -keystore android/app/debug.keystore \
     -storepass android -alias androiddebugkey -keypass android \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -dname "CN=Android Debug,O=Android,C=US"
   ```

2. `android/.gitignore` ignores `**/*.keystore` and `**/*.jks`. Add the line
   `!app/debug.keystore` after those two lines so this one file is tracked.
   Commit it. (A debug key is not a secret; the Play keystore in
   `docs/RELEASE.md` is, and stays ignored.)

3. `android/app/build.gradle.kts`, inside `android { }`, before
   `buildTypes`:

   ```kotlin
   signingConfigs {
       getByName("debug") {
           storeFile = file("debug.keystore")
           storePassword = "android"
           keyAlias = "androiddebugkey"
           keyPassword = "android"
       }
   }
   ```

   The release block already uses `signingConfigs.getByName("debug")`, so
   release APKs from CI and from the laptop now share one key. On the phone
   the *next* install still needs one uninstall (the old key differs); after
   that updates install in place.

4. CI needs no change; it checks out the keystore with the repo.

### Task 9 — verification (TODO checklist) and report

On the phone, release build (`flutter run --release` or the CI APK):

- [ ] Parent mode → create a cs→pl pack: completes; flags switch to 🇨🇿→🇵🇱.
- [ ] Download the speech model; run a lesson; say one word wrongly on
      purpose → no star for that word; review inbox stays small; parent
      speech card shows no "Poslední hodnocení selhalo".
- [ ] Progress → category detail: correct/wrong counts grow.
- [ ] `flutter test` green (86), `flutter analyze` clean; push; CI produces
      the APK.

Report format (keep it short, paste raw output where it matters):

1. Phone: model, Android version, `PAGE_SIZE`.
2. Alignment table before/after Task 5 (library → `2**12`/`2**14`).
3. The first real Vosk error text from the parent card after Task 1.
4. The ML Kit registration stack trace (Task 6) and which branch applied.
5. What fixed what, with commit hashes.
6. Open decisions for Jan: star rule (Task 7); libvosk rebuild vs
   `speech_to_text` if Task 5 did not rescue Vosk.

---

## 4. Order of work, one line

Task 0 → Task 1 → Task 2 (gate) → Task 3 → Task 4 (gate) → Task 5 → Task 6
→ Task 7 (decision) → Task 8 → Task 9.

Tasks 1–3 and 8 are safe to do blind. Tasks 4–6 need the phone over USB.
