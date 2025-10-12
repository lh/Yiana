# Next Steps

## macOS Page Copy/Cut/Paste
- [ ] Implement writable `DocumentViewModel` for macOS (mirror iOS APIs)
- [ ] Update `DocumentReadView` to host the new view-model and present the Page Organizer
- [ ] Ensure mac `NoteDocument` save flow handles page edits
- [ ] Address read-only cases (show banner, disable cut/paste)

## iPad Page Navigator
- Sidebar will remain a **page navigator** / quick jump surface
- Page Organizer is the **one place for editing operations**
- [ ] Add affordance (double-tap, context menu) to launch the Organizer from the sidebar
- [ ] Remove stray editing affordances from sidebar unless we bring it to full parity later

## Testing Follow-up
- [ ] Expand unit/UI tests for copy/cut/paste once mac work lands
