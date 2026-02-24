---
name: testflight
description: Bumps the build number, archives, and uploads to TestFlight via App Store Connect. Use when user says "testflight", "upload to testflight", "ship a build", or wants to deploy a new beta.
---

# Deploy to TestFlight

1. **Check for uncommitted changes** — warn the user and do not proceed until the working tree is clean
2. **Bump the build number** — read `CURRENT_PROJECT_VERSION` from `Yiana/Yiana.xcodeproj/project.pbxproj`, increment by 1, and replace all 6 occurrences in the file
3. **Commit the bump** — stage the pbxproj and commit with message: `Bump build number to N for TestFlight deployment`
4. **Build and upload iOS** — archive, then export+upload:
   ```
   xcodebuild archive -project Yiana/Yiana.xcodeproj -scheme Yiana -destination 'generic/platform=iOS' -archivePath /tmp/Yiana-iOS.xcarchive
   ```
   ```
   xcodebuild -exportArchive -archivePath /tmp/Yiana-iOS.xcarchive -exportOptionsPlist Yiana/ExportOptions.plist -exportPath /tmp/YianaExport-iOS -allowProvisioningUpdates
   ```
   If the build fails, show the errors and stop.
5. **Build and upload macOS** — archive, then export+upload:
   ```
   xcodebuild archive -project Yiana/Yiana.xcodeproj -scheme Yiana -destination 'generic/platform=macOS' -archivePath /tmp/Yiana-macOS.xcarchive
   ```
   ```
   xcodebuild -exportArchive -archivePath /tmp/Yiana-macOS.xcarchive -exportOptionsPlist Yiana/ExportOptions.plist -exportPath /tmp/YianaExport-macOS -allowProvisioningUpdates
   ```
   If the build fails, show the errors and stop.
6. **Report result** — show success or failure for each platform. On success, remind the user to check App Store Connect for processing status.
7. **Do NOT push to git automatically** — ask the user if they want to push the build number bump.
