# Testing Strategy

**Purpose**: Unified testing strategy for Yiana project
**Audience**: Developers writing and reviewing tests
**Last Updated**: 2025-10-08

---

## Overview

Yiana follows **Test-Driven Development (TDD)** as a mandatory practice. This document outlines our testing strategy, coverage expectations, and best practices.

## Core Principles

1. **Test-First Development** - Write failing tests before implementation
2. **Comprehensive Coverage** - Test all code paths, especially edge cases
3. **Fast Feedback** - Tests should run quickly (<5 seconds for unit tests)
4. **Isolated Tests** - No dependencies between tests
5. **Readable Tests** - Tests serve as documentation

## Testing Pyramid

```
         /\
        /UI\          10% - End-to-end user workflows
       /Tests\
      /--------\
     /Integration\    30% - Component interactions
    /  Tests     \
   /--------------\
  /   Unit Tests   \  60% - Individual functions/classes
 /------------------\
```

### Unit Tests (60% of tests)

**Purpose**: Test individual functions, methods, and classes in isolation

**Scope**:
- Services (`DocumentRepository`, `TextPagePDFRenderer`, `OCRProcessor`)
- ViewModels (`DocumentListViewModel`, `DocumentViewModel`, `TextPageEditorViewModel`)
- Utilities (extensions, helpers)
- Models (data validation, transformations)

**Coverage targets**:
- Services: 80%+
- ViewModels: 70%+
- Utilities: 80%+
- Models: 90%+

**Location**: `YianaTests/`

### Integration Tests (30% of tests)

**Purpose**: Test interactions between components

**Scope**:
- Document creation → save → load → verify
- Scanning → PDF generation → append to document
- Text page → render → provisional composition → finalization
- Search → OCR results → result display

**Coverage targets**: All major workflows

**Location**: `YianaTests/Integration/`

### UI Tests (10% of tests)

**Purpose**: Test end-to-end user workflows

**Scope**:
- Document creation flow
- Scanning flow
- Text page creation flow
- Search flow
- Navigation

**Coverage targets**: Critical user paths only (not exhaustive)

**Location**: `YianaUITests/`

## TDD Workflow

### 1. Red Phase (Write Failing Test)

```swift
// YianaTests/DocumentRepositoryTests.swift
func testCreateDocumentRequiresTitle() {
    // Arrange
    let repo = DocumentRepository()

    // Act
    let result = repo.createDocument(title: "")

    // Assert
    XCTAssertNil(result, "Should not create document with empty title")
}
```

**Run test** (should FAIL):
```bash
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentRepositoryTests/testCreateDocumentRequiresTitle
```

### 2. Green Phase (Minimal Implementation)

```swift
// Yiana/Services/DocumentRepository.swift
func createDocument(title: String) -> NoteDocument? {
    guard !title.isEmpty else { return nil }  // Minimal fix

    // ... rest of implementation
    return document
}
```

**Run test** (should PASS):
```bash
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentRepositoryTests/testCreateDocumentRequiresTitle
```

### 3. Refactor Phase (Improve Code)

```swift
// Yiana/Services/DocumentRepository.swift
func createDocument(title: String) -> NoteDocument? {
    guard !title.isEmpty else {
        logger.warning("Attempted to create document with empty title")
        return nil
    }

    // ... improved implementation
    return document
}
```

**Run all tests** (should still PASS):
```bash
xcodebuild test -scheme Yiana
```

### 4. Commit

```bash
git add YianaTests/DocumentRepositoryTests.swift Yiana/Services/DocumentRepository.swift
git commit -m "Add title validation for document creation"
```

## Test Organization

### File Structure

