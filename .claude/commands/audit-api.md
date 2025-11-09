# .claude/commands/audit-api.md

Use project-steward to audit API documentation (doc comments for public APIs).

## Thoroughness Requirement
**BE EXHAUSTIVE**: Scan EVERY SINGLE public API declaration in the target scope. Do not skip files or stop early. This is a comprehensive audit.

## Scope
Check all public APIs in Sources/System/ (or $ARGUMENTS if provided).

## Look For
- Missing doc comments on public declarations
- Missing parameter documentation (for public functions/methods/inits)
- Missing return value documentation (for public functions/methods with non-Void returns)
- Missing throws documentation (for throwing public functions/methods)
- Missing precondition documentation (if applicable on public API)
- Unclear or incomplete descriptions (on public API)
- Vague descriptions that don't explain "why" or purpose
- Missing usage examples for complex APIs

## Skip
- Deprecated APIs (marked with `@available(*, deprecated)`)
- Internal or private functions, methods, properties, and types

## Process
1. **Scan Phase**: Systematically scan ALL Swift files in scope
   - Search for all public declarations: classes, structs, enums, protocols, functions, properties, inits, methods
   - For each API, evaluate documentation quality
   - Record ALL issues with file:line references

2. **Report Phase**: Generate a detailed quality report including:
   - **Summary Statistics**:
     - Total public APIs found
     - Number with complete documentation
     - Number with incomplete/missing documentation
     - Documentation coverage percentage
   - **Issues by Category**:
     - Missing doc comments
     - Missing parameter docs
     - Missing return value docs
     - Missing throws docs
     - Unclear/vague descriptions
   - **Detailed Issue List**:
     - Group by file
     - Show file:line for each issue
     - Include brief description of what's missing/unclear
   - **Worst Offenders**: Files with most documentation issues
   - **CRITICAL: File-by-File Checklist**:
     - List EVERY file that has issues, organized by category
     - Show issue count per file (e.g., "MachPort.swift (6 issues)")
     - This checklist will be used to track remediation progress

3. **Remediation Phase** (if issues found):
   - Ask: "Fix all / pick specific / skip?"
   - **BEFORE STARTING**: Create a complete todo list with ALL files from the report checklist
   - Apply approved fixes (edit files directly)
   - **DURING WORK**: Mark each file complete in the todo list ONLY after fixing all its issues
   - **VERIFICATION STEP**: Before declaring completion, verify every file from the original checklist has been addressed
   - Show summary of what changed
   - Provide commit message for user to copy:
   ```
   Improve API documentation

   - [Each specific change by file]
   ```

## Important
- DO NOT run git commands (no git add, git commit, etc.)
- Only edit source files
- User will commit changes themselves
- Don't add unnecessary documentation structure (like Returns: for simple properties)
- It's fine (and good!) if everything is already documented
- Complete the scan even if you find many issues - get the full picture
- **CRITICAL**: During remediation, work from the file checklist, not from memory. Cross-reference the original report before marking completion.

## Rules
- Only audit public (non-underscored) declarations
- Follow Swift doc comment conventions
- Don't change code behavior
- Be thorough: every public API must be checked
