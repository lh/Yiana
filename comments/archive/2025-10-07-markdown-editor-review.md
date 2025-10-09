# Code Review: MarkdownTextEditor.swift Changes
**Date**: 2025-10-07
**Reviewer**: Senior Supervising Programmer
**Branch**: feature/text-page-editor
**Commit**: Uncommitted changes

## Summary
Changes introduce a queueing mechanism for toolbar actions in `MarkdownTextEditor.swift` to handle rapid successive actions (e.g., bold, italic, heading changes). The implementation adds action queuing with sequential processing via `DispatchQueue.main.async`.

## Files Changed
- `Yiana/Views/MarkdownTextEditor.swift` (+27 lines, -2 lines)
- `../AGENTS.md` (documentation updates - not reviewed here)

---

## 🔴 Critical Issues

### 1. Race Condition in `pendingAction` Clear Logic
**Location**: `updateUIView()` lines 61-64

```swift
DispatchQueue.main.async {
    if self.pendingAction == action {
        self.pendingAction = nil
    }
}
```

**Issue**: The equality check `self.pendingAction == action` requires `TextPageEditorAction` to be `Equatable`. If it's not, this won't compile. If it is, there's still a timing window where:
1. Action A is dispatched
2. User triggers Action B (updates `pendingAction`)
3. Action A's async closure runs and checks `if pendingAction == actionA` → false
4. Action A never clears, causing stale state

**Recommendation**:
- Use an action ID or timestamp to track which action is currently being processed
- Or, rethink the coordination between `pendingAction` (SwiftUI state) and `toolbarActionQueue` (Coordinator state)

---

### 2. Duplicate Queueing System Creates Confusion
**Location**: Coordinator class

The code now has **two** action management systems:
1. **SwiftUI-level**: `@State var pendingAction` → triggers `updateUIView()` → calls `handle()`
2. **Coordinator-level**: `toolbarActionQueue` → processes via `processNextToolbarAction()`

**Problems**:
- Actions flow through both systems: `pendingAction` → `handle()` → `toolbarActionQueue` → `apply()`
- `pendingAction` is cleared asynchronously while `toolbarActionQueue` processes synchronously (then async again)
- If `pendingAction` changes before the async clear happens, queue and state diverge

**Recommendation**:
Choose ONE action management approach:
- **Option A**: Keep toolbar queue in Coordinator, remove `pendingAction` entirely (use Coordinator as single source of truth)
- **Option B**: Keep `pendingAction` in SwiftUI state, remove queue (process actions immediately in sequence)

My preference: **Option A** - `UIViewRepresentable` coordinators are designed to manage UIKit lifecycle, so queuing belongs there.

---

### 3. Recursive Processing Without Termination Guarantee
**Location**: `processNextToolbarAction()` lines 127-136

```swift
private func processNextToolbarAction(on textView: UITextView) {
    guard !toolbarActionQueue.isEmpty else { return }

    isProcessingToolbarAction = true
    let next = toolbarActionQueue.removeFirst()

    DispatchQueue.main.async {
        self.apply(action: next, to: textView)
        self.isProcessingToolbarAction = false
        self.processNextToolbarAction(on: textView)  // Recursive call
    }
}
```

**Issue**: Recursion happens inside `DispatchQueue.main.async`, which is fine for stack depth, but consider:
- If `apply()` throws or crashes, `isProcessingToolbarAction` stays `true` forever
- Queue drains without user-visible errors

**Recommendation**:
```swift
DispatchQueue.main.async { [weak self] in
    defer { self?.isProcessingToolbarAction = false }
    self?.apply(action: next, to: textView)
    self?.processNextToolbarAction(on: textView)
}
```

---

## ⚠️ Medium Priority Issues

### 4. Missing Thread Safety for Queue Operations
**Location**: `handle()` and `processNextToolbarAction()`

`toolbarActionQueue` is accessed from multiple contexts:
- `handle()` appends (called from `updateUIView` on main thread)
- `processNextToolbarAction()` reads/removes (called from async main queue)

While both use main queue, there's no guarantee about ordering if multiple `updateUIView()` calls happen rapidly.

**Recommendation**:
- Document that queue operations MUST happen on main thread
- Add `dispatchPrecondition(condition: .onQueue(.main))` in debug builds

---

### 5. Original Method `apply()` Still Exposed
**Location**: Public/internal interface

The new `handle()` method wraps `apply()`, but `apply()` is still accessible. This creates two entry points:
- `handle()` → queues action
- `apply()` → executes immediately

**Recommendation**:
- Make `apply()` private if it's an internal detail
- Or document clearly when to use each method

---

## 💡 Suggestions for Improvement

### 6. No Queue Size Limit
If a user rapidly taps toolbar buttons faster than rendering, the queue grows unbounded. Consider:
```swift
func handle(action: TextPageEditorAction, on textView: UITextView) {
    guard toolbarActionQueue.count < 10 else {
        print("⚠️ Toolbar action queue overflow, dropping oldest")
        _ = toolbarActionQueue.removeFirst()
    }
    toolbarActionQueue.append(action)
    // ...
}
```

### 7. Action Coalescing Missing
Multiple identical actions (e.g., "toggle bold" 5 times) will toggle on/off/on/off/on. Consider detecting and coalescing:
```swift
if let last = toolbarActionQueue.last, last == action {
    return // Skip duplicate actions
}
```

---

## 📋 Testing Recommendations

Before merging, ensure tests cover:
1. **Rapid toolbar button presses** (5+ actions in < 100ms)
2. **Action cancellation** (user changes selection mid-processing)
3. **View lifecycle interruption** (backgrounding app during action processing)
4. **Memory leaks** (retain cycles in async closures)
5. **Error handling** (malformed selection ranges, empty text)

Consider adding:
```swift
// YianaUITests/MarkdownEditorTests.swift
func testRapidToolbarActionsAreQueued() {
    // Tap bold 3 times rapidly
    // Verify final state matches expected toggle count
}
```

---

## 🎯 Alignment with Project Guidelines

### ✅ Follows Guidelines
- Platform-specific SwiftUI implementation (no cross-platform abstraction)
- Uses `DispatchQueue.main.async` for state updates (per CLAUDE.md guidance)

### ❌ Potential Violations
- **TDD requirement**: No visible test changes accompany this implementation
- **Commit hygiene**: AGENTS.md documentation changes bundled with feature work (should be separate commits)

---

## Overall Assessment

**Risk Level**: 🟡 MEDIUM-HIGH

The changes address a real problem (toolbar action conflicts) but introduce architectural complexity that needs refinement:
- Two competing state management systems (SwiftUI + Coordinator)
- Race conditions in action clearing
- No tests demonstrating the fix works

**Recommendation**:
1. **Do not merge** until race condition (#1) and duplicate queueing (#2) are resolved
2. Add UI tests proving rapid toolbar actions work correctly
3. Separate AGENTS.md changes into documentation commit

---

## Questions for the Team

1. What specific bug prompted this change? (GitHub issue link?)
2. Is `TextPageEditorAction` Equatable? (needed for equality check)
3. Have you tested this with VoiceOver/accessibility rapid actions?
4. Why both queue and `pendingAction`? Can we simplify?

---

## Next Steps

If I were implementing this fix, I would:
1. Remove `pendingAction` entirely → use queue as single source of truth
2. Add action ID tracking instead of equality checks
3. Write failing test first (TDD per CLAUDE.md)
4. Add defer blocks for cleanup safety
5. Document thread safety requirements

**Estimated refactor time**: 2-3 hours including tests

---

**Reviewer**: Available for pair programming session if needed to resolve architectural questions.
