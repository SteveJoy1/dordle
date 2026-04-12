#!/bin/bash
set -e

# App Store Connect API Key (never expires)
KEY_PATH=~/private_keys/AuthKey_UM2XCC6L7R.p8
KEY_ID=UM2XCC6L7R
ISSUER_ID=b63e4ac9-62bc-4b6c-84fe-68cfb086f4c7

# Bump build number
CURRENT=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | awk '{print $2}')
NEXT=$((CURRENT + 1))
sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT/CURRENT_PROJECT_VERSION: $NEXT/" project.yml
echo "📦 Build $NEXT"

# Generate project
xcodegen generate 2>&1 | head -3

# Archive
echo "🔨 Archiving..."
xcodebuild -project Dordle.xcodeproj -scheme Dordle \
  -destination 'generic/platform=iOS' \
  -archivePath build/Dordle.xcarchive archive \
  2>&1 | tail -1

# Export & Upload
echo "🚀 Uploading to TestFlight..."
rm -rf build/export
xcodebuild -exportArchive \
  -archivePath build/Dordle.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates \
  -authenticationKeyPath "$KEY_PATH" \
  -authenticationKeyID "$KEY_ID" \
  -authenticationKeyIssuerID "$ISSUER_ID" \
  2>&1 | tail -3

echo "✅ Build $NEXT uploaded to TestFlight"
