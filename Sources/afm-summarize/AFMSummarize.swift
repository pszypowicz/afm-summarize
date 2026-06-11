import ArgumentParser
import Foundation
import FoundationModels

@main
struct AFMSummarize: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "afm-summarize",
        abstract: "Summarize text from stdin into one short sentence using Apple's on-device Foundation Models.",
        discussion: """
            Reads text on stdin and prints a one-sentence summary produced \
            entirely on-device by the Apple Intelligence base model. No \
            network calls, no API keys. Requires macOS 26 or later on Apple \
            Silicon with Apple Intelligence enabled.

            Exit codes: 0 on success, 64 on usage errors (bad flags, empty \
            stdin), 3 when the on-device model is unavailable, 4 when \
            generation fails (including safety guardrail refusals).

            Example:
              printf '%s' "$LONG_TEXT" | afm-summarize --max-chars 120
            """
    )

    @Option(help: "Hard cap on the summary length in characters.")
    var maxChars: Int = 120

    func validate() throws {
        guard maxChars > 0 else {
            throw ValidationError("--max-chars must be a positive integer.")
        }
    }

    func run() async throws {
        guard let data = try? FileHandle.standardInput.readToEnd(),
              let input = String(data: data, encoding: .utf8)?
                  .trimmingCharacters(in: .whitespacesAndNewlines),
              !input.isEmpty
        else {
            throw ValidationError("No text on stdin.")
        }

        guard case .available = SystemLanguageModel.default.availability else {
            FileHandle.standardError.write(Data(
                "afm-summarize: on-device model unavailable (is Apple Intelligence enabled?)\n".utf8))
            throw ExitCode(3)
        }

        // Small on-device models routinely overshoot a character budget, so
        // instruct below the cap and word-boundary-truncate any overrun.
        let target = max(20, maxChars * 4 / 5)
        let session = LanguageModelSession(instructions: """
            You summarize text for a one-line notification. Reply with one \
            plain-text sentence of at most \(target) characters stating \
            the key outcome or question. Output only the sentence, with no \
            quotes and no preamble.
            """)

        let line: String
        do {
            let response = try await session.respond(to: input)
            line = response.content
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            FileHandle.standardError.write(Data("afm-summarize: \(error)\n".utf8))
            throw ExitCode(4)
        }

        guard !line.isEmpty else {
            FileHandle.standardError.write(Data("afm-summarize: model returned empty output\n".utf8))
            throw ExitCode(4)
        }

        var output = line
        if output.count > maxChars {
            let clipped = String(output.prefix(maxChars))
            if let lastSpace = clipped.lastIndex(of: " ") {
                output = String(clipped[..<lastSpace])
            } else {
                output = clipped
            }
            output = output.trimmingCharacters(in: CharacterSet(charactersIn: " ,;:-"))
        }
        print(output)
    }
}
