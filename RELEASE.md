# Releasing HabitFlow

Step-by-step guide from a merged `develop` to Google Play. Uploading to Play
Console is done by the account owner; everything up to the signed bundle is
reproducible from this repository.

## 1. One-time setup

### Signing (already done for 1.0.0)

- Upload keystore: `C:\AndroidKeys\habitflow-upload-key.jks` (outside the repo)
- `android/key.properties` (git-ignored):

  ```properties
  storeFile=C:\\AndroidKeys\\habitflow-upload-key.jks
  storePassword=...
  keyAlias=...
  keyPassword=...
  ```

- **Back up the keystore and both passwords** somewhere safe and separate
  (e.g. a password manager plus an offline copy). Never commit them, email
  them or put them in CI logs.
- Use **Play App Signing** (the default for new apps): Google holds the
  app-signing key, and this file is only the *upload* key. If the upload key
  is lost or leaked, the account owner can request an upload-key reset in
  Play Console. Without Play App Signing, a lost key would mean the app can
  never be updated.

Without `key.properties` the release build is debug-signed and Gradle prints
a warning; Play rejects such uploads.

### Play Console

1. Create a developer account (one-time fee) and complete identity
   verification.
2. *Create app*: name **HabitFlow**, default language English, App, Free.
3. Fill in *Store presence → Main store listing* from `store/listing.md`
   (text, 512 icon, feature graphic, screenshots per
   `store/screenshot_checklist.md`).
4. Host `store/privacy_policy.html` at a public URL (see §5) and enter it
   under *Policy → App content → Privacy policy*.
5. Complete every *App content* declaration using the draft answers in
   `store/listing.md` (ads, content rating, target audience, data safety…).

## 2. Prepare the release (Git)

Per `CONTRIBUTING.md`:

```sh
git switch develop && git pull
git switch -c release/1.0.0
```

1. Set the version in `pubspec.yaml`: `version: <name>+<code>`.
   - `name` follows semantic versioning (1.0.0, 1.0.1, 1.1.0…).
   - `code` must **increase with every upload** to Play (1, 2, 3…), even
     for the same version name.
2. Run the checks and the manual checklist:

   ```sh
   flutter pub get
   dart run build_runner build
   dart format --output=none --set-exit-if-changed .
   flutter analyze
   flutter test
   ```

   Then work through `QA_CHECKLIST.md` on a device with a **release** build.
3. Fix only release blockers on the release branch (`fix/...` PRs into it).

## 3. Build the signed bundle

```sh
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

Verify it is signed with the upload key (not "Android Debug"):

```sh
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Expected owner for 1.0.0: `CN=Muhammad Azeem, OU=Personal, O=Individual
Developer, L=Karachi, ST=Sindh, C=PK`.

To try the exact release build on a phone first:

```sh
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

(A phone with a debug build installed must uninstall it first; the
signatures differ.)

## 4. Testing tracks on Play

1. **Internal testing:** *Testing → Internal testing → Create release*,
   upload the `.aab`, add testers by email (up to 100). Available within
   minutes; no review needed. Use it to smoke-test the Play-delivered build.
2. **Closed testing (required for new personal accounts):** personal
   developer accounts created after **13 November 2023** must run a closed
   test with **at least 12 testers opted in for at least 14 consecutive
   days** before they can apply for production access. Start this as early
   as possible; it sets the earliest launch date. Organisation accounts are
   exempt.
3. Collect feedback, fix blockers on `release/1.0.0`, bump the version
   **code**, rebuild and upload again.

## 5. Hosting the privacy policy

Play needs a public, non-editable web page. `store/privacy_policy.html` is
self-contained (no external files). Options:

- **GitHub Pages:** in this public repo's *Settings → Pages*, publish from a
  branch; the file is then served at
  `https://<user>.github.io/HabitFlow/store/privacy_policy.html`.
- **Google Sites** or any static host: paste or upload the page.

Update the policy (and the Play *Data safety* form) **before** shipping any
change in what the app collects, e.g. when ads are added.

## 6. Production

1. In Play Console, *Production → Create release*, promote the tested
   bundle, add release notes, and roll out (a staged rollout, e.g. 20%, is a
   good default).
2. After the release is live, finish the Git flow:

   ```sh
   # merge release/1.0.0 into main via PR ("Create a merge commit"), then:
   git switch main && git pull
   git tag -a v1.0.0 -m "HabitFlow 1.0.0"
   git push origin v1.0.0
   # merge release/1.0.0 back into develop via PR, then delete the branch
   ```

## 7. Hotfixes

```sh
git switch main && git pull
git switch -c hotfix/short-description
```

Fix, bump the patch version and version code (e.g. `1.0.1+2`), PR into
`main`, tag `v1.0.1`, then merge `main` back into `develop`.
