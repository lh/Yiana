# UbiquityMonitor Testing Options

**Context:** UbiquityMonitor uses NSMetadataQuery to detect iCloud changes. What can we test automatically?

## What CAN Be Tested Automatically ✅

### 1. Lifecycle Tests
```swift
// YianaTests/UbiquityMonitorTests.swift
func testMonitorStartsOnlyOnce() {
    let monitor = UbiquityMonitor.shared

    monitor.start()
    XCTAssertTrue(monitor.isRunning)

    // Second start should be no-op
    monitor.start()
    XCTAssertTrue(monitor.isRunning) // Still running, not crashed

    monitor.stop()
    XCTAssertFalse(monitor.isRunning)
}

func testMonitorStopsCleanly() {
    let monitor = UbiquityMonitor.shared

    monitor.start()
    monitor.stop()

    XCTAssertFalse(monitor.isRunning)

    // Should be safe to stop again
    monitor.stop()
}
```

### 2. Thread Safety Tests
```swift
func testStartStopFromBackgroundThread() {
    let monitor = UbiquityMonitor.shared
    let expectation = XCTestExpectation(description: "Background start completes")

    DispatchQueue.global().async {
        monitor.start() // Should marshal to main
        XCTAssertTrue(monitor.isRunning)

        monitor.stop() // Should marshal to main
        XCTAssertFalse(monitor.isRunning)

        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
}

func testIsRunningFromBackgroundThread() {
    let monitor = UbiquityMonitor.shared
    monitor.start()

    let expectation = XCTestExpectation(description: "Can query from background")

    DispatchQueue.global().async {
        let running = monitor.isRunning // Should sync to main
        XCTAssertTrue(running)
        expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
    monitor.stop()
}
```

### 3. Notification Behavior Tests
```swift
func testNotificationPostedOnDocumentChange() {
    // This is HARD because we can't easily mock NSMetadataQuery
    // But we can test the notification infrastructure

    let expectation = XCTestExpectation(description: "Notification received")

    let observer = NotificationCenter.default.addObserver(
        forName: .yianaDocumentsChanged,
        object: nil,
        queue: .main
    ) { _ in
        expectation.fulfill()
    }

    // Start monitor (may trigger initial gather)
    UbiquityMonitor.shared.start()

    // Wait for potential initial notification
    wait(for: [expectation], timeout: 5.0)

    NotificationCenter.default.removeObserver(observer)
    UbiquityMonitor.shared.stop()
}
```

### 4. Retry Logic Tests
```swift
func testRetryScheduledWhenContainerUnavailable() {
    // This is tricky - requires iCloud to be unavailable
    // Best tested manually by signing out of iCloud

    // In code, we can at least verify retry doesn't crash:
    let monitor = UbiquityMonitor.shared

    // Start multiple times in quick succession
    monitor.start()
    monitor.stop()
    monitor.start()
    monitor.stop()

    // Should not crash or leak
}
```

## What CANNOT Be Tested Automatically ❌

### 1. Actual iCloud Synchronization
**Why:** Requires real iCloud infrastructure and multiple devices/accounts

**Manual test needed:**
- Device A: Create document
- Device B: Verify it appears automatically
- Device A: Delete document
- Device B: Verify it disappears automatically

### 2. NSMetadataQuery Results
**Why:** NSMetadataQuery behavior is opaque and system-controlled

**Cannot easily:**
- Mock query results
- Inject fake metadata items
- Simulate query updates

### 3. Network Conditions
**Why:** Simulator doesn't properly simulate iCloud sync

**Manual test needed:**
- Test with airplane mode on/off
- Test with poor network conditions
- Test with iCloud Drive paused

### 4. Container Availability
**Why:** Requires actual iCloud account state changes

**Manual test needed:**
- Sign out of iCloud
- Sign back in
- Verify monitor restarts

## Recommended Testing Strategy

