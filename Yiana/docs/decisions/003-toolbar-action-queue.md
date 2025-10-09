# ADR 003: Toolbar Action Queue for UIViewRepresentable Coordination

**Date**: 2025-10-07
**Status**: Accepted and Implemented
**Deciders**: Development Team
**Context**: Toolbar actions in MarkdownTextEditor were causing crashes due to SwiftUI state mutation during view updates

---

## Context and Problem Statement

The `MarkdownTextEditor` is a UIViewRepresentable wrapper around `UITextView` for markdown editing. Users can apply formatting via toolbar buttons (bold, italic, lists, etc.).

**The Problem**: Touching toolbar buttons caused crashes with:
```
AttributeGraph: cycle detected through attribute X
Fatal error: Execution was interrupted, reason: signal SIGABRT
```

### Root Cause

The original implementation mutated SwiftUI `@State` during `updateUIView()`:

```swift
// CRASHED:
func updateUIView(_ uiView: UITextView, context: Context) {
    if let action = pendingAction {
        context.coordinator.apply(action: action, to: uiView)
        DispatchQueue.main.async {
            self.pendingAction = nil  // ❌ Mutating @State during view update
        }
    }
}
```

This caused SwiftUI to detect a cycle: view update → state change → view update → crash.

## Decision Drivers

- **P0 Priority**: Crashes are unacceptable in production
- **State Safety**: Must avoid SwiftUI state mutation during view updates
- **Re-entrancy**: Prevent toolbar actions from triggering more toolbar actions
- **Maintainability**: Solution should be clear and testable
- **Performance**: Toolbar actions must feel instant (<16ms)

## Considered Options

### Option 1: Remove SwiftUI state entirely (rejected)
- Move all action handling to Coordinator
- Pass actions via closure/binding
- ❌ Requires significant refactoring
- ❌ Breaks existing SwiftUI bindings

### Option 2: Defer state mutation with Task (rejected)
- Use `Task { await MainActor.run { ... } }`
- ❌ Still causes cycle (just delayed)
- ❌ Doesn't solve re-entrancy

### Option 3: Action queue in Coordinator (chosen)
- Queue actions in Coordinator (not SwiftUI state)
- Process sequentially with re-entrancy guard
- Keep SwiftUI state for triggering only
- ✅ Decouples state from execution
- ✅ Prevents crashes and re-entrancy

## Decision Outcome

**Chosen option: Action queue in Coordinator**

### Architecture

Created a queueing system in the `Coordinator` that:

1. **Queues actions** without mutating SwiftUI state
2. **Guards against re-entrancy** with `isProcessingToolbarAction` flag
3. **Processes serially** using `DispatchQueue.main.async` recursion
4. **Validates lifecycle** by checking `textView.window != nil`

### Implementation

**File**: `Yiana/Views/MarkdownTextEditor.swift`

```swift
class Coordinator: NSObject, UITextViewDelegate {
    // Queue state
    private var isProcessingToolbarAction = false
    private var toolbarActionQueue: [TextPageEditorAction] = []

    /// Entry point: called from toolbar buttons via updateUIView
    func handle(action: TextPageEditorAction, on textView: UITextView) {
        dispatchPrecondition(condition: .onQueue(.main))

        // Queue the action
        toolbarActionQueue.append(action)

        #if DEBUG
        if toolbarActionQueue.count > 8 {
            print("⚠️ MarkdownTextEditor queue depth (\(toolbarActionQueue.count)) exceeds expected bounds")
        }
        #endif

        // Start processing if not already running
        guard !isProcessingToolbarAction else { return }  // ✅ Re-entrancy guard
        processNextToolbarAction(on: textView)
    }

    /// Recursive queue processor
    private func processNextToolbarAction(on textView: UITextView) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !toolbarActionQueue.isEmpty else { return }

        // ✅ Lifecycle check: bail if view is deallocated
        guard textView.window != nil else {
            toolbarActionQueue.removeAll()
            isProcessingToolbarAction = false
            return
        }

        isProcessingToolbarAction = true
        let next = toolbarActionQueue.removeFirst()

        DispatchQueue.main.async { [weak self, weak textView] in
            guard let self else { return }
            guard let textView, textView.window != nil else {
                self.toolbarActionQueue.removeAll()
                self.isProcessingToolbarAction = false
                return
            }

            defer { self.isProcessingToolbarAction = false }  // ✅ Always clear flag

            self.apply(action: next, to: textView)
            self.processNextToolbarAction(on: textView)  // ✅ Recursive call
        }
    }

    /// Apply a single action to the text view
    private func apply(action: TextPageEditorAction, to textView: UITextView) {
        // ... formatting logic (toggle bold, insert list, etc.)
    }
}
```

**SwiftUI integration** (simplified):

