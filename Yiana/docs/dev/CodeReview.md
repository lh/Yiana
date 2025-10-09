# Code Review Checklist

**Purpose**: Guidelines and checklist for conducting effective code reviews
**Audience**: Reviewers and pull request authors
**Last Updated**: 2025-10-08

---

## Philosophy

Code reviews serve multiple purposes:
1. **Catch bugs** before they reach production
2. **Share knowledge** across the team
3. **Maintain quality** and consistency
4. **Mentor** junior developers
5. **Document decisions** through discussion

**Key principle**: Be constructive, not critical. Focus on the code, not the person.

## Review Process

### For Authors

#### Before Requesting Review

- [ ] **Self-review** - Review your own changes first
- [ ] **Tests pass** - All unit and UI tests pass locally
- [ ] **No warnings** - No console warnings or build warnings
- [ ] **Documentation** - User/dev docs updated
- [ ] **Commit quality** - Clean commit history, no "WIP" commits
- [ ] **Description** - Clear PR description with context

#### During Review

- [ ] **Respond promptly** - Address feedback within 24-48 hours
- [ ] **Be receptive** - Accept constructive criticism gracefully
- [ ] **Ask questions** - If feedback is unclear, ask for clarification
- [ ] **Explain decisions** - If you disagree, explain your reasoning
- [ ] **Don't take it personally** - Reviews are about code quality, not your worth

#### After Approval

- [ ] **Merge promptly** - Don't leave approved PRs open for days
- [ ] **Squash commits** (optional) - Consolidate if many small fixes
- [ ] **Delete branch** - Clean up after merge

### For Reviewers

#### Review Timeline

- **Small PRs** (<100 lines): Review within 24 hours
- **Medium PRs** (100-500 lines): Review within 48 hours
- **Large PRs** (>500 lines): Review within 72 hours, or request breakdown

#### Review Mindset

**Ask yourself**:
- Does this change solve the stated problem?
- Is this the simplest solution?
- Will I understand this code in 6 months?
- Are there edge cases not handled?
- Is this well-tested?

**Remember**:
- Praise good work ("Nice refactoring!")
- Suggest, don't command ("Consider X" vs "Change this")
- Explain "why" for requested changes
- Offer to pair if complex issue

## Code Review Checklist

### 1. Correctness ✅ BLOCKING

- [ ] **Code does what it claims** - Matches PR description
- [ ] **Edge cases handled** - Empty strings, nil values, large inputs
- [ ] **No obvious bugs** - Logic errors, off-by-one, null dereferences
- [ ] **Error handling** - Graceful failures, user-friendly errors
- [ ] **Thread safety** - No race conditions, proper async/await usage

**Red flags**:
- Force unwrapping (`!`) without validation
- Unbounded loops or recursion
- Missing error handling
- Hard-coded values that should be configurable

### 2. Testing ✅ BLOCKING

- [ ] **Tests exist** - New code has corresponding tests (TDD mandate)
- [ ] **Tests pass** - All tests pass in CI
- [ ] **Coverage adequate** - Services 80%+, ViewModels 70%+
- [ ] **Tests are meaningful** - Not just for coverage numbers
- [ ] **Edge cases tested** - Not just happy path

**Red flags**:
- No tests for new feature
- Tests only test trivial cases
- Tests are flaky (pass/fail randomly)
- Tests mock everything (integration tests needed)

### 3. Code Quality ⚠️ NON-BLOCKING (but important)

