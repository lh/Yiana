# Progress Tracker

## Current Status: Beta Testing

Build 49 is live on TestFlight. Website live at https://lh.github.io/Yiana/

---

## Completed ✅

### Core App
- [x] Document scanning (monochrome and colour)
- [x] Text notes (save as PDF on exit)
- [x] Add text to pages with precise positioning
- [x] PDF import
- [x] Folder organisation
- [x] iCloud sync (iPhone, iPad, Mac)
- [x] Document search
- [x] Page management (add, delete, reorder)
- [x] Bulk PDF export (Mac)
- [x] Welcome document for new users

### Infrastructure
- [x] .yianazip format (ZIP with PDF + metadata)
- [x] UIDocument (iOS) / NSDocument (Mac) architecture
- [x] DocumentRepository for file management
- [x] YianaDocumentArchive Swift package

### Optional Backends
- [x] YianaOCRService (Mac-based OCR processing)
- [x] AddressExtractor (Python address extraction)
- [x] Address database integration in app
- [x] Graceful degradation when backends unavailable

### App Store Preparation
- [x] TestFlight deployment (Build 49)
- [x] Entitlements set to production
- [x] Privacy policy published
- [x] Support page published
- [x] GitHub Pages website with Jekyll
- [x] "Why Yiana" about page
- [x] Beta disclaimer added
- [x] App Store submission checklist written

---

## In Progress 🔄
- [ ] Gathering TestFlight user feedback
- [ ] Monitoring for bug reports

---

## Not Started ❌
- [ ] App Store screenshots
- [ ] App Store submission
- [ ] Open source release of backends

---

## Milestones

### Phase 1: Core App ✅
- Document management, scanning, viewing
- iCloud sync
- Basic UI

### Phase 2: Advanced Features ✅
- Text notes
- Add text to pages
- Folder organisation
- Search

### Phase 3: Polish & Backend ✅
- OCR backend service
- Address extraction
- Bulk export
- Welcome document

### Phase 4: Release (Current)
- TestFlight beta ✅
- Website ✅
- User feedback 🔄
- App Store submission ❌

---

## Version History

| Build | Date | Notes |
|-------|------|-------|
| 49 | Jan 2025 | Beta release to TestFlight. Welcome document, graceful degradation, website live. |
