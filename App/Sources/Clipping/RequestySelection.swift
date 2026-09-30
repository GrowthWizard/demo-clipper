import Foundation
import Transcript

enum RequestySelectionError: LocalizedError {
    case invalidTranscript, invalidSelection, noClips, configuration, refused, incomplete, transcriptTooLong, durationLimit
    case service(Int)
    case connection

    var errorDescription: String? {
        switch self {
        case .invalidTranscript: "The transcript has invalid sentence IDs or timings."
        case .invalidSelection: "Requesty returned invalid, overlapping or overlong clips. Try selecting again or adjust the instructions."
        case .noClips: "The model found no suitable clips. Try another focus or model."
        case .configuration: "Requesty needs REQUESTY_API_KEY, REQUESTY_BASE_URL and an OpenAI REQUESTY_MODEL from the project's 1Password environment."
        case .refused: "The model declined this selection request."
        case .incomplete: "The model did not finish its selection. Try again with fewer clips."
        case .service(let status): "Requesty could not complete the request (HTTP \(status)). Check the key, model access and account limits."
        case .connection: "Could not reach Requesty. Check the connection and try again."
        case .transcriptTooLong: "This transcript is too large for one selection request. Use a shorter recording."
        case .durationLimit: "Requesty clips must stay within 60 seconds. Remove a sentence or shorten the clip."
        }
    }
}

enum RequestySelection {
    static func validate(_ data: Data, in sentences: [Sentence], count: Int,
                         maximumDuration: Double) throws -> [Clip] {
        try validateTranscript(sentences)
        guard count > 0, count <= 10, maximumDuration.isFinite,
              maximumDuration > 0 else { throw RequestySelectionError.invalidSelection }
        let output: Output
        do { output = try JSONDecoder().decode(Output.self, from: data) }
        catch { throw RequestySelectionError.invalidSelection }
        guard !output.clips.isEmpty else { throw RequestySelectionError.noClips }
        guard output.clips.count <= count else { throw RequestySelectionError.invalidSelection }
        var used = Set<Int>()
        return try output.clips.enumerated().map { rank, range in
            guard range.startSentenceID >= 0, range.endSentenceID >= range.startSentenceID,
                  range.endSentenceID < sentences.count else {
                throw RequestySelectionError.invalidSelection
            }
            let ids = Array(range.startSentenceID...range.endSentenceID)
            guard used.isDisjoint(with: ids) else { throw RequestySelectionError.invalidSelection }
            used.formUnion(ids)
            let clip = Clip(id: rank, sentenceIDs: ids,
                            text: ids.map { sentences[$0].text }.joined(separator: " "),
                            score: 0, percentile: 0,
                            estimatedDurationSec: ids.reduce(0) { $0 + sentences[$1].duration })
            // Exactly the SDK ranges used by playback and AVFoundation export,
            // including boundary padding and removed pauses. Never trim a story
            // arbitrarily to make it fit, or accept invented timecodes.
            let duration = clip.duration(in: sentences)
            guard duration.isFinite, duration > 0,
                  duration <= min(60, maximumDuration) else {
                throw RequestySelectionError.invalidSelection
            }
            return clip
        }
    }

    static func validateTranscript(_ sentences: [Sentence]) throws {
        guard !sentences.isEmpty else { throw RequestySelectionError.invalidTranscript }
        for (index, sentence) in sentences.enumerated() {
            guard sentence.id == index, !sentence.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  sentence.start.isFinite, sentence.end.isFinite,
                  sentence.start >= 0, sentence.end > sentence.start,
                  index == 0 || sentence.start >= sentences[index - 1].start else {
                throw RequestySelectionError.invalidTranscript
            }
        }
    }

    private struct Output: Decodable {
        let clips: [Range]
        struct Range: Decodable {
            let startSentenceID: Int
            let endSentenceID: Int
        }
    }
}
