# Deploy to TestFlight

1. **Check for uncommitted changes** — warn the user and do not proceed until the working tree is clean
2. **Bump the build number** — read `CURRENT_PROJECT_VERSION` from `Yiana/Yiana.xcodeproj/project.pbxproj`, increment by 1, and replace all 6 occurrences in the file
3. **Commit the bump** — stage the pbxproj and commit with message: `Bump build number to N for TestFlight deployment`
4. **Build the iOS archive** — run:
   ```
   xcodebuild archive -project Yiana/Yiana.xcodeproj -scheme Yiana -destination 'generic/platform=iOS' -archivePath /tmp/Yiana.xcarchive
   ```
   If the build fails, show the errors and stop.
5. **Export and upload** — run:
   ```
   xcodebuild -exportArchive -archivePath /tmp/Yiana.xcarchive.xcarchive -exportOptionsPlist Yiana/ExportOptions.plist -exportPath /tmp/YianaExport
   ```
   This automatically uploads to App Store Connect (destination=upload in the plist).
6. **Report result** — show success or failure. On success, remind the user to check App Store Connect for processing status.
7. **Do NOT push to git automatically** — ask the user if they want to push the build number bump.
