import AppKit

@MainActor
final class HotkeyMonitor {
    private let onTrigger: () -> Void
    private var globalMonitor: Any?
    private var lastPressAt: Date?
    private var rightOptionHeld = false

    private let doubleTapWindow: TimeInterval = 0.3
    private let rightOptionKeyCode: UInt16 = 0x3D

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let keyCode = event.keyCode
            let optionFlag = event.modifierFlags.contains(.option)
            Task { @MainActor in
                self?.handle(keyCode: keyCode, optionFlag: optionFlag)
            }
        }
    }

    func stop() {
        if let m = globalMonitor {
            NSEvent.removeMonitor(m)
            globalMonitor = nil
        }
    }

    private func handle(keyCode: UInt16, optionFlag: Bool) {
        guard keyCode == rightOptionKeyCode else { return }

        if optionFlag && !rightOptionHeld {
            rightOptionHeld = true
            let now = Date()
            if let last = lastPressAt, now.timeIntervalSince(last) <= doubleTapWindow {
                lastPressAt = nil
                onTrigger()
            } else {
                lastPressAt = now
            }
        } else if !optionFlag && rightOptionHeld {
            rightOptionHeld = false
        }
    }
}
