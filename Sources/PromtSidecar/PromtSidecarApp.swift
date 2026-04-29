import SwiftUI
import AppKit
import ApplicationServices

@main
struct PromtSidecarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading) {
                Text(appDelegate.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            Divider()
            Button("Test review (paste from clipboard)") {
                Task { await appDelegate.testFromClipboard() }
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
        } label: {
            Image(systemName: "text.bubble")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var statusText: String = "Idle"

    private var hotkeyMonitor: HotkeyMonitor?
    private var panelController: ReviewPanelController?
    private let backend: ClaudeBackend = ClaudeOneShotBackend()

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureAccessibilityPermission()
        panelController = ReviewPanelController()

        hotkeyMonitor = HotkeyMonitor { [weak self] in
            Task { @MainActor in
                await self?.handleTrigger()
            }
        }
        hotkeyMonitor?.start()

        statusText = "Ready — double-tap Right Option"
    }

    private func ensureAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts = [key: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        if !trusted {
            statusText = "Grant Accessibility, then relaunch"
        }
    }

    private func handleTrigger() async {
        guard let text = FocusedFieldReader.readFocusedFieldValue(), text.count >= 8 else {
            statusText = "No text in focused field"
            return
        }
        await runReview(text: text)
    }

    func testFromClipboard() async {
        guard let text = NSPasteboard.general.string(forType: .string), text.count >= 8 else {
            statusText = "Clipboard empty / too short"
            return
        }
        await runReview(text: text)
    }

    private func runReview(text: String) async {
        statusText = "Reviewing…"
        panelController?.showLoading()
        do {
            let result = try await backend.review(text: text)
            panelController?.show(result: result, original: text)
            statusText = "Idle"
        } catch {
            panelController?.showError(error.localizedDescription)
            statusText = "Error"
        }
    }
}
