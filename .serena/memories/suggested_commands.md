# Yiana Development Commands

## Building & Running
```bash
# Open project in Xcode
open Yiana/Yiana.xcodeproj

# Build from command line
xcodebuild build -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'

# Run in Xcode
# Select target device/simulator and press Cmd+R
```

## Testing
```bash
# Run all tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test file
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentMetadataTests

# Run tests after each phase (checkpoint)
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Git Commands
```bash
# Clone repository
git clone https://github.com/lh/Yiana.git

# Basic git workflow
git status
git add .
git commit -m "message"
git push

# Commit after each successful test/implementation pair (as per TDD workflow)
```

## macOS/Darwin System Commands
```bash
# File operations
ls -la          # List files with details
find . -name "*.swift"  # Find Swift files
grep -r "pattern" .     # Search in files

# Directory navigation
cd Yiana
pwd            # Print working directory
mkdir -p path/to/dir  # Create nested directories

# File viewing
cat file.swift
less file.swift
open file.swift  # Open in default editor
```

## Project-Specific Tasks
- After completing each development phase, update memory-bank/activeContext.md
- Follow TDD: Write failing tests first, then implementation
- Commit after each successful test/implementation pair