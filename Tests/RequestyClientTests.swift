import Foundation
import Testing
import Transcript

@Suite("Requesty boundary")
struct RequestyClientTests {
    private let spoken = [Sentence(id: 0, text: "A complete example.", start: 0, end: 8)]
    private var configuration: RequestyConfiguration {
        get throws {
            try RequestyConfiguration(environment: [
                "REQUESTY_API_KEY": "test-key",
                "REQUESTY_BASE_URL": "https://router.eu.requesty.ai/v1/",
                "REQUESTY_MODEL": "openai/gpt-5",
            ])
        }
    }

    @Test("Sends only the transcript and preferences with a strict sentence schema")
    func buildsTranscriptRequest() throws {
        var options = SelectionOptions()
        options.provider = .requesty
        options.focus = .hook
        options.count = 2
        let request = try RequestySelector(configuration: configuration).request(in: spoken, options: options)
        #expect(request.url?.absoluteString == "https://router.eu.requesty.ai/v1/responses")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        let body = try #require(request.httpBody)
        #expect(!String(decoding: body, as: UTF8.self).contains("test-key"))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "openai/gpt-5")
        #expect(json["store"] as? Bool == false)
        let input = try #require(json["input"] as? String)
        let transcript = try #require(JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any])
        #expect(Set(transcript.keys) == ["sentences", "preferences"])
        let sentences = try #require(transcript["sentences"] as? [[String: Any]])
        #expect(Set(try #require(sentences.first).keys) == ["id", "text", "cutDuration"])
        #expect(sentences.first?["text"] as? String == "A complete example.")
        let text = try #require(json["text"] as? [String: Any])
        let format = try #require(text["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        #expect(format["strict"] as? Bool == true)
        let schema = try #require(format["schema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test("Refuses credentials to arbitrary URLs or non-OpenAI routing policies", arguments: [
        ("http://router.eu.requesty.ai/v1", "openai/gpt-5"),
        ("https://example.com/v1", "openai/gpt-5"),
        ("https://router.eu.requesty.ai.evil.example/v1", "openai/gpt-5"),
        ("https://user:password@router.eu.requesty.ai/v1", "openai/gpt-5"),
        ("https://router.eu.requesty.ai/v1?key=bad", "openai/gpt-5"),
        ("https://router.eu.requesty.ai/v1", "policy/fallback"),
        ("https://router.eu.requesty.ai/v1", "anthropic/claude"),
    ])
    func rejectsUnsafeConfiguration(url: String, model: String) {
        #expect(throws: RequestySelectionError.self) {
            try RequestyConfiguration(environment: ["REQUESTY_API_KEY": "test-key", "REQUESTY_BASE_URL": url, "REQUESTY_MODEL": model])
        }
    }

    @Test("Parses completed Responses output into real clips")
    func parsesCompletedResponse() throws {
        let data = Data(#"{"status":"completed","output":[{"type":"message","role":"assistant","status":"completed","content":[{"type":"output_text","text":"{\"clips\":[{\"startSentenceID\":0,\"endSentenceID\":0}]}","annotations":[]}]}]}"#.utf8)
        let clips = try RequestySelector.decode(data, in: spoken, options: SelectionOptions())
        #expect(clips.first?.sentenceIDs == [0])
    }

    @Test("Never accepts unfinished output, refusals or echoed server errors", arguments: [
        #"{"status":"incomplete","output":[]}"#,
        #"{"status":"completed","output":[{"type":"message","content":[{"type":"refusal","refusal":"private-marker"}]}]}"#,
        #"{"error":{"message":"private-marker"}}"#,
    ])
    func rejectsBadResponse(json: String) {
        do {
            _ = try RequestySelector.decode(Data(json.utf8), in: spoken, options: SelectionOptions())
            Issue.record("Unusable output was accepted")
        } catch {
            #expect(error is RequestySelectionError)
            #expect(!error.localizedDescription.contains("private-marker"))
        }
    }
}