### Phase 1: Automated Unit Tests (Do Now)
```swift
// YianaTests/UbiquityMonitorTests.swift
class UbiquityMonitorTests: XCTestCase {

    override func tearDown() {
        // Always stop monitor after each test
        UbiquityMonitor.shared.stop()
        super.tearDown()
    }

    func testSingletonPattern() {
        let monitor1 = UbiquityMonitor.shared
        let monitor2 = UbiquityMonitor.shared
        XCTAssertTrue(monitor1 === monitor2)
    }

    func testStartStopLifecycle() {
        let monitor = UbiquityMonitor.shared

        XCTAssertFalse(monitor.isRunning)

        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
        XCTAssertFalse(monitor.isRunning)
    }

    func testMultipleStartsAreSafe() {
        let monitor = UbiquityMonitor.shared

        monitor.start()
        monitor.start()
        monitor.start()

        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
    }

    func testMultipleStopsAreSafe() {
        let monitor = UbiquityMonitor.shared

        monitor.start()
        monitor.stop()
        monitor.stop()
        monitor.stop()

        XCTAssertFalse(monitor.isRunning)
    }

    func testThreadSafetyOfStart() {
        let monitor = UbiquityMonitor.shared
        let expectation = XCTestExpectation(description: "Background start")

        DispatchQueue.global().async {
            monitor.start()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()
    }

    func testThreadSafetyOfIsRunning() {
        let monitor = UbiquityMonitor.shared
        monitor.start()

        let expectation = XCTestExpectation(description: "Background query")

        DispatchQueue.global().async {
            _ = monitor.isRunning // Should not crash
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
        monitor.stop()
    }
}
```

### Phase 2: Manual Integration Tests (After Automated)

Create a test plan document: `docs/testing/icloud-sync-manual-tests.md`

```markdown
# iCloud Sync Manual Test Plan

## Prerequisites
- Two devices signed into same iCloud account
- iCloud Drive enabled
- Yiana installed on both devices

## Test Cases

### TC1: Document Creation Sync
1. Device A: Create new document "Test Doc 1"
2. Wait 10 seconds
3. Device B: Pull to refresh (should see document automatically)
4. **Expected:** Document appears without manual refresh

### TC2: Document Deletion Sync
1. Device A: Delete "Test Doc 1"
2. Wait 10 seconds
3. Device B: Check document list
4. **Expected:** Document disappears automatically

### TC3: Offline Handling
1. Device A: Enable airplane mode
2. Device A: Create "Offline Doc"
3. Device A: Disable airplane mode
4. Wait 30 seconds
5. Device B: Check list
6. **Expected:** "Offline Doc" appears after reconnection

### TC4: iCloud Account Change
1. Device A: Sign out of iCloud
2. Device A: Verify documents list is empty
3. Device A: Sign back in
4. Wait 60 seconds
5. **Expected:** All documents reappear

### TC5: Large Batch Sync
1. Device A: Import 20 PDFs
2. Device B: Monitor console for "[UbiquityMonitor]" logs
3. **Expected:** Single notification after batch completes
```

### Phase 3: Simulator Smoke Tests

Even though simulator iCloud sync is unreliable, we can verify:

```swift
func testMonitorStartsInSimulator() {
    let monitor = UbiquityMonitor.shared

    // Should not crash even if container is unavailable
    monitor.start()

    // May or may not be running depending on simulator iCloud state
    // Just verify it doesn't crash
    _ = monitor.isRunning

    monitor.stop()
}
```

## Debug Logging for Testing

Your existing debug logging is perfect for manual testing:

```swift
#if DEBUG
print("[UbiquityMonitor] \(message)")
#endif
```

Testers can watch for:
- `Starting metadata query` - Monitor started
- `Documents changed (added: N, removed: M)` - Changes detected
- `Ubiquity container unavailable; will retry` - iCloud issues

## Instrumentation for Performance Testing

Add these for Instruments profiling:

```swift
// In handleQueryNotification
os_signpost(.begin, log: log, name: "Process Query Update")
// ... processing ...
os_signpost(.end, log: log, name: "Process Query Update")
```

This helps identify if query processing becomes a bottleneck with many documents.

## Recommended Approach

1. **Write automated tests for:**
   - Lifecycle (start/stop/restart)
   - Thread safety
   - Multiple calls safety
   - Singleton pattern

2. **Document manual tests for:**
   - Multi-device sync
   - Network conditions
   - Large document sets
   - Account changes

3. **Use debug builds with logging for:**
   - Initial deployment testing
   - Beta tester feedback
   - Troubleshooting sync issues

4. **Consider adding:**
   - Development menu item to force monitor restart
   - Settings toggle to show sync status
   - Diagnostic screen showing last query update time

## What NOT To Do

❌ Don't try to mock NSMetadataQuery - it's too tightly coupled to system
❌ Don't try to simulate iCloud sync in tests - use real devices
❌ Don't rely on simulator for iCloud testing - results are unreliable
❌ Don't test timing-dependent behavior - query updates are unpredictable

## Bottom Line

- **30% automated** - Lifecycle, thread safety, basic safety
- **70% manual** - Actual iCloud sync behavior requires real devices

This is normal for iCloud-dependent features. Focus automated tests on code correctness, manual tests on integration behavior.
