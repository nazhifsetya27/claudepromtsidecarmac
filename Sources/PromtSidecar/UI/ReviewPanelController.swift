import AppKit
import SwiftUI

@MainActor
final class ReviewPanelController {
    private var panel: ReviewPanel?
    private var clickAwayMonitor: Any?

    func showLoading() {
        present(content: AnyView(LoadingView()))
    }

    func showError(_ message: String) {
        present(content: AnyView(ErrorView(message: message)))
    }

    func show(result: ReviewResult, original: String) {
        let halfScreen = (NSScreen.main?.visibleFrame.height ?? 1000) / 2
        let view = ReviewView(result: result, original: original, maxHeight: halfScreen) { [weak self] text in
            self?.copy(text)
        }
        present(content: AnyView(view))
    }

    func hide() {
        panel?.orderOut(nil)
        removeClickAwayMonitor()
    }

    private func present(content: AnyView) {
        let hosting = NSHostingController(rootView: content)
        if panel == nil {
            let initialRect = NSRect(x: 0, y: 0, width: 480, height: 100)
            panel = ReviewPanel(contentRect: initialRect)
        }
        panel?.contentViewController = hosting
        hosting.view.layoutSubtreeIfNeeded()

        let fitting = hosting.view.fittingSize
        if fitting.height > 0 {
            panel?.setContentSize(NSSize(width: 480, height: fitting.height))
        }

        positionTopRight()
        panel?.makeKeyAndOrderFront(nil)
        installClickAwayMonitor()
    }

    private func positionTopRight() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let topLeftX = visible.maxX - panel.frame.width - margin
        let topLeftY = visible.maxY - margin
        panel.setFrameTopLeftPoint(NSPoint(x: topLeftX, y: topLeftY))
    }

    private func installClickAwayMonitor() {
        removeClickAwayMonitor()
        clickAwayMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    private func removeClickAwayMonitor() {
        if let m = clickAwayMonitor {
            NSEvent.removeMonitor(m)
            clickAwayMonitor = nil
        }
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct LoadingView: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text("Reviewing your prompt…")
                .font(.subheadline)
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
    }
}

private struct ErrorView: View {
    let message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Review failed", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.headline)
            Text(message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 480, alignment: .topLeading)
    }
}
