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

## Process
1. Scan and list ALL issues with file:line references
2. Ask: "Fix all / pick specific / skip?"
3. Apply approved fixes
4. Generate commit message:
```
Improve API documentation

- [Each specific change]
```

## Rules
- Only audit public (non-underscored) declarations
- Follow Swift doc comment conventions
- Don't change code behavior