```
YianaTests/
├── Unit/
│   ├── Services/
│   │   ├── DocumentRepositoryTests.swift
│   │   ├── TextPagePDFRendererTests.swift
│   │   ├── OCRProcessorTests.swift
│   │   └── ScanningServiceTests.swift
│   ├── ViewModels/
│   │   ├── DocumentListViewModelTests.swift
│   │   ├── DocumentViewModelTests.swift
│   │   └── TextPageEditorViewModelTests.swift
│   ├── Models/
│   │   ├── DocumentMetadataTests.swift
│   │   └── NoteDocumentTests.swift
│   └── Extensions/
│       └── PDFDocumentIndexingTests.swift
│
├── Integration/
│   ├── DocumentCreationFlowTests.swift
│   ├── ScanningFlowTests.swift
│   ├── TextPageFlowTests.swift
│   └── SearchFlowTests.swift
│
└── Helpers/
    ├── MockDocumentRepository.swift
    ├── TestDataFactory.swift
    └── TestHelpers.swift

YianaUITests/
├── DocumentCreationUITests.swift
├── ScanningUITests.swift
├── TextPageUITests.swift
└── SearchUITests.swift
```

### Naming Conventions

**Test class names**:
```swift
// ✅ GOOD
class DocumentRepositoryTests: XCTestCase { ... }
class TextPagePDFRendererTests: XCTestCase { ... }

// ❌ BAD
class DocumentTests: XCTestCase { ... }  // Too vague
class Tests: XCTestCase { ... }  // Not descriptive
```

**Test method names**:
```swift
// ✅ GOOD
func testCreateDocumentRequiresTitle() { ... }
func testRenderMarkdownToMultiplePagesWhenContentOverflows() { ... }
func testSearchReturnsPageNumberForOCRMatches() { ... }

// ❌ BAD
func test1() { ... }  // No description
func testDocument() { ... }  // Too vague
func testCreateDocumentRequiresTitleAndReturnsNilWhenEmptyAndLogsWarning() { ... }  // Too long
```

**Format**: `test[WhatIsBeingTested][ExpectedOutcome][OptionalCondition]`

## Test Patterns

### Arrange-Act-Assert (AAA)

```swift
func testAppendPDFIncrementsPageCount() {
    // Arrange - Set up test conditions
    let document = NoteDocument(fileURL: testURL)
    let originalPageCount = document.pageCount
    let pdfToAppend = createTestPDF(pageCount: 3)

    // Act - Perform the action being tested
    document.appendPDF(pdfToAppend)

    // Assert - Verify expected outcome
    XCTAssertEqual(document.pageCount, originalPageCount + 3)
}
```

### Given-When-Then (BDD style)

```swift
func testSearchReturnsPageNumberForOCRMatches() {
    // Given a document with OCR text on page 2
    let document = createDocumentWithOCR(
        pageText: ["", "Receipt for coffee", ""]
    )

    // When searching for "coffee"
    let results = searchService.search("coffee", in: document)

    // Then result includes page number 2
    XCTAssertEqual(results.first?.pageNumber, 2)
}
```

### Test Data Builders

```swift
// TestDataFactory.swift
class TestDataFactory {
    static func createDocument(
        title: String = "Test Document",
        pageCount: Int = 1,
        ocrCompleted: Bool = false
    ) -> NoteDocument {
        let metadata = DocumentMetadata(
            id: UUID(),
            title: title,
            created: Date(),
            modified: Date(),
            pageCount: pageCount,
            ocrCompleted: ocrCompleted,
            fullText: nil
        )
        return NoteDocument(fileURL: testURL, metadata: metadata)
    }
}

// Usage in tests
func testSearchOnlySearchesCompletedOCRDocuments() {
    let doc1 = TestDataFactory.createDocument(ocrCompleted: true)
    let doc2 = TestDataFactory.createDocument(ocrCompleted: false)
    // ... test logic
}
```

### Mocking

**Use protocols for dependencies**:

```swift
// Production code
protocol DocumentRepositoryProtocol {
    func createDocument(title: String) -> NoteDocument?
    func getDocument(id: UUID) -> NoteDocument?
}

class DocumentRepository: DocumentRepositoryProtocol {
    func createDocument(title: String) -> NoteDocument? { ... }
    func getDocument(id: UUID) -> NoteDocument? { ... }
}

// Test code
class MockDocumentRepository: DocumentRepositoryProtocol {
    var createDocumentCalled = false
    var createDocumentTitle: String?
    var documentToReturn: NoteDocument?

    func createDocument(title: String) -> NoteDocument? {
        createDocumentCalled = true
        createDocumentTitle = title
        return documentToReturn
    }

    func getDocument(id: UUID) -> NoteDocument? {
        return documentToReturn
    }
}

// Test usage
func testViewModelCreatesDocument() {
    let mockRepo = MockDocumentRepository()
    let viewModel = DocumentListViewModel(repository: mockRepo)

    viewModel.createDocument(title: "Test")

    XCTAssertTrue(mockRepo.createDocumentCalled)
    XCTAssertEqual(mockRepo.createDocumentTitle, "Test")
}
```

