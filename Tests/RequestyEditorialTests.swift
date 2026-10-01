import Foundation
import Testing
import Transcript

@Suite("Editorial selection")
struct RequestyEditorialTests {
    private let spoken = [
        Sentence(id: 0, text: "Public information is hidden behind a login.", start: 0, end: 4),
        Sentence(id: 1, text: "Show it first; login can add saved preferences.", start: 4, end: 8),
        Sentence(id: 2, text: "Navigation is another subject.", start: 8, end: 12),
        Sentence(id: 3, text: "Important information requires an extra click.", start: 12, end: 16),
        Sentence(id: 4, text: "Put decision information in the listing.", start: 16, end: 20),
    ]
    private func item(id: Int = 0, start: Int = 0, end: Int = 1,
                      verdict: String = "accept", context: String = "none",
                      failedCheck: String? = nil, quote: String? = nil) -> [String: Any] {
        var checks = ["clearOpening": true, "completeThought": true, "singleTopic": true,
                      "specificValue": true, "faithfulMetadata": true]
        if let failedCheck { checks[failedCheck] = false }
        return ["candidateID": id, "startSentenceID": start, "endSentenceID": end,
            "verdict": verdict, "title": "Browse before login", "summary": "Public information should be accessible.",
            "takeaway": "Login adds saved preferences.", "reason": "Concrete problem and benefit.",
            "context": context, "contextNote": context == "none" ? "" : "Show the referenced interface.",
            "checks": checks, "evidence": [["sentenceID": start, "quote": quote ?? spoken[start].text]]]
    }
    private func payload(_ items: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["reviews": items])
    }
    private func envelope(_ payload: Data) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop",
            "message": ["content": String(decoding: payload, as: UTF8.self)]]]])
    }

    @Test("Keeps original words, tightened boundaries and reviewed metadata together")
    func preservesReviewedSelection() throws {
        let draft = [EditorialCandidate(candidateID: 0, startSentenceID: 0, endSentenceID: 2, premise: "Login")]
        let result = try RequestyEditorial.review(payload([item()]), in: spoken, options: SelectionOptions(), candidates: draft)
        #expect(result.clips[0].sentenceIDs == [0, 1])
        #expect(result.clips[0].text == spoken[0].text + " " + spoken[1].text)
        #expect(result.reviews[0].title == "Browse before login")
        #expect(result.rejectedCount == 0)
    }

    @Test("Acceptance cannot override a failed editorial check", arguments: [
        "clearOpening", "completeThought", "singleTopic", "specificValue", "faithfulMetadata",
    ])
    func enforcesQualityGates(check: String) throws {
        let result = try RequestyEditorial.review(payload([item(failedCheck: check), item(id: 1, start: 3, end: 4)]),
            in: spoken, options: SelectionOptions())
        #expect(result.clips.count == 1)
        #expect(result.clips[0].sentenceIDs == [3, 4])
        #expect(result.rejectedCount == 1)
    }

    @Test("Invented quotes and unavailable context exclude a candidate", arguments: ["invented", "visual"])
    func excludesUnsupportedCandidate(kind: String) throws {
        let weak = item(context: kind == "visual" ? "visual" : "none", quote: kind == "invented" ? "Invented outcome" : nil)
        let result = try RequestyEditorial.review(payload([weak, item(id: 1, start: 3, end: 4)]),
            in: spoken, options: SelectionOptions())
        #expect(result.clips.map(\.sentenceIDs) == [[3, 4]])
        #expect(result.rejectedCount == 1)
    }

    @Test("Extra accepted reviews respect the requested ceiling without invalidating the best result")
    func capsAcceptedReviews() throws {
        var options = SelectionOptions(); options.count = 1
        let result = try RequestyEditorial.review(payload([item(), item(id: 1, start: 3, end: 4)]), in: spoken, options: options)
        #expect(result.clips.map(\.sentenceIDs) == [[0, 1]])
        #expect(result.rejectedCount == 1)
    }

    @Test("Overlapping accepted alternatives keep only the earlier ranked review")
    func excludesOverlappingReview() throws {
        let result = try RequestyEditorial.review(payload([item(), item(id: 1, start: 1, end: 2)]), in: spoken, options: SelectionOptions())
        #expect(result.clips.map(\.sentenceIDs) == [[0, 1]])
        #expect(result.rejectedCount == 1)
    }

    @Test("General clips can explicitly require the visible demonstration")
    func labelsVisualContext() throws {
        var options = SelectionOptions(); options.destination = .general
        let result = try RequestyEditorial.review(payload([item(context: "visual")]), in: spoken, options: options)
        #expect(result.reviews.first?.context == .visual)
    }

    @Test("Rejecting every candidate never falls back to unreviewed ranges")
    func rejectsAll() throws {
        #expect(throws: RequestySelectionError.self) {
            try RequestyEditorial.review(payload([item(verdict: "reject")]), in: spoken, options: SelectionOptions())
        }
    }

    @Test("The review must account for the real draft and cannot swap its topic")
    func respectsDraftIdentity() throws {
        let draft = [EditorialCandidate(candidateID: 0, startSentenceID: 0, endSentenceID: 1, premise: "Login")]
        for changed in [item(id: 1), item(start: 3, end: 4)] {
            #expect(throws: RequestySelectionError.self) {
                try RequestyEditorial.review(payload([changed]), in: spoken, options: SelectionOptions(), candidates: draft)
            }
        }
    }

    @Test("Both passes use the same model, brief and transcript; only reviewed clips return")
    func runsTwoPasses() async throws {
        let draft = try JSONSerialization.data(withJSONObject: ["candidates": [["candidateID": 0,
            "startSentenceID": 0, "endSentenceID": 2, "premise": "Login"]]])
        let transport = StubTransport(responses: [try envelope(draft), try envelope(payload([item()]))])
        let configuration = try RequestyConfiguration(apiKey: "test-key", baseURL: "https://router.eu.requesty.ai/v1", model: "glm-5.3-flash@eu")
        let selector = RequestySelector(configuration: configuration, transport: { try await transport.send($0) })
        var options = SelectionOptions(); options.audience = "Product leaders"; options.contentGoal = "Explain one decision"
        let result = try await selector.selectReviewed(in: spoken, options: options)
        #expect(result.clips.map(\.sentenceIDs) == [[0, 1]])
        let requests = await transport.requests
        #expect(requests.count == 2)
        var names: [String] = []
        for request in requests {
            let requestBody = try #require(request.httpBody)
            let body = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
            #expect(body["model"] as? String == "glm-5.3-flash@eu")
            #expect(body["store"] as? Bool == false)
            #expect(!String(decoding: try #require(request.httpBody), as: UTF8.self).contains("test-key"))
            let messages = try #require(body["messages"] as? [[String: String]])
            let inputText = try #require(messages.last?["content"])
            let input = try #require(JSONSerialization.jsonObject(with: Data(inputText.utf8)) as? [String: Any])
            let prefs = try #require(input["preferences"] as? [String: Any])
            #expect(prefs["audience"] as? String == "Product leaders")
            #expect(prefs["contentGoal"] as? String == "Explain one decision")
            let format = try #require(body["response_format"] as? [String: Any])
            let schema = try #require(format["json_schema"] as? [String: Any])
            names.append(try #require(schema["name"] as? String))
        }
        #expect(names == ["editorial_candidates", "editorial_review"])
    }

    @Test("A failed review never returns the successful discovery draft")
    func reviewFailure() async throws {
        let draft = try JSONSerialization.data(withJSONObject: ["candidates": [["candidateID": 0,
            "startSentenceID": 0, "endSentenceID": 1, "premise": "Login"]]])
        let transport = StubTransport(responses: [try envelope(draft)])
        let config = try RequestyConfiguration(apiKey: "test-key", baseURL: "https://router.eu.requesty.ai/v1", model: "glm-5.3-flash@eu")
        await #expect(throws: RequestySelectionError.self) {
            try await RequestySelector(configuration: config, transport: { try await transport.send($0) })
                .selectReviewed(in: spoken, options: SelectionOptions())
        }
        #expect(await transport.requests.count == 2)
    }
}

private actor StubTransport {
    let responses: [Data]
    var requests: [URLRequest] = []
    init(responses: [Data]) { self.responses = responses }
    func send(_ request: URLRequest) throws -> Data {
        requests.append(request)
        guard responses.indices.contains(requests.count - 1) else { throw RequestySelectionError.service(403) }
        return responses[requests.count - 1]
    }
}
