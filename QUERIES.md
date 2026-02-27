# Documentation Queries

All items resolved. This file can be deleted after review.

## Resolved During Verification

1. **Folder rename** -- Fully implemented. FAQ corrected from "Not yet" to "Yes".
2. **Tags** -- Metadata field exists and displays read-only in info panels, but no UI to add/edit/filter. Documented as a known limitation.
3. **Backup/restore** -- Bulk export exists (macOS). No daily-backup/revert system. Documented bulk export as the backup mechanism.
4. **On-device OCR** -- Fully implemented via Vision framework. Runs automatically. No user toggle.
5. **Deployment targets** -- iOS 18.5, macOS 15.5. Updated everywhere.
6. **.yianazip format** -- ZIP archive (metadata.json + content.pdf + format.json). Fixed everywhere.

## Resolved After Review

7. **Address extraction** -- Wrote a separate backend guide at `Yiana/docs/dev/AddressExtraction.md` with full pipeline docs and LLM prompts for domain adaptation. User docs reference it.
8. **"Coming soon" removal** -- All removed from user docs. Forward-looking language only in dev/Roadmap.md. Confirmed OK.
9. **iOS print** -- Documented as share sheet for iOS, Cmd+P for macOS. Confirmed accurate.
10. **Swipe down gesture** -- Not implemented. Removed from gesture tables. Confirmed correct.
11. **Connected scanner on macOS** -- Not implemented. Removed from user docs. Logged to Serena ideas_and_problems memory: out of scope (DevonTHINK territory, would need external LLM integration).

## Out of Scope (noted for future)

These files still reference the old `.yianazip` byte-separator format but are historical/reference docs:
- `Yiana/docs/DataStructures.md`
- `Yiana/docs/Phase11-Summary.md`
- `Yiana/docs/diagrams/data-flow.md`
