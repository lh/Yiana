# Work List Click Navigation: What We Tried and Why It Failed

## The Problem

Clicking a work list item in the macOS sidebar should open the corresponding document. It doesn't work reliably. After six consecutive fix attempts across two days, the behaviour remains broken: items sometimes open on the first click, then stop responding when switching between items.

## Architecture Context

The macOS layout uses `NavigationSplitView` with two columns:

1. **Sidebar** — a `List(selection: $selectedSidebarFolder)` containing folder rows and a `WorkListPanelView` section
2. **Detail** — a `NavigationStack(path: $navigationPath)` showing the selected folder's documents, with documents pushed onto the stack

Two independent navigation mechanisms coexist:

- **`selectedSidebarFolder: String?`** — drives `List(selection:)`. When it changes, an `.onChange` handler calls `viewModel.navigateToFolderPath()` to load that folder's contents into the detail column.
- **`navigationPath: NavigationPath`** — a push stack within the detail `NavigationStack`. Appending a URL pushes a document view onto the stack.

Work list items need to use `navigationPath.append(url)` to open a document. They do not represent folders and should not interact with `selectedSidebarFolder`.

## The Core Conflict

`List(selection:)` backed by `NSTableView` owns the click gesture on all rows inside it — including work list rows. Any attempt to navigate via `navigationPath` that also triggers a `selectedSidebarFolder` change causes `NavigationSplitView` to recompute the detail column, which can discard or conflict with the `navigationPath.append()`.

This is the fundamental tension: the work list section lives inside a `List` whose selection model is designed for folder navigation, but work list clicks need to do something completely different (push onto a navigation stack).

## Attempt History

### Attempt 1: SidebarItem enum (37de778, Mar 7 afternoon)

**Approach:** Replace `String?` selection with a typed `SidebarItem` enum so work list rows could participate in `List(selection:)` natively alongside folder rows. Each enum case (`.folder(path)`, `.workListItem(mrn)`) would be handled in `.onChange(of: selection)`.

**Result:** This was part of the Yiale (letter) app, not the Yiana document list, so it was in the wrong codebase. The approach was also conceptually wrong — work list items are not sidebar destinations, they're document shortcuts. Making them full sidebar selection cases meant that selecting a work list item deselected the current folder, which wiped the folder content from the detail column.

**Why it failed:** Treating work list items as sidebar selections conflates two different navigation concepts.

### Attempt 2: onTapGesture (8981447, Mar 7 evening)

**Approach:** Replace `Button` wrappers on work list rows with `.onTapGesture` so clicks would fire the tap handler without interfering with `List(selection:)`. Renamed "Clinic List" to "Work List" throughout.

**Result:** The gesture recogniser added a delay (SwiftUI disambiguates taps from other gestures). More critically, tapping the row text didn't always fire because the label's hit area competed with the List's own selection gesture. The sidebar lozenge (blue highlight) stayed on the previously selected folder instead of moving to the work list row.

**Why it failed:** `onTapGesture` on a row inside a `List` competes with NSTableView's built-in selection gesture. Inconsistent hit testing.

### Attempt 3: Tagged values with "wl:" prefix (27e8398, Mar 7 late evening)

**Approach:** Give work list rows `.tag("wl:\(item.mrn)")` so they participate in `List(selection: $selectedSidebarFolder)`. Guard the `.onChange(of: selectedSidebarFolder)` and `currentFolderURL` computed property to ignore values prefixed with `"wl:"`.

**Result:** The sidebar lozenge moved correctly to the clicked work list row. But changing `selectedSidebarFolder` to a `"wl:"` value still triggered `NavigationSplitView` to recompute the detail column. The folder content briefly disappeared or flickered. Navigation to the document was unreliable.

**Why it failed:** Even with guards, mutating the `List(selection:)` binding triggers view invalidation throughout the `NavigationSplitView`. The guards prevented the folder-loading side effect but not the view recomputation itself.

### Attempt 4: Separate selection with mutual clearing (da70bac, Mar 7 late evening)

**Approach:** Remove `.tag()` from work list rows. Track work list selection independently via `@State private var selectedMRN: String?` with a manual `.listRowBackground` highlight. On work list tap: set `selectedMRN`, clear `sidebarSelection` (folder) to nil. On folder tap (via `.onChange`): clear `selectedMRN`. Two selection states, mutually exclusive.

**Result:** Setting `sidebarSelection?.wrappedValue = nil` in `handleTap` triggered the `List(selection:)` to update, which caused `NavigationSplitView` to recompute. The `navigationPath.append(url)` that followed was sometimes discarded because the view tree was being rebuilt.

