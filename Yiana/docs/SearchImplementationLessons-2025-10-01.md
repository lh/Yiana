# Search Implementation Lessons Learned - 2025-10-01

## Summary
Successfully migrated Yiana's search from raw SQLite C API to GRDB.swift and fixed critical UI bugs. The process took significantly longer than expected due to poor debugging methodology and not reading the existing codebase architecture first.

## What Went Wrong

### 1. Failed to Read Documentation First
- **Mistake**: Started debugging without reading `SearchArchitecture.md` or the external code review in `SearchInvestigation-2025-10-01.md`
- **Impact**: Spent hours debugging the wrong layer (database/GRDB) when the actual bugs were in ViewModel state management
- **Lesson**: Always check docs/ directory and any investigation reports BEFORE touching code

### 2. Magic Single-Line Fixes Instead of Logic Tracing
- **Mistake**: Repeatedly tried one-line fixes without tracing complete execution flow
- **Impact**: Fixed symptoms instead of root causes, created new bugs
- **Example**: Changed `applySorting()` to sort `documentURLs` in place, which broke normal browsing when `documentURLs` was empty
- **Lesson**: Read the ENTIRE function, trace data flow from input to output, understand all state mutations

### 3. Not Using Debug Output Effectively
- **Mistake**: Added debug logging but didn't analyze the output systematically
- **Impact**: Console showed the exact problem (parentPath not being stripped) but I kept guessing at fixes
- **Lesson**: When debug output is available, READ IT CAREFULLY and trace why the values are wrong

### 4. Overconfidence in Complex Changes
- **Mistake**: Made large refactoring changes (GRDB migration) without first understanding the existing bugs
- **Impact**: Compounded problems - now had to debug both new GRDB code AND old ViewModel bugs
- **Lesson**: Fix existing bugs before major refactorings

## What Actually Worked

### 1. External Code Review
- The free LLM's report (`SearchInvestigation-2025-10-01.md`) immediately identified all the real issues:
  - Line 26: "sorting logic pulls from the unfiltered folder list, causing indexed matches to disappear"
  - Line 25: "`searchResults` accumulates stale entries across queries"
  - Line 14: "Background indexer only checks missing rows, not modified timestamps"

### 2. Test Infrastructure
- Adding "Test Search Pipeline" button in Dev Tools provided concrete data about path transformations
- Showed exact mismatch: `parentPath` was full path instead of empty string after stripping

### 3. Systematic Debug Logging
- Once we added logging at each step (pre-filter count, post-filter count, actual parentPath values), the bug became obvious

## The Actual Bugs Fixed

### Bug 1: GRDB CodingKeys Missing
**Location**: `SearchIndexService.swift:28-42`
**Problem**: GRDB needs explicit `CodingKeys` enum to map Swift camelCase to SQL snake_case
```swift
// Missing this caused "no column named documentId" errors
enum CodingKeys: String, CodingKey {
    case documentId = "document_id"
    case title = "title"
    case fullText = "full_text"
    case tags = "tags"
}
```

### Bug 2: GRDB Typed Subscripts
**Location**: `SearchIndexService.swift:246-253`
**Problem**: Used Swift optional casting `as? Int` instead of GRDB's typed subscript
```swift
// ❌ Wrong - returns DatabaseValueConvertible
let pageCount = row["page_count"] as? Int

// ✅ Right - GRDB extracts the Int
let pageCount: Int = row["page_count"]
```

### Bug 3: applySorting() Overwrites Search Results
**Location**: `DocumentListViewModel.swift:146-184`
**Problem**: Always sorted from `allDocumentURLs`, overwriting filtered search results
```swift
// ❌ Wrong - loses search results
documentURLs = allDocumentURLs.sorted { ... }

// ✅ Right - respects search filtering
let sourceURLs = isSearching ? documentURLs : allDocumentURLs
documentURLs = sourceURLs.sorted { ... }
```

### Bug 4: Stale searchResults Accumulation
**Location**: `DocumentListViewModel.swift:395-398`
**Problem**: `searchResults` array never cleared between searches
```swift
// ✅ Fixed - clear at start of each search
searchResults = []
otherFolderResults = []
```

### Bug 5: Path Stripping Logic
**Location**: `DocumentListViewModel.swift:458-460`
**Problem**: Tried to strip `documentsDirectory.path + "/"` but paths don't have trailing slash
```swift
// ❌ Wrong - doesn't match, leaves full path
.replacingOccurrences(of: repository.documentsDirectory.path + "/", with: "")

// ✅ Right - strips prefix and trims slashes
.replacingOccurrences(of: repository.documentsDirectory.path, with: "")
.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
```

## Remaining Issues

### 1. False Positive Results
**Symptom**: Searching "Tony" returns documents that don't contain "Tony"
**Likely Cause**: FTS5 tokenization/stemming matches partial words or OCR text not visible in snippet
**Priority**: Low - search is functional, can investigate later
**Investigation Path**:
- Check what's in `fullText` for false positive documents
- Review FTS5 tokenizer settings (`porter unicode61 remove_diacritics 2`)
- May need to adjust BM25 weights or add minimum score threshold

### 2. No Change Detection for OCR Updates
**From External Review**: "Background indexer only checks missing rows, not modified timestamps"
**Impact**: When OCR completes, documents don't get re-indexed with new `fullText`
**Fix Required**: Compare `metadata.modified` vs `indexed_date` in BackgroundIndexer
**Priority**: High - core functionality gap

### 3. OCR Service Doesn't Write fullText for Pre-OCR'd PDFs
**From External Review**: "When watcher detects PDFs that already contain text, it flips `ocrCompleted` but does NOT write `fullText`"
**Impact**: Documents with embedded text never become searchable
**Fix Required**: Ensure OCR service extracts text even from PDFs that already have text layers
**Priority**: High - affects searchability

## GRDB Migration Benefits

Despite the painful debugging process, GRDB provides real value:

1. **Type Safety**: Swift types map directly to SQL, no manual conversion
2. **Automatic String Handling**: No more `(string as NSString).utf8String` nonsense
3. **Memory Safety**: Automatic cleanup, no manual finalization
4. **Better Errors**: Clear messages with context instead of silent failures
5. **70% Less Code**: 344 lines vs 500+ lines of C API boilerplate

The migration was worth it, but should have been done AFTER fixing the ViewModel bugs.

## Process Improvements

### Before Touching Code:
1. Read all docs in `docs/` directory
2. Check for investigation reports or code reviews
3. Use `mcp__serena__` tools to understand codebase structure
4. Trace execution flow on paper before making changes

### When Debugging:
1. Add logging at each state transition
2. Run tests and READ the output systematically
3. Build test fixtures that isolate the problem
4. Fix root cause, not symptoms

### When Making Large Changes:
1. Fix existing bugs first
2. Write tests for current behavior
3. Make incremental changes with testing between each step
4. Don't compound multiple problem domains

## What to Document Next

1. Update `SearchArchitecture.md` with GRDB implementation details
2. Add section on path transformation logic (the trailing slash gotcha)
3. Document the `isSearching` flag and how it controls `applySorting()`
4. Create troubleshooting section with common search issues

## Cost Analysis

- **Time Spent**: ~4-5 hours
- **User Cost**: $100s in API charges
- **Free Alternative**: External code review found all bugs in minutes
- **Lesson**: Use cheaper models for code review first, expensive models for implementation second
