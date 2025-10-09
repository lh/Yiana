# Contributing to Yiana

**Purpose**: Guidelines for contributing code, documentation, and other improvements
**Audience**: Contributors (internal team and external)
**Last Updated**: 2025-10-08

---

## Welcome!

Thank you for your interest in contributing to Yiana! This document outlines the process for contributing and our expectations for code quality, testing, and collaboration.

## Core Principles

1. **Test-Driven Development (TDD)** - Write tests first, then implement
2. **Small, focused commits** - One logical change per commit
3. **Follow coding conventions** - See [`CODING_STYLE.md`](../../CODING_STYLE.md)
4. **Documentation is code** - Update docs with every feature change
5. **Be respectful and professional** - Code reviews should be constructive

## Before You Start

### 1. Read the Documentation

**Essential reading**:
- [`CLAUDE.md`](../../CLAUDE.md) - Project overview and core rules
- [`CODING_STYLE.md`](../../CODING_STYLE.md) - Code conventions
- [`GettingStarted.md`](GettingStarted.md) - Developer setup guide

### 2. Check Existing Issues

- Search [GitHub Issues](https://github.com/lh/Yiana/issues) for existing work
- Comment on issues you'd like to work on to avoid duplication
- For new features, create an issue first to discuss approach

### 3. Set Up Development Environment

Follow the [Getting Started Guide](GettingStarted.md) to:
- Clone repository
- Build and run on simulator
- Run tests and verify they pass

## Contribution Workflow

### 1. Create a Feature Branch

```bash
# Update main branch
git checkout main
git pull origin main

# Create feature branch
git checkout -b feature/descriptive-name

# Examples:
# feature/add-export-to-pdf
# fix/search-crash-on-empty-query
# docs/update-architecture-diagrams
```

**Branch naming conventions**:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code improvements without behavior changes
- `test/` - Test additions or improvements

### 2. Follow Test-Driven Development (TDD)

**This is mandatory for all code changes.**

#### TDD Workflow

```swift
// 1. Write failing test first
// YianaTests/DocumentRepositoryTests.swift
func testCreateDocumentRequiresTitle() {
    let repo = DocumentRepository()
    let result = repo.createDocument(title: "")
    XCTAssertNil(result)  // Should fail to create with empty title
}
```

```bash
# 2. Run test - it should FAIL
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentRepositoryTests/testCreateDocumentRequiresTitle
```

```swift
// 3. Implement minimal code to make test pass
// Yiana/Services/DocumentRepository.swift
func createDocument(title: String) -> NoteDocument? {
    guard !title.isEmpty else { return nil }
    // ... create document
}
```

```bash
# 4. Run test - it should PASS
xcodebuild test -scheme Yiana -only-testing:YianaTests/DocumentRepositoryTests/testCreateDocumentRequiresTitle
```

```bash
# 5. Commit
git add YianaTests/DocumentRepositoryTests.swift Yiana/Services/DocumentRepository.swift
git commit -m "Add title validation for document creation"
```

#### TDD Benefits

- **Prevents regressions** - Tests catch breaking changes
- **Documents behavior** - Tests serve as executable specifications
- **Encourages better design** - Testable code is usually well-structured
- **Reduces debugging time** - Find issues immediately, not in production

### 3. Make Your Changes

#### Code Guidelines

**1-Based Page Indexing** (CRITICAL):
```swift
// ✅ GOOD - using wrapper
pdfDocument.getPage(number: 1)  // First page

// ❌ BAD - direct PDFKit call
pdfDocument.page(at: 0)  // First page
```

**State Management**:
```swift
// ✅ GOOD - deferred state update
DispatchQueue.main.async {
    self.totalPages = document.pageCount
}

// ❌ BAD - state mutation during view update
func updateUIView(...) {
    self.totalPages = document.pageCount  // Crash risk!
}
```

**Platform-Specific Code**:
```swift
// ✅ GOOD - separate platform implementations
#if os(iOS)
struct IOSPDFViewer: UIViewRepresentable { ... }
#elseif os(macOS)
struct MacPDFViewer: NSViewRepresentable { ... }
#endif

// ❌ AVOID - complex conditionals in shared code
```

See [`CODING_STYLE.md`](../../CODING_STYLE.md) for complete guidelines.

#### Documentation Updates

**Update documentation with every feature change**:

- **User-facing features** → Update `docs/user/Features.md`
- **New APIs** → Document in code comments and `docs/dev/api/`
- **Architecture changes** → Create ADR in `docs/decisions/`
- **New workflows** → Update `docs/diagrams/data-flow.md`

### 4. Test Your Changes

#### Unit Tests (Required)

```bash
# Run all unit tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15'
```

**Test coverage expectations**:
- **Services**: 80%+ coverage
- **ViewModels**: 70%+ coverage
- **Views**: UI tests only (unit tests optional)

#### UI Tests (For UI Changes)

```bash
# Run UI tests
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:YianaUITests
```

#### Manual Testing Checklist

- [ ] Test on iPhone simulator (compact layout)
- [ ] Test on iPad simulator (regular layout, split view)
- [ ] Test on macOS (if applicable)
- [ ] Test with empty document list
- [ ] Test with large documents (50+ pages)
- [ ] Test with iCloud sync disabled (local fallback)
- [ ] Test edge cases (empty strings, missing files, etc.)

See [`ManualTestingGuide.md`](../ManualTestingGuide.md) for detailed scenarios.

### 5. Commit Your Changes

#### Commit Guidelines

**Good commits**:
- Small and focused (one logical change)
- Clear, concise message
- No emojis or attributions
- Present tense ("Add feature" not "Added feature")

**Examples**:

```bash
# ✅ GOOD
git commit -m "Add title validation for document creation"
git commit -m "Fix search crash when query is empty"
git commit -m "Update Architecture.md with text page flow"

# ❌ BAD
git commit -m "🎉 Added cool new feature!"
git commit -m "Fixed stuff"
git commit -m "WIP"
git commit -m "Changes by Claude"
```

#### Commit Frequency

**Commit frequently** (every test/implementation pair):

```bash
# Commit after each passing test
git commit -m "Add test for title validation"
git commit -m "Implement title validation"

# NOT after bulk changes
git commit -m "Implemented entire feature with 10 changes"
```

### 6. Push and Create Pull Request

```bash
# Push feature branch
git push origin feature/descriptive-name
```

**On GitHub**:
1. Navigate to repository
2. Click "Compare & pull request"
3. Fill out PR template (see below)
4. Request review from team member

#### Pull Request Template

```markdown
## Description
[Brief summary of changes]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Refactoring
- [ ] Other (specify)

## Related Issue
Fixes #[issue number]

## Testing
- [ ] Unit tests added/updated
- [ ] UI tests added/updated (if applicable)
- [ ] Manual testing completed (see checklist)

## Screenshots (if UI changes)
[Add before/after screenshots]

## Checklist
- [ ] Code follows CODING_STYLE.md
- [ ] All tests pass
- [ ] Documentation updated
- [ ] No console warnings/errors
- [ ] Tested on iPhone and iPad simulators
- [ ] Tested on macOS (if applicable)

## Additional Notes
[Any context reviewers should know]
```

## Code Review Process

### For Authors

**When submitting a PR**:
1. Self-review your changes first
2. Ensure all tests pass
3. Update documentation
4. Add screenshots for UI changes
5. Respond to feedback constructively

**Responding to feedback**:
- Address all comments (or explain why not)
- Push new commits (don't force-push during review)
- Mark resolved conversations
- Thank reviewers for their time

### For Reviewers

**Code review checklist**: See [`CodeReview.md`](CodeReview.md)

**Key principles**:
- Be constructive and respectful
- Explain "why" for requested changes
- Approve if no blocking issues
- Use "Request changes" sparingly

**Review timeline**: Aim to review within 24-48 hours

## Dependency Management

### When to Add Dependencies ✅

- **Complex subsystems** (databases, networking, parsers)
- **Bug prevention** (memory safety, type safety libraries)
- **Time savings** (10x+ development time vs integration effort)
- **Maturity** (5+ years production use)
- **Safety-critical** (C interop, concurrency, cryptography)

### When NOT to Add Dependencies ❌

- **Trivial features** (<50 lines of straightforward code)
- **Duplicate functionality** (already in Apple frameworks)
- **Unmaintained projects** (no updates in 2+ years)
- **Vendor lock-in** (difficult to migrate away from)
- **Feature bloat** (using <10% of library features)

### Approved Dependencies

- **GRDB.swift** (v7.7+) - Type-safe SQLite wrapper

**Adding new dependencies**:
1. Create GitHub issue with justification
2. Discuss with team before implementing
3. Document decision in ADR (`docs/decisions/`)

## Documentation Contributions

### Types of Documentation

1. **User documentation** (`docs/user/`) - For end users
2. **Developer documentation** (`docs/dev/`) - For contributors
3. **Architecture decisions** (`docs/decisions/`) - ADRs
4. **Code comments** - In-line documentation

### Documentation Standards

**Every document should have**:
- Clear purpose statement
- Intended audience
- Last updated date
- Table of contents (if >3 sections)

**Code examples should**:
- Be runnable (copy-paste works)
- Include comments explaining "why"
- Show both good and bad patterns

**Screenshots should**:
- Be high resolution (2x/3x)
- Include annotations (arrows, highlights)
- Show realistic data (not Lorem Ipsum)
- Be up to date (re-capture when UI changes)

### Creating an ADR (Architecture Decision Record)

**When to create an ADR**:
- Significant architectural change
- Technology choice (framework, library, pattern)
- Trade-offs between multiple approaches

**ADR template**:

```markdown
# ADR [Number]: [Title]

**Date**: YYYY-MM-DD
**Status**: Accepted/Proposed/Deprecated
**Deciders**: [Who made the decision]
**Context**: [Brief context]

---

## Context and Problem Statement

[Detailed problem description]

## Decision Drivers

- Driver 1
- Driver 2

## Considered Options

### Option 1: [Name]
- ✅ Pros
- ❌ Cons

### Option 2: [Name] (Chosen)
- ✅ Pros
- ❌ Cons

## Decision Outcome

[Chosen option and why]

### Consequences

**Positive**:
- ✅ Benefit 1

**Negative**:
- ⚠️ Trade-off 1

## References

- Code: path/to/implementation.swift
- Related ADRs: ADR-XXX
```

Save to `docs/decisions/[number]-[title].md`

## Issue Reporting

### Creating a Good Issue

**Bug report template**:

```markdown
## Description
[Clear summary of the bug]

## Steps to Reproduce
1. Open app
2. Navigate to X
3. Tap Y
4. Observe Z

## Expected Behavior
[What should happen]

## Actual Behavior
[What actually happens]

## Environment
- Device: iPhone 15 Pro
- iOS version: 17.0
- App version: 1.2.3
- Build: 45

## Screenshots/Logs
[Add screenshots or console logs]

## Additional Context
[Any other relevant info]
```

**Feature request template**:

```markdown
## Problem Statement
[What problem does this solve?]

## Proposed Solution
[How should it work?]

## Alternatives Considered
[Other approaches]

## User Stories
- As a [user type], I want [goal] so that [benefit]

## Mockups/Wireframes
[If applicable]
```

## Release Process

**For maintainers only** - Contributors do not cut releases.

See: [`ReleaseProcess.md`](ReleaseProcess.md) (coming soon)

## Getting Help

### Stuck on Something?

1. **Search documentation** - Check `docs/` directory
2. **Search issues** - Someone may have asked before
3. **Create draft PR** - Ask for early feedback
4. **Ask in PR comments** - Tag reviewers with specific questions

### Common Questions

**Q: How do I test iCloud sync locally?**
A: Use two simulators or one simulator + device. Documents should sync via iCloud Drive.

**Q: Can I use Swift Concurrency (async/await)?**
A: Yes, preferred for new code. See existing async patterns in `DocumentViewModel`.

**Q: Should I update PLAN.md?**
A: No, PLAN.md is historical. Update `Roadmap.md` instead.

**Q: How do I handle merge conflicts?**
A: Rebase on main (`git rebase main`), resolve conflicts, then force-push to your branch.

## Code of Conduct

### Our Pledge

We are committed to providing a welcoming and professional environment for all contributors.

### Expected Behavior

- Be respectful and constructive in feedback
- Focus on the code, not the person
- Accept constructive criticism gracefully
- Help onboard new contributors

### Unacceptable Behavior

- Personal attacks or derogatory language
- Harassment or discrimination
- Publishing private information without consent
- Trolling or intentionally disruptive behavior

### Enforcement

Violations can be reported to project maintainers. All reports will be reviewed and addressed appropriately.

## Thank You!

Your contributions make Yiana better for everyone. We appreciate your time and effort!

**Questions?** Create an issue or reach out to the maintainers.
