# Lessons Learned

## Multiplatform Architecture (2025-07-15)

### Problem
Attempted to create a complex protocol-based architecture to share document code between iOS and macOS platforms. This led to:
- Conflicts between UIDocument (non-optional fileURL) and NSDocument (optional fileURL)
- Complex conditional compilation
- Overengineered abstractions that didn't add value

### Solution
iOS/iPadOS and macOS apps should:
- Share the same data format (.yianazip, DocumentMetadata)
- Have separate implementations using their native document classes
- Use platform idioms directly without forcing abstraction

### Key Insight
Don't force shared code when platforms have different paradigms. It's better to have clean, platform-specific implementations that handle the same data format than complex abstractions that fight the frameworks.

### What to do instead
- Use conditional compilation at the file level (#if os(iOS) around entire files)
- Share only data structures and business logic that truly makes sense
- Let each platform use its native patterns