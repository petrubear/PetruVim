# PetruVim — Implementation Spec

## Context

PetruVim mirrors the core functionality of kindaVim: a macOS menu bar app that provides
system-wide Vim keybindings by reading and writing text in any focused text field via the
macOS Accessibility API (AXUIElement).

**Constraints:**
- Swift only, macOS 14+
- Hexagonal (ports & adapters) architecture
- Simple, readable code — no over-engineering
- No keyboard remapping strategy (Accessibility API only)
- SPM packages allowed where they reduce complexity
- Open source / personal use, no sandbox

---

## Implementation Tasks

| # | Status | Scope |
|---|--------|-------|
| 1 | ✅ | Project scaffold: `project.yml`, `Info.plist`, entitlements, `PetruVimApp.swift` |
| 2 | ✅ | Domain models: `VimMode`, `TextBuffer`, `Motion`, `Operator`, `VimCommand`, `VimError` |
| 3 | ✅ | Domain ports: `TextElementPort`, `KeyboardPort`, `ClipboardPort`, `NotificationPort` |
| 4 | ✅ | `MotionResolver` (all 20 motions: h/l/j/k, w/b/e/W/B/E, 0/$/_/^, gg/G, f/F/t/T) |
| 5 | ✅ | `OperatorResolver` (delete/change/yank/deleteChar/paste, line + visual variants) |
| 6 | ✅ | `CommandParser` (count accumulation, dd/cc/yy, gg, f/F/t/T char awaiting) |
| 7 | ✅ | `VimEngine` (@MainActor state machine, mode transitions, clipboard sync, undo/redo) |
| 8 | ✅ | Infrastructure adapters: `AXTextElementAdapter`, `CGEventKeyboardAdapter`, `NSPasteboardAdapter`, `DistributedNotifAdapter` |
| 9 | ✅ | `AppCoordinator`, `PermissionsManager`, `MenuBarController`, `PermissionsView` |
| 10 | ✅ | Visual mode: extend selection with motions, `d/c/y` on selection |
| 11 | ✅ | Generate Xcode project from `project.yml` via XcodeGen and verify compile |
| 12 | ⬜ | Manual integration testing on real macOS apps |
| 13 | ✅ | SPM packages: LaunchAtLogin-Modern (added + wired in SettingsView); Defaults/swift-log deferred |
| 14 | ✅ | Repeat `.` operator: track lastChange and replay |
| 15 | ✅ | Count prefix support for all motions/operators |

---

## MVP Feature Set

**Modes:** Normal, Insert, Visual (characterwise)

**Motions:** `h j k l` · `w b e W B E` · `0 $ ^ _` · `gg G` · `f F t T {char}`

**Operators:** `d` delete · `c` change · `y` yank · `x` delete char · `p P` paste · `u` undo · `Ctrl-R` redo · `.` repeat

**Mode entry/exit:** `ESC` → Normal · `i a I A o O` → Insert · `v` → Visual

**Visual:** extend with motions, apply `d/c/y` on selection

---

## Architecture

### Hexagonal Layers

```
Domain (pure Swift, no frameworks)
  Models:    VimMode, TextBuffer, Motion, Operator, VimCommand
  Ports:     TextElementPort, KeyboardPort, ClipboardPort, NotificationPort
  Engine:    CommandParser, MotionResolver, OperatorResolver, VimEngine

Application (wiring)
  AppCoordinator, PermissionsManager

Infrastructure (adapters)
  AXTextElementAdapter     ← TextElementPort
  CGEventKeyboardAdapter   ← KeyboardPort
  NSPasteboardAdapter      ← ClipboardPort
  DistributedNotifAdapter  ← NotificationPort

Presentation
  MenuBarController (NSStatusItem showing N/I/V)
  PermissionsView (SwiftUI onboarding)
```

---

## File Structure

```
PetruVim/
├── SPEC.md
├── project.yml
├── PetruVim/
│   ├── PetruVimApp.swift
│   ├── Info.plist
│   ├── PetruVim.entitlements
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── VimMode.swift
│   │   │   ├── TextBuffer.swift
│   │   │   ├── Motion.swift
│   │   │   ├── Operator.swift
│   │   │   ├── VimCommand.swift
│   │   │   └── VimError.swift
│   │   ├── Ports/
│   │   │   ├── TextElementPort.swift
│   │   │   ├── KeyboardPort.swift
│   │   │   ├── ClipboardPort.swift
│   │   │   └── NotificationPort.swift
│   │   └── Engine/
│   │       ├── CommandParser.swift
│   │       ├── MotionResolver.swift
│   │       ├── OperatorResolver.swift
│   │       └── VimEngine.swift
│   ├── Application/
│   │   ├── AppCoordinator.swift
│   │   ├── ExcludedAppsStore.swift
│   │   └── PermissionsManager.swift
│   ├── Infrastructure/
│   │   ├── AXTextElementAdapter.swift
│   │   ├── CGEventKeyboardAdapter.swift
│   │   ├── NSPasteboardAdapter.swift
│   │   └── DistributedNotifAdapter.swift
│   └── Presentation/
│       ├── MenuBarController.swift
│       ├── PermissionsView.swift
│       └── SettingsView.swift
└── PetruVimTests/
    ├── CommandParserTests.swift
    ├── ModeTransitionTests.swift
    ├── MotionResolverTests.swift
    ├── OperatorResolverTests.swift
    ├── VimEngineTests.swift
    └── Mocks/
        ├── MockTextElement.swift
        ├── MockClipboard.swift
        └── MockKeyboard.swift
```

