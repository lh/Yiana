# Address Extraction - UX & Architecture Design

**Date**: November 1, 2025
**Status**: Phase 1 (MVP) - In Progress
**Related**: AddressExtractor system in `/AddressExtractor/`

---

## Overview

Integration of the Python-based address extraction system into the Yiana iOS/macOS app. Extracts patient/GP/optician addresses from OCR text and displays them in the app for letter generation and record keeping.

---

## Design Decisions

### 1. UI Placement - Addresses Tab (DECIDED ✅)

**Decision**: Add "Addresses" as the **first tab** in DocumentInfoSheet

```
Tab order: [Addresses] [Metadata] [Text] [Debug]
                ↑ Primary use case
```

**Rationale**:
- Most frequently accessed information for patient correspondence
- Natural fit alongside other document metadata
- Non-intrusive (doesn't clutter main document view)
- Future-proofs for letter-writing app integration

**Alternative Considered**: Separate toolbar button → Rejected (too cluttered)

---

### 2. Database Location - iCloud Container (PHASE 1 ✅)

**Current Decision (MVP)**: Option A - Same iCloud container as documents

```
iCloud.com.vitygas.Yiana/
├── Documents/           # .yianazip files
├── .ocr_results/        # OCR JSON output
└── addresses.db         # Extracted addresses (NEW)
```

**Pros**:
- Single sync mechanism (iCloud handles it)
- Available offline on all devices
- No network API needed
- Fast local SQLite queries
- Simple to implement

**Cons**:
- Database conflicts if editing from multiple devices (mitigated: single user)
- iCloud sync can be slow for databases (mitigated: small DB size)

**IMPORTANT - Future Migration Path**:

### **OPTION C - Hybrid Approach (PLANNED FOR PHASE 4)**

When scaling beyond single user or deploying extraction service:

```
Devon (Master):
  /Users/devon/.yiana/addresses.db (read/write)

iCloud (Cache):
  iCloud.com.vitygas.Yiana/addresses_cache.db (read-only)
  + sync_metadata.json (last sync timestamp, version)

Yiana App:
  - Reads from cache (fast, offline)
  - User edits stored in document metadata (NOT in DB)
  - Periodic sync updates cache from master
```

**Migration Strategy**:
1. Keep Swift database wrapper interface identical
2. Change only the file path being read
3. Add background sync service on devon
4. No changes to UI layer needed

**Trigger for Migration**:
- Multi-device editing conflicts arise
- Extraction service deployed to devon
- Need centralized backup/audit trail

---

### 3. Encryption Strategy (DECIDED ✅)

**Current State**: Yiana stores all data in **plaintext**
- Only crypto usage: SHA256 hashing for backup paths
- No encryption of PDFs, metadata, or OCR results

**Decision**: Apply **iOS Data Protection** to all Yiana files

**Implementation**:
```swift
// Set on all file writes:
try data.write(to: url, options: .completeUntilFirstUserAuthentication)

// Or for existing files:
try FileManager.default.setAttributes(
    [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
    ofItemAtPath: path
)
```

**What This Provides**:
- Files encrypted when device locked
- Automatic decryption when device unlocked
- OS-managed, zero performance impact
- No vendor lock-in (standard file format underneath)
- Good enough for personal medical data

**What This Doesn't Provide**:
- Encryption while device unlocked
- Protection if device compromised while unlocked
- Password-based database encryption

**Future Upgrade Path (if needed)**:

1. **SQLCipher** (addresses.db only)
   - Encrypted SQLite with password
   - Open source, no lock-in
   - Database file itself is encrypted
   - Key stored in iOS Keychain

2. **Full CryptoKit Encryption** (all files)
   - Encrypt PDFs, JSON, DB with AES-256
   - More complex key management
   - Full control over encryption

**Decision Criteria for Upgrade**:
- Regulatory requirement (HIPAA, GDPR)
- Multi-user deployment
- Cloud backup security concerns

---

### 4. Multiple Patients - List All + Smart Alerts (DECIDED ✅)

**Decision**: Display all extracted addresses with intelligent conflict detection

**UI Design**:

```
┌─────────────────────────────────┐
│ Addresses (3 found)       🔔 1   │ ← Badge for unresolved conflicts
├─────────────────────────────────┤
│ 📄 Patient 1 (Page 1)            │
│   Patricia Wheatley              │
│   DOB: 12/03/1956                │
│   123 Main St, Brighton BN1 1AA  │
│   GP: Dr E Robinson              │
│   Confidence: 85%                │
│   [Set as Primary] [Edit]        │
├─────────────────────────────────┤
│ 📄 Patient 2 (Page 5) ⭐ PRIMARY │
│   John Smith                     │
│   DOB: 05/11/1962                │
│   456 Oak Rd, London SW1 1AA     │
│   GP: Dr S Jones                 │
│   Confidence: 92%                │
│   [Edit]                         │
├─────────────────────────────────┤
│ ⚠️ Potential Duplicate (Page 8)   │
│   Patricia Wheatley              │
│   789 New Address, Brighton BN2  │
│   [Same Person - Address Changed?]
│   [Different Patient]            │
└─────────────────────────────────┘
```

**Smart Detection Rules**:
- Same name + different address → "Address Changed?" alert
- Same address + different name → "Possible Error" alert
- Multiple unique people → List without alert

**Rationale**:
- Medical records often span years (addresses change)
- Referral letters may mention multiple patients
- Future use: General letter-writing tool (not GP-specific)
- Future integration: Letter-writing app (not yet developed)

---

### 5. Editing Workflow - Read-Only First, Then Override (PHASED)

**Phase 1 (MVP - Current)**: Read-only display
- Show extracted data
- No editing capability
- Validate extraction is working correctly

**Phase 2 (Next)**: User overrides
- [Edit] button shows editable form
- User edits stored in **document metadata**, NOT database
- Prevents auto-extraction from overwriting user corrections

**Data Model**:
```swift
// Add to DocumentMetadata:
struct AddressOverride: Codable {
    let addressId: String        // Links to extracted_addresses.id
    let userFullName: String?
    let userAddress: String?
    let userGPName: String?
    let userGPAddress: String?
    let markedAsPrimary: Bool
    let verifiedByUser: Bool
    let lastEditedAt: Date
}

var addressOverrides: [AddressOverride] = []
var addressConflictsResolved: Bool = false
```

**Display Priority**:
1. User override (if exists) → Show with "✏️ User Edited" badge
2. Auto-extracted → Show with confidence score
3. No data → "No addresses found"

**Change Detection** (Phase 3):

When new pages added with different addresses:
1. Extract new addresses from new pages
2. Compare to existing addresses (fuzzy match on name)
3. If conflict: Set `addressConflictsResolved = false`
4. Show notification badge on Addresses tab
5. User reviews and chooses action:
   - Keep current
   - Use new
   - Mark as different patient
   - Manual override

**Never Auto-Replace Rules**:
- ❌ Never replace user-edited data automatically
- ❌ Never update without user review
- ✅ Always notify user of conflicts
- ✅ Always preserve edit history

---

## Implementation Phases

### Phase 1 - MVP (Current Session)
**Goal**: Display extracted addresses, validate system works

- [x] Document design decisions (this file)
- [ ] Apply iOS Data Protection to all Yiana files
- [ ] Copy `addresses.db` to iCloud container
- [ ] Create Swift database wrapper (`AddressRepository.swift`)
- [ ] Add "Addresses" tab to DocumentInfoSheet (first position)
- [ ] Display extracted addresses (read-only)
- [ ] Show: Name, DOB, Address, GP, Confidence, Page Number
- [ ] Handle "no addresses found" gracefully

**Success Criteria**:
- Can view extracted addresses in Yiana app
- Data syncs across devices via iCloud
- Files protected when device locked

---

### Phase 2 - Safety & Intelligence (Next Session)
**Goal**: Handle real-world complexity

- [ ] Multi-patient display with primary marking
- [ ] Duplicate/conflict detection alerts
- [ ] GP fuzzy matching against 12k practice database
- [ ] Address validation (postcode format, district extraction)
- [ ] Confidence score visualization

**Success Criteria**:
- Correctly identifies duplicate patients
- Alerts user to address conflicts
- Matches GPs to official database

---

### Phase 3 - Editing (Future)
**Goal**: Allow user corrections and overrides

- [ ] Edit functionality with form UI
- [ ] User override storage in document metadata
- [ ] Change detection when new pages added
- [ ] Conflict resolution UI
- [ ] Edit history tracking

**Success Criteria**:
- User can correct wrong extractions
- Edits never lost when re-scanning
- Clear audit trail of changes

---

### Phase 4 - Production Deployment (Future)
**Goal**: Scale to multi-device, deploy extraction service

- [ ] Deploy AddressExtractor service to devon
- [ ] Migrate to Option C (hybrid master/cache architecture)
- [ ] Background sync service (devon → iCloud cache)
- [ ] Consider SQLCipher encryption upgrade
- [ ] Build letter-writing app integration
- [ ] Export functionality (CSV, vCard, etc.)

**Success Criteria**:
- Extraction runs automatically on devon
- No conflicts from multi-device access
- Ready for letter generation workflow

---

## Technical Architecture

### Data Flow (Phase 1)

```
PDF Document
    ↓
OCR Service (devon) → .ocr_results/{documentId}.json
    ↓
AddressExtractor (Python) → addresses.db
    ↓
iCloud Sync → iCloud.com.vitygas.Yiana/addresses.db
    ↓
Yiana App (Swift) → AddressRepository → DocumentInfoSheet
```

### Data Flow (Phase 4 - Future)

```
PDF Document
    ↓
OCR Service (devon) → .ocr_results/{documentId}.json
    ↓
AddressExtractor (devon) → /Users/devon/.yiana/addresses.db (MASTER)
    ↓
Sync Service → iCloud/addresses_cache.db (READ-ONLY CACHE)
    ↓
Yiana App (Swift) → AddressRepository → DocumentInfoSheet
    ↑
User Edits → DocumentMetadata.addressOverrides (NOT in DB)
```

**Key Principle**:
- **Machine data** (auto-extracted) lives in database
- **Human data** (user corrections) lives in document metadata
- Clear separation prevents merge conflicts

---

## Database Schema

### Current Schema (addresses.db)

```sql
CREATE TABLE extracted_addresses (
    id INTEGER PRIMARY KEY,
    document_id TEXT NOT NULL,        -- Links to NoteDocument.metadata.id
    page_number INTEGER,              -- 1-based page number

    -- Patient Information
    full_name TEXT,
    date_of_birth TEXT,

    -- Address
    address_line_1 TEXT,
    address_line_2 TEXT,
    city TEXT,
    county TEXT,
    postcode TEXT,
    country TEXT DEFAULT 'UK',

    -- Contact Details
    phone_home TEXT,
    phone_work TEXT,
    phone_mobile TEXT,

    -- GP Information
    gp_name TEXT,
    gp_practice TEXT,
    gp_address TEXT,
    gp_postcode TEXT,
    gp_ods_code TEXT,                 -- NHS ODS code (official)
    gp_official_name TEXT,            -- Matched from gp_local.db

    -- Metadata
    extraction_confidence REAL,       -- 0.0 to 1.0
    extraction_method TEXT,           -- 'pattern', 'spire_form', 'llm'
    extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- Validation
    postcode_valid BOOLEAN,
    postcode_district TEXT,           -- e.g., 'BN1' from 'BN1 1AA'

    -- Raw Data
    raw_text TEXT,                    -- Original OCR text
    ocr_json TEXT                     -- Full OCR JSON for debugging
);

CREATE INDEX idx_document_id ON extracted_addresses(document_id);
CREATE INDEX idx_page_number ON extracted_addresses(document_id, page_number);
```

### Related Databases

**gp_local.db** (12,369 practices)
- Used for fuzzy matching GP names to official NHS data
- Provides ODS codes, official names, addresses

**letter_addresses.db** (8 patients, 7 practitioners)
- Letter generation system (future integration)
- Tracks sent letters and missing addresses

**opticians_uk.db** (7 records)
- UK optician database (needs population)
- Chain/independent classification

---

## Security & Privacy

### Current State (Phase 1)
- **iOS Data Protection**: Files encrypted when device locked
- **iCloud sync**: Encrypted in transit by Apple
- **No password**: Data accessible when device unlocked
- **Single user**: No multi-user access control

### Future Considerations
- **SQLCipher**: Password-protected database encryption
- **Field-level encryption**: Encrypt sensitive fields (DOB, addresses)
- **Audit logging**: Track all address access/edits
- **Retention policy**: Auto-delete old extractions
- **Export controls**: Password-protect CSV exports

### Privacy Design Principles
1. **Minimal exposure**: Only show addresses when needed
2. **User control**: Easy to view/edit/delete extracted data
3. **No cloud processing**: All extraction happens locally/devon
4. **Transparency**: Clear indicators of auto vs. user data
5. **Portability**: Standard formats, easy export

---

## Open Questions & Future Decisions

### 1. Multi-User Scenario
**Question**: How to handle if multiple doctors use same Yiana install?
**Options**:
- User profiles with separate databases
- Document-level permissions
- Separate iCloud accounts

**Decision**: Defer until needed (currently single-user)

---

### 2. Letter Writing Integration
**Question**: When building letter app, how to link addresses?
**Options**:
- Direct database read (share AddressRepository)
- Export API (JSON/CSV)
- Shared Swift Package

**Decision**: Defer until letter app design begins

---

### 3. Backup Strategy
**Question**: How to back up extracted addresses separately from documents?
**Options**:
- iCloud backup (automatic)
- Time Machine (automatic on macOS)
- Manual export to CSV/JSON
- Dedicated backup service

**Decision**: Rely on iCloud for Phase 1, revisit in Phase 4

---

### 4. Conflict Resolution
**Question**: What if same patient has 3 different addresses in one document?
**Options**:
- Let user pick "primary"
- Show all with timestamps/page numbers
- Auto-pick most recent (risky)

**Decision**: Show all, let user mark primary (Phase 2)

---

## Success Metrics

### Phase 1 (MVP)
- [ ] 100% of extracted addresses visible in app
- [ ] Zero crashes from database access
- [ ] iCloud sync working across devices
- [ ] Files protected when device locked

### Phase 2 (Safety)
- [ ] >90% GP matches to official database
- [ ] User reviews all conflict alerts
- [ ] Zero false duplicate alerts

### Phase 3 (Editing)
- [ ] User edits never overwritten
- [ ] 100% conflict detection accuracy
- [ ] Clear audit trail of all changes

### Phase 4 (Production)
- [ ] Extraction service runs 24/7 on devon
- [ ] <5 minute sync delay master→cache
- [ ] Zero data loss incidents
- [ ] Letter integration working

---

## Related Documentation

- **AddressExtractor/README.md**: Python extraction system docs
- **AddressExtractor/INTEGRATION_GUIDE.md**: Integration patterns
- **docs/Architecture.md**: Overall Yiana architecture
- **PLAN.md**: Project roadmap
- **CODING_STYLE.md**: Swift code conventions

---

## Change Log

| Date | Change | Reason |
|------|--------|--------|
| 2025-11-01 | Initial design document | Capture UX/architecture decisions |
| 2025-11-01 | Option A (iCloud) selected for MVP | Simplicity, single user |
| 2025-11-01 | iOS Data Protection for all files | Balance security vs. lock-in |
| 2025-11-01 | Addresses tab as first position | Primary use case priority |

---

**Next Steps**: Implement Phase 1 MVP
