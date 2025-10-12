# YianaOCRService Distribution Options

**Date**: 2025-10-11
**Context**: Exploring ways to make YianaOCRService deployment easier for non-technical users

---

## Current Deployment Process

**Status**: Command-line based, requires:
- SSH setup
- Manual script execution
- Terminal comfort level
- Understanding of LaunchAgents

**Target users**: Developers/technical users comfortable with command line

**Pain points for non-technical users**:
- SSH key setup intimidating
- No visual feedback
- No way to check if service is running
- Hard to troubleshoot issues
- Manual log checking

---

## Distribution Options

### 1. Mac App Store App ✅ (Best User Experience)

**How it works**:
- Package YianaOCRService as a standard macOS app
- Users download from Mac App Store
- App has a GUI with "Start/Stop" button and settings
- Auto-configures LaunchAgent on first run
- Shows log viewer in the app

**Pros**:
- Most user-friendly
- Auto-updates via App Store
- Sandboxed and secure
- No command line needed
- Discoverable (users can search "Yiana OCR")
- Trusted source

**Cons**:
- App Store review process (~1-2 weeks initial, ~1-3 days updates)
- Annual $99 Apple Developer fee
- Sandboxing restrictions (but iCloud access is allowed)
- Can't use background daemons directly (must use XPC service or keep app running)
- Review rejections possible (need to handle carefully)

**Feasibility**: **Easy-Medium**
- Convert CLI to menubar app with SwiftUI
- Use App Groups for IPC with main Yiana app
- Add Settings window for path configuration
- Probably 2-3 days of development

**Technical approach**:
- Main app: Menubar app (no dock icon)
- Service: XPC service or background process managed by app
- Data: Shared via App Groups
- iCloud: Use NSFilePresenter to watch iCloud folder

---

### 2. Standalone macOS App (Outside App Store) ✅ (Good Middle Ground)

**How it works**:
- Same as App Store version but distributed as DMG on GitHub releases
- Users download, drag to Applications, open
- First launch: asks for iCloud folder location, sets up LaunchAgent
- Notarized but not sandboxed

**Pros**:
- No App Store review delays
- More flexible (can use LaunchAgent directly)
- Still user-friendly GUI
- Free distribution
- Can update immediately (no review wait)
- Keep current architecture (LaunchAgent)

**Cons**:
- Users must trust "downloaded from internet" warning (mitigated by notarization)
- Need to notarize (requires Developer ID certificate - $99/year, but you likely have this)
- No auto-updates (or need to implement Sparkle framework)
- Less discoverable (users must find it via docs/website)

**Feasibility**: **Easy**
- Same development as App Store version
- Simpler distribution
- ~2 days development
- Can graduate to App Store later if desired

**Technical approach**:
- Build as standard Mac app
- Sign with Developer ID
- Notarize with Apple
- Distribute as DMG on GitHub Releases
- Optional: Add Sparkle for auto-updates

**Recommended**: This is the sweet spot for indie apps

---

### 3. Homebrew Formula ✅ (Developer-Friendly)

**How it works**:
```bash
brew install yiana-ocr
brew services start yiana-ocr
```

**Pros**:
- Familiar to developers
- Easy updates: `brew upgrade yiana-ocr`
- Handles LaunchAgent automatically via `brew services`
- Free
- Popular in developer community
- Can include in documentation: "Installation: `brew install yiana-ocr`"

**Cons**:
- Requires Homebrew installed (but most developers have it)
- Still command line (but just 2 commands)
- Less discoverable for non-developers
- Won't help non-technical users

**Feasibility**: **Very Easy**
- Create homebrew formula (1 file, ~50 lines)
- Submit PR to homebrew-core or create your own tap
- ~1 day work

**Technical approach**:
```ruby
class YianaOcr < Formula
  desc "OCR service for Yiana document management"
  homepage "https://github.com/lh/Yiana"
  url "https://github.com/lh/Yiana/archive/v1.0.0.tar.gz"
  sha256 "..."

  depends_on :macos
  depends_on :xcode => :build

  def install
    system "swift", "build", "-c", "release"
    bin.install ".build/release/yiana-ocr"
  end

  service do
    run [opt_bin/"yiana-ocr", "watch", "--path", "~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"]
    keep_alive true
    log_path "#{ENV["HOME"]}/Library/Logs/yiana-ocr.log"
    error_log_path "#{ENV["HOME"]}/Library/Logs/yiana-ocr-error.log"
  end
end
```

