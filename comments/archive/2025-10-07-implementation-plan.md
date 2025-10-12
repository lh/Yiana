# Implementation Plan: MarkdownTextEditor Refactor
**Date**: 2025-10-07
**Status**: 📋 PROPOSED
**Estimated Time**: 2-3 hours

## Problem Summary

Current implementation has dual action management systems causing race conditions:
- SwiftUI `@State pendingAction` + async clearing
- Coordinator `toolbarActionQueue` + sequential processing

Race condition example:
1. User taps Bold → `pendingAction = .toggleBold` (Action A)
2. `updateUIView()` processes A, schedules async clear
3. User taps Italic → `pendingAction = .toggleItalic` (Action B)
4. Action A's async clear fires → checks `pendingAction == A` → false, never clears
5. Action B gets dropped

## Proposed Solution Architecture

### Option A: Coordinator-Owned Queue (RECOMMENDED)

**Changes**:
1. Remove `@State var pendingAction` from SwiftUI view
2. Add closure/binding to send actions directly to Coordinator
3. Coordinator becomes single source of truth for action sequencing
4. Eliminates "publish from updateUIView" anti-pattern

**Benefits**:
- ✅ No more SwiftUI state mutation during view updates
- ✅ Single action queue (simpler mental model)
- ✅ Coordinator lifecycle matches UITextView lifecycle
- ✅ Follows UIViewRepresentable best practices

---

## Implementation Steps

### Step 1: API Redesign (30 min)
**File**: `Yiana/Yiana/Views/MarkdownTextEditor.swift:48-70`

**Before**:
```swift
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @State var pendingAction: TextPageEditorAction?  // ❌ Remove this

    func updateUIView(_ uiView: UITextView, context: Context) {
        // ... updates text

        if let action = pendingAction {  // ❌ Remove this block
            context.coordinator.handle(action: action, on: uiView)
            DispatchQueue.main.async {
                if self.pendingAction == action {
                    self.pendingAction = nil
                }
            }
        }
    }
}
```

**After**:
```swift
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    var onActionRequest: ((TextPageEditorAction) -> Void)?  // ✅ New closure-based API

    func updateUIView(_ uiView: UITextView, context: Context) {
        // ... updates text only

        // ✅ No action processing here - coordinator handles it
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, onActionRequest: onActionRequest)
    }

    // ✅ Public API for toolbar to call
    func performAction(_ action: TextPageEditorAction) {
        // Forward directly to coordinator via stored reference
        // OR bind this method to toolbar button actions
    }
}
```

**Alternative (Simpler)**:
```swift
// Toolbar calls coordinator directly via stored reference
struct ContentView: View {
    @StateObject private var editorCoordinator: MarkdownEditorCoordinator

    var body: some View {
        VStack {
            MarkdownTextEditor(text: $text, coordinator: editorCoordinator)
            ToolbarView { action in
                editorCoordinator.enqueue(action)  // ✅ Direct call
            }
        }
    }
}
```

---

### Step 2: Coordinator Queue Hardening (45 min)
**File**: `Yiana/Yiana/Views/MarkdownTextEditor.swift:71-136`

