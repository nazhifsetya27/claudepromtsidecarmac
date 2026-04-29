import AppKit

@MainActor
final class HotkeyMonitor {
    private let onTrigger: () -> Void
    private var globalMonitor: Any?
    private var lastPressAt: Date?
    private var rightCommandHeld = false

    private let doubleTapWindow: TimeInterval = 0.3
    private let rightCommandKeyCode: UInt16 = 0x36

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = event.keyCode
            let commandFlag = event.modifierFlags.contains(.command)
            Task { @MainActor in
                self?.handle(keyCode: keyCode, commandFlag: commandFlag)
            }
        }
    }

    func stop() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }

    private func handle(keyCode: UInt16, commandFlag: Bool) {
        NSLog("[PromtSidecar] flagsChanged keyCode=0x%X cmdFlag=%d", keyCode, commandFlag ? 1 : 0)
        guard keyCode == rightCommandKeyCode else { return }

        if commandFlag && !rightCommandHeld {
            rightCommandHeld = true
            let now = Date()
            if let last = lastPressAt, now.timeIntervalSince(last) <= doubleTapWindow {
                lastPressAt = nil
                onTrigger()
            } else {
                lastPressAt = now
            }
        } else if !commandFlag && rightCommandHeld {
            rightCommandHeld = false
        }
    }
}
