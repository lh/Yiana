# Active Context

## Current State (January 2025)

### App Status: Beta on TestFlight
- ✅ Build 49 uploaded to TestFlight
- ✅ iOS and macOS app fully functional
- ✅ Website live at https://lh.github.io/Yiana/
- ⏳ Awaiting user feedback before App Store release

### Core Features Complete
- ✅ One-tap scanning (monochrome and colour)
- ✅ Text notes (save as permanent PDF on exit)
- ✅ Add text to pages with precise positioning
- ✅ Import PDFs
- ✅ Folder organisation
- ✅ iCloud sync across iPhone, iPad, Mac
- ✅ Search (with optional OCR backend)
- ✅ Bulk PDF export (Mac)

### App Store Readiness
- ✅ Privacy policy at https://lh.github.io/Yiana/privacy/
- ✅ Support page at https://lh.github.io/Yiana/support/
- ✅ Entitlements set to production
- ✅ Camera usage description configured
- ✅ No data collection (App Privacy: "Data Not Collected")
- ✅ Beta disclaimer on website
- 📋 Checklist at docs/AppStoreSubmissionChecklist.md

### Recent Session (January 2025)
- Added graceful degradation when backends unavailable
- Created WelcomeDocumentService for new users
- Built GitHub Pages website with Jekyll
- Added "Why Yiana" story page
- Added beta disclaimer
- Deployed Build 49 to TestFlight

## What's Next
1. Gather TestFlight feedback
2. Fix any reported issues
3. Take App Store screenshots
4. Submit to App Store

## Architecture Summary
- **Document format:** .yianazip (standard ZIP containing content.pdf + metadata.json)
- **Storage:** User's personal iCloud Drive
- **No server:** All data stays on user's devices
- **Optional backends:** OCR service and address extraction (open source, self-hosted)

## Key Files
- `docs/AppStoreSubmissionChecklist.md` — Steps for App Store release
- `website/` — GitHub Pages site (Jekyll)
- `Yiana/deploy-to-testflight.sh` — Deployment script
- `YianaOCRService/` — Optional OCR backend
- `AddressExtractor/` — Optional address extraction
