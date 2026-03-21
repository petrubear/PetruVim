import Cocoa
import ApplicationServices

final class AXTextElementAdapter: TextElementPort {
    func readFocusedElement() throws -> TextBuffer {
        let systemElement = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              focusedApp != nil else {
            throw VimError.noFocusedElement
        }
        let app = focusedApp as! AXUIElement

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              focusedElement != nil else {
            throw VimError.noFocusedElement
        }
        let axElement = focusedElement as! AXUIElement

        // Check role
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleValue)
        guard let role = roleValue as? String,
              role == kAXTextFieldRole || role == kAXTextAreaRole else {
            throw VimError.unsupportedElementRole
        }

        // Read value
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXValueAttribute as CFString, &valueRef) == .success,
              let text = valueRef as? String else {
            throw VimError.accessibilityReadFailed
        }

        // Read selected text range
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              rangeRef != nil else {
            throw VimError.accessibilityReadFailed
        }

        var cfRange = CFRange()
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &cfRange) else {
            throw VimError.accessibilityReadFailed
        }

        let cursorOffset = cfRange.location
        let clampedOffset = min(max(cursorOffset, 0), text.count)
        let cursorIndex = text.index(text.startIndex, offsetBy: clampedOffset)

        return TextBuffer(text: text, cursorIndex: cursorIndex)
    }

    func writeFocusedElement(_ buffer: TextBuffer) throws {
        let systemElement = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success,
              focusedApp != nil else {
            throw VimError.noFocusedElement
        }
        let app = focusedApp as! AXUIElement

        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              focusedElement != nil else {
            throw VimError.noFocusedElement
        }
        let axElement = focusedElement as! AXUIElement

        // Write value
        guard AXUIElementSetAttributeValue(axElement, kAXValueAttribute as CFString, buffer.text as CFString) == .success else {
            throw VimError.accessibilityWriteFailed
        }

        // Write cursor position or visual selection range
        let location: Int
        let length: Int
        if let sel = buffer.selectionRange {
            location = buffer.text.distance(from: buffer.text.startIndex, to: sel.lowerBound)
            length   = buffer.text.distance(from: sel.lowerBound, to: sel.upperBound)
        } else {
            location = buffer.cursorOffset
            length   = 0
        }
        var cfRange = CFRange(location: location, length: length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            throw VimError.accessibilityWriteFailed
        }

        guard AXUIElementSetAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, rangeValue) == .success else {
            throw VimError.accessibilityWriteFailed
        }
    }
}
