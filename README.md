# PromtSidecar

A macOS menu-bar app that reviews dictated prompts in a floating sidecar window — improved prompt + English correction notes — without polluting your Claude Code session.

Built for the Wispr Flow → Claude Code workflow. Dictate, double-tap Right Option, get a coaching review in the top-right of your screen, then re-dictate the better version.

## What It Does

- Watches for **double-tap Right Option** as a global hotkey.
- On trigger, reads the text in your currently focused input field via the macOS Accessibility API.
- Sends it to a local `claude` CLI subprocess (your Claude Max subscription, no API key needed) using Sonnet 4.6 with **all tools disabled** — pure chat, no shell, no file access.
- Returns a structured review: improved prompt + English mistakes (with *why* explanations).
- Renders in a floating, always-on-top NSPanel pinned to the top-right of your main screen.
- Maintains one conversation per local day (resumed via `--resume`) so Claude can learn your recurring English mistake patterns. Rotates at midnight.

## Requirements

- macOS 13+ (uses `MenuBarExtra`, NSPanel, AXUIElement APIs)
- **Full Xcode** (App Store) — Command Line Tools alone is not sufficient on macOS 26+ (see Toolchain Note below)
- `claude` CLI (Claude Code) installed and authenticated with a Claude Max subscription
  - Verify: `claude --version`

### Toolchain Note (macOS 26 / Tahoe)

On macOS 26 (Tahoe), Apple's Command Line Tools 16.2 ships a `PackageDescription` library whose `swiftinterface` and runtime dylib disagree on the `swiftLanguageVersions` parameter type — the linker fails with:

```
Undefined symbols: PackageDescription.Package.__allocating_init(... swiftLanguageVersions: [SwiftVersion]? ...)
```

Even a fresh `swift package init` template fails. Workarounds:

1. **Recommended:** install full Xcode from the App Store. Its bundled toolchain is internally consistent and `swift build` works.
2. Or install a newer CLT manually from <https://developer.apple.com/download/all/> matching macOS 26.
3. Or install a swift.org toolchain via [`swiftly`](https://www.swift.org/install/) and use that instead of the CLT one.

Once you have a working toolchain, run `./bundle.sh`.

## Build

```bash
./bundle.sh
```

This runs `swift build -c release` and wraps the binary into `build/PromtSidecar.app`.

For a stable Accessibility permission grant, move the app to `~/Applications`:

```bash
mv build/PromtSidecar.app ~/Applications/
open ~/Applications/PromtSidecar.app
```

## First Launch

1. macOS will block global hotkey/AX reading until you grant permission.
2. **System Settings → Privacy & Security → Accessibility** → toggle on `PromtSidecar`.
3. Quit and relaunch the app. Menu bar should show a `text.bubble` icon.

## Usage

1. Dictate (or type) a prompt into any focused text field — the Claude Code chatbox, TextEdit, anywhere with a normal text input.
2. **Double-tap Right Option** within ~300ms.
3. The review panel appears at the top-right of your screen with:
   - **Improved prompt** (with copy button)
   - **English notes** (your mistake → suggested fix → why)
4. Re-dictate the better version manually. Click anywhere outside the panel or press `Esc` to dismiss.

## Configuration

For now, settings are hardcoded in source:

- **Model:** `claude-sonnet-4-6` ([Claude/ClaudeOneShotBackend.swift](Sources/PromtSidecar/Claude/ClaudeOneShotBackend.swift))
- **Hotkey:** Double-tap Right Option, 300ms window ([Hotkey/HotkeyMonitor.swift](Sources/PromtSidecar/Hotkey/HotkeyMonitor.swift))
- **System prompt:** [Claude/SystemPrompt.swift](Sources/PromtSidecar/Claude/SystemPrompt.swift)

A settings UI is planned for v2.

## Development

Open `Package.swift` in Xcode (when installed) — Xcode reads SPM packages natively. Or use any Swift-aware editor; build from CLI:

```bash
swift build           # debug build
swift build -c release
```

The executable is at `.build/debug/PromtSidecar` or `.build/release/PromtSidecar`. Running this raw binary won't satisfy macOS's Accessibility permission requirements — always launch via the `.app` bundle from `bundle.sh`.

## Architecture

```
[Right Option pressed twice within 300ms]
        ↓ (NSEvent global flagsChanged monitor)
[FocusedFieldReader reads kAXValueAttribute via AXUIElementCreateSystemWide]
        ↓
[ClaudeSession.ensureFreshDay rotates if local date changed]
        ↓
[ClaudeOneShotBackend spawns: claude -p <prompt> --tools "" --model claude-sonnet-4-6 --output-format json [--resume <id>]]
        ↓
[Parses JSON envelope, extracts result + session_id, persists session_id to UserDefaults]
        ↓
[ReviewPanelController shows NSPanel at top-right with ReviewView]
        ↓
[Esc or click-away dismisses]
```

## Known Limitations

- **Claude Code's Electron input box may not expose `kAXValueAttribute`.** If capture from Claude Code itself doesn't work, a clipboard-based fallback is on the roadmap. Capture from native fields (TextEdit, Cursor, terminal) works.
- **~1-2s spawn cost per trigger.** The `claude` CLI long-running stream-json mode is undocumented; I picked the safe documented path. If Anthropic documents persistent stream-json, this can drop to ~300ms.
- **No code signing certificate** — the bundle is ad-hoc signed. Fine for personal use, will trigger Gatekeeper warnings if redistributed.
- **No auto-launch at login yet** — add manually via System Settings → Login Items, or wait for v2.

## Safety Note

The `claude` subprocess runs with `--tools ""` which disables ALL built-in tools (Bash, Read, Write, Edit, WebSearch, etc.). It can only return text. This is a load-bearing safety guarantee: even if the system prompt is hijacked by user input, the subprocess cannot run shell commands or touch your filesystem. Do not remove this flag.

## License

MIT — see [LICENSE](LICENSE).
