# Git Hooks Setup Guide

## Overview

This repository includes custom git hooks to enforce code quality and architectural patterns. These hooks prevent common issues that cause build failures or performance problems.

## Installed Hooks

### Pre-Commit Hook: SwiftUI Architecture Checks

**Location:** `.git/hooks/pre-commit`

**Purpose:** Prevents SwiftUI type-checking timeouts by enforcing architectural patterns documented in `discussion/2025-10-14-swiftui-typecheck-instability-v2.md`

**What it checks:**

1. ✅ **View body line count** - No view `body` exceeds 15 lines (excluding blank lines/comments)
2. ✅ **Inline computations** - No optional chaining (`?.`) or nil-coalescing (`??`) in `ForEach` ranges
3. ✅ **Conditional nesting** - No nested conditionals deeper than 2 levels within view bodies
4. ⚠️  **Accessibility modifiers** - Warns if multiple `.accessibility*` modifiers are stacked (should use extension)
5. ⚠️  **Repeated patterns** - Warns if Button/HStack/VStack appears 5+ times (should extract component)

**Example output:**

```bash
🔍 Running SwiftUI architecture checks...

Check 1: View body line count...
✗ Yiana/Views/DocumentReadView.swift: view body exceeds 15 lines

Check 2: Inline computations in ForEach...
✗ Yiana/Views/MacPDFViewer.swift: ForEach contains inline optional chaining (?.) - hoist to local variable

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✗ Pre-commit check failed with 2 violation(s)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

These checks prevent SwiftUI type-checking timeouts.
See: discussion/2025-10-14-swiftui-typecheck-instability-v2.md
```

## Installation

The pre-commit hook is already installed in `.git/hooks/`. If you need to reinstall it:

```bash
# Make sure you're in the repository root
cd /Users/rose/Code/Yiana

# Copy the hook (if needed)
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit

# Make it executable
chmod +x .git/hooks/pre-commit
```

## Bypassing Hooks (Emergency Use Only)

If you need to commit despite hook failures (NOT RECOMMENDED):

```bash
git commit --no-verify
```

**⚠️ WARNING:** Bypassing these checks will likely cause build failures. Only use in emergencies and fix violations immediately after committing.

## Troubleshooting

### Hook doesn't run

**Check if it's executable:**
```bash
ls -l .git/hooks/pre-commit
# Should show: -rwxr-xr-x
```

**Make it executable if needed:**
```bash
chmod +x .git/hooks/pre-commit
```

### False positives

If the hook incorrectly flags valid code:

1. Check if the pattern is documented in the v2 architecture doc
2. If it's a legitimate false positive, file an issue with the code example
3. As a temporary workaround, use `--no-verify` (but document why)

### Hook runs slowly

The hook only analyzes staged SwiftUI view files, so it should be fast (<1 second for typical commits). If it's slow:

- Check if you have unusually large files staged
- Verify you're not accidentally staging build artifacts
- Run `git status` to see what's being analyzed

## Maintenance

### Updating the hook

To update the hook logic, edit `.git/hooks/pre-commit` directly. Remember that `.git/hooks/` is not version controlled, so document changes in this file.

### Adding new checks

When adding new architectural patterns:

1. Update `discussion/2025-10-14-swiftui-typecheck-instability-v2.md` with the pattern
2. Add corresponding check to `.git/hooks/pre-commit`
3. Update this documentation
4. Notify team via Slack/email about the new check

## Related Documentation

- [SwiftUI Type-Checking Instability (v2)](../discussion/2025-10-14-swiftui-typecheck-instability-v2.md) - Architecture patterns these hooks enforce
- [CODING_STYLE.md](../CODING_STYLE.md) - General coding standards
- [Architecture.md](./Architecture.md) - System architecture overview

## Support

If you have questions about these hooks or need help fixing violations:

1. Read the architecture doc first: `discussion/2025-10-14-swiftui-typecheck-instability-v2.md`
2. Ask in #engineering Slack channel
3. Pair with a team member on refactoring complex views