---

### 4. PKG Installer ✅ (Traditional macOS)

**How it works**:
- Create .pkg installer with Packages.app or pkgbuild
- User double-clicks, follows wizard
- Post-install script sets up LaunchAgent

**Pros**:
- Native macOS experience
- Can ask for install location in GUI
- Free to distribute
- Familiar to Mac users
- Can include uninstaller

**Cons**:
- Still requires download from GitHub/website
- Users see security warnings for unsigned PKG (mitigated by signing)
- No auto-updates
- Not as modern as app-based approach

**Feasibility**: **Easy**
- Use `pkgbuild` and `productbuild`
- Add post-install script
- ~1 day work

**Technical approach**:
```bash
# Build
swift build -c release

# Create package
pkgbuild --root ./pkg-root \
         --identifier com.vitygas.yiana-ocr \
         --version 1.0.0 \
         --install-location /usr/local/bin \
         --scripts ./scripts \
         YianaOCR.pkg

# Post-install script installs LaunchAgent
```

---

### 5. Setup Script with GUI ✅ (Hybrid Approach)

**How it works**:
- Ship a shell script that uses `osascript` for GUI dialogs
- User downloads script, double-clicks
- AppleScript dialogs ask for settings
- Script builds, installs, configures everything

**Pros**:
- No app needed
- Visual feedback for non-technical users
- Free
- Quick to implement
- Works on any Mac

**Cons**:
- Still requires trusting downloaded script
- Not as polished as native app
- No status monitoring
- Can't show logs easily

**Feasibility**: **Very Easy**
- Wrap existing deploy.sh with AppleScript dialogs
- ~4 hours work

**Example**:
```bash
#!/bin/bash
# install-yiana-ocr-gui.sh

# Show welcome dialog
osascript -e 'display dialog "Welcome to YianaOCR Installer!" buttons {"Cancel", "Continue"} default button "Continue"'

# Auto-detect iCloud path
ICLOUD_PATH=$(osascript -e 'display dialog "iCloud Documents folder detected at:\n\n~/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents\n\nIs this correct?" buttons {"No", "Yes"} default button "Yes"')

# Build
osascript -e 'display notification "Building YianaOCR..." with title "Installation"'
swift build -c release

# Install
# ... etc
```

---

## Recommended Solution: Menubar App (Outside App Store)

### Why This Wins:
1. **User Experience**: Best UX for both technical and non-technical users
2. **Flexibility**: No App Store restrictions
3. **Immediate Updates**: Push updates instantly
4. **Visual Feedback**: Status at a glance
5. **Future Path**: Can move to App Store later

### Proposed App Design

#### YianaOCR.app Features:

**Menubar Interface**:
```
[Menubar Icon: 🔍]

Status: Running ✅ (or Stopped ❌)
━━━━━━━━━━━━━━━━━
📊 Documents Processed: 12
⏱️  Last Processed: 2 mins ago
━━━━━━━━━━━━━━━━━
▶️  Start Service
⏸️  Stop Service
⚙️  Settings...
📋 View Logs...
━━━━━━━━━━━━━━━━━
ℹ️  About
🔄 Check for Updates
❌ Quit
```

#### Settings Window (SwiftUI):
- **iCloud Folder Path**: Auto-detected, with browse button
- **Log Level**: Dropdown (Info, Debug, Error)
- **Start at Login**: Checkbox
- **Notifications**: Show notification when OCR completes
- **Current Version**: 1.0.0 + "Check for Updates" button

#### First Launch Wizard:
1. **Welcome Screen**:
   - "Welcome to YianaOCR!"
   - Explain what the service does
   - [Continue]

2. **Setup Screen**:
   - "Detected iCloud folder at: [path]"
   - [Browse...] if user wants to change
   - [Continue]

3. **Permissions Screen**:
   - "YianaOCR needs permission to:"
   - ✓ Access iCloud Documents folder
   - ✓ Install background service (LaunchAgent)
   - [Install]

4. **Success Screen**:
   - "✅ Installation Complete!"
   - "YianaOCR is now running in the menubar"
   - [x] Start at login
   - [Done]

#### Features:
- **Real-time Status**: Shows if service is running, last activity
- **Document Counter**: Shows total documents processed
- **Log Viewer**: Built-in log viewer with search/filter
- **Error Notifications**: User notification when OCR fails
- **Auto-Recovery**: Restarts service if it crashes
- **Update Checker**: Uses Sparkle framework for auto-updates

