# Technical Debt Registry

**Last Updated:** 2026-03-20
**Total Items:** 1
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

_None._

---

## P3 - Low Priority

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
| DEBT-009 | Retain cycle in `awaitingChar` closure | 2026-03-20 | Changed `[self]` to `[weak self]`; count falls back to 1 if self is nil |
| DEBT-010 | Unknown keys silently suppressed | 2026-03-20 | Added `VimCommand.passThrough`; CommandParser returns it for unknown keys; VimEngine returns false to pass key to host |
| DEBT-011 | NSRunningApplication on every SwiftUI render | 2026-03-20 | ExcludedAppRow.app moved to @State, resolved once in .onAppear |
| DEBT-012 | `applyCount` dead code | 2026-03-20 | Method deleted; all call sites inlined to return cmd directly |
| DEBT-013 | `moveVertical` two-pass over allLines | 2026-03-20 | Single pass collects lineStarts[] and locates currentLine simultaneously |
| DEBT-014 | Exclusion wrapper post-hoc on onKeyEvent | 2026-03-20 | Added preFilter to CGEventKeyboardAdapter; AppCoordinator installs it before engine.start() |
