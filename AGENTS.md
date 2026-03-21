# PetruVim

## Overview

PetruVim is a macOS menu bar app (macOS 14+) providing system-wide Vim keybindings in any focused
text field. It uses the macOS Accessibility API (AXUIElement) to read and write text without
keyboard remapping, modeled after kindaVim and built with hexagonal (ports & adapters) architecture.

## Tech Stack

- **Language:** Swift 6
- **Framework:** AppKit + SwiftUI (PermissionsView, SettingsView)
- **Platform:** macOS 14+ (no sandbox)
- **Key Dependencies:** `LaunchAtLogin-Modern` (launch-at-login toggle)

## Architecture

Hexagonal (ports & adapters): a pure-Swift domain core (models + engine + ports) is wired to
infrastructure adapters (AX, CGEvent, Pasteboard, DistributedNotifications) via `AppCoordinator`.
`VimEngine` is `@MainActor` and drives all mode transitions. See
`.context/architecture/SYSTEM_MAP.md` for full type names, notification flow, and entry point wiring.

## Quick Commands

| Action           | Command                   |
| ---------------- | ------------------------- |
| Generate project | `xcodegen generate`       |
| Open in Xcode    | `open PetruVim.xcodeproj` |
| Build            | Cmd-B in Xcode            |
| Test             | Cmd-U in Xcode            |

## Project Structure

```
PetruVim/
├── .context/                   # AI session context files
│   ├── core/
│   │   └── ACTIVE_CONTEXT.md   # Current focus, scope, requirements
│   │   └── SESSION_STATUS.md   # Current session state - read first
│   ├── architecture/
│   │   └── SYSTEM_MAP.md       # Detailed system architecture
│   └── quality/
│       └── TECHNICAL_DEBT.md   # Debt registry
├── AGENTS.md                   # This file — AI briefing document
├── SPEC.md                     # Full architecture reference & task list
├── project.yml                 # XcodeGen project definition
└── PetruVim/                   # Source root
    ├── main.swift
    ├── PetruVimApp.swift        (AppDelegate)
    ├── Info.plist
    ├── PetruVim.entitlements
    ├── Domain/
    │   ├── Models/              VimMode, TextBuffer, Motion, VimOperator, VimCommand, VimError
    │   ├── Ports/               TextElementPort, KeyboardPort, ClipboardPort, NotificationPort
    │   └── Engine/              CommandParser, MotionResolver, OperatorResolver, VimEngine
    ├── Application/             AppCoordinator, PermissionsManager, ExcludedAppsStore
    ├── Infrastructure/          AXTextElementAdapter, CGEventKeyboardAdapter, NSPasteboardAdapter, DistributedNotifAdapter
    └── Presentation/            MenuBarController, PermissionsView, SettingsView
```

## Conventions

- No sandbox — required for CGEventTap + AX write access
- No keyboard remapping — Accessibility API only
- `@MainActor` on `VimEngine` and `AppCoordinator` — never dispatch engine work to background threads
- `LSUIElement = YES` — menu bar only, no Dock icon
- Use `VimOperator` (not `Operator` — Swift keyword conflict)
- Error handling: throw `VimError`, don't return optionals from engine methods
- Always check `ExcludedAppsStore.shared` before processing a key event

## Context Files

| File                                  | Purpose                                               |
| ------------------------------------- | ----------------------------------------------------- |
| `.context/core/SESSION_STATUS.md`     | Current session state — read first every session      |
| `.context/core/ACTIVE_CONTEXT.md`     | Current focus: files in scope, requirements, approach |
| `.context/architecture/SYSTEM_MAP.md` | Detailed architecture, type names, notification flow  |
| `.context/quality/TECHNICAL_DEBT.md`  | Known issues and debt registry                        |

### How to use at session start

1. Read `.context/core/SESSION_STATUS.md` to understand current state
2. Read `.context/core/ACTIVE_CONTEXT.md` for current focus and scope
3. Check `SPEC.md` for the full task list
4. Pick up from "Next Session Priorities" in SESSION_STATUS.md

### How to use at session end

- Update `.context/core/SESSION_STATUS.md`: move completed tasks, add handoff notes, set date
- Update `.context/core/ACTIVE_CONTEXT.md` if scope changed
- Add any new debt to `.context/quality/TECHNICAL_DEBT.md`

## Current Focus

Manual integration testing (Task 12). All code is complete. Run `xcodegen generate`, open in Xcode,
resolve SPM packages (LaunchAtLogin-Modern), build and test in TextEdit.

## Important Notes

- Notification name: `com.petru.PetruVim.modeChange`, userInfo key `"mode"` → `"N"` / `"I"` / `"V"`
- `app as! AXUIElement` in `AXTextElementAdapter` is correct — Swift 6 requires `as!` for CFTypes (`as?` is a compile error)
- Synthetic undo/redo re-entrancy is handled via `isSendingSyntheticEvent` flag in `CGEventKeyboardAdapter`
- `MotionResolver.apply` accepts `visualAnchor: Int?` — pass it in visual mode to compute selection internally
- `@MainActor` is required on: `VimEngine`, `AppCoordinator`, `PermissionsManager`, `ExcludedAppsStore`, `MenuBarController`
