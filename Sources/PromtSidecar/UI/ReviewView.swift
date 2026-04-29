import SwiftUI

struct ReviewView: View {
    let result: ReviewResult
    let original: String
    let maxHeight: CGFloat
    let onCopy: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if result.looksGood {
                    Label("Looks good — ship it.", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else {
                    if let improved = result.improvedPrompt, !improved.isEmpty {
                        improvedPromptSection(improved)
                    }
                    if !result.englishNotes.isEmpty {
                        englishNotesSection
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(width: 480)
        .frame(minHeight: 80, maxHeight: maxHeight)
    }

    private func improvedPromptSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Improved Prompt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onCopy(text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 200)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var englishNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("English Notes")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(result.englishNotes) { note in
                    EnglishNoteRow(note: note)
                }
            }
        }
    }
}

private struct EnglishNoteRow: View {
    let note: ReviewResult.EnglishNote

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(note.original)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(note.suggested)
                    .fontWeight(.medium)
            }
            Text(note.why)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
