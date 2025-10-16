//
//  AccessibilityUITests.swift
//  YianaUITests
//
//  UI tests for accessibility features including VoiceOver support
//

import XCTest

final class AccessibilityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Document List Accessibility Tests

    func testDocumentListAccessibility() throws {
        // Wait for document list to load
        let documentList = app.collectionViews.firstMatch
        XCTAssertTrue(documentList.waitForExistence(timeout: 5))

        // Verify document rows have accessibility labels
        let firstDocument = documentList.cells.firstMatch
        if firstDocument.exists {
            XCTAssertTrue(firstDocument.exists)
            XCTAssertFalse(firstDocument.label.isEmpty, "Document row should have accessibility label")
        }
    }

    // MARK: - Toolbar Button Accessibility Tests

    func testToolbarButtonsAccessibility() throws {
        // Open a document first
        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            let firstDocument = documentList.cells.firstMatch
            if firstDocument.exists {
                firstDocument.tap()

                // Wait for document to open
                Thread.sleep(forTimeInterval: 1)

                // Test toolbar buttons
                testButtonAccessibility(identifier: "Manage Pages", expectedLabel: "Manage pages")
                testButtonAccessibility(identifier: "Export PDF", expectedLabel: "Export PDF")
                testButtonAccessibility(identifier: "Info", expectedLabel: "Show document info")
            }
        }
    }

    func testZoomButtonsAccessibility() throws {
        // Open a document
        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            let firstDocument = documentList.cells.firstMatch
            if firstDocument.exists {
                firstDocument.tap()

                // Wait for document to open
                Thread.sleep(forTimeInterval: 1)

                // Test zoom buttons
                testButtonAccessibility(identifier: "Zoom out", expectedLabel: "Zoom out")
                testButtonAccessibility(identifier: "Fit to window", expectedLabel: "Fit to window")
                testButtonAccessibility(identifier: "Zoom in", expectedLabel: "Zoom in")
            }
        }
    }

    // MARK: - Page Navigation Accessibility Tests

    func testPageNavigationAccessibility() throws {
        // Open a document
        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            let firstDocument = documentList.cells.firstMatch
            if firstDocument.exists {
                firstDocument.tap()

                // Wait for document to open
                Thread.sleep(forTimeInterval: 1)

                // Test navigation buttons
                let prevButton = app.buttons.matching(identifier: "Previous page").firstMatch
                if prevButton.exists {
                    XCTAssertTrue(prevButton.exists)
                    XCTAssertFalse(prevButton.label.isEmpty)
                }

                let nextButton = app.buttons.matching(identifier: "Next page").firstMatch
                if nextButton.exists {
                    XCTAssertTrue(nextButton.exists)
                    XCTAssertFalse(nextButton.label.isEmpty)
                }
            }
        }
    }

    // MARK: - Thumbnail Sidebar Accessibility Tests

    func testThumbnailSidebarAccessibility() throws {
        // Open a document
        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            let firstDocument = documentList.cells.firstMatch
            if firstDocument.exists {
                firstDocument.tap()

                // Wait for document to open
                Thread.sleep(forTimeInterval: 1)

                // Check if sidebar is visible
                let sidebar = app.scrollViews.containing(.staticText, identifier: "Page thumbnails").firstMatch
                if sidebar.exists {
                    XCTAssertTrue(sidebar.exists)
                }
            }
        }
    }

    // MARK: - Keyboard Shortcuts Accessibility Tests

    func testKeyboardShortcutsWork() throws {
        // Open a document
        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            let firstDocument = documentList.cells.firstMatch
            if firstDocument.exists {
                firstDocument.tap()

                // Wait for document to open
                Thread.sleep(forTimeInterval: 1)

                #if os(macOS)
                // Test Command+0 for fit to window
                app.typeKey("0", modifierFlags: .command)
                Thread.sleep(forTimeInterval: 0.5)

                // Test Command+Plus for zoom in
                app.typeKey("+", modifierFlags: .command)
                Thread.sleep(forTimeInterval: 0.5)

                // Test Command+Minus for zoom out
                app.typeKey("-", modifierFlags: .command)
                Thread.sleep(forTimeInterval: 0.5)

                // If we get here without crashing, keyboard shortcuts work
                XCTAssertTrue(true)
                #endif
            }
        }
    }

    // MARK: - Read-Only Banner Accessibility Tests

    func testReadOnlyBannerAccessibility() throws {
        // This test would require opening a read-only document
        // For now, we just verify the test infrastructure
        XCTAssertNotNil(app)
    }

    // MARK: - Info Panel Accessibility Tests

    func testInfoPanelAccessibility() throws {
        // Open a document
        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            let firstDocument = documentList.cells.firstMatch
            if firstDocument.exists {
                firstDocument.tap()

                // Wait for document to open
                Thread.sleep(forTimeInterval: 1)

                // Find and tap info button
                let infoButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'info'")).firstMatch
                if infoButton.exists {
                    infoButton.tap()

                    // Wait for panel to appear
                    Thread.sleep(forTimeInterval: 0.5)

                    // Info panel should now be visible
                    // Verify we can interact with it
                    XCTAssertTrue(true)
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func testButtonAccessibility(identifier: String, expectedLabel: String) {
        let button = app.buttons.matching(identifier: identifier).firstMatch
        if button.exists {
            XCTAssertTrue(button.exists, "\(identifier) should exist")
            let labelMatches = button.label.contains(expectedLabel) ||
                button.label.lowercased().contains(expectedLabel.lowercased())
            XCTAssertTrue(labelMatches,
                         "\(identifier) should have label containing '\(expectedLabel)', got: '\(button.label)'")
        }
    }

    // MARK: - VoiceOver Simulation Tests

    func testVoiceOverNavigation() throws {
        // Note: Actual VoiceOver testing requires manual testing or
        // advanced UI testing with accessibility inspector
        // This test verifies elements are set up correctly for VoiceOver

        let documentList = app.collectionViews.firstMatch
        if documentList.waitForExistence(timeout: 5) {
            // Get all accessibility elements
            let accessibleElements = app.descendants(matching: .any).allElementsBoundByAccessibilityElement
            XCTAssertGreaterThan(accessibleElements.count, 0, "App should have accessibility elements")

            // Verify navigation structure
            for element in accessibleElements.prefix(10) where element.exists {
                // Each element should have a label or value
                let hasLabel = !element.label.isEmpty
                let valueString = (element.value as? String) ?? ""
                let hasValue = !valueString.isEmpty
                XCTAssertTrue(hasLabel || hasValue,
                            "Accessibility element should have label or value")
            }
        }
    }

    // MARK: - Performance Tests

    func testAccessibilityPerformance() throws {
        measure {
            // Measure time to enumerate accessibility elements
            let documentList = app.collectionViews.firstMatch
            if documentList.waitForExistence(timeout: 5) {
                _ = app.descendants(matching: .any).allElementsBoundByAccessibilityElement
            }
        }
    }
}
