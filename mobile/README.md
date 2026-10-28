# PhiloScroll

A quiet scroll of short teachings from the Philokalia, for iPhone and Android. Swipe up for the next teaching and down to go back. The place is remembered on the device.

The teachings in `assets/data.json` are the same file as `data.json` at the repo root. `flutter test` fails if the two copies drift.

## Check

```
flutter test
```

The same test runs on every push and pull request.

## Android

`flutter build appbundle` produces the Play Store bundle. To sign it with an upload key, add `android/key.properties` (gitignored):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

Without that file the release bundle is signed with the debug key so it can be installed on a device. Play Store will not accept that signature.

The Release workflow signs with the same four values, stored as repository secrets: `ANDROID_KEYSTORE_BASE64` (the `.jks` file, base64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS`. Download the bundle from the run and upload it in Play Console.

The application id is `app.philoscroll.philoscroll`.

## iOS

The Release workflow builds the App Store package on a Mac runner. Run it from the Actions tab. It needs `IOS_DISTRIBUTION_CERTIFICATE_BASE64` (the Apple Distribution certificate exported as a `.p12`, base64), `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD`, and `IOS_PROVISIONING_PROFILE_BASE64` (the App Store profile).

Turn on upload for that run, and set `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_API_KEY_BASE64` (the AuthKey `.p8`, base64), to send the package to App Store Connect. The app record has to exist there already.

Each Release run uses a new build number. The version name stays the one in `pubspec.yaml`.

The name on the home screen is PhiloScroll. The bundle id is `app.philoscroll.philoscroll`. The app does not use encryption beyond what the system provides, and it does not collect data.

### App Store Connect (one-time)

Do this in [Apple Developer](https://developer.apple.com/account) and [App Store Connect](https://appstoreconnect.apple.com) before the first upload.

1. **Identifiers** — Register an App ID with bundle id `app.philoscroll.philoscroll` (no special capabilities required).
2. **Certificates** — Create an **Apple Distribution** certificate. Export it as a `.p12` with a password.
3. **Profiles** — Create an **App Store** provisioning profile for that App ID. Download the `.mobileprovision` file.
4. **App record** — In App Store Connect, add a new app with the same bundle id and name **PhiloScroll**.
5. **API key** — Users and Access → Integrations → App Store Connect API. Generate a key with **Developer** access. Save the `.p8`, Key ID, and Issuer ID.

**GitHub repository secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|--------|
| `IOS_DISTRIBUTION_CERTIFICATE_BASE64` | `.p12` file, base64 (no line breaks) |
| `IOS_DISTRIBUTION_CERTIFICATE_PASSWORD` | export password |
| `IOS_PROVISIONING_PROFILE_BASE64` | `.mobileprovision`, base64 |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID (only needed when upload is on) |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_BASE64` | `.p8` file, base64 |

On Windows, base64 for a binary file:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('path\to\file.p12'))
```

6. **Release workflow** — Actions → **Release** → Run workflow. Leave **upload** off the first time; download the **app-store-ipa** artifact and confirm the build. Run again with **upload** on to send it to App Store Connect.
7. **Listing** — In the app’s **App Store** tab, set privacy policy URL `https://philoscroll.lightvoid.app/privacy.html`, support URL or email `support@lightvoid.app`, category (e.g. Books or Lifestyle), screenshots, and description. Under **App Privacy**, declare that you do not collect data. Export compliance should match `ITSAppUsesNonExemptEncryption` (standard encryption only / exempt). Submit the build for review when the listing is complete.