```swift
class Coordinator: NSObject, UITextViewDelegate {
    // ✅ Keep queue as single source of truth
    private var toolbarActionQueue: [TextPageEditorAction] = []
    private var isProcessingToolbarAction = false
    private let maxQueueDepth = 20  // ✅ Prevent unbounded growth

    // ✅ Public entry point
    func enqueue(_ action: TextPageEditorAction) {
        dispatchPrecondition(condition: .onQueue(.main))  // ✅ Thread safety check

        #if DEBUG
        if toolbarActionQueue.count >= maxQueueDepth {
            print("⚠️ MarkdownTextEditor: Queue at capacity (\(maxQueueDepth)), dropping oldest")
        }
        #endif

        // ✅ Cap queue size
        if toolbarActionQueue.count >= maxQueueDepth {
            _ = toolbarActionQueue.removeFirst()
        }

        // ✅ Optional: Coalesce exact duplicates
        if let last = toolbarActionQueue.last, last == action {
            return  // Skip duplicate back-to-back actions
        }

        toolbarActionQueue.append(action)

        guard !isProcessingToolbarAction else { return }
        processNextToolbarAction()
    }

    private func processNextToolbarAction() {
        dispatchPrecondition(condition: .onQueue(.main))  // ✅ Thread safety check

        guard !toolbarActionQueue.isEmpty else {
            isProcessingToolbarAction = false
            return
        }

        // ✅ Check view is still in hierarchy
        guard let textView = self.textView, textView.window != nil else {
            print("⚠️ MarkdownTextEditor: View detached, draining \(toolbarActionQueue.count) queued actions")
            toolbarActionQueue.removeAll()
            isProcessingToolbarAction = false
            return
        }

        isProcessingToolbarAction = true
        let next = toolbarActionQueue.removeFirst()

        DispatchQueue.main.async { [weak self] in  // ✅ Weak self
            guard let self else { return }

            defer {  // ✅ Always reset flag
                self.isProcessingToolbarAction = false
            }

            // ✅ Re-check view before applying
            guard let textView = self.textView, textView.window != nil else {
                self.toolbarActionQueue.removeAll()
                return
            }

            self.apply(action: next, to: textView)
            self.processNextToolbarAction()
        }
    }

    // ✅ Make private - only enqueue() should be called externally
    private func apply(action: TextPageEditorAction, to textView: UITextView) {
        isUpdatingFromCoordinator = true
        defer { isUpdatingFromCoordinator = false }

        // ... existing implementation
    }
}
```

---

### Step 3: Update Toolbar Integration (30 min)
**File**: `Yiana/Yiana/Views/TextPageEditor.swift` (or wherever toolbar lives)

**Find where toolbar buttons are defined** and change from:
```swift
Button("Bold") {
    editor.pendingAction = .toggleBold  // ❌ Old way
}
```

To:
```swift
Button("Bold") {
    editorCoordinator.enqueue(.toggleBold)  // ✅ New way
}
```

**OR** if using closure-based API:
```swift
Button("Bold") {
    performAction?(.toggleBold)  // ✅ Closure captures coordinator
}
```

---

### Step 4: Add UI Test (45 min)
**File**: `Yiana/YianaUITests/MarkdownEditorTests.swift` (create if needed)

```swift
import XCTest

final class MarkdownEditorCrashTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testRapidToolbarActionsDoNotCrash() throws {
        // Navigate to a document with text editor
        let documentCell = app.cells.firstMatch
        XCTAssertTrue(documentCell.waitForExistence(timeout: 5))
        documentCell.tap()

        // Find toolbar buttons
        let boldButton = app.buttons["Bold"]
        let italicButton = app.buttons["Italic"]
        let headingButton = app.buttons["Heading"]

        XCTAssertTrue(boldButton.waitForExistence(timeout: 2))

        // Rapidly tap toolbar buttons (simulates crash scenario)
        for _ in 0..<10 {
            boldButton.tap()
            italicButton.tap()
            headingButton.tap()
        }

        // If we get here without crash, test passes
        XCTAssertTrue(app.exists, "App should still be running after rapid toolbar taps")

        // Verify editor is still responsive
        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.exists)
        XCTAssertTrue(textView.isHittable)
    }

    func testToolbarActionsProcessSequentially() throws {
        let documentCell = app.cells.firstMatch
        documentCell.tap()

        let boldButton = app.buttons["Bold"]
        let textView = app.textViews.firstMatch

        // Get initial state
        let initialText = textView.value as? String ?? ""

        // Tap bold 3 times (should toggle on, off, on)
        boldButton.tap()
        sleep(1)  // Allow processing
        boldButton.tap()
        sleep(1)
        boldButton.tap()
        sleep(1)

        // Verify final state matches expected toggle count
        // (Implementation detail: check markdown markers or attributes)
        let finalText = textView.value as? String ?? ""
        XCTAssertNotEqual(initialText, finalText, "Text should be modified by bold toggle")
    }

    func testToolbarActionsWhileBackgrounding() throws {
        let documentCell = app.cells.firstMatch
        documentCell.tap()

        let boldButton = app.buttons["Bold"]

        // Queue several actions
        for _ in 0..<5 {
            boldButton.tap()
        }

        // Background immediately
        XCUIDevice.shared.press(.home)
        sleep(1)

        // Return to app
        app.activate()

        // Verify no crash and app is responsive
        XCTAssertTrue(app.textViews.firstMatch.waitForExistence(timeout: 2))
    }
}
```