**Why it failed:** Clearing the folder selection is itself a sidebar mutation. Any change to the `List(selection:)` binding, even setting it to nil, triggers the same view invalidation cycle.

### Attempt 5: Button + Transaction with disabled animations (3caad7c, Mar 8 morning)

**Approach:** Switch from `onTapGesture` back to `Button(.plain)` for immediate tap response. Wrap the `selectedMRN` and `sidebarSelection` mutations in a `Transaction` with `disablesAnimations = true` to force them into a single frame, hoping the `navigationPath.append` would survive the view update.

**Result:** First click sometimes worked. Switching to a second work list item sometimes failed to navigate. The Transaction did not prevent the `NavigationSplitView` from recomputing — it only suppressed animations during the recomputation.

**Why it failed:** `Transaction.disablesAnimations` controls animation, not view identity or lifecycle. The underlying problem — mutating `selectedSidebarFolder` triggers a detail column rebuild — is unchanged.

### Attempt 6: Remove sidebarSelection entirely (b644ae9, Mar 8 midday)

**Approach:** Remove all interaction between work list taps and `selectedSidebarFolder`. Delete the `sidebarSelection` binding property from `WorkListPanelView`, the `.onChange` observer, and the Transaction wrapper. `handleTap` simply sets `selectedMRN` and calls `onNavigate(url)`.

**Result:** Still unreliable. The first click might not find the document, then it works, then switching between items stops working.

**Why it failed:** The symptom changed, which suggests this was the right direction for the selection coupling issue. But there's likely a second, independent problem — possibly related to how `resolvedURL(for:)` works, or a timing issue with `navigationPath.append()` inside a `List` section that's being redrawn for other reasons (e.g., `resolvedURLs` updating).

## Patterns Observed

1. **Any mutation to `selectedSidebarFolder` during a work list tap is fatal.** It triggers `NavigationSplitView` to rebuild the detail column, which races with `navigationPath.append()`.

2. **The `List` owns the click gesture.** Work list rows live inside `List(selection: $selectedSidebarFolder)`. NSTableView processes the click for its own selection handling before any SwiftUI gesture or Button action fires. This means the List may change `selectedSidebarFolder` on its own when an untagged row is clicked (setting it to nil), which triggers the same cascade.

3. **The problem may be two bugs, not one.** The selection coupling (attempts 1-5) and the "can't find document" / "won't switch" behaviour (attempt 6) may be separate issues. Attempt 6 removed the coupling but the navigation still fails.

## Uninvestigated Hypotheses

### The List itself may be setting selectedSidebarFolder to nil

When you click a work list row that has no `.tag()`, the `List(selection:)` may set `selectedSidebarFolder` to `nil` because no tag matched. This would trigger the `.onChange` handler and potentially interfere with navigation. This would explain why attempt 6 still fails — we removed our explicit clearing but the List's native selection handling still fires.

**Test:** Add logging in the `.onChange(of: selectedSidebarFolder)` handler to see if it fires when a work list item is clicked, even without explicit manipulation.

### navigationPath.append may not work from inside a List Section

The `onNavigate` closure calls `navigationPath.append(url)` from within a view update triggered by a `Button` tap inside a `List` `Section`. SwiftUI may coalesce or discard state changes that happen during certain view update phases.

**Test:** Dispatch the `navigationPath.append` to the next run loop via `DispatchQueue.main.async` or `Task { @MainActor in }` to break it out of the current view update cycle.

### resolvedURL(for:) may return nil on first access

If the address resolution is lazy or async, the first click may arrive before `resolvedURLs` is populated. The "first click fails, second works" pattern is consistent with a race condition in data loading.

**Test:** Add logging in `handleTap` to print whether `resolvedURL(for:)` returns nil or a URL.

### Work list rows may need to be outside the List entirely

The fundamental problem may be that work list rows cannot coexist inside a `List(selection:)` that serves a different purpose. The macOS sidebar might need to be restructured so the work list section is rendered outside/below the folder `List`, perhaps in a separate `VStack` section that doesn't participate in `List(selection:)` at all.

**Test:** Move `WorkListPanelView` out of the `List { ... }` block and into a `VStack` alongside it, with its own independent scroll region if needed.

## Recommendation

Before the next attempt, add diagnostic logging to answer the three open questions:

1. Does `selectedSidebarFolder` change when a work list row is clicked (even without explicit code to change it)?
2. Does `navigationPath.append()` actually execute, and does the path length increase?
3. Does `resolvedURL(for:)` return a valid URL on every click?

The answers will determine whether the fix is (a) moving work list out of the List, (b) dispatching navigation asynchronously, (c) fixing a data race in URL resolution, or some combination.
