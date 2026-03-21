# System Map

## Layer Overview

```
Domain (pure Swift — no UIKit/AppKit imports)
  Models:   VimMode · TextBuffer · Motion · VimOperator · VimCommand · VimError
  Ports:    TextElementPort · KeyboardPort · ClipboardPort · NotificationPort
  Engine:   CommandParser · MotionResolver · OperatorResolver · VimEngine (@MainActor)

Application
  AppCoordinator (@MainActor) · PermissionsManager · ExcludedAppsStore

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
| `ExcludedAppsStore.shared` | Singleton — in-memory Set + UserDefaults persistence |
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
Events are forwarded to `VimEngine.handleKeyEvent(_:)` via the `KeyboardPort.onKeyEvent` callback.
Synthetic undo/redo are posted via `keyboard.postSyntheticEvent` using keyCode 6 (Z) with Cmd/Cmd-Shift.

## App Exclusion Flow

1. `VimEngine.handleKeyEvent` queries `NSWorkspace.shared.frontmostApplication?.bundleIdentifier`
2. If the bundle ID is in `ExcludedAppsStore.shared.excludedBundleIDs`, return `false` (pass-through)
3. `SettingsView` lets users add running apps or remove entries from the exclusion list

## Permissions

`PermissionsManager` checks `AXIsProcessTrusted()` and prompts via `PermissionsView` (SwiftUI sheet)
if accessibility access is not granted. `AppCoordinator` polls until access is granted before
starting the event tap.

## Visual Mode (Planned)

- `VimEngine` stores `visualAnchor: Int` when entering visual mode via `v`
- On each motion, new cursor is computed; selection = `min(anchor, cursor)..<max(anchor, cursor)+1`
- `TextBuffer.selection` is set accordingly on every visual mode key event
- Operators `d`/`c`/`y` in visual mode read `TextBuffer.selection` instead of a motion range