- [ ] **Follows CODING_STYLE.md** - 1-based indexing, wrappers, etc.
- [ ] **Clear naming** - Variables, functions, types are self-documenting
- [ ] **Single Responsibility** - Functions/classes do one thing well
- [ ] **No duplication** - DRY (Don't Repeat Yourself)
- [ ] **Appropriate abstractions** - Not over-engineered, not under-engineered

**Red flags**:
- Function >50 lines (consider breaking up)
- God classes (>500 lines, many responsibilities)
- Magic numbers without constants
- Inconsistent naming conventions

### 4. Architecture & Design ⚠️ NON-BLOCKING (discuss if concerns)

- [ ] **Follows project patterns** - Consistent with existing code
- [ ] **No anti-patterns** - Avoids known bad practices
- [ ] **Dependency direction** - ViewModels → Services, not reverse
- [ ] **Separation of concerns** - View/ViewModel/Model/Service boundaries clear
- [ ] **Platform-appropriate** - Uses platform-specific code when clearer

**Red flags**:
- Mixing UI and business logic
- ViewModels calling Views
- Circular dependencies
- Breaking existing architectural patterns

### 5. Performance 💡 INFORMATIONAL

- [ ] **No obvious performance issues** - N+1 queries, excessive loops
- [ ] **Appropriate data structures** - Set vs Array for lookups
- [ ] **Caching where needed** - Expensive operations cached
- [ ] **Lazy loading** - Don't load all data upfront if not needed
- [ ] **Memory leaks avoided** - Weak references where appropriate

**When to flag**:
- Blocking main thread (heavy computation, I/O)
- O(n²) algorithms for large n
- Loading entire PDF into memory unnecessarily
- Retaining strong references in closures

### 6. Security 🔒 BLOCKING

- [ ] **No hardcoded secrets** - API keys, passwords, tokens
- [ ] **User input validated** - XSS, injection attacks prevented
- [ ] **Sensitive data protected** - Encryption where needed
- [ ] **Permissions checked** - File access, camera, etc.

**Red flags**:
- Credentials in code
- SQL string concatenation (use GRDB query builder)
- Unvalidated user input used in file paths

### 7. Documentation 📝 NON-BLOCKING

- [ ] **Code comments** - Complex logic explained
- [ ] **Public API documented** - Function/class comments for public APIs
- [ ] **User docs updated** - Features.md, GettingStarted.md, etc.
- [ ] **ADR created** - If architectural decision made
- [ ] **TODO/FIXME explained** - If present, has context

**When to request updates**:
- Complex algorithm without explanation
- Public API without usage example
- New feature not in user documentation

### 8. UI/UX (if applicable) 💡 INFORMATIONAL

- [ ] **Follows HIG** - Apple Human Interface Guidelines
- [ ] **Responsive layout** - iPhone + iPad + macOS (if applicable)
- [ ] **Accessibility** - VoiceOver, Dynamic Type support
- [ ] **Loading states** - Spinners, placeholders for async operations
- [ ] **Error states** - Clear error messages, recovery options

**Consider**:
- Does this work on all supported devices?
- Is this intuitive for users?
- Are there visual bugs (misalignment, clipping)?

## Yiana-Specific Checks

### Page Numbering ✅ BLOCKING

- [ ] **1-based indexing** - All user-facing code uses 1-based pages
- [ ] **Wrapper methods** - Uses `getPage(number:)` not `page(at:)`
- [ ] **Comments** - `// 1-based page number` where appropriate

**Example**:
```swift
// ✅ GOOD
let page = pdfDocument.getPage(number: userSelectedPage)

// ❌ BAD
let page = pdfDocument.page(at: userSelectedPage - 1)
```

### State Management ⚠️ NON-BLOCKING

- [ ] **No state mutation during view updates** - Uses `DispatchQueue.main.async`
- [ ] **Coordinator pattern** - UIViewRepresentable uses Coordinator for actions
- [ ] **Published properties** - ViewModels use `@Published` appropriately

**Example**:
```swift
// ✅ GOOD
func updateUIView(_ uiView: UIView, context: Context) {
    DispatchQueue.main.async {
        self.updateState()
    }
}

// ❌ BAD
func updateUIView(_ uiView: UIView, context: Context) {
    self.updateState()  // Crash risk!
}
```

### Platform-Specific Code ⚠️ NON-BLOCKING

- [ ] **Separate implementations** - iOS vs macOS, not complex conditionals
- [ ] **No forced abstractions** - Platform-specific is OK

**Example**:
```swift
// ✅ GOOD
#if os(iOS)
struct IOSPDFViewer: UIViewRepresentable { ... }
#elseif os(macOS)
struct MacPDFViewer: NSViewRepresentable { ... }
#endif

// ❌ AVOID
struct PDFViewer: View {
    #if os(iOS)
    // 100 lines of iOS code
    #else
    // 100 lines of macOS code
    #endif
}
```

### TDD Compliance ✅ BLOCKING

- [ ] **Tests written first** - PR description confirms TDD followed
- [ ] **Red-Green-Refactor** - Commit history shows test → implementation pairs
- [ ] **Test coverage** - All new code paths tested

## Common Feedback Templates

### Requesting Changes

**Blocking issue**:
> **[Blocking]** This could cause a crash when X is nil. Consider adding a guard statement:
> ```swift
> guard let page = pdfDocument.getPage(number: pageNum) else {
>     logger.error("Invalid page number: \(pageNum)")
>     return
> }
> ```

**Non-blocking suggestion**:
> **[Suggestion]** This function is getting long. Consider extracting the validation logic into a separate helper:
> ```swift
> private func validateInput(_ input: String) -> Bool { ... }
> ```
> Not blocking, but would improve readability.

**Question for clarification**:
> **[Question]** I'm not sure I understand why we're using a Set here instead of an Array. Could you explain the performance benefits?

### Approving with Comments

> Looks great overall! A few minor suggestions (non-blocking):
>
> 1. Line 42: Consider extracting this magic number to a constant
> 2. Line 67: Nice use of the Coordinator pattern here!
>
> Approved, feel free to merge after addressing or explaining.

### Requesting Major Revision

> Thanks for the PR! I have some concerns about the approach:
>
> 1. **[Blocking]** This introduces a circular dependency between ViewModel and Service
> 2. **[Blocking]** Tests are missing for the error handling paths
> 3. **[Suggestion]** Consider using the existing DocumentRepository instead of creating a new service
>
> Let's discuss the architecture before proceeding. Happy to pair on this if helpful!

## Review Best Practices

### DO ✅

- **Start with positives** - Acknowledge good work
- **Be specific** - Point to exact lines, provide code examples
- **Explain "why"** - Help author understand reasoning
- **Offer alternatives** - Don't just say "wrong", suggest better approaches
- **Use labels** - [Blocking], [Suggestion], [Question], [Nit]
- **Approve liberally** - If no blocking issues, approve
- **Pair when stuck** - Complex issues? Offer to pair program

### DON'T ❌

- **Nitpick excessively** - Focus on important issues
- **Rewrite the PR** - Suggest changes, don't demand rewrite
- **Be condescending** - No "obviously" or "everyone knows"
- **Delay without reason** - Review promptly or explain delay
- **Request changes for style** - Unless CODING_STYLE.md violation
- **Assume intent** - Ask questions, don't assume author made mistake
- **Bikeshed** - Don't debate trivial issues (variable names, etc.)

## Severity Levels

Use labels to indicate severity:

- **[Blocking]** 🔴 - Must fix before merge (bugs, security, missing tests)
- **[Important]** 🟡 - Should fix, but not blocking (architecture, performance)
- **[Suggestion]** 🔵 - Nice to have (refactoring, style improvements)
- **[Nit]** ⚪ - Trivial (typos, minor style)
- **[Question]** ❓ - Seeking clarification, not requesting change
- **[Praise]** 🎉 - Good work, keep it up!

## When to Escalate

**Approve** if:
- No blocking issues
- Minor suggestions only
- Author can merge after addressing or explaining

**Request changes** if:
- Blocking issues exist (bugs, missing tests, security)
- Significant architectural concerns
- TDD not followed

**Escalate to team** if:
- Fundamental disagreement on approach
- Multiple reviewers have conflicting feedback
- Decision requires broader context

## Review Metrics

Track (informally) to improve process:

- **Review turnaround time** - How long from PR to first review?
- **Revision cycles** - How many rounds of feedback?
- **Approval rate** - % of PRs approved without major revision?
- **Bug catch rate** - % of bugs caught in review vs production?

**Goal**: Fast, constructive reviews that catch issues early.

## Resources

- [CODING_STYLE.md](../../CODING_STYLE.md) - Code conventions
- [Contributing.md](Contributing.md) - Contribution guidelines
- [TDD Workflow](Contributing.md#test-driven-development-tdd) - Test-first approach
- [ADRs](../decisions/) - Architecture decisions

## Example Review

**PR**: Add export to PDF feature

### Review Comments

**Line 23** [Blocking]:
> This force unwraps `document`. Should handle nil case:
> ```swift
> guard let document = documentRepository.getDocument(id: documentID) else {
>     throw ExportError.documentNotFound
> }
> ```

**Line 45** [Suggestion]:
> Consider caching the export result instead of regenerating on every call. Not blocking, but would improve performance for large documents.

**Line 67** [Praise]:
> Nice use of the provisional page manager pattern here! 🎉

**Line 89** [Question]:
> Why are we using A4 page size here instead of the document's original page size?

**Line 102** [Nit]:
> Typo in comment: "proccess" → "process"

**Overall**:
> Great work on this feature! The implementation is clean and follows our patterns well.
>
> **Blocking**: Just the nil handling on line 23
> **Non-blocking**: Consider the caching optimization on line 45
>
> Once line 23 is addressed, feel free to merge. Thanks!

---

**Remember**: Code reviews are collaborative, not adversarial. We're all working toward the same goal—a better product.
