# Task Completion Checklist

When completing any development task in Yiana, follow these steps:

## 1. Run Tests
```bash
xcodebuild test -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'
```
Ensure all tests pass before considering the task complete.

## 2. Build Verification
```bash
xcodebuild build -scheme Yiana -destination 'platform=iOS Simulator,name=iPhone 16'
```
Verify the project builds without errors or warnings.

## 3. Code Quality Checks
- Ensure code follows Swift naming conventions (camelCase for properties/methods, PascalCase for types)
- Verify proper access control (private, internal, public)
- Check for proper error handling
- Ensure no force unwrapping unless absolutely necessary

## 4. Documentation
- Add inline comments for complex logic (using ///)
- Update relevant documentation if behavior changes
- Ensure public APIs have documentation comments

## 5. Git Commit
After tests pass and build succeeds:
```bash
git add .
git commit -m "descriptive message following TDD pattern"
```

## 6. Update Project Memory
If completing a phase from PLAN.md:
- Update memory-bank/activeContext.md with completion status
- Note any deviations from the original plan

## TDD Specific Workflow
1. Write failing test first
2. Implement minimal code to pass test
3. Refactor if needed
4. Commit the test/implementation pair
5. Move to next test

## Important Notes
- Never skip the test-first approach
- Each commit should represent a working state
- Keep commits small and focused