# Release guide

Two GitHub Actions workflows do the building:

| Workflow | Runs on | Produces |
|---|---|---|
| `CI` (`.github/workflows/ci.yml`) | every branch except `master`, every PR | analysis + tests, a debug-signed APK as a run artifact (14 days) |
| `Release` (`.github/workflows/release.yml`) | every push to `master` | analysis + tests, APK + AAB, a git tag and a **GitHub Release** with the APK attached, optional upload to Google Play |

## Everyday installs

- Work on a branch: **Actions** → the branch's latest green `CI` run →
  **Artifacts** → `otterly-apk-<sha>`. Download the zip on the phone, extract,
  open the APK, allow "install from unknown sources".
- Releases: repository → **Releases** → latest → the `.apk` asset. Same install
  steps.

Both are signed with the committed debug key (`android/app/debug.keystore`),
so they install over each other. A build signed with the Play upload key (see
below) is a different signature: switching between the two needs one
uninstall.

## Cutting a release

1. Bump `version:` in `pubspec.yaml` — `1.0.1+3` = versionName 1.0.1,
   versionCode 3. **Always increase the `+N` part**; Play rejects a reused
   versionCode and the pipeline uses it in the tag.
2. Merge to `master` (or push to it).
3. `Release` tags the commit `v1.0.1-b3`, publishes the GitHub Release with
   generated notes, and — when the secrets below exist — ships the AAB to
   Play's internal testing track.

A push to `master` whose version already has a tag still builds and uploads
the artifact, but does not publish a release (the run shows a notice). This is
what makes "a release" a deliberate act: it is the version bump.

## Google Play

Play requires a bundle signed with **your own upload keystore** (keep it and
its passwords safe — losing it means you can never update the app on Play
again) and, for the very first upload, a manual step in the Play Console.

### One-time setup

1. **Create the keystore** on your computer:

   ```bash
   keytool -genkey -v -keystore otterly-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Local release builds** (optional): create `android/key.properties` — it
   is git-ignored (`android/.gitignore`: `key.properties`, `**/*.jks`):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/absolute/path/to/otterly-upload.jks
   ```

   `android/app/build.gradle.kts` picks it up automatically; without the file
   it signs with the debug key.

3. **GitHub secrets** (repository → Settings → Secrets and variables →
   Actions):

   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | `base64 -w0 otterly-upload.jks` (PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("otterly-upload.jks"))`) |
   | `ANDROID_KEYSTORE_PASSWORD` | the store password |
   | `ANDROID_KEY_ALIAS` | `upload` |
   | `ANDROID_KEY_PASSWORD` | the key password |
   | `PLAY_SERVICE_ACCOUNT_JSON` | the JSON key of a Play Console service account with "Release to testing tracks" permission |

   With the four `ANDROID_*` secrets the Release workflow signs with the upload
   key (the release asset loses its `-debugsigned` suffix). With
   `PLAY_SERVICE_ACCOUNT_JSON` as well, it uploads the AAB to the **internal**
   track after publishing the GitHub Release.

4. **First Play upload is manual**: create the app in the
   [Play Console](https://play.google.com/console), download the
   `otterly-v…aab` asset from the GitHub Release (or build locally with
   `flutter build appbundle`) and upload it to Internal testing by hand. The
   API refuses to create the first release of a new app; from the second
   version on the pipeline does it.

5. Play will ask for: an app name, short/full description, a few screenshots,
   a 512×512 icon (upscale `tool`'s generated icon or re-export at 512), the
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

