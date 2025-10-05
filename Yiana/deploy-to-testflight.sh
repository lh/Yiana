#!/bin/bash

# Yiana TestFlight Deployment Script
# Usage: ./deploy-to-testflight.sh

set -e  # Exit on error

echo "🚀 Starting Yiana TestFlight deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCHEME="Yiana"
CONFIGURATION="Release"
ARCHIVE_PATH="$HOME/Desktop/Yiana.xcarchive"
EXPORT_PATH="$HOME/Desktop/Yiana-Upload"
PLIST_PATH="ExportOptions.plist"

# Step 1: Clean build folder
echo -e "${YELLOW}Step 1: Cleaning build folder...${NC}"
xcodebuild clean -scheme "$SCHEME" -configuration "$CONFIGURATION"

# Step 2: Increment build number
echo -e "${YELLOW}Step 2: Incrementing build number...${NC}"
CURRENT_BUILD=$(agvtool what-version -terse)
NEW_BUILD=$((CURRENT_BUILD + 1))
agvtool new-version -all $NEW_BUILD
echo -e "${GREEN}Build number incremented to: $NEW_BUILD${NC}"

# Step 3: Archive for iOS
echo -e "${YELLOW}Step 3: Creating archive...${NC}"
xcodebuild archive \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk iphoneos \
    -archivePath "$ARCHIVE_PATH" \
    -destination "generic/platform=iOS" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM=GNC28XBQ2D

if [ -d "$ARCHIVE_PATH" ]; then
    echo -e "${GREEN}✓ Archive created successfully${NC}"
else
    echo -e "${RED}✗ Archive creation failed${NC}"
    exit 1
fi

# Step 4: Export and Upload IPA
echo -e "${YELLOW}Step 4: Exporting and uploading IPA to App Store Connect...${NC}"
echo -e "${YELLOW}Note: This uses automatic upload via -exportOptionsPlist destination:upload${NC}"

# When using destination:upload, xcodebuild uploads directly without creating local IPA
# The command may return exit code 1 even on successful upload, so we capture and check output
OUTPUT=$(xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$PLIST_PATH" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates 2>&1)

EXIT_CODE=$?
echo "$OUTPUT"

# Check if upload succeeded by looking for success message in output
if echo "$OUTPUT" | grep -q "Upload succeeded"; then
    echo -e "${GREEN}✓ Export and upload succeeded${NC}"
elif [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Export completed successfully${NC}"
else
    echo -e "${RED}✗ Export/upload failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Deployment complete!${NC}"
echo -e "${GREEN}The build will appear in App Store Connect TestFlight in 5-30 minutes.${NC}"
echo -e "${GREEN}You'll receive an email when processing is complete.${NC}"

# Optional: Clean up
read -p "Do you want to clean up the archive and export folders? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$ARCHIVE_PATH"
    rm -rf "$EXPORT_PATH"
    echo -e "${GREEN}Cleaned up temporary files${NC}"
fi

echo -e "${GREEN}Version 1.0 (Build $NEW_BUILD) has been submitted to TestFlight!${NC}"