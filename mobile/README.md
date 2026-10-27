# Philokalia

A quiet scroll of short teachings from the Philokalia, for iPhone and Android. Swipe up for the next teaching and down to go back. The place is remembered on the device.

The teachings in `assets/data.json` are the same file as `data.json` at the repo root. `flutter test` fails if the two copies drift.

## Check

```
flutter test
```

## Android

`flutter build appbundle` produces the Play Store bundle. To sign it with an upload key, add `android/key.properties` (gitignored):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

Without that file the release bundle is signed with the debug key so it can be installed on a device. Play Store will not accept that signature.

The application id is `app.philoscroll.philoscroll`.

## iOS

Open `ios/Runner.xcworkspace` on a Mac, select the Runner target’s signing team, and archive. The name on the home screen is Philokalia. The bundle id is `app.philoscroll.philoscroll`. The app does not use encryption beyond what the system provides, and it does not collect data.
