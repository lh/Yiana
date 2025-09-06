# Proposal: A Reliable Markup Solution Using PDFKit

## 1. Executive Summary

The current markup implementation, based on Apple's `QLPreviewController`, is fundamentally unreliable. It suffers from a well-known iOS bug where the "Done" button, required to save annotations, intermittently fails to appear. This provides a broken user experience and makes the feature unusable.

This proposal outlines a pivot to a more robust solution using the `PDFKit` framework, specifically `PDFView`. By leveraging `PDFView`, we gain direct control over the user interface, allowing us to implement our own reliable Save and Cancel buttons. This approach guarantees a functional and maintainable markup feature that aligns with the Yiana project's core philosophy of using the right tool for the job.

## 2. Problem Analysis: The Failure of `QLPreviewController`

The project's "LEGO" philosophy encourages using native Apple frameworks. `QLPreviewController` was initially chosen for its simplicity in displaying content and providing a standard markup interface. However, it has proven to be the wrong tool for this task due to a critical flaw:

*   **The "Missing Done Button" Bug:** The save mechanism in `QLPreviewController` can only be triggered by an internal "Done" button that is part of its private user interface. This button frequently and unpredictably fails to appear, leaving the user unable to save their work.

*   **A "Black Box" Framework:** `QLPreviewController` offers minimal programmatic control. We cannot manually trigger the save action, nor can we reliably fix the broken UI. Attempts to implement workarounds have proven to be fragile dead ends.

*   **Violation of Project Philosophy:** Continuing to fight a known, long-standing framework bug violates the principle of "knowing the limitations of frameworks and respecting them." The current approach is brittle and unreliable.

## 3. Proposed Solution: `PDFView` for Reliability and Control

To solve this problem definitively, we will replace `QLPreviewController` with `PDFKit`'s `PDFView`.

### 3.1. Why `PDFView` is the Correct Tool

*   **Full UI Control:** `PDFView` is a UI component, not a sealed controller. We can embed it in our own view controller and add our own navigation bar with Save and Cancel buttons that are guaranteed to be present and functional.

*   **Direct Data Handling:** It is designed specifically for displaying and editing PDF documents. When the user annotates the view, it directly modifies the underlying `PDFDocument` object. We can then reliably request the final data from this object by calling `.dataRepresentation()`.

*   **Preserves Document Quality:** Annotations created in `PDFView` are standard `PDFAnnotation` objects. This preserves the vector quality of the document and its annotations, unlike other methods (e.g., `PencilKit`) that would require flattening the PDF into a lower-quality image.

*   **Aligns with Project Philosophy:** This pivot represents choosing a better, more appropriate "LEGO block" for the task. It prioritizes reliability and maintainability over the perceived initial simplicity of a buggy component.

### 3.2. Implementation Plan

The refactoring will be contained primarily within `DocumentEditView.swift`.

1.  **Remove `MarkupCoordinator`:** The `MarkupCoordinator.swift` file, which was built entirely around `QLPreviewController`, will be deleted.

2.  **Create an Inline `PDFKitMarkupView`:** Inside `DocumentEditView.swift`, the existing `MarkupViewWrapper` will be replaced by a new `PDFKitMarkupView`. This new `UIViewControllerRepresentable` will be responsible for creating and presenting a custom `UIViewController` that contains our configured `PDFView`.

3.  **Implement Reliable UI:** The custom view controller will have its own `UINavigationBar` with our own "Save" and "Cancel" actions, ensuring they are always visible.

4.  **Update `DocumentEditView` Logic:**
    *   The `presentMarkup()` function will be simplified. It will no longer create a coordinator. Instead, it will prepare the single-page PDF data and set the state to present the new `PDFKitMarkupView`.
    *   The `handleMarkupResult()` completion handler will be updated to accept the data directly from the `PDFKitMarkupView`'s completion block.

## 4. Conclusion

Pivoting from `QLPreviewController` to `PDFView` is a necessary and pragmatic engineering decision. It replaces a fragile, unreliable component with a robust solution that gives us complete control over the user experience. This change will fix the markup feature, eliminate a source of user frustration, and align the implementation with the project's core principles of reliability and maintainability.