<!-- Thanks for taking the time to create this Pull Request ❤️ -->
<!-- Keep this template in sync with the Userpilot Android SDK's — same sections, same order. -->

# 🚀 Description
<!-- Please describe your changes in detail. -->
<!-- Mention any relevant technical details, architecture notes, or new patterns introduced. -->

# 📄 Motivation and Context
<!-- Why is this change required? What problem does it solve? -->
<!-- If it fixes an open issue, please link it here. (e.g., Closes #123) -->

# 📦 Types of Changes
<!-- What type of change does your PR introduce? Select all that apply: -->
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Refactor (code change that neither fixes a bug nor adds a feature)
- [ ] Optimization (improves performance without changing behavior)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

# 🔌 Public API & Wrapper Impact
<!-- This is the base SDK. The Flutter, React Native, and Capacitor wrappers bind to its
     public @objc surface, so a changed signature breaks them at RUNTIME rather than at
     compile time. -->
- [ ] **No public API change** — nothing below applies
- [ ] Public API changed, and it is **additive only**
- [ ] Public API changed in a **breaking** way (requires a major version bump)

If the public API changed, confirm:
- [ ] New/changed symbols are `@objc`-exposed and Objective-C-bridgeable, and non-throwing
- [ ] Doc comments added on new public symbols
- [ ] Wrapper migration notes written below

<details>
<summary>Wrapper migration notes (required for any public API change)</summary>

<!-- What must Flutter / React Native / Capacitor change, and when?
     Say "none needed" explicitly if that is the case. -->

</details>

# 🧪 How Has This Been Tested?
<!-- Please describe how you tested your changes. -->
<!-- Mention devices/simulators, iOS versions, edge cases, etc. -->
- [ ] Unit tests (XCTest)
- [ ] Manual testing on real devices
- [ ] Manual testing on simulators
- [ ] Tested on different iOS versions (please list — deployment target is iOS 13)
- [ ] Tested with different device types (iPhone, iPad)

# 📷 Screenshots / Screen Recordings (if appropriate)
<!-- Provide before/after screenshots, GIFs, or videos to help reviewers understand the UI changes. -->

# 🛠 Migration Notes (optional)
<!-- Does this require migration steps (e.g., persisted Storage changes, data format updates)? -->
<!-- If not applicable, you can leave this section empty. -->

# ⚠️ Deprecations (optional)
<!-- If your change deprecates any classes, methods, or features, list them here. -->

# 🧹 Cleanup Tasks (optional)
<!-- Mention if there are any follow-up tasks, cleanup steps, or tech debt created. -->

# ✅ Checklist
<!-- CI enforces these via the "Green gate" check (same steps as
     `scripts/release-preflight.sh`). -->
- [ ] My code follows the project's coding standards and conventions (`AGENTS.md`)
- [ ] Environment is `.PRODUCTION` with placeholder socket URL / token, and no `NX-` in SocketManager
- [ ] `xcodebuild test -scheme Userpilot` passes, and I added tests where applicable
- [ ] `swiftlint --strict` is clean (no new warnings or errors in Xcode)
- [ ] XCFramework still builds (device + simulator)
- [ ] I have updated documentation (`docs/`, README, DocC) if needed
- [ ] My changes are backwards compatible (unless flagged as breaking above)
- [ ] If I added files or resources, `Userpilot.podspec` still covers them (`pod lib lint`)
- [ ] No PII, tokens, or secrets are logged
