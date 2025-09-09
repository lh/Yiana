# macOS Annotation Implementation Plan

This document outlines the engineering tasks required to build the "digital paper" annotation feature for the Yiana macOS application, based on the provided design document. The core philosophy is "permanent ink": annotations are flattened into the PDF and are not editable after being committed.

## Phase 1: UI Scaffolding & State Management

This phase focuses on building the user-facing controls and the state management that drives them.

1.  **Create `AnnotationState` Model:**
    *   Define an `ObservableObject` class named `AnnotationState`.
    *   It will publish properties like `currentTool: ToolType` (an enum with cases like `.none`, `.text`, `.highlight`), `selectedFont: String`, `selectedFontSize: CGFloat`, and `selectedColor: NSColor`.

2.  **Build the `AnnotationToolbar` View:**
    *   Create a new SwiftUI view for the toolbar.
    *   It will contain buttons for each tool (Text, Highlight, etc.). These buttons will update the `currentTool` property in the `AnnotationState` object.
    *   Add the "Commit Page" button. Initially, it can be disabled.
    *   Add the "Revert to Start of Day" dropdown/button.

3.  **Build the `AnnotationInspector` View:**
    *   Create a new SwiftUI view for the inspector panel.
    *   Its visibility will be tied to whether `currentTool` is something other than `.none`.
    *   It will contain UI controls (e.g., `Picker`, `Stepper`, `ColorPicker`) bound to the font, size, and color properties in `AnnotationState`.

4.  **Integrate into Main Document View:**
    *   In your primary Mac document view (likely modifying `EnhancedMacPDFViewer`), instantiate `AnnotationState` as a `@StateObject`.
    *   Add the `AnnotationToolbar` and `AnnotationInspector` as overlays or sibling views, passing the `AnnotationState` object down as an `EnvironmentObject` or `ObservedObject`.

## Phase 2: Temporary Annotation Layer

This phase implements the "ephemeral" editing experience before the "ink" is permanent.

1.  **Enhance `PDFViewer` Coordinator:**
    *   The `Coordinator` for your `PDFViewer` (`NSViewRepresentable`) will gain access to the `AnnotationState` object.
    *   It will manage a list of temporary annotations currently on the page, e.g., `var temporaryAnnotations: [PDFAnnotation] = []`.

2.  **Implement User Interaction Logic:**
    *   Add a gesture recognizer to the `PDFView`. When a user clicks on the PDF:
        *   **If `currentTool` is `.text`:** Create a new `PDFAnnotation` of type `.freeText` using the properties from `AnnotationState`. Add it to the `PDFPage` and the `temporaryAnnotations` array. Programmatically activate it so the user can begin typing immediately.
        *   **If `currentTool` is `.highlight`:** `PDFKit` has default behavior for text selection. We will observe the `PDFViewSelectionDidChange` notification. When a selection is made, create a corresponding `.highlight` annotation, style it, and add it to the page and the `temporaryAnnotations` array.

## Phase 3: The Flattening Engine

This is the core technical task that makes the ink permanent.

1.  **Create a `PDFPage+Flattening` Extension:**
    *   Create a new Swift file for an extension on `PDFKit.PDFPage`.
    *   Define a new method, `func pageByFlattening(annotations: [PDFAnnotation]) -> PDFPage?`.

2.  **Implement Core Graphics Drawing:**
    *   Inside this method, use `Core Graphics` to create a new in-memory graphics context (e.g., `CGContext`).
    *   First, draw the original page's content into the context: `self.draw(with: .mediaBox, to: context)`.
    *   Next, iterate through the provided `annotations` array and draw each one into the *same* context: `annotation.draw(with: .mediaBox, to: context)`.
    *   Finally, create a new `PDFPage` from the contents of this graphics context. Return this new, flattened page.

## Phase 4: Commit Triggers & Document Management

This phase connects the temporary annotations to the flattening engine based on user actions.

1.  **Create a `DocumentManager` Service:**
    *   This class will be responsible for handling the high-level logic of committing changes.
    *   It will contain a method `commitAnnotations(for page: PDFPage, in document: PDFDocument)`. This method will:
        a. Call the `pageByFlattening` method from Phase 3.
        b. Get the index of the original page.
        c. Remove the original page from the document.
        d. Insert the new, flattened page at the same index.
        e. Clear the `temporaryAnnotations` array for that page.

2.  **Wire Up Commit Triggers:**
    *   **Explicit Trigger:** The "Commit Page" button will call `commitAnnotations` for the currently visible page.
    *   **Implicit Trigger (Page Change):** The `PDFViewer`'s `Coordinator` will subscribe to `PDFViewPageChangedNotification`. On receipt, it will call `commitAnnotations` for the *previous* page before navigating.
    *   **Implicit Trigger (Close):** In your app's `SceneDelegate` or `AppDelegate`, implement logic to detect window/document closing and call `commitAnnotations` for any pages with pending changes.

## Phase 5: The Backup System

This phase implements the "filing cabinet" for safety.

1.  **Create a `BackupManager` Service:**
    *   This class will manage the creation and restoration of backups.
    *   It will have a method `backupIfNeeded(for documentURL: URL)` that checks for and creates the daily backup in a `.yiana_backups` folder as specified in your design.
    *   The first time `commitAnnotations` is called for a document on a given day, it must trigger `backupIfNeeded`.

2.  **Implement Restore Logic:**
    *   The "Revert to Start of Day" button will use the `BackupManager` to find today's backup and present a confirmation dialog to the user before replacing the current working file.

3.  **Implement Retention Policy:**
    *   Add a function to `BackupManager` to scan the backup folders and delete any files older than the 7-day retention period. This can be run once on application startup.