---

## Key Domain Types

### TextBuffer
```swift
struct TextBuffer: Equatable {
    var text: String
    var cursorIndex: String.Index          // position of cursor (before char)
    var selectionRange: Range<String.Index>?

    // Test convenience: Int-based init
    init(_ text: String, cursor: Int, selection: Range<Int>? = nil)

    var cursorOffset: Int
    var currentChar: Character?
    var currentLine: Substring
}
```

### VimCommand
```swift
enum VimCommand: Equatable {
    case motion(count: Int, Motion)
    case operatorMotion(count: Int, Operator, Motion)
    case operatorLine(count: Int, Operator)       // dd / yy / cc
    case operatorVisual(Operator)                  // d/c/y on visual selection
    case enterInsert(InsertEntryPoint)             // i/a/I/A/o/O
    case enterVisual
    case exitToNormal
    case standalone(count: Int, Operator)          // x, p, P, u, Ctrl-R, .
}
```

### Motion enum
```swift
enum Motion: Equatable {
    case left, right, up, down
    case wordForward, wordBackward, wordEnd
    case wordForwardBig, wordBackwardBig, wordEndBig
    case lineStart, lineEnd, lineFirstNonBlank, lineDown
    case fileStart, fileEnd
    case findForward(Character), findBackward(Character)
    case tillForward(Character), tillBackward(Character)
}
```

### Operator enum
```swift
enum VimOperator: Equatable {
    case delete, change, yank
    case deleteChar        // x
    case paste(before: Bool)  // p / P
    case undo, redo
    case repeatLast
}
```

---

## Key Behaviours

### CommandParser state machine
- Digits accumulate a count prefix
- `d/c/y` set pending operator; second of same → `operatorLine`
- `g` buffers; second `g` → `motion(.fileStart)`
- `f/F/t/T` set an `awaitingChar` closure for next keystroke
- All Normal/Visual keys are suppressed from the host app (return `true`)
- Command/Option modified keys always pass through (never intercepted)

### VimEngine (@MainActor)
1. Normal/Visual: feed event to parser → on complete command: `updateFocusedElement { transform }` (single read+write on same element) → update register/lastChange → post mode notification
2. Insert: all keys pass through; on ESC record `insertedText` → transition to Normal
3. Undo/Redo: synthesize Cmd-Z / Cmd-Shift-Z as CGEvents and post them
4. Yank/delete syncs unnamed register to NSPasteboard on every operation

### AXTextElementAdapter
- Walk: `AXUIElementCreateSystemWide` → `kAXFocusedApplicationAttribute` → `kAXFocusedUIElementAttribute`
- Only act on `kAXTextFieldRole` or `kAXTextAreaRole`
- Read/write `kAXValueAttribute` + `kAXSelectedTextRangeAttribute`

### CGEventKeyboardAdapter
- Tap at `.cgSessionEventTap`, `.headInsertEventTap`
- RunLoop source added to `CFRunLoopGetMain()`
- Return `nil` to suppress, return event to pass through

---

## Event Flow (example: `dw`)

```
User presses 'd'
  → CGEventKeyboardAdapter: constructs KeyEvent, calls onKeyEvent
  → VimEngine.handleCommandMode
  → CommandParser: pendingOperator = .delete, returns nil
  → engine returns true (suppress 'd')

User presses 'w'
  → CommandParser: returns .operatorMotion(count:1, .delete, .wordForward)
  → VimEngine: updateFocusedElement { buffer → OperatorResolver.apply(.delete, .wordForward, …) }
  → clipboard.write(yankedText)
  → notifications.postModeChange(.normal)
  → returns true (suppress 'w')
```

---

## Testing Strategy

Unit tests (no AX/CGEvent needed) — all Domain layer:
```swift
// MotionResolverTests
let buf = TextBuffer("hello world", cursor: 2)
let result = MotionResolver.apply(.wordForward, count: 1, to: buf)
XCTAssertEqual(result.cursorOffset, 6)

// OperatorResolverTests
let result = OperatorResolver.apply(.delete, motion: .wordForward, count: 1,
                                    buffer: buf, register: nil, lastChange: nil)
XCTAssertEqual(result.buffer.text, "world")
XCTAssertEqual(result.yankedText, "hello ")

// CommandParserTests
_ = parser.feed(dKeyEvent, mode: .normal)
let cmd = parser.feed(dKeyEvent, mode: .normal)
XCTAssertEqual(cmd, .operatorLine(count: 1, .delete))
```

Mock adapters (`MockTextElement`, `MockClipboard`) for `VimEngineTests`.

Not unit-tested: `AXTextElementAdapter`, `CGEventKeyboardAdapter`, `MenuBarController`.

---

## SPM Packages

| Package | Status | Purpose |
|---------|--------|---------|
| LaunchAtLogin-Modern (Sindre Sorhus) | ✅ Added | Launch-at-login toggle in SettingsView |
| Defaults (Sindre Sorhus) | Deferred | Typed UserDefaults (UserDefaults works fine for now) |
| swift-log (Apple) | Deferred | Structured logging |
