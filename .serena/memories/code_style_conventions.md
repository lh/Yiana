# Yiana Code Style & Conventions

## Swift Style Guidelines

### Naming Conventions
- **Types (Classes, Structs, Enums)**: PascalCase
  - Example: `DocumentMetadata`, `NoteDocument`, `DocumentListViewModel`
- **Properties and Methods**: camelCase
  - Example: `pdfData`, `ocrCompleted`, `handleIncomingURL()`
- **Constants**: camelCase (not SCREAMING_SNAKE_CASE)
  - Example: `let pageCount`, `let created`

### Property Declarations
- Use `let` for immutable properties
- Use `var` for mutable properties
- Mark stored properties with appropriate access control
- Use `@Published` for ObservableObject properties that trigger UI updates
- Use `@StateObject` for owned ObservableObject instances in Views

### Documentation
- Use triple-slash comments (///) for property documentation
- Document public APIs and complex logic
- Keep comments concise and meaningful
```swift
/// Unique identifier for the document
let id: UUID
```

### Code Organization
- Properties first, then initializers, then methods
- Group related functionality together
- Use MARK: comments for section organization in larger files

### SwiftUI Specific
- Use `@main` attribute for app entry point
- Prefer composition over inheritance
- Use ViewModels as ObservableObject for complex state
- Keep Views focused on UI, logic in ViewModels

### Testing Conventions
- Test files named: `{ClassUnderTest}Tests.swift`
- Follow TDD: Write failing tests first
- Test methods start with `test`
- Use XCTest framework assertions

### File Structure
```
Models/         - Data structures and document classes
ViewModels/     - ObservableObject classes for business logic
Views/          - SwiftUI view files
Services/       - Repository and service classes
Utilities/      - Helper classes and extensions
Tests/          - Unit test files
```

### Platform-Specific Code
- Use compiler directives for platform differences:
```swift
#if os(iOS)
    // iOS specific code
#endif
```

### Protocol & Type Design
- Make types Codable when they need serialization
- Make types Equatable for testing and comparison
- Prefer structs over classes unless reference semantics needed
- Use protocols for dependency injection and testing

### Async State Capture (CRITICAL)
- **Never read `@State` or `@Published` inside `Task {}` bodies** — the value may change before the Task runs
- Always capture to a local variable first, then pass the local into the Task
- Clear the state synchronously after capture, before the Task
- Post-flight check: grep for `Task {` in Views and verify no @State reads inside
```swift
// BAD
Task { doSomething(with: someState) }
someState = nil

// GOOD
let captured = someState
someState = nil
Task { doSomething(with: captured) }
```

### List Selection vs NavigationLink (CRITICAL)
- `List(selection:)` is silently broken when rows contain `NavigationLink` or `Button` — the interactive element captures the gesture before the selection binding fires
- When combining selection with navigation, conditionally render: plain view in select mode, NavigationLink-wrapped row in normal mode
- Applies to both iOS and macOS

### Error Handling
- Use proper error types
- Handle errors gracefully
- Provide meaningful error messages
- Never force unwrap without absolute certainty

### Import Statements
- Keep imports minimal and specific
- Standard order: System frameworks, then third-party, then local