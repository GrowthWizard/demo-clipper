import Foundation
import Testing
import Transcript

@Suite("Requesty sentence selection")
struct RequestySelectionTests {
    private let spoken = [
        Sentence(id: 0, text: "The question.", start: 0, end: 10),
        Sentence(id: 1, text: "The context.", start: 10, end: 20),
        Sentence(id: 2, text: "The answer.", start: 20, end: 30),
        Sentence(id: 3, text: "A second idea.", start: 30, end: 40),
        Sentence(id: 4, text: "Its explanation.", start: 40, end: 70),
    ]

    @Test("Uses original speech and timings, preserving the returned ranking")
    func usesOriginalSentences() throws {
        let data = Data(#"{"clips":[{"startSentenceID":3,"endSentenceID":4},{"startSentenceID":0,"endSentenceID":2}]}"#.utf8)
        let clips = try RequestySelection.validate(data, in: spoken, count: 3, maximumDuration: 60)
        try #require(clips.count == 2)
        #expect(clips.map(\.sentenceIDs) == [[3, 4], [0, 1, 2]])
        #expect(clips.map(\.id) == [0, 1])
        #expect(clips[1].text == "The question. The context. The answer.")
        #expect(clips[1].ranges(in: spoken) == [TimeRange(start: 0, end: 30)])
    }

    @Test("Rejects invented, reversed and overlapping boundaries", arguments: [
        #"{"clips":[{"startSentenceID":-1,"endSentenceID":2}]}"#,
        #"{"clips":[{"startSentenceID":0,"endSentenceID":99}]}"#,
        #"{"clips":[{"startSentenceID":2,"endSentenceID":1}]}"#,
        #"{"clips":[{"startSentenceID":0,"endSentenceID":2},{"startSentenceID":2,"endSentenceID":3}]}"#,
    ])
    func rejectsInvalidBoundaries(json: String) {
        #expect(throws: RequestySelectionError.self) {
            try RequestySelection.validate(Data(json.utf8), in: spoken, count: 5, maximumDuration: 60)
        }
    }

    @Test("The duration cap includes the padding used by preview and export")
    func includesCutPadding() {
        let transcript = [Sentence(id: 0, text: "A full minute.", start: 0, end: 60)]
        let data = Data(#"{"clips":[{"startSentenceID":0,"endSentenceID":0}]}"#.utf8)
        #expect(throws: RequestySelectionError.self) {
            try RequestySelection.validate(data, in: transcript, count: 1, maximumDuration: 60)
        }
    }

    @Test("An actual 60 second cut is allowed")
    func acceptsExactlySixtySeconds() throws {
        let transcript = [Sentence(id: 0, text: "A complete thought.", start: 0, end: 59.85)]
        let data = Data(#"{"clips":[{"startSentenceID":0,"endSentenceID":0}]}"#.utf8)
        let clips = try RequestySelection.validate(data, in: transcript, count: 1, maximumDuration: 60)
        #expect(clips.count == 1)
        #expect(clips.first?.duration(in: transcript) == 60)
    }

    @Test("Neither a higher requested cap nor extra clips bypass the limits")
    func enforcesRequestLimits() {
        let tooLong = Data(#"{"clips":[{"startSentenceID":0,"endSentenceID":4}]}"#.utf8)
        #expect(throws: RequestySelectionError.self) {
            try RequestySelection.validate(tooLong, in: spoken, count: 5, maximumDuration: 120)
        }
        let tooMany = Data(#"{"clips":[{"startSentenceID":0,"endSentenceID":1},{"startSentenceID":3,"endSentenceID":3}]}"#.utf8)
        #expect(throws: RequestySelectionError.self) {
            try RequestySelection.validate(tooMany, in: spoken, count: 1, maximumDuration: 60)
        }
    }

    @Test("Malformed output never exposes response contents in the error")
    func doesNotEchoBadResponse() {
        let data = Data(#"{"private-transcript-marker":"unexpected"}"#.utf8)
        do {
            _ = try RequestySelection.validate(data, in: spoken, count: 3, maximumDuration: 60)
            Issue.record("Malformed output was accepted")
        } catch {
            #expect(error is RequestySelectionError)
            #expect(!error.localizedDescription.contains("private-transcript-marker"))
        }
    }

    @Test("An incorrectly numbered transcript is rejected before cutting the wrong speech")
    func rejectsRenumberedTranscript() {
        let transcript = [Sentence(id: 8, text: "Wrong ID.", start: 0, end: 10)]
        let data = Data(#"{"clips":[{"startSentenceID":0,"endSentenceID":0}]}"#.utf8)
        #expect(throws: RequestySelectionError.self) {
            try RequestySelection.validate(data, in: transcript, count: 1, maximumDuration: 60)
        }
    }
}
