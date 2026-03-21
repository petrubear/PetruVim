# Technical Debt Registry

**Last Updated:** 2026-03-20
**Total Items:** 9
**Critical (P0):** 0

## Priority Definitions

| Priority | Definition | SLA |
|----------|------------|-----|
| P0 | Blocking development or causing incidents | Immediate |
| P1 | Significant impact on velocity | This sprint |
| P2 | Moderate impact, workaround exists | This quarter |
| P3 | Minor, address when convenient | Backlog |

---

## P0 - Critical

_None._

---

## P1 - High Priority

_None._

---

## P2 - Medium Priority

### [DEBT-009] Retain cycle in `CommandParser.awaitingChar` closure

- **Source:** Kiro BUG-6
- **Location:** `PetruVim/Domain/Engine/CommandParser.swift` — `feedNormal`, `feedVisual`
- **Added:** 2026-03-20
- **Impact:** `awaitingChar = { [self] foundChar in ... }` captures `CommandParser` strongly. Since `awaitingChar` is a property of `CommandParser`, this creates a retain cycle: `parser` → `awaitingChar` → captures `parser`. If the parser is deallocated while waiting for a target character, the closure keeps it alive indefinitely.
- **Proposed Fix:** Change `[self]` to `[weak self]` with a `guard let self` inside the closure.
- **Estimated Effort:** 15 min

### [DEBT-010] Unknown keys silently suppressed in Normal/Visual mode

- **Source:** Kiro DESIGN-4
- **Location:** `PetruVim/Domain/Engine/VimEngine.swift` — `handleCommandMode`; `PetruVim/Domain/Engine/CommandParser.swift`
- **Added:** 2026-03-20
- **Impact:** `CommandParser.feed` returns `nil` for both "waiting for more input" (e.g., after `d`) and "unrecognized key, reset" (e.g., `q`, `z`, `r`). `VimEngine` treats both as suppress. Unrecognized keys like `q` never reach the host app.
- **Proposed Fix:** Add a distinction in `CommandParser`'s return — e.g., a separate `Bool` flag, a two-value enum, or a dedicated `.unrecognized` case — so VimEngine can pass through genuinely unknown keys.
- **Estimated Effort:** 2 hours (touches CommandParser return type, VimEngine, and tests)

### [DEBT-011] `ExcludedAppRow` calls `NSRunningApplication` on every SwiftUI render

- **Source:** Kiro DESIGN-5
- **Location:** `PetruVim/Presentation/SettingsView.swift` — `ExcludedAppRow`
- **Added:** 2026-03-20
- **Impact:** `app` is a computed var that invokes `NSRunningApplication.runningApplications(withBundleIdentifier:)` on every render cycle. This is an expensive AppKit call inside a SwiftUI view body.
- **Proposed Fix:** Resolve `NSRunningApplication` once in `onAppear` and store in a `@State` var, or pass the resolved app as a parameter from the parent.
- **Estimated Effort:** 30 min

---

## P3 - Low Priority

### [DEBT-012] `applyCount` in `CommandParser` is dead code

- **Source:** OpenCode
- **Location:** `PetruVim/Domain/Engine/CommandParser.swift` — `applyCount`
- **Added:** 2026-03-20
- **Impact:** The method does nothing but `return cmd`. All callers pass count via the command's associated value directly. The method name implies logic that doesn't exist and misleads readers.
- **Proposed Fix:** Delete the method and inline `cmd` at all call sites (already the effective behavior).
- **Estimated Effort:** 10 min

### [DEBT-013] `moveVertical` is O(n²) on large documents

- **Source:** Kiro DESIGN-3
- **Location:** `PetruVim/Domain/Engine/MotionResolver.swift` — `moveVertical`
- **Added:** 2026-03-20
- **Impact:** Two separate iterations over all lines: one to find the current line, one to compute the target line start offset. Imperceptible for typical documents; potentially slow on files with thousands of lines.
- **Proposed Fix:** Compute current line index and target line start in a single pass.
- **Estimated Effort:** 1 hour

### [DEBT-014] `onKeyEvent` exclusion wrapper installed after `engine.start()`

- **Source:** Kiro DESIGN-2
- **Location:** `PetruVim/Application/AppCoordinator.swift` — `startEngine`
- **Added:** 2026-03-20
- **Impact:** `engine.start()` assigns `keyboard.onKeyEvent`. AppCoordinator then wraps it with the exclusion-list check. If VimEngine ever reassigns `onKeyEvent` (e.g., on restart), the exclusion wrapper is silently lost and all apps are intercepted regardless of the exclusion list.
- **Proposed Fix:** Inject the exclusion check before `engine.start()`, or restructure so the exclusion logic is part of the keyboard adapter setup rather than a post-hoc wrapper.
- **Estimated Effort:** 1 hour

### [DEBT-015] `AXTextElementAdapter` re-fetches focused element on every write

- **Source:** Kiro DESIGN-1
- **Location:** `PetruVim/Infrastructure/AXTextElementAdapter.swift`
- **Added:** 2026-03-20
- **Impact:** `readFocusedElement` and `writeFocusedElement` each make two AX calls to obtain the focused element. Between read and write, focus can change, causing a write to the wrong element.
- **Proposed Fix:** Accept `axElement` as a parameter to `writeFocusedElement`, or wrap both operations in a single method that reads, transforms, and writes atomically. Requires changing `TextElementPort`.
- **Estimated Effort:** 3 hours (interface change + all implementations + tests)

---

## Resolved Debt (Last 30 Days)

| ID | Title | Resolved | Resolution |
|----|-------|----------|------------|
| — | `@main` / entry point conflict | 2026-03-15 | Removed `@main` from AppDelegate; created `main.swift` |
| — | Non-throwing ClipboardPort called with `try?` | 2026-03-15 | Removed `try?` wrappers |
| — | Duplicate `VimOperator: Equatable` conformance | 2026-03-15 | Removed extension from CommandParser |
| — | `NotificationCenter` vs `DistributedNotificationCenter` | 2026-03-15 | Updated AppCoordinator to use correct center |
| DEBT-004 | No unit tests | 2026-03-16 | 116 unit tests written covering MotionResolver, OperatorResolver, CommandParser, VimEngine with mock adapters |
| DEBT-001 | CGEventTap re-entrancy on synthetic events | 2026-03-20 | Added `isSendingSyntheticEvent` flag in CGEventKeyboardAdapter; superseded by DEBT-005 |
| DEBT-005 | `postSyntheticEvent` race condition | 2026-03-20 | Changed `.cgSessionEventTap` → `.cghidEventTap`; removed `isSendingSyntheticEvent` flag and guard entirely |
| DEBT-006 | `applyToLine` cursor off-by-one on last line | 2026-03-20 | Introduced `cursorBase` computed before `rangeStart -= 1`; `newCursor` now uses `cursorBase` |
| DEBT-002 | Force cast `app as! AXUIElement` | 2026-03-20 | Restructured guards to check `!= nil` before `as!`; `as!` retained for CFTypes (Swift 6 requires it) |
| DEBT-003 | Visual mode strips selection in MotionResolver | 2026-03-20 | Added `visualAnchor: Int?` param to MotionResolver.apply; selection computed internally; VimEngine simplified |
| DEBT-007 | `executeStandalone(.paste)` ignores `count` | 2026-03-20 | `OperatorResolver.paste` now accepts `count` and repeats content; VimEngine passes actual count |
| DEBT-008 | `yankWithMotion` excludes till motions from inclusive range | 2026-03-20 | Added `.tillForward`/`.tillBackward` to inclusive switch in `yankWithMotion`, mirroring `deleteWithMotion` |
