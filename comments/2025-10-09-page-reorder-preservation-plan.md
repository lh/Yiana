# Page Reorder Preservation Plan
**Date**: 2025-10-09
**Author**: GPT-5 Codex

## Current Situation
- `PageManagementView.saveChanges()` rebuilds a new `PDFDocument` by copying/splicing pages from `pages` (which includes both saved PDF pages and provisional draft pages).
- `page.copy()` works for scanned pages but produces blank pages for markdown-rendered pages (likely because those PDFPages are backed by a different document or contain annotations not carried over by the shallow copy).
- Simply falling back to the original `page` invokes the same issue because it's still referencing the page in the temporary reorder document.

## Root Cause Hypothesis
- Markdown pages originate from `TextPageRenderService` and may rely on internal `PDFAnnotation` or `PDFPage` state that becomes detached when the page is pulled from its document and reinserted elsewhere.
- `page.copy()` is not guaranteed to duplicate the page's content stream; when it fails, we need to recreate a page from the rendered data rather than reuse the existing object.

## Proposed Solution
### High-level Strategy
1. **Capture page data** from the source document before we manipulate the pages.
2. **Rebuild** the new document using those data blobs, guaranteeing the visual content is preserved.
3. Treat provisional pages carefully—only copy committed pages; keep provisional pages out of the reorder document.

### Detailed Steps
1. Before `loadPages()` populates `pages`, fetch `pdfData` (the saved document only) and create an array of `Data` blobs per page:
   - Example: `originalDocument.page(at: i)?.dataRepresentation()` (if available).
   - If `dataRepresentation()` isn’t available on `PDFPage`, use `PDFDocument.dataRepresentation()` with a single-page extraction (e.g., `page.document?.dataRepresentation()` or render the page with `PDFView` to a PDF context).
2. Store these blobs alongside the `pages` array (e.g., new property `originalPageData: [Data?]`).
3. When reordering, instead of copying the `PDFPage` directly, rebuild each page by loading its corresponding `Data` into a new `PDFDocument` and extracting `page(at: 0)`.
4. After building the new document, set `pdfData` to the combined data, call `refreshDisplayPDF()`, and reload the sidebar.
5. Ensure provisional pages (draft pages) are appended after the saved pages. They shouldn’t participate in the reorder until committed.

### Additional Considerations
- If per-page data extraction isn’t available, render each page to a `UIGraphicsPDFRenderer`/`PDFContext` to create a deep copy (essentially re-rendering the page into a temporary PDF).
- Add debug logging to confirm which path we use (copy vs. render) so we can diagnose future issues.
- Update tests (or add new ones) to reorder markdown-only documents and ensure the resulting PDF matches the original content (possibly by text extraction or by counting annotations).

## Next Steps
1. Prototype extraction of per-page `Data` for both scanned and markdown pages.
2. Update `PageManagementView` to store these data blobs when loading pages.
3. Modify `saveChanges()` to recreate pages from the stored data instead of using `page.copy()`.
4. Manually verify reorder behaves correctly for mixed page types (scanned + markdown).
5. Add regression notes/tests documenting the behavior.

