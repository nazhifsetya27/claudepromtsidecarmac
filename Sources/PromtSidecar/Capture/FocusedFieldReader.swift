import ApplicationServices
import Foundation

enum FocusedFieldReader {
    static func readFocusedFieldValue() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedElementRef: AnyObject?
        let focusErr = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )
        guard focusErr == .success, let focusedElement = focusedElementRef else {
            return nil
        }
        let element = focusedElement as! AXUIElement

        var valueRef: AnyObject?
        let valueErr = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &valueRef
        )
        guard valueErr == .success, let value = valueRef as? String else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
