#!/bin/bash
# Build a signed App Store IPA. Run from mobile/ on a macOS runner.
set -euo pipefail

for name in IOS_DISTRIBUTION_CERTIFICATE_BASE64 IOS_DISTRIBUTION_CERTIFICATE_PASSWORD IOS_PROVISIONING_PROFILE_BASE64; do
  if [ -z "${!name:-}" ]; then
    echo "Missing GitHub secret: $name"
    exit 1
  fi
done

decode() {
  printf '%s' "$1" | tr -d '[:space:]' | openssl base64 -d -A -out "$2"
}

CERT_PATH="$RUNNER_TEMP/distribution.p12"
PROFILE_PATH="$RUNNER_TEMP/profile.mobileprovision"
PROFILE_PLIST="$RUNNER_TEMP/profile.plist"
EXPORT_PLIST="$RUNNER_TEMP/ExportOptions.plist"
KEYCHAIN_PATH="$RUNNER_TEMP/app-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

cleanup() {
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
}
trap cleanup EXIT

decode "$IOS_DISTRIBUTION_CERTIFICATE_BASE64" "$CERT_PATH"
decode "$IOS_PROVISIONING_PROFILE_BASE64" "$PROFILE_PATH"
security cms -D -i "$PROFILE_PATH" > "$PROFILE_PLIST"

PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST")"
TEAM_ID="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST")"
PROFILE_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST")"
echo "Signing with profile \"$PROFILE_NAME\" for team $TEAM_ID"

install -d "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$CERT_PATH" -P "$IOS_DISTRIBUTION_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"

cat >> ios/Flutter/Release.xcconfig <<EOF
CODE_SIGN_STYLE = Manual
DEVELOPMENT_TEAM = $TEAM_ID
CODE_SIGN_IDENTITY = Apple Distribution
CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Distribution
PROVISIONING_PROFILE_SPECIFIER = $PROFILE_NAME
EOF

cat > "$EXPORT_PLIST" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict/>
</plist>
EOF
/usr/libexec/PlistBuddy -c "Add :method string app-store-connect" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :destination string export" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :signingStyle string manual" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :signingCertificate string Apple Distribution" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :teamID string $TEAM_ID" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :uploadSymbols bool true" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$EXPORT_PLIST"
/usr/libexec/PlistBuddy -c "Add :provisioningProfiles:app.philoscroll.philoscroll string $PROFILE_NAME" "$EXPORT_PLIST"

export FLUTTER_SWIFT_PACKAGE_MANAGER=true
flutter build ipa --release --build-number="${GITHUB_RUN_NUMBER}" --export-options-plist="$EXPORT_PLIST"

shopt -s nullglob
ipas=(build/ios/ipa/*.ipa)
if [ "${#ipas[@]}" -eq 0 ]; then
  echo "The archive finished without an IPA. App Store Connect needs the IPA, and a failed export still looks successful to Flutter."
  exit 1
fi
