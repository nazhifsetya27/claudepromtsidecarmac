import SwiftUI
import AppKit
import ApplicationServices

@main
struct PromtSidecarApp: App {
    @StateObject private var manager = AppManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(manager: manager)
        } label: {
            Text("PS")
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var manager: AppManager

    var body: some View {
        Text(manager.statusText)
            .font(.caption)
            .foregroundStyle(.secondary)
        Divider()
        Button("Test review (paste from clipboard)") {
            Task { await manager.testFromClipboard() }
        }
        Button("Open Accessibility settings") {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
        Divider()
        Button("Quit PromtSidecar") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

@MainActor
final class AppManager: ObservableObject {
    @Published var statusText: String = "Initializing…"

    private var hotkeyMonitor: HotkeyMonitor?
    private let panelController = ReviewPanelController()
    private let backend: ClaudeBackend = ClaudeOneShotBackend()

    init() {
        NSLog("[PromtSidecar] AppManager.init")
        ensureAccessibilityPermission()

        hotkeyMonitor = HotkeyMonitor { [weak self] in
            NSLog("[PromtSidecar] Hotkey trigger fired")
            Task { @MainActor in
                await self?.handleTrigger()
            }
        }
        hotkeyMonitor?.start()

        statusText = "Ready — double-tap Right Command"
        NSLog("[PromtSidecar] Setup complete; statusText=\(statusText)")
    }

    private func ensureAccessibilityPermission() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        NSLog("[PromtSidecar] AX trusted=\(trusted)")
        if !trusted {
            statusText = "Grant Accessibility, then relaunch"
        }
    }

    private func handleTrigger() async {
        NSLog("[PromtSidecar] handleTrigger entered")
        guard let text = FocusedFieldReader.readFocusedFieldValue(), text.count >= 8 else {
            statusText = "No text in focused field"
            NSLog("[PromtSidecar] No focused text or too short")
            return
        }
        await runReview(text: text)
    }

    func testFromClipboard() async {
        NSLog("[PromtSidecar] testFromClipboard entered")
        guard let text = NSPasteboard.general.string(forType: .string), text.count >= 8 else {
            statusText = "Clipboard empty / too short"
            NSLog("[PromtSidecar] Clipboard empty or too short")
            return
        }
        await runReview(text: text)
    }

    private func runReview(text: String) async {
        NSLog("[PromtSidecar] runReview start (chars=\(text.count))")
        statusText = "Reviewing…"
        panelController.showLoading()
        do {
            let result = try await backend.review(text: text)
            NSLog("[PromtSidecar] Review success: looksGood=\(result.looksGood) notes=\(result.englishNotes.count)")
            panelController.show(result: result, original: text)
            statusText = "Ready — double-tap Right Command"
        } catch {
            NSLog("[PromtSidecar] Review error: \(error.localizedDescription)")
            panelController.showError(error.localizedDescription)
            statusText = "Error"
        }
    }
}
