# .claude/commands/audit-api.md

Use project-steward to audit API documentation (doc comments for public APIs).

## Scope
Check all public APIs in Sources/System/ (or $ARGUMENTS if provided).

## Look For
- Missing doc comments on public declarations
- Missing parameter documentation (for public functions/methods/inits)
- Missing return value documentation (for public functions/methods with non-Void returns)
- Missing throws documentation (for throwing public functions/methods)
- Missing precondition documentation (if applicable on public API)
- Unclear or incomplete descriptions (on public API)

## Skip
- Deprecated APIs (marked with `@available(*, deprecated)`)
- Internal or private functions, methods, properties, and types

## Process
1. Scan and list ALL issues with file:line references
2. If NO issues found: Report "✓ API documentation is complete" and stop
3. If issues found, ask: "Fix all / pick specific / skip?"
4. Apply approved fixes (edit files directly)
5. Show what changed
6. Provide commit message for user to copy:
```
Improve API documentation

- [Each specific change]
```

## Important
- DO NOT run git commands (no git add, git commit, etc.)
- Only edit source files
- User will commit changes themselves
- Don't add unnecessary documentation structure (like Returns: for simple properties)
- It's fine (and good!) if everything is already documented

## Rules
- Only audit public (non-underscored) declarations
- Follow Swift doc comment conventions
- Don't change code behavior