## Test Coverage

### Measuring Coverage

**Enable code coverage in Xcode**:
1. Edit Scheme → Test → Options
2. Check "Gather coverage for some targets"
3. Select Yiana target

**View coverage**:
1. Run tests (⌘U)
2. Open Report Navigator (⌘9)
3. Select latest test run
4. Click Coverage tab

**Command line**:
```bash
xcodebuild test -scheme Yiana -enableCodeCoverage YES -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Coverage Targets

| Component | Target | Current | Status |
|-----------|--------|---------|--------|
| Services | 80% | TBD | 🟡 |
| ViewModels | 70% | TBD | 🟡 |
| Models | 90% | TBD | 🟡 |
| Extensions | 80% | TBD | 🟡 |
| Views | N/A | N/A | UI tests only |

### What to Test

**DO test** ✅:
- Business logic (validation, calculations, transformations)
- Edge cases (nil, empty, max values)
- Error handling (failures, exceptions)
- State transitions (draft → saved, pending → completed)
- Data transformations (markdown → PDF, image → PDF)

**DON'T test** ❌:
- Framework code (PDFKit, SwiftUI)
- Third-party libraries (GRDB)
- Trivial getters/setters
- View rendering (use UI tests instead)

## Edge Cases and Boundary Conditions

### Critical Test Cases

**String inputs**:
- Empty string (`""`)
- Single character (`"a"`)
- Very long string (10,000 characters)
- Special characters (`"<>&\"'`)
- Unicode/emoji (`"🎉😀"`)
- Whitespace only (`"   "`)

**Numeric inputs**:
- Zero (`0`)
- Negative (`-1`)
- Max int (`Int.max`)
- Min int (`Int.min`)
- Off-by-one (page count - 1, page count + 1)

**Collections**:
- Empty array (`[]`)
- Single element (`[item]`)
- Large array (1000+ elements)
- Nil vs empty (`nil` vs `[]`)

**Page numbers** (1-based indexing):
```swift
func testPageIndexingEdgeCases() {
    let document = createTestDocument(pageCount: 10)

    // Valid cases
    XCTAssertNotNil(document.getPage(number: 1))  // First page
    XCTAssertNotNil(document.getPage(number: 10))  // Last page

    // Invalid cases
    XCTAssertNil(document.getPage(number: 0))  // Before first
    XCTAssertNil(document.getPage(number: 11))  // After last
    XCTAssertNil(document.getPage(number: -1))  // Negative
}
```

## Performance Testing

### Measuring Performance

```swift
func testSearchPerformance() {
    let largeDocument = createDocumentWithOCR(pageCount: 100)

    measure {
        _ = searchService.search("test query", in: largeDocument)
    }
}
```

**Performance baselines**:
- PDF rendering: <200ms per page
- Search: <100ms per document
- Document load: <50ms
- Provisional composition (cache hit): <1ms
- Provisional composition (cache miss): <50ms

### Load Testing

```swift
func testHandlesLargeDocuments() {
    let largeDocument = createTestDocument(pageCount: 500)

    XCTAssertNoThrow(try documentRepository.save(largeDocument))
    XCTAssertNotNil(documentRepository.load(id: largeDocument.id))
}
```

## UI Testing

### XCTest UI Testing

```swift
// YianaUITests/DocumentCreationUITests.swift
func testCreateNewDocument() {
    let app = XCUIApplication()
    app.launch()

    // Tap "New Document" button
    app.buttons["New Document"].tap()

    // Enter title
    let titleField = app.textFields["Document Title"]
    titleField.tap()
    titleField.typeText("Test Document")

    // Tap "Create"
    app.buttons["Create"].tap()

    // Verify document appears in list
    XCTAssertTrue(app.staticTexts["Test Document"].exists)
}
```

