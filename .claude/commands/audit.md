# .claude/commands/audit.md

Interactive audit menu for Swift System.

Present audit options:

1. **API Documentation** - Check public API doc comments
2. **Test Coverage** - Find missing tests
3. **Code Quality** - Check style, comments, clarity
4. **Project Docs** - Check docs/ folder and README
5. **Run All** - Execute all audits in sequence

Ask which audit to run, then invoke the corresponding command:
- Option 1 → /audit-api
- Option 2 → /audit-tests
- Option 3 → /audit-code
- Option 4 → /audit-docs

After each audit completes, ask: "Continue with another audit?"

If "Run All" is selected, execute each audit in sequence, allowing the user to review and commit after each one.
