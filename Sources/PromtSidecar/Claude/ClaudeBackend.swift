import Foundation

protocol ClaudeBackend: Sendable {
    func review(text: String) async throws -> ReviewResult
}

enum ClaudeBackendError: Error, LocalizedError {
    case claudeNotFound
    case processFailed(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .claudeNotFound:
            return "Could not find `claude` CLI on PATH. Run `which claude` in Terminal to confirm install."
        case .processFailed(let s):
            return "claude exited with error: \(s)"
        case .parseError(let s):
            return "Could not parse Claude response — \(s)"
        }
    }
}
