#!/bin/bash

# Yiana TestFlight Deployment Script
# Usage: ./deploy-to-testflight.sh
# Builds and uploads both iOS and macOS versions to TestFlight

set -e  # Exit on error

echo "🚀 Starting Yiana TestFlight deployment (iOS + macOS)..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCHEME="Yiana"
CONFIGURATION="Release"
ARCHIVE_PATH_IOS="$HOME/Desktop/Yiana-iOS.xcarchive"
ARCHIVE_PATH_MAC="$HOME/Desktop/Yiana-macOS.xcarchive"
EXPORT_PATH_IOS="$HOME/Desktop/Yiana-Upload-iOS"
EXPORT_PATH_MAC="$HOME/Desktop/Yiana-Upload-macOS"
PLIST_PATH="ExportOptions.plist"
PLIST_PATH_MAC="ExportOptions-macOS.plist"

# Step 1: Clean build folder
echo -e "${YELLOW}Step 1: Cleaning build folder...${NC}"
xcodebuild clean -scheme "$SCHEME" -configuration "$CONFIGURATION"

# Step 2: Increment build number (shared across both platforms)
echo -e "${YELLOW}Step 2: Incrementing build number...${NC}"
CURRENT_BUILD=$(agvtool what-version -terse)
NEW_BUILD=$((CURRENT_BUILD + 1))
agvtool new-version -all $NEW_BUILD
echo -e "${GREEN}Build number incremented to: $NEW_BUILD${NC}"

# ============================================
# iOS Build
# ============================================
echo -e "${YELLOW}Step 3a: Creating iOS archive...${NC}"
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    -archivePath "$ARCHIVE_PATH_IOS" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM=GNC28XBQ2D

if [ -d "$ARCHIVE_PATH_IOS" ]; then
    echo -e "${GREEN}✓ iOS archive created successfully${NC}"
else
    echo -e "${RED}✗ iOS archive creation failed${NC}"
    exit 1
fi

echo -e "${YELLOW}Step 4a: Uploading iOS to App Store Connect...${NC}"
OUTPUT_IOS=$(xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH_IOS" \
    -exportOptionsPlist "$PLIST_PATH" \
    -exportPath "$EXPORT_PATH_IOS" \
    -allowProvisioningUpdates 2>&1)

echo "$OUTPUT_IOS"

if echo "$OUTPUT_IOS" | grep -q "Upload succeeded"; then
    echo -e "${GREEN}✓ iOS upload succeeded${NC}"
else
    echo -e "${YELLOW}⚠ iOS upload status unclear, check App Store Connect${NC}"
fi

# ============================================
# macOS Build
# ============================================
echo -e "${YELLOW}Step 3b: Creating macOS archive...${NC}"
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -archivePath "$ARCHIVE_PATH_MAC" \
    -destination "generic/platform=macOS" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM=GNC28XBQ2D

if [ -d "$ARCHIVE_PATH_MAC" ]; then
    echo -e "${GREEN}✓ macOS archive created successfully${NC}"
else
    echo -e "${RED}✗ macOS archive creation failed${NC}"
    exit 1
fi

# Create macOS export options if it doesn't exist
if [ ! -f "$PLIST_PATH_MAC" ]; then
    echo -e "${YELLOW}Creating macOS export options plist...${NC}"
    cat > "$PLIST_PATH_MAC" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>destination</key>
    <string>upload</string>
    <key>method</key>
    <string>app-store-connect</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>GNC28XBQ2D</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
fi

echo -e "${YELLOW}Step 4b: Uploading macOS to App Store Connect...${NC}"
OUTPUT_MAC=$(xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH_MAC" \
    -exportOptionsPlist "$PLIST_PATH_MAC" \
    -exportPath "$EXPORT_PATH_MAC" \
    -allowProvisioningUpdates 2>&1)

echo "$OUTPUT_MAC"

if echo "$OUTPUT_MAC" | grep -q "Upload succeeded"; then
    echo -e "${GREEN}✓ macOS upload succeeded${NC}"
else
    echo -e "${YELLOW}⚠ macOS upload status unclear, check App Store Connect${NC}"
fi

# ============================================
# Summary
# ============================================
echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}iOS and macOS builds submitted to TestFlight.${NC}"
echo -e "${GREEN}Builds will appear in App Store Connect in 5-30 minutes.${NC}"
echo -e "${GREEN}You'll receive emails when processing is complete.${NC}"

# Optional: Clean up
read -p "Do you want to clean up the archive and export folders? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$ARCHIVE_PATH_IOS"
    rm -rf "$ARCHIVE_PATH_MAC"
    rm -rf "$EXPORT_PATH_IOS"
    rm -rf "$EXPORT_PATH_MAC"
    echo -e "${GREEN}Cleaned up temporary files${NC}"
fi

echo -e "${GREEN}Version 1.0 (Build $NEW_BUILD) has been submitted to TestFlight!${NC}"
