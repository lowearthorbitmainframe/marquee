#!/bin/bash
# Archives Scenester and uploads it to App Store Connect for TestFlight.
# Signs with the team in project.yml through the Apple ID signed in to Xcode.
# Each upload needs a higher build number, so the build number is the current time.
set -euo pipefail
cd "$(dirname "$0")"
BUILD=$(date +%Y%m%d%H%M)
xcodegen generate -q
xcodebuild -project Marquee.xcodeproj -scheme Marquee -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Scenester.xcarchive \
  -allowProvisioningUpdates CURRENT_PROJECT_VERSION="$BUILD" archive -quiet
xcodebuild -exportArchive -archivePath build/Scenester.xcarchive -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export -allowProvisioningUpdates
echo "Uploaded build $BUILD. It shows in App Store Connect > TestFlight after Apple finishes processing (usually 5-30 minutes)."
