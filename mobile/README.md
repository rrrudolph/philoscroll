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
