import ApplicationServices
import AppKit
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
            NSLog("[PromtSidecar] FocusedFieldReader: no focused element (err=\(focusErr.rawValue))")
            return nil
        }
        let element = focusedElement as! AXUIElement

        let attrs: [String] = [
            kAXSelectedTextAttribute as String,
            kAXValueAttribute as String,
        ]
        for attr in attrs {
            var valueRef: AnyObject?
            let err = AXUIElementCopyAttributeValue(element, attr as CFString, &valueRef)
            if err == .success, let s = valueRef as? String {
                let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    NSLog("[PromtSidecar] FocusedFieldReader: got via \(attr) (\(trimmed.count) chars)")
                    return trimmed
                }
            }
        }

        if let pasteboardText = readViaClipboardSimulation() {
            NSLog("[PromtSidecar] FocusedFieldReader: got via clipboard fallback (\(pasteboardText.count) chars)")
            return pasteboardText
        }

        NSLog("[PromtSidecar] FocusedFieldReader: all paths failed")
        return nil
    }

    private static func readViaClipboardSimulation() -> String? {
        let pb = NSPasteboard.general
        let original = pb.string(forType: .string)

        let src = CGEventSource(stateID: .combinedSessionState)
        let cmdA_down = CGEvent(keyboardEventSource: src, virtualKey: 0x00, keyDown: true)
        cmdA_down?.flags = .maskCommand
        let cmdA_up = CGEvent(keyboardEventSource: src, virtualKey: 0x00, keyDown: false)
        cmdA_up?.flags = .maskCommand
        let cmdC_down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        cmdC_down?.flags = .maskCommand
        let cmdC_up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        cmdC_up?.flags = .maskCommand

        cmdA_down?.post(tap: .cghidEventTap)
        cmdA_up?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.05)
        cmdC_down?.post(tap: .cghidEventTap)
        cmdC_up?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.15)

        let captured = pb.string(forType: .string)

        if let original {
            pb.clearContents()
            pb.setString(original, forType: .string)
        }

        guard let captured, captured != original else { return nil }
        let trimmed = captured.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