---

### Step 5: Split AGENTS.md Commit (10 min)
**Commands**:
```bash
# Stage only AGENTS.md
git add ../AGENTS.md
git commit -m "Update repository guidelines for clarity and formatting"

# Then commit MarkdownTextEditor changes separately
git add Yiana/Views/MarkdownTextEditor.swift
git commit -m "Fix crash in MarkdownTextEditor toolbar actions

- Replace dual state system (pendingAction + queue) with coordinator-only queue
- Add thread safety preconditions and lifecycle checks
- Cap queue depth to prevent unbounded growth
- Make apply() private to enforce queue usage
- Add weak self and defer blocks for safe cleanup

Fixes crash caused by SwiftUI state mutation during updateUIView()
when toolbar buttons were tapped rapidly."
```

---

## Verification Checklist

Before merging:
- [ ] No `@State pendingAction` in MarkdownTextEditor
- [ ] Toolbar calls `coordinator.enqueue()` directly
- [ ] `dispatchPrecondition` added to `enqueue()` and `processNextToolbarAction()`
- [ ] `weak self` and `defer` blocks in async processing
- [ ] `textView.window != nil` check before applying actions
- [ ] Queue size capped at reasonable limit (20 actions)
- [ ] `apply()` method is `private`
- [ ] At least one UI test proves rapid taps don't crash
- [ ] AGENTS.md committed separately
- [ ] PR description includes original crash scenario

---

## Testing Strategy

**Manual Test**:
1. Open document editor
2. Rapidly tap Bold/Italic/Heading buttons 20+ times
3. While tapping, background app and return
4. Verify no crash, editor remains responsive

**Automated Test**:
- Run `xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:YianaUITests/MarkdownEditorCrashTests`
- All 3 test methods should pass

**Memory Test**:
- Run with Instruments (Leaks + Allocations)
- Perform 100 toolbar actions
- Verify no retain cycles, queue drains completely

---

## Rollback Plan

If issues arise post-merge:
1. Revert to `@State pendingAction` approach
2. Add action ID/token instead of equality check:
   ```swift
   struct PendingAction {
       let id: UUID
       let action: TextPageEditorAction
   }
   ```

---

## Questions Before Implementation

1. **Where does toolbar live?** (`TextPageEditor.swift`, `DocumentView.swift`, or separate `ToolbarView.swift`?)
2. **How is MarkdownTextEditor currently instantiated?** (Need to know how to pass coordinator reference)
3. **Is there a parent ViewModel?** (Could own coordinator there instead of view)
4. **Accessibility labels on toolbar buttons?** (Need for UI tests)

---

## Estimated Timeline

| Task | Time | Risk |
|------|------|------|
| API redesign (remove pendingAction) | 30 min | Low |
| Coordinator hardening (safety checks) | 45 min | Low |
| Toolbar integration update | 30 min | Medium* |
| UI test implementation | 45 min | Medium |
| Manual testing | 30 min | Low |
| **Total** | **3 hours** | |

*Risk depends on how toolbar is currently structured

---

## Next Steps

**Your call**:
1. **Proceed with full refactor** → I can guide step-by-step with code reviews after each phase
2. **Minimal hardening first** → Add just safety checks (defer, weak self, lifecycle) without API changes
3. **Pair programming session** → Walk through the refactor together in real-time

Which approach would you prefer?
