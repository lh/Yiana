# Build Check

Build both platform targets and report results. Run this at logical checkpoints — after completing a subtask, before committing, or whenever you want to verify the project compiles.

1. Build iOS: `xcodebuild -project Yiana/Yiana.xcodeproj -scheme Yiana -destination 'generic/platform=iOS' -quiet build 2>&1 | tail -10`
2. Build macOS: `xcodebuild -project Yiana/Yiana.xcodeproj -scheme Yiana -destination 'platform=macOS' -quiet build 2>&1 | tail -10`
3. Report: show pass/fail for each target. If either fails, show the errors.
4. Do NOT proceed with further edits if a build is broken — fix it first.