---

### Implementation Plan

#### Phase 1: Core App (1 day)
- **MenubarApp.swift**: Create menubar app with icon
- **AppDelegate.swift**: Handle app lifecycle
- **ServiceManager.swift**: Wrapper around current CLI
- **StatusView.swift**: Menubar menu content

#### Phase 2: Settings & Setup (1 day)
- **SettingsView.swift**: Settings window (SwiftUI)
- **SetupWizard.swift**: First-launch wizard
- **LaunchAgentManager.swift**: Install/uninstall LaunchAgent
- **PermissionsHelper.swift**: Request folder access

#### Phase 3: Polish (0.5 day)
- **LogViewer.swift**: Built-in log viewer
- **UpdateManager.swift**: Integrate Sparkle
- **NotificationManager.swift**: User notifications
- **AppIcon**: Design proper app icon

#### Phase 4: Distribution (0.5 day)
- **Build script**: Automate build + sign + notarize
- **DMG creation**: Create installer DMG
- **GitHub Release**: Automated release workflow

**Total Effort**: ~3 days for polished, production-ready app

---

### File Structure

```
YianaOCRApp/
├── YianaOCRApp/
│   ├── App/
│   │   ├── MenubarApp.swift           # Main app entry
│   │   ├── AppDelegate.swift          # App lifecycle
│   │   └── StatusMenuController.swift # Menubar menu
│   ├── Views/
│   │   ├── SettingsView.swift         # Settings window
│   │   ├── SetupWizardView.swift      # First launch
│   │   ├── LogViewerView.swift        # Log viewer
│   │   └── AboutView.swift            # About window
│   ├── Managers/
│   │   ├── ServiceManager.swift       # Manage yiana-ocr process
│   │   ├── LaunchAgentManager.swift   # LaunchAgent install/uninstall
│   │   ├── UpdateManager.swift        # Sparkle integration
│   │   └── NotificationManager.swift  # User notifications
│   ├── Models/
│   │   ├── ServiceStatus.swift        # Service state model
│   │   └── Settings.swift             # App settings model
│   └── Resources/
│       ├── Assets.xcassets/           # Icons, images
│       └── Info.plist
├── Embedded/
│   └── yiana-ocr                      # Embedded CLI binary
└── Scripts/
    ├── build-and-sign.sh              # Build automation
    └── create-dmg.sh                  # DMG creation
```

---

### Distribution Workflow

#### 1. GitHub Actions CI/CD
```yaml
name: Release
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: macos-latest
    steps:
      - name: Build app
      - name: Sign with Developer ID
      - name: Notarize
      - name: Create DMG
      - name: Upload to GitHub Releases
      - name: Update appcast.xml for Sparkle
```

#### 2. User Downloads
- Go to GitHub Releases
- Download YianaOCR-1.0.0.dmg
- Double-click DMG
- Drag YianaOCR.app to Applications
- Launch app
- Follow setup wizard

#### 3. Updates
- App checks for updates on launch
- Sparkle shows "Update Available" notification
- User clicks "Install Update"
- App downloads, verifies, installs
- Relaunches automatically

---

## Quick Win: Enhanced Script with Dialogs

If you want something **immediately** without full app development:

### install-yiana-ocr-gui.sh

**Features**:
- AppleScript dialogs for user input
- Auto-detects iCloud folder
- Builds service
- Installs to ~/bin/ or /usr/local/bin
- Sets up LaunchAgent
- Shows success notification

**Implementation**: ~30 minutes

**Example**:
```bash
#!/bin/bash

# Welcome
result=$(osascript -e 'display dialog "Install YianaOCR Service?" buttons {"Cancel", "Install"} default button "Install"')
if [[ $result == *"Cancel"* ]]; then exit; fi

# Auto-detect iCloud path
ICLOUD_PATH="$HOME/Library/Mobile Documents/iCloud~com~vitygas~Yiana/Documents"
if [ -d "$ICLOUD_PATH" ]; then
    osascript -e "display dialog \"iCloud folder detected at:\n\n$ICLOUD_PATH\n\nProceed with installation?\" buttons {\"Cancel\", \"Yes\"} default button \"Yes\""
fi

# Build
osascript -e 'display notification "Building YianaOCR..." with title "Installation"'
swift build -c release

# Install
mkdir -p ~/bin
cp .build/release/yiana-ocr ~/bin/
chmod +x ~/bin/yiana-ocr

# Setup LaunchAgent
# ... (existing logic)

# Success
osascript -e 'display notification "YianaOCR installed successfully!" with title "Installation Complete"'
osascript -e 'display dialog "✅ Installation Complete!\n\nYianaOCR is now running." buttons {"OK"} default button "OK"'
```

