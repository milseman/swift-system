# .claude/commands/audit-api.md

Use project-steward to audit API documentation (doc comments for public APIs).

## Scope
Check all public APIs in Sources/SystemPackage/ (or $ARGUMENTS if provided).

## Look For
- Missing doc comments on public declarations
- Missing parameter documentation
- Missing return value documentation
- Missing throws documentation
- Unclear or incomplete descriptions

## Skip
- Deprecated APIs (marked with `@available(*, deprecated)`)

## Process
1. Scan and list ALL issues with file:line references
2. Ask: "Fix all / pick specific / skip?"
3. Apply approved fixes (edit files directly)
4. Show what changed
5. Provide commit message for user to copy:
```
Improve API documentation

- [Each specific change]
```

## Important
- DO NOT run git commands (no git add, git commit, etc.)
- Only edit source files
- User will commit changes themselves

## Rules
- Only audit public (non-underscored) declarations
- Follow Swift doc comment conventions
- Don't change code behavior