### UI Test Best Practices

**DO** ✅:
- Use accessibility identifiers
- Test critical user flows only
- Keep tests simple and readable
- Use page object pattern for complex flows

**DON'T** ❌:
- Test every UI variation
- Hardcode wait times (use `waitForExistence` instead)
- Make tests brittle with specific coordinates

### Accessibility Identifiers

```swift
// Production code
Button("New Document") {
    // ...
}
.accessibilityIdentifier("newDocumentButton")

// Test code
app.buttons["newDocumentButton"].tap()
```

## Testing Patterns for Yiana

### Testing 1-Based Page Indexing

```swift
func testPageIndexingUsesOneBased() {
    let document = createTestDocument(pageCount: 5)

    // Verify first page is page 1 (not 0)
    XCTAssertNotNil(document.getPage(number: 1))
    XCTAssertNil(document.getPage(number: 0))

    // Verify last page
    XCTAssertNotNil(document.getPage(number: 5))
    XCTAssertNil(document.getPage(number: 6))
}
```

### Testing Provisional Page Composition

```swift
func testProvisionalPageCompositionCaching() {
    let manager = ProvisionalPageManager()
    let savedPDF = createTestPDF(pageCount: 3)
    let draftPDF = createTestPDF(pageCount: 1)

    manager.updateProvisionalData(draftPDF)

    // First call (cache miss)
    let start1 = Date()
    let result1 = manager.combinedData(using: savedPDF)
    let time1 = Date().timeIntervalSince(start1)

    // Second call (cache hit)
    let start2 = Date()
    let result2 = manager.combinedData(using: savedPDF)
    let time2 = Date().timeIntervalSince(start2)

    // Verify cache hit is faster
    XCTAssertLessThan(time2, time1 * 0.1)  // At least 10x faster
    XCTAssertEqual(result1.data, result2.data)
}
```

### Testing Async Code

```swift
func testDocumentSaveIsAsync() async throws {
    let document = createTestDocument()

    await document.save()

    let loaded = try await documentRepository.load(id: document.id)
    XCTAssertEqual(loaded.title, document.title)
}
```

## Continuous Integration (CI)

### GitHub Actions (planned)

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run Tests
        run: xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Pre-commit Hook (optional)

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Run tests before allowing commit
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'

if [ $? -ne 0 ]; then
    echo "Tests failed. Commit aborted."
    exit 1
fi
```

## Test Maintenance

### When Tests Fail

1. **Don't skip failing tests** - Fix the test or the code
2. **Update tests when requirements change** - Tests should reflect current behavior
3. **Refactor tests** - Apply same quality standards as production code
4. **Remove obsolete tests** - Delete tests for removed features

### Flaky Tests

**Common causes**:
- Timing issues (use `waitForExpectation`)
- Shared state between tests
- Non-deterministic behavior (random, dates, UUIDs)

**Solutions**:
```swift
// ❌ BAD - timing dependent
Thread.sleep(forTimeInterval: 1.0)

// ✅ GOOD - explicit expectation
let expectation = XCTestExpectation(description: "Document saved")
document.save {
    expectation.fulfill()
}
wait(for: [expectation], timeout: 2.0)
```

## Resources

- [Apple XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)
- [Testing SwiftUI](https://developer.apple.com/documentation/swiftui/testing-swiftui-views)
- [CODING_STYLE.md](../../CODING_STYLE.md) - Code conventions
- [Contributing.md](../Contributing.md) - TDD workflow

## Summary

**Key Takeaways**:
- ✅ TDD is mandatory - write tests first
- ✅ Aim for 70-80% coverage on services and view models
- ✅ Test edge cases and error handling
- ✅ Keep tests fast, isolated, and readable
- ✅ Use mocks to isolate dependencies
- ✅ UI tests for critical user flows only

**Next Steps**:
- Review existing tests for coverage gaps
- Add integration tests for major workflows
- Set up CI pipeline for automated testing
- Create performance baselines
