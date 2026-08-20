#!/bin/bash
set -euo pipefail

# Scroll My Mac — Release Build, Sign, Notarize, and Staple
# Usage: ./scripts/build-release.sh
#
# Prerequisites:
#   1. Developer ID Application certificate installed in keychain
#   2. Notarization credentials stored:
#      xcrun notarytool store-credentials "ScrollMyMac" \
#        --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID
#      (You will be prompted for an app-specific password)

# Configuration
APP_NAME="ScrollMyMac"
SCHEME="ScrollMyMac"
BUILD_DIR="build/release"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"

# Auto-detect signing identity from keychain
SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')

if [ -z "$SIGNING_IDENTITY" ]; then
  echo "ERROR: No Developer ID Application certificate found in keychain."
  echo "Install one via Xcode > Settings > Accounts > Manage Certificates."
  exit 1
fi

echo "Using signing identity: $SIGNING_IDENTITY"

# Clean build directory
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Archive
echo ""
echo "==> Step 1/7: Archiving..."
xcodebuild archive \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  OTHER_CODE_SIGN_FLAGS="--options=runtime" \
  ENABLE_HARDENED_RUNTIME=YES \
  | tail -5

# Step 2: Export app from archive
echo ""
echo "==> Step 2/7: Exporting app from archive..."
mkdir -p "$EXPORT_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$APP_PATH"

# Step 3: Re-sign with hardened runtime and entitlements
echo ""
echo "==> Step 3/7: Signing with hardened runtime..."
codesign --force --deep --options runtime \
  --sign "$SIGNING_IDENTITY" \
  --entitlements "$APP_NAME/$APP_NAME.entitlements" \
  "$APP_PATH"

# Step 4: Verify signature
echo ""
echo "==> Step 4/7: Verifying signature..."
codesign -v --verbose=2 "$APP_PATH"
echo "Signature authorities:"
codesign -d --verbose=2 "$APP_PATH" 2>&1 | grep "Authority" || true

# Step 5: Create zip for notarization
echo ""
echo "==> Step 5/7: Creating zip for notarization..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# Step 6: Submit for notarization
echo ""
echo "==> Step 6/7: Submitting for notarization..."
echo "(This typically takes 1-5 minutes)"
echo ""

# Try keychain profile first, fall back to env vars
if xcrun notarytool submit "$ZIP_PATH" --keychain-profile "ScrollMyMac" --wait 2>/dev/null; then
  echo "Notarization complete (keychain profile)."
else
  echo "Keychain profile 'ScrollMyMac' not found. Trying environment variables..."
  if [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    xcrun notarytool submit "$ZIP_PATH" --wait \
      --apple-id "$APPLE_ID" \
      --team-id "$TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD"
  else
    echo ""
    echo "ERROR: No credentials available for notarization."
    echo ""
    echo "Option 1 — Store credentials (recommended, one-time setup):"
    echo "  xcrun notarytool store-credentials \"ScrollMyMac\" \\"
    echo "    --apple-id YOUR_APPLE_ID --team-id YOUR_TEAM_ID"
    echo ""
    echo "Option 2 — Set environment variables:"
    echo "  export APPLE_ID=your@email.com"
    echo "  export TEAM_ID=YOUR_TEAM_ID"
    echo "  export APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    echo ""
    exit 1
  fi
fi

# Step 7: Staple the notarization ticket
echo ""
echo "==> Step 7/7: Stapling notarization ticket..."
xcrun stapler staple "$APP_PATH"

# Verify staple
echo ""
echo "==> Verifying stapled ticket..."
xcrun stapler validate "$APP_PATH"

# Re-zip with stapled app for distribution
echo ""
echo "==> Creating final distribution zip..."
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo ""
echo "========================================"
echo "  BUILD COMPLETE"
echo "========================================"
echo ""
echo "Signed and notarized app: $APP_PATH"
echo "Distribution zip:         $ZIP_PATH"
echo ""
echo "Verify Gatekeeper acceptance:"
echo "  spctl --assess --verbose=4 --type execute \"$APP_PATH\""
