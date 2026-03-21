# Active Context

**Current Focus:** Task 12 — Manual integration testing
**Started:** 2026-03-20
**Target Completion:** Ongoing
**Priority:** P1

## Scope

### Pending Tasks

| Task | Description | Notes |
|------|-------------|-------|
| 12 | Manual integration testing | User-driven; checklist in SESSION_STATUS.md |

### Files in Scope

- Ninguno — todas las tareas de código están completas. Solo queda Task 12 (usuario).

### Files Out of Scope

- `PetruVim/Presentation/` — UI is complete; do not modify unless wiring new feature
- `PetruVim/Domain/Models/` — Models are stable
- `PetruVim/Domain/Ports/` — Ports are stable
- `PetruVim/Application/PermissionsManager.swift` — complete

## Technical Notes

### Task 14 — Repeat `.`
- `lastChange: VimCommand?` already stored in `VimEngine`
- `saveLastChange()` already skips motions/undo/redo/repeatLast
- `executeStandalone(.repeatLast)` already calls `executeCommand(lastChange)` — skeleton is complete
- Missing: CommandParser must emit `.standalone(.repeatLast)` on `.` keypress
- KeyCode for `.` = 47

### Task 15 — Count prefix
- `CommandParser` accumulates count digits into `pendingCount`
- Count is already passed to `.motion`, `.operatorMotion`, `.operatorLine`
- Not yet wired for: standalone operators (x, p), insert entry (o/O with count)

### DEBT-001 — CGEvent re-entrancy
- `CGEventKeyboardAdapter.postSyntheticEvent` posts via `.cgSessionEventTap`
- Risk: synthetic Cmd-Z gets re-intercepted by the same tap
- Fix A: use `.cghidEventTap` for posting (events injected at HID level bypass session tap)
- Fix B: set a `isSendingSyntheticEvent` Bool flag; check it at top of tap callback

## Open Questions

- Task 13: add all three SPM packages at once, or per-feature?
- Visual linewise mode `V` — not in MVP scope per SPEC.md; confirm before implementing
