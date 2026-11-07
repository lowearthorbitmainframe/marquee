#!/bin/bash
# Archives Scenester and uploads it to App Store Connect for TestFlight.
# Signs with the team in project.yml through the Apple ID signed in to Xcode.
# Each upload needs a higher build number, so the build number is the current time.
set -euo pipefail
cd "$(dirname "$0")"
BUILD=$(date +%Y%m%d%H%M)
# An App Store Connect API key, if set up, signs in without Xcode's saved account:
# put AuthKey_<KEYID>.p8 in ~/.appstoreconnect/private_keys and the two IDs in ~/.appstoreconnect/scenester.env
# as ASC_KEY_ID=... and ASC_ISSUER_ID=...
AUTH=()
if [ -f ~/.appstoreconnect/scenester.env ]; then
  source ~/.appstoreconnect/scenester.env
  AUTH=(-authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8
        -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi
xcodegen generate -q
xcodebuild -project Marquee.xcodeproj -scheme Marquee -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Scenester.xcarchive \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$BUILD" archive -quiet
# Xcode's signed-in account signs the app; the API key only uploads it.
rm -rf build/export
xcodebuild -exportArchive -archivePath build/Scenester.xcarchive -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
xcrun altool --upload-app --type ios --file build/export/*.ipa --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
echo "Uploaded build $BUILD. It shows in App Store Connect > TestFlight after Apple finishes processing (usually 5-30 minutes)."
