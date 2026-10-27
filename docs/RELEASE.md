# Release guide

## Everyday installs (no setup needed)

Every push builds an installable APK in GitHub Actions: repository → **Actions**
→ latest green run → **Artifacts** → `language-teatcher-apk`. Download the zip
on the phone, extract, open the APK, allow "install from unknown sources". This
APK is signed with the debug key — fine for your own phone, updates install
over the previous version.

## Publishing to Google Play (when you want it)

Play requires a release signed with **your own keystore** (keep it and its
passwords safe — losing it means you can never update the app on Play again).

1. **Create a keystore** (once, on your computer):

   ```bash
   keytool -genkey -v -keystore languageteatcher.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias languageteatcher
   ```

2. **Create `android/key.properties`** (never commit it — it is covered by
   `android/.gitignore`'s `key.properties` entry; verify before committing):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=languageteatcher
   storeFile=/absolute/path/to/languageteatcher.jks
   ```

3. **Switch signing in `android/app/build.gradle.kts`** — replace the debug
   `signingConfig` in the `release` build type with a config read from
   `key.properties` (the standard snippet from the Flutter docs:
   https://docs.flutter.dev/deployment/android#signing-the-app).

4. **Build the bundle**: `flutter build appbundle` → upload
   `build/app/outputs/bundle/release/app-release.aab` in the
   [Play Console](https://play.google.com/console) to an **Internal testing**
   track first. Internal testing needs no review to start and installs via a
   link on your phone.

5. Play will ask for: an app name, short/full description, a few screenshots,
   a 512×512 icon (upscale `tool`'s generated icon or re-export at 512), a
   privacy declaration (see below), and — because it appeals to children —
   the Families policy questionnaire.

## What the app does with data (for the Data safety form)

The app has no analytics or accounts of its own. Still, "collects nothing" is
not accurate once the bundled SDKs are counted:

- **Lessons, the child's recordings, the parent's recordings, progress** —
  stored only in the app's private storage on the phone. Never uploaded,
  never logged. Lessons run offline.
- **ML Kit on-device translation (Google)** — used only when the parent
  creates a new language pack. The words are translated on the phone, but the
  SDK downloads its language models from Google, creates a Firebase
  installation identifier for the app instance, fetches remote configuration
  and uploads SDK usage/diagnostic telemetry to Google
  (`firebaselogging.googleapis.com`). Declare this as third-party collection
  of device/app identifiers and diagnostics, and check Google's current ML
  Kit terms for the exact wording and any opt-out before submitting. Because
  the app is child-directed, the Families policy requires every SDK in it to
  be suitable for children — verify ML Kit's status at submission time.
- **Vosk speech model** — downloaded once from `alphacephei.com` (the
  server sees the phone's IP address for that download). Recognition itself
  runs entirely on the device; no audio leaves the phone.
- **Logging** — release builds strip `Log.v`/`Log.d` calls app-wide
  (`android/app/proguard-rules.pro`), which removes ML Kit's debug output of
  installation tokens. The app's own warnings/errors (tags `Otterly`,
  `VoskScorer`) contain no user data.

## Version numbers

`pubspec.yaml` → `version: 1.0.0+2` = versionName 1.0.0, versionCode 2.
Bump the `+N` part on every release; Play rejects a reused versionCode.
