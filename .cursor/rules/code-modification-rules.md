# ⚠️ CRITICAL CODE MODIFICATION RULES

These rules are **MANDATORY** and must be followed for every code change, edit, or modification to the Userpilot iOS SDK codebase.

---

## 🚨 FORMATTING & STYLE - DO NOT MODIFY

### Rule 1: Do NOT Reformat Code
**CRITICAL**: When editing files, preserve the exact formatting as it exists.

- ❌ **NEVER** reformat existing code indentation
- ❌ **NEVER** change spacing, line breaks, or alignment
- ❌ **NEVER** add/remove blank lines unless explicitly requested
- ❌ **NEVER** reorder existing code unless explicitly requested
- ✅ **ONLY** make the specific changes requested by the user
- ✅ **PRESERVE** all existing formatting exactly as it is

**Example - DO NOT DO THIS**:
```swift
// Original code (DO NOT CHANGE)
func example() {
    let value=10
    processData(value)
}

// WRONG - Reformatted (DON'T DO THIS)
func example() {
    let value = 10
    
    processData(value)
}
```

### Rule 2: Do NOT Reformat Comments
**CRITICAL**: Preserve all comment formatting exactly as it exists.

- ❌ **NEVER** reformat comment style (`//` vs `///` vs `/* */`)
- ❌ **NEVER** reflow comment text or change line breaks
- ❌ **NEVER** "fix" comment grammar or wording unless explicitly asked
- ❌ **NEVER** add or remove emoji from comments unless explicitly requested
- ✅ **PRESERVE** all existing comments in their exact format
- ✅ **ONLY** add new comments when explicitly requested

**Example - DO NOT DO THIS**:
```swift
// Original comment (DO NOT CHANGE)
//Opens socket connection
private func connect() { }

// WRONG - Reformatted comment (DON'T DO THIS)
/// Opens socket connection.
private func connect() { }
```

---

## 🧪 TESTING - DO NOT MODIFY

### Rule 3: Do NOT Add Unit Tests
**CRITICAL**: Do not create or add new test files or test cases unless explicitly requested.

- ❌ **NEVER** proactively create new test files
- ❌ **NEVER** add test cases without explicit user request
- ❌ **NEVER** suggest adding tests unless asked
- ✅ **ONLY** create tests when user explicitly says "add tests" or "write tests"

### Rule 4: Do NOT Update Existing Unit Tests
**CRITICAL**: Do not modify existing test files unless explicitly requested.

- ❌ **NEVER** update test files when changing production code
- ❌ **NEVER** "fix" failing tests automatically
- ❌ **NEVER** refactor test code unless explicitly asked
- ❌ **NEVER** add assertions or test cases to existing tests
- ✅ **ONLY** modify tests when user explicitly requests test changes
- ✅ **MAY** inform user if tests might need updates, but don't make changes

**When tests fail**:
- ✅ Inform the user that tests may need updating
- ✅ Explain what changed in production code
- ❌ Do NOT automatically update the tests

---

## 📝 GENERAL MODIFICATION RULES

### Surgical Changes Only
When making edits:
- Make **minimal, surgical changes** to achieve the requested goal
- Change **only** what is explicitly requested
- Preserve **everything else** exactly as it is
- Do NOT "improve" or "clean up" unrequested aspects

### What You CAN Do (When Requested)
- ✅ Add new functionality when explicitly asked
- ✅ Fix bugs when explicitly asked
- ✅ Refactor code when explicitly asked
- ✅ Add documentation when explicitly asked
- ✅ Add logging statements when explicitly asked

### What You CANNOT Do (Unless Explicitly Requested)
- ❌ Reformat code for "consistency"
- ❌ "Clean up" comments
- ❌ Add or update tests
- ❌ Add documentation "for completeness"
- ❌ Refactor "for better practices"
- ❌ Add error handling "for safety"
- ❌ Add logging "for debugging"

---

## 🎯 VERIFICATION CHECKLIST

Before submitting ANY code change, verify:

- [ ] I have NOT reformatted any existing code
- [ ] I have NOT reformatted any existing comments  
- [ ] I have NOT added any unit tests (unless explicitly requested)
- [ ] I have NOT updated any unit tests (unless explicitly requested)
- [ ] I have made ONLY the specific changes requested
- [ ] I have preserved ALL existing formatting
- [ ] I have not "improved" unrequested aspects

---

## ⚡ QUICK REFERENCE

| Action | Allowed | Notes |
|--------|---------|-------|
| Reformat code | ❌ NEVER | Preserve exact formatting |
| Reformat comments | ❌ NEVER | Keep original style |
| Add tests | ❌ NEVER | Unless explicitly requested |
| Update tests | ❌ NEVER | Unless explicitly requested |
| Add requested feature | ✅ YES | Make minimal changes |
| Fix requested bug | ✅ YES | Surgical fix only |
| "Improve" unrequested code | ❌ NEVER | Only what's requested |

---

## 🔥 REMEMBER

**When in doubt, do LESS rather than MORE.**

Your job is to make the **specific change requested**, not to improve, clean up, or perfect the codebase. The user will explicitly request improvements when they want them.

**These rules override all other guidelines.** Even if the SDK rules suggest adding documentation or tests, these critical rules take precedence - do NOT add anything unless explicitly requested.

