# PetruVim

A macOS menu bar app that brings system-wide Vim keybindings to any focused text field — without keyboard remapping.

## Overview

PetruVim intercepts key events via the macOS Accessibility API (AXUIElement) and translates them into cursor movements and text edits in whatever app is currently focused. It works in any standard text field: TextEdit, Terminal, Safari address bar, Xcode, and more. No input method switching, no keyboard remapping, no per-app configuration required.

Inspired by [kindaVim](https://kindavim.app/).

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Accessibility permission (prompted on first launch)

## Getting Started

```bash
# 1. Generate the Xcode project
xcodegen generate

# 2. Open in Xcode
open PetruVim.xcodeproj

# 3. Resolve Swift Package Manager dependencies
# File → Packages → Resolve Package Versions

# 4. Build and run (Cmd-R)
```

On first launch, macOS will prompt for Accessibility permission. Grant it in **System Settings → Privacy & Security → Accessibility**. PetruVim cannot function without it.

## Features

- **Normal, Insert, and Visual modes** — full mode-switching with status indicator in the menu bar
- **Motions** — `h j k l`, `w b e W B E`, `0 ^ $`, `gg G`, `f/F/t/T{char}`, count prefixes (e.g. `3w`, `5j`)
- **Operators** — `d` (delete), `c` (change), `y` (yank), with motion or line (`dd`, `yy`, `cc`)
- **Insert entry points** — `i a I A o O`
- **Visual mode** — `v` to enter, motions to extend selection, `d/c/y` to operate
- **Standalone commands** — `x` (delete char), `p/P` (paste), `u` (undo), `Ctrl-R` (redo), `.` (repeat)
- **App exclusion** — exclude specific apps via Settings so their native keybindings are unaffected
- **Launch at login** — optional, configurable from the menu bar

## Keybinding Reference

### Normal Mode — Motions

| Key | Motion |
|-----|--------|
| `h` / `l` | Character left / right |
| `j` / `k` | Line down / up |
| `w` / `W` | Word forward (word / WORD) |
| `b` / `B` | Word backward (word / WORD) |
| `e` / `E` | Word end (word / WORD) |
| `0` | Line start |
| `^` | First non-blank character |
| `$` | Line end |
| `gg` | File start |
| `G` | File end |
| `f{char}` | Find character forward |
| `F{char}` | Find character backward |
| `t{char}` | Till character forward |
| `T{char}` | Till character backward |

All motions accept a count prefix: `3w`, `10j`, `2f,`.

### Normal Mode — Operators

| Key | Action |
|-----|--------|
| `d{motion}` | Delete |
| `dd` | Delete line |
| `c{motion}` | Change (delete + enter Insert) |
| `cc` | Change line |
| `y{motion}` | Yank (copy) |
| `yy` | Yank line |
| `x` | Delete character under cursor |
| `p` | Paste after cursor |
| `P` | Paste before cursor |
| `u` | Undo |
| `Ctrl-R` | Redo |
| `.` | Repeat last change |

### Mode Switching

| Key | Action |
|-----|--------|
| `i` | Insert before cursor |
| `a` | Insert after cursor |
| `I` | Insert at line start |
| `A` | Insert at line end |
| `o` | Open new line below, enter Insert |
| `O` | Open new line above, enter Insert |
| `v` | Enter Visual mode |
| `Esc` | Return to Normal mode |

### Visual Mode

| Key | Action |
|-----|--------|
| (any motion) | Extend selection |
| `d` | Delete selection |
| `c` | Change selection (enter Insert) |
| `y` | Yank selection |
| `Esc` | Return to Normal mode |

## Architecture

PetruVim follows hexagonal (ports & adapters) architecture. The domain core is pure Swift with no AppKit dependency.

```
Domain (pure Swift)
  Models:   VimMode · TextBuffer · Motion · VimOperator · VimCommand · VimError
  Ports:    TextElementPort · KeyboardPort · ClipboardPort · NotificationPort
  Engine:   CommandParser · MotionResolver · OperatorResolver · VimEngine

Application
  AppCoordinator · PermissionsManager · ExcludedAppsStore

Infrastructure (implements Ports)
  AXTextElementAdapter    ← TextElementPort
  CGEventKeyboardAdapter  ← KeyboardPort
  NSPasteboardAdapter     ← ClipboardPort
  DistributedNotifAdapter ← NotificationPort

Presentation
  MenuBarController · PermissionsView · SettingsView
```

### How It Works

1. `CGEventKeyboardAdapter` installs a `.cgSessionEventTap` that intercepts all key-down events system-wide.
2. A pre-filter in `AppCoordinator` checks the frontmost app against the exclusion list — excluded apps receive their keystrokes unchanged.
3. Eligible events are forwarded to `VimEngine.handleKeyEvent(_:)`, which runs `CommandParser` to build a `VimCommand`.
4. `MotionResolver` or `OperatorResolver` computes the resulting `TextBuffer` (new cursor/selection/text).
5. `AXTextElementAdapter` writes the result back to the focused element via the Accessibility API.
6. Mode changes are broadcast via `DistributedNotificationCenter` and reflected in the menu bar icon.

## Project Structure

```
PetruVim/
├── project.yml                 # XcodeGen project definition
├── SPEC.md                     # Full architecture reference & task list
├── AGENTS.md                   # AI session briefing
├── .context/                   # AI session context files
└── PetruVim/
    ├── main.swift
    ├── PetruVimApp.swift        # AppDelegate
    ├── Domain/
    │   ├── Models/              # VimMode, TextBuffer, Motion, VimOperator, VimCommand, VimError
    │   ├── Ports/               # TextElementPort, KeyboardPort, ClipboardPort, NotificationPort
    │   └── Engine/              # CommandParser, MotionResolver, OperatorResolver, VimEngine
    ├── Application/             # AppCoordinator, PermissionsManager, ExcludedAppsStore
    ├── Infrastructure/          # AXTextElementAdapter, CGEventKeyboardAdapter, NSPasteboardAdapter, DistributedNotifAdapter
    └── Presentation/            # MenuBarController, PermissionsView, SettingsView
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern) | Launch at login toggle |

## Testing

The test suite covers `CommandParser`, `MotionResolver`, `OperatorResolver`, and `VimEngine` with 159 unit tests.

```bash
# Run tests in Xcode: Cmd-U
# Or via xcodebuild:
xcodebuild test -scheme PetruVim -destination 'platform=macOS'
```

## Notes

- **No sandbox** — required for `CGEventTap` and Accessibility write access.
- **No keyboard remapping** — all edits go through the Accessibility API.
- Undo/redo are implemented by posting synthetic `Cmd-Z` / `Cmd-Shift-Z` events at the `.cghidEventTap` level, which bypasses the session tap and avoids re-entrancy.
- `VimEngine` and `AppCoordinator` are `@MainActor` — never dispatch engine work to background threads.
- Mode change notifications use the name `com.petru.PetruVim.modeChange` with userInfo key `"mode"` → `"N"` / `"I"` / `"V"`.

## License

MIT
