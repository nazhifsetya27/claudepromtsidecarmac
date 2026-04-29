import Foundation

struct ReviewResult: Codable, Sendable {
    let looksGood: Bool
    let improvedPrompt: String?
    let englishNotes: [EnglishNote]

    struct EnglishNote: Codable, Identifiable, Sendable {
        let original: String
        let suggested: String
        let why: String

        var id: String { original + "→" + suggested }
    }

    enum CodingKeys: String, CodingKey {
        case looksGood = "looks_good"
        case improvedPrompt = "improved_prompt"
        case englishNotes = "english_notes"
    }
}
