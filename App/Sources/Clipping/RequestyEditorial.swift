import Foundation
import Transcript

struct EditorialCandidate: Codable, Sendable, Equatable {
    let candidateID: Int
    let startSentenceID: Int
    let endSentenceID: Int
    let premise: String
}

/// Model judgments, not a quality score or a claim that a video was watched.
struct EditorialReview: Codable, Sendable, Equatable {
    enum Context: String, Codable, Sendable { case none, post, visual }
    enum Verdict: String, Codable, Sendable { case accept, reject }
    struct Checks: Codable, Sendable, Equatable {
        var clearOpening: Bool
        var completeThought: Bool
        var singleTopic: Bool
        var specificValue: Bool
        var faithfulMetadata: Bool
        var passed: Bool { clearOpening && completeThought && singleTopic && specificValue && faithfulMetadata }
    }
    struct Evidence: Codable, Sendable, Equatable {
        let sentenceID: Int
        let quote: String
    }
    let candidateID: Int
    let startSentenceID: Int
    let endSentenceID: Int
    let verdict: Verdict
    let title: String
    let summary: String
    let takeaway: String
    let reason: String
    let context: Context
    let contextNote: String
    let checks: Checks
    let evidence: [Evidence]
}

struct EditorialResult: Sendable {
    let clips: [Clip]
    /// One approved review per clip, in the exact same rank order.
    let reviews: [EditorialReview]
    let rejectedCount: Int
}

enum RequestyEditorial {
    static func candidates(_ data: Data, in sentences: [Sentence], options: SelectionOptions) throws -> [EditorialCandidate] {
        struct Output: Decodable { let candidates: [EditorialCandidate] }
        let output: Output
        do { output = try JSONDecoder().decode(Output.self, from: data) }
        catch { throw RequestySelectionError.invalidSelection }
        guard output.candidates.count <= options.candidateLimit else { throw RequestySelectionError.invalidSelection }
        guard !output.candidates.isEmpty else { throw RequestySelectionError.noClips }
        guard Set(output.candidates.map(\.candidateID)).count == output.candidates.count,
              output.candidates.allSatisfy({ $0.candidateID >= 0 && bounded($0.premise, limit: 600) }) else {
            throw RequestySelectionError.invalidSelection
        }
        _ = try RequestySelection.validate(try ranges(output.candidates.map { ($0.startSentenceID, $0.endSentenceID) }),
            in: sentences, count: options.candidateLimit, maximumDuration: options.maximumDuration)
        return output.candidates
    }

    static func review(_ data: Data, in sentences: [Sentence], options: SelectionOptions,
                       candidates: [EditorialCandidate]? = nil) throws -> EditorialResult {
        try options.validate()
        try RequestySelection.validateTranscript(sentences)
        struct Output: Decodable { let reviews: [EditorialReview] }
        let output: Output
        do { output = try JSONDecoder().decode(Output.self, from: data) }
        catch { throw RequestySelectionError.invalidSelection }
        guard output.reviews.count <= options.candidateLimit,
              Set(output.reviews.map(\.candidateID)).count == output.reviews.count else {
            throw RequestySelectionError.invalidSelection
        }
        if let candidates {
            guard Set(output.reviews.map(\.candidateID)) == Set(candidates.map(\.candidateID)) else {
                throw RequestySelectionError.invalidSelection
            }
        }
        var approved: [EditorialReview] = []
        var used = Set<Int>()
        for review in output.reviews {
            guard review.startSentenceID >= 0, review.endSentenceID >= review.startSentenceID,
                  review.endSentenceID < sentences.count else { throw RequestySelectionError.invalidSelection }
            if let candidate = candidates?.first(where: { $0.candidateID == review.candidateID }) {
                // The reviewer can tighten a candidate or add two adjacent context
                // sentences. It cannot substitute another topic under that identity.
                guard review.startSentenceID >= max(0, candidate.startSentenceID - 2),
                      review.endSentenceID <= candidate.endSentenceID + 2,
                      review.startSentenceID <= candidate.endSentenceID,
                      review.endSentenceID >= candidate.startSentenceID else {
                    throw RequestySelectionError.invalidSelection
                }
            }
            guard review.verdict == .accept else { continue }
            // Enforce the model's own gates locally. An "accept" cannot override
            // a failed gate or unsupported quotation. Reject the weak candidate
            // without filling its place with an unreviewed draft.
            guard review.checks.passed,
                  options.destination != .linkedIn || review.context != .visual,
                  bounded(review.title, limit: 160), bounded(review.summary, limit: 900),
                  bounded(review.takeaway, limit: 600), bounded(review.reason, limit: 900),
                  review.contextNote.count <= 600,
                  review.context == .none || bounded(review.contextNote, limit: 600),
                  (1...4).contains(review.evidence.count),
                  review.evidence.allSatisfy({ evidence in
                      (review.startSentenceID...review.endSentenceID).contains(evidence.sentenceID)
                          && bounded(evidence.quote, limit: 700)
                          && sentences[evidence.sentenceID].text.contains(evidence.quote)
                  }) else { continue }
            let ids = Set(review.startSentenceID...review.endSentenceID)
            guard approved.count < options.count, used.isDisjoint(with: ids) else { continue }
            // Valid boundaries can still exceed the cap after a reviewer adds
            // context. Exclude that candidate without losing valid alternatives.
            guard (try? RequestySelection.validate(try ranges([(review.startSentenceID, review.endSentenceID)]),
                in: sentences, count: 1, maximumDuration: options.maximumDuration)) != nil else { continue }
            used.formUnion(ids)
            approved.append(review)
        }
        let clips = try RequestySelection.validate(try ranges(approved.map { ($0.startSentenceID, $0.endSentenceID) }),
            in: sentences, count: options.count, maximumDuration: options.maximumDuration)
        return EditorialResult(clips: clips, reviews: approved, rejectedCount: output.reviews.count - approved.count)
    }

    private static func bounded(_ text: String, limit: Int) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= limit
    }

    private static func ranges(_ ranges: [(Int, Int)]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["clips": ranges.map {
            ["startSentenceID": $0.0, "endSentenceID": $0.1]
        }])
    }

    static var candidateSchema: [String: Any] {
        let item = object(["candidateID": integer, "startSentenceID": integer, "endSentenceID": integer, "premise": string])
        return object(["candidates": array(item)])
    }
    static var reviewSchema: [String: Any] {
        let checks = object(["clearOpening": boolean, "completeThought": boolean, "singleTopic": boolean,
                             "specificValue": boolean, "faithfulMetadata": boolean])
        let evidence = object(["sentenceID": integer, "quote": string])
        let item = object(["candidateID": integer, "startSentenceID": integer, "endSentenceID": integer,
            "verdict": ["type": "string", "enum": ["accept", "reject"]],
            "title": string, "summary": string, "takeaway": string, "reason": string,
            "context": ["type": "string", "enum": ["none", "post", "visual"]], "contextNote": string,
            "checks": checks, "evidence": array(evidence)])
        return object(["reviews": array(item)])
    }
    private static var integer: [String: Any] { ["type": "integer"] }
    private static var string: [String: Any] { ["type": "string"] }
    private static var boolean: [String: Any] { ["type": "boolean"] }
    private static func array(_ items: [String: Any]) -> [String: Any] { ["type": "array", "items": items] }
    private static func object(_ properties: [String: Any]) -> [String: Any] {
        ["type": "object", "additionalProperties": false, "properties": properties, "required": properties.keys.sorted()]
    }
}
