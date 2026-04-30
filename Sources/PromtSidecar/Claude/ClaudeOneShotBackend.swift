import Foundation

final class ClaudeOneShotBackend: ClaudeBackend {
    private let model = "claude-haiku-4-5-20251001"

    func review(text: String) async throws -> ReviewResult {
        do {
            return try await runOnce(text: text, useResume: true)
        } catch ClaudeBackendError.processFailed(let msg) where msg.contains("No conversation found") {
            ClaudeSession.sessionId = nil
            return try await runOnce(text: text, useResume: false)
        }
    }

    private func runOnce(text: String, useResume: Bool) async throws -> ReviewResult {
        ClaudeSession.ensureFreshDay()
        let resumeId = useResume ? ClaudeSession.sessionId : nil

        let prompt = SystemPrompt.render(text: text)
        let claudePath = try locateClaudeBinary()

        var args: [String] = [
            "-p", prompt,
            "--tools", "",
            "--model", model,
            "--output-format", "json",
        ]
        if let resumeId {
            args.append(contentsOf: ["--resume", resumeId])
        }

        let (stdoutData, stderrData, status) = try await runProcess(path: claudePath, args: args)

        guard status == 0 else {
            let errStr = String(data: stderrData, encoding: .utf8) ?? "exit \(status)"
            throw ClaudeBackendError.processFailed(errStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let envelope: ClaudeEnvelope
        do {
            envelope = try JSONDecoder().decode(ClaudeEnvelope.self, from: stdoutData)
        } catch {
            let preview = String(data: stdoutData, encoding: .utf8)?.prefix(300) ?? "<non-utf8>"
            throw ClaudeBackendError.parseError("envelope decode failed (\(error.localizedDescription)). Raw: \(preview)")
        }

        if let newId = envelope.sessionId {
            ClaudeSession.setSessionId(newId)
        }

        let cleaned = stripCodeFences(envelope.result.trimmingCharacters(in: .whitespacesAndNewlines))
        let jsonCandidate = extractFirstJSONObject(cleaned) ?? cleaned
        guard let resultData = jsonCandidate.data(using: .utf8) else {
            throw ClaudeBackendError.parseError("could not encode result as utf8")
        }
        do {
            return try JSONDecoder().decode(ReviewResult.self, from: resultData)
        } catch {
            let preview = jsonCandidate.count > 600 ? String(jsonCandidate.prefix(600)) + "…" : jsonCandidate
            throw ClaudeBackendError.parseError("review JSON decode failed (\(error.localizedDescription)). Got: \(preview)")
        }
    }

    private func extractFirstJSONObject(_ s: String) -> String? {
        guard let startIdx = s.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escaped = false
        var i = startIdx
        while i < s.endIndex {
            let c = s[i]
            if escaped {
                escaped = false
            } else if inString {
                if c == "\\" { escaped = true }
                else if c == "\"" { inString = false }
            } else {
                if c == "\"" { inString = true }
                else if c == "{" { depth += 1 }
                else if c == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(s[startIdx...i])
                    }
                }
            }
            i = s.index(after: i)
        }
        return nil
    }

    private func locateClaudeBinary() throws -> String {
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "\(home)/.npm-global/bin/claude",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        if let path = try? whichClaude(), FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        throw ClaudeBackendError.claudeNotFound
    }

    private func whichClaude() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-l", "-c", "command -v claude"]
        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func runProcess(path: String, args: [String]) async throws -> (Data, Data, Int32) {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<(Data, Data, Int32), Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = args
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
                process.environment = ProcessInfo.processInfo.environment

                do {
                    try process.run()
                } catch {
                    cont.resume(throwing: ClaudeBackendError.processFailed(error.localizedDescription))
                    return
                }
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                cont.resume(returning: (outData, errData, process.terminationStatus))
            }
        }
    }

    private func stripCodeFences(_ s: String) -> String {
        var t = s
        if t.hasPrefix("```json") {
            t = String(t.dropFirst("```json".count))
        } else if t.hasPrefix("```") {
            t = String(t.dropFirst(3))
        }
        if t.hasSuffix("```") {
            t = String(t.dropLast(3))
        }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ClaudeEnvelope: Decodable {
    let result: String
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case result
        case sessionId = "session_id"
    }
}
