# Address System - Next Session TODOs

## Verification Needed
- [ ] Open Swift app and verify Addresses tab displays extracted data
- [ ] Test with document `Menis_Juana_080156` which has patient + GP records

## Extraction Quality Improvements
- [ ] Add exclusion patterns for noise (e.g., "Powered By Tcpdf", "wwwtcpdforg")
- [ ] Filter out hospital/business addresses that aren't patient data
- [ ] Improve name extraction for non-Spire forms

## Integration Work
- [ ] Integrate gp_matcher.py to look up ODS codes for extracted GP practices
- [ ] Connect GP practice lookup to extraction pipeline
- [ ] Add address validation (postcode lookup API)

## Service Deployment
- [ ] Configure extraction_service.py to run as launchd daemon
- [ ] Add health monitoring for extraction service
- [ ] Document service setup in README

## UI Enhancements (Swift App)
- [ ] Add address exclusions management UI
- [ ] Show extraction confidence in address cards
- [ ] Add "re-extract" button for documents

---
Last updated: 2025-01-06
Current state: Basic pipeline working (Python extraction → iCloud DB → Swift reading)