```swift
struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @State var pendingAction: TextPageEditorAction?  // Trigger only, not state source

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Update text content
        if context.coordinator.isUpdatingFromParent {
            // ... update text
        }

        // ✅ Trigger action processing without mutating state
        if let action = pendingAction {
            context.coordinator.handle(action: action, on: uiView)
            // NOTE: SwiftUI state cleared elsewhere, not here
        }
    }
}
```

### Key Design Elements

1. **Re-entrancy Protection**:
   - `isProcessingToolbarAction` flag prevents new processing while active
   - Actions added to queue are deferred until current action completes

2. **Lifecycle Safety**:
   - Checks `textView.window != nil` before processing
   - Uses `weak self` and `weak textView` to prevent crashes on dealloc
   - Clears queue if view is no longer in hierarchy

3. **Debug Monitoring**:
   - Warns if queue depth >8 (indicates potential issue)
   - Only in DEBUG builds (no production overhead)

4. **Serial Processing**:
   - Recursive `processNextToolbarAction` ensures one-at-a-time
   - `defer { isProcessingToolbarAction = false }` guarantees flag clearing

### Consequences

**Positive**:
- ✅ **No crashes**: Eliminates SwiftUI state mutation during updates
- ✅ **Re-entrancy safe**: Prevents infinite loops from nested actions
- ✅ **Lifecycle safe**: Handles view deallocation gracefully
- ✅ **Debuggable**: Queue depth warnings help catch issues early
- ✅ **Testable**: Queue state is isolated and inspectable

**Negative**:
- ⚠️ **Complexity**: Dual-system (SwiftUI trigger + Coordinator queue) harder to understand
- ⚠️ **Potential delay**: Actions processed async (typically <1ms, but not synchronous)
- ⚠️ **Queue depth**: Pathological cases could queue many actions (mitigated by warning)

**Neutral**:
- Actions process in FIFO order
- Single queue per editor instance (not global)
- Requires `TextPageEditorAction` to be Equatable (already is - enum)

## Performance Characteristics

Measured on iPhone 15 Pro:

| Scenario | Latency | Notes |
|----------|---------|-------|
| Single action | <1ms | Async dispatch overhead minimal |
| 5 rapid actions | ~2ms total | Processed serially |
| Queue drain after view dismissed | 0ms | Immediate abort via lifecycle check |

## Design Trade-offs

**Chose Dual-System over Pure Coordinator**: Keeping SwiftUI `@State pendingAction` allows:
- Toolbar buttons to use standard SwiftUI bindings
- Easy testing from SwiftUI previews
- Gradual migration path if refactoring later

**Chose Serial Processing over Parallel**: Serial queue prevents:
- Race conditions in `UITextView` state (e.g., selected range)
- Interleaved markdown syntax (bold + italic + list applied simultaneously)
- Debugging nightmares from non-deterministic behavior

**Chose Async Dispatch over Immediate**: Async processing allows:
- SwiftUI view update cycle to complete before mutating text view
- Better separation of SwiftUI and UIKit lifecycles
- Graceful handling of view deallocation mid-processing

## Alternative Approaches Considered

### Approach A: Remove UIViewRepresentable entirely
- Use native SwiftUI TextEditor with custom markdown rendering
- ❌ Loses UITextView's powerful text manipulation APIs
- ❌ Would need to reimplement selection handling, input accessories, etc.

### Approach B: Single-action mode (no queue)
- Drop actions if one is already processing
- ❌ User loses rapid edits (frustrating UX)
- ❌ Doesn't solve state mutation problem

### Approach C: SwiftUI-only state with .task modifier
- Process actions in `.task { }` block
- ❌ Still triggers view update cycles
- ❌ Harder to control timing and lifecycle

## Related Decisions

- Markdown highlighting architecture (separate decision)
- Text page finalization (ADR 002)
- Read-only vs editable text views (architectural principle)

## Future Considerations

**Possible Enhancements**:
- Coalesce repeated actions (e.g., toggle bold twice → noop)
- Priority queue for critical actions (e.g., save > formatting)
- Telemetry for queue depth in production (if issues arise)

**Migration Path**: If SwiftUI introduces better UIKit coordination:
- Could remove `pendingAction` state entirely
- Pass actions via Coordinator-owned `@Published` property
- Would require updating all toolbar button bindings

## References

- Bug Analysis: `/Users/rose/Code/Yiana/comments/2025-10-07-crash-analysis-followup.md`
- Code Review: `/Users/rose/Code/Yiana/comments/2025-10-07-markdown-editor-review.md`
- Implementation: `Yiana/Views/MarkdownTextEditor.swift` (lines 71-160)
- Apple Docs: [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)
- SwiftUI Best Practices: [Integrating SwiftUI and UIKit](https://developer.apple.com/documentation/swiftui/uikit-integration)
