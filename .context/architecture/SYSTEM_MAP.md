# System Map

## Layer Overview

```
Domain (pure Swift — no UIKit/AppKit imports)
  Models:   VimMode · TextBuffer · Motion · VimOperator · VimCommand · VimError
  Ports:    TextElementPort · KeyboardPort · ClipboardPort · NotificationPort
  Engine:   CommandParser · MotionResolver · OperatorResolver · VimEngine (@MainActor)

Application
  AppCoordinator (@MainActor) · PermissionsManager · IncludedAppsStore

Infrastructure (implements Ports)
  AXTextElementAdapter    ← TextElementPort
  CGEventKeyboardAdapter  ← KeyboardPort
  NSPasteboardAdapter     ← ClipboardPort
  DistributedNotifAdapter ← NotificationPort

Presentation
  MenuBarController · PermissionsView · SettingsView
```

## Entry Point

`main.swift` creates `NSApplication.shared`, sets `AppDelegate` as delegate, calls `.run()`.
`AppDelegate.applicationDidFinishLaunching` creates and starts `AppCoordinator`.
`AppCoordinator` instantiates all adapters and creates `VimEngine`, injecting adapters via ports.

## Key Type Names

| Name | Notes |
|------|-------|
| `VimOperator` | Not `Operator` — avoids Swift keyword conflict |
| `InsertEntryPoint` | Enum: `i, a, I, A, o, O` |
| `KeyEvent.Modifiers` | OptionSet: `shift, control, option, command` |
| `IncludedAppsStore.shared` | Singleton — in-memory Set + UserDefaults persistence |
| `TextBuffer` | Holds `text: String`, `cursorOffset: Int`, `selection: Range<Int>?` |

## Notification Flow (mode changes)

```
VimEngine
  → DistributedNotifAdapter.postModeChange()
    → DistributedNotificationCenter.default().postNotificationName(...)
      → AppCoordinator observer
        → MenuBarController.updateMode()
```

- **Notification name:** `com.petru.PetruVim.modeChange`
- **UserInfo key:** `"mode"` → `"N"` / `"I"` / `"V"`

## CGEvent Tap

`CGEventKeyboardAdapter` installs a `.cgSessionEventTap` that intercepts all key-down events.
On each event, `preFilter` is checked first (installed by `AppCoordinator`); if it returns `true` the event passes through unchanged. Otherwise the event is forwarded to `VimEngine.handleKeyEvent(_:)` via the `KeyboardPort.onKeyEvent` callback.
Synthetic undo/redo are posted via `keyboard.postSyntheticEvent` using keyCode 6 (Z) with Cmd/Cmd-Shift.

## App Inclusion Flow

1. `AppCoordinator.startEngine()` installs `keyboard.preFilter` on `CGEventKeyboardAdapter` **before** `engine.start()`; also stores the mode-change observer token and removes any previous one
2. On every key-down, `preFilter` queries `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` inside `MainActor.assumeIsolated { }`
3. `IncludedAppsStore.shared.isBlocked(bundleID)` returns `true` if the app is NOT in the included list (and the list is non-empty); empty list → Vim active everywhere
4. If `isBlocked` returns `true`, `preFilter` returns `true` → event passes through unchanged; `VimEngine` never sees it
5. `SettingsView` lets users add running apps or remove entries from the inclusion list

## Permissions

`PermissionsManager` checks `AXIsProcessTrusted()` and prompts via `PermissionsView` (SwiftUI sheet)
if accessibility access is not granted. `AppCoordinator` polls until access is granted before
starting the event tap. `observePermissionChanges` runs indefinitely — it detects both grant and
subsequent revocation by tracking the last known state inside the poll loop.

## Visual Mode

- `VimEngine` stores `visualAnchor: Int` when entering visual mode via `v`
- On each motion, new cursor is computed; selection = `min(anchor, cursor)..<max(anchor, cursor)+1`
- `MotionResolver.apply` receives `visualAnchor:` and computes the selection internally
- Operators `d`/`c`/`y` in visual mode dispatch to `OperatorResolver.applyToVisualSelection`