---

## Comparison Table

| Solution | Setup Time | User Effort | Cost | Maintainability | Discoverability |
|----------|------------|-------------|------|-----------------|-----------------|
| **App Store App** | High (2-3 days + review) | None (download & open) | $99/year | High (auto-updates) | High (App Store search) |
| **Standalone App** | Medium (2-3 days) | Low (download DMG) | $99/year (notarization) | Medium (Sparkle updates) | Medium (docs/website) |
| **Homebrew** | Low (1 day) | Low (2 commands) | Free | High (brew updates) | Medium (developer community) |
| **PKG Installer** | Low (1 day) | Medium (download, trust) | Free | Low (manual updates) | Low (docs/website) |
| **Script with GUI** | Very Low (4 hours) | Medium (download, run) | Free | Low (manual updates) | Low (docs only) |
| **Current (CLI)** | Done | High (SSH, scripts) | Free | Low | Low |

---

## Recommendations

### Short Term (This Week)
**Option**: Enhanced script with dialogs (~4 hours)
- Quick improvement over current process
- Visual feedback helps non-technical users
- No infrastructure needed
- Can be improved incrementally

### Medium Term (Next Month)
**Option**: Standalone menubar app (~3 days)
- Professional UX
- Status monitoring
- Log viewer
- Auto-updates with Sparkle
- Can move to App Store later

### Long Term (Future Release)
**Option**: App Store + Homebrew
- App Store for non-technical users
- Homebrew for developers
- Both point to same GitHub repo
- Maximize reach

---

## Action Items

### If Building Menubar App:

**Prerequisites**:
- [ ] Apple Developer account (for notarization)
- [ ] App icon designed (1024x1024 PNG)
- [ ] Domain for update feed (or use GitHub)

**Development**:
- [ ] Create Xcode project for menubar app
- [ ] Embed yiana-ocr CLI in app bundle
- [ ] Implement ServiceManager (start/stop/status)
- [ ] Build Settings UI (SwiftUI)
- [ ] Add LaunchAgent installer
- [ ] Integrate Sparkle for updates
- [ ] Create first-launch wizard
- [ ] Add log viewer

**Distribution**:
- [ ] Code sign with Developer ID
- [ ] Notarize with Apple
- [ ] Create DMG installer
- [ ] Set up GitHub Actions for releases
- [ ] Create appcast.xml for Sparkle
- [ ] Update documentation

**Estimated Timeline**: 3-4 days full-time development

---

## Technical Notes

### Embedding CLI in App
```swift
// Get path to embedded binary
let binaryPath = Bundle.main.path(forResource: "yiana-ocr", ofType: nil)!

// Copy to user's bin on first launch
let destinationURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("bin/yiana-ocr")
try FileManager.default.copyItem(at: URL(fileURLWithPath: binaryPath),
                                  to: destinationURL)
```

### LaunchAgent Management
```swift
class LaunchAgentManager {
    static let plistURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents/com.vitygas.yiana-ocr.plist")

    func install() throws {
        let plist = createPlist()
        try plist.write(to: plistURL)
        try shell("launchctl load \(plistURL.path)")
    }

    func uninstall() throws {
        try shell("launchctl unload \(plistURL.path)")
        try FileManager.default.removeItem(at: plistURL)
    }
}
```

### Service Status Monitoring
```swift
class ServiceManager: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var lastProcessed: Date?
    @Published var documentsProcessed: Int = 0

    func checkStatus() {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", "launchctl list | grep yiana-ocr"]
        // Parse output to determine status
    }
}
```

---

## Conclusion

**Recommended Approach**: Build standalone menubar app (Option 2)

**Why**:
1. Best balance of user experience and development effort
2. No App Store gatekeeping
3. Professional appearance
4. Easy updates via Sparkle
5. Can graduate to App Store later
6. ~3 days of development for production-ready app

**Next Steps**:
1. Decide on distribution method
2. If menubar app: Design app icon
3. Set up Xcode project
4. Implement core features
5. Test with beta users
6. Create release workflow
7. Update documentation

---

**Document Version**: 1.0
**Last Updated**: 2025-10-11
**Author**: Claude (based on discussion with Rose)
