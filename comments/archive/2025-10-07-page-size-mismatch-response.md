# Response: Page Size & Gesture Diagnostics
**Date**: 2025-10-07  
**Author**: GPT-5 Codex  
**Related Reviews**: `2025-10-07-page-size-mismatch-diagnosis.md`, `2025-10-07-tolerance-calculation.md`

## Reviewer Findings & Actions
- **Mixed page sizes break gesture tolerance**  
  - Confirmed merged documents contained US Letter scans (~612×792 pt) and A4 markdown pages (595.2×841.8 pt).  
  - Scanning pipeline now honors the shared `TextPageLayoutSettings` preference, emitting fixed-size pages with centered content (`Yiana/Yiana/Services/ScanningService.swift`).  
  - Markdown renderer already respects the same setting; default remains A4, with US Letter selectable for US teams.

- **Gesture tolerance too strict (0.01)**  
  - Increased tolerance to `0.10`, matching reviewer calculations so swipe-up/down gestures work across iPhone/iPad with mixed stock (`Yiana/Yiana/Views/PDFViewer.swift:427`).

- **Need configurable paper size**  
  - Added paper-size menu to the text editor toolbar; selection persists via `TextPageLayoutSettings` and triggers an immediate preview re-render (`Yiana/Yiana/Views/TextPageEditorView.swift`, `Yiana/Yiana/ViewModels/TextPageEditorViewModel.swift`).

## Follow-up / Open Items
- Consider surfacing the paper-size selector in a global settings view for discoverability (currently lives in the editor toolbar).  
- Evaluate PDF normalization for previously scanned documents (existing files retain their original geometry).  
- Test tolerance change on physical iPad hardware during QA sweep.
