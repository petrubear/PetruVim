# Technical Debt Registry

**Last Updated:** 2026-03-20
**Total Items:** 0
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

_None._

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
| DEBT-015 | AX re-fetch on every write | 2026-03-20 | TextElementPort.writeFocusedElement replaced by updateFocusedElement(transform:); AXTextElementAdapter fetches element once per update; VimEngine migrated to closures |
| DEBT-016 | `preFilter` accede a `@MainActor` sin aislamiento verificado | 2026-03-20 | Envuelto el closure de `preFilter` en `MainActor.assumeIsolated { }` en AppCoordinator; mismo patrón que `onKeyEvent` en VimEngine |
| DEBT-017 | Parámetro muerto `lastChange` en `OperatorResolver.apply` | 2026-03-20 | Parámetro eliminado de la firma; todos los call sites (VimEngine ×3, OperatorResolverTests ×11) actualizados |
| DEBT-018 | `readFocusedElement()` zombie en `TextElementPort` | 2026-03-20 | Método eliminado del protocolo, AXTextElementAdapter y MockTextElement; ningún call site existía en producción |
| DEBT-019 | `Motion.lineDown` no avanza líneas con `count > 1` | 2026-03-20 | `apply()` en MotionResolver special-casea `.lineDown`: `count-1` downs + firstNonBlank; 3 tests añadidos |
| DEBT-020 | `SYSTEM_MAP.md` desactualizado (App Exclusion Flow + Visual Mode) | 2026-03-20 | App Exclusion Flow actualizado a preFilter/AppCoordinator; Visual Mode "(Planned)" → implementación real documentada |
| DEBT-021 | `ACTIVE_CONTEXT.md` con notas de deuda ya resuelta | 2026-03-20 | Sección Technical Notes eliminada (Task 14, 15, DEBT-001 ya cerrados); Open Question de Task 13 eliminada |
| DEBT-022 | `SPEC.md` referencia API y nombre de tipo obsoletos | 2026-03-20 | `enum Operator` → `VimOperator`; flujo VimEngine y Event Flow actualizados a `updateFocusedElement(transform:)` |
