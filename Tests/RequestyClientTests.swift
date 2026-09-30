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
                "REQUESTY_MODEL": "glm-5.3-flash@eu",
            ])
        }
    }

    @Test("Accepts the API key, router and model entered in the app")
    func usesAppCredentials() throws {
        let configuration = try RequestyConfiguration(apiKey: " session-key ",
            baseURL: "https://router.eu.requesty.ai/v1", model: "glm-5.3-flash@eu")
        let request = try RequestySelector(configuration: configuration).request(in: spoken, options: SelectionOptions())
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-key")
        #expect(request.url?.host == "router.eu.requesty.ai")
        #expect(!String(decoding: try #require(request.httpBody), as: UTF8.self).contains("session-key"))
    }

    @Test("Sends only the transcript and preferences with a strict sentence schema")
    func buildsTranscriptRequest() throws {
        var options = SelectionOptions()
        options.provider = .requesty
        options.focus = .hook
        options.count = 2
        let request = try RequestySelector(configuration: configuration).request(in: spoken, options: options)
        #expect(request.url?.absoluteString == "https://router.eu.requesty.ai/v1/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        let body = try #require(request.httpBody)
        #expect(!String(decoding: body, as: UTF8.self).contains("test-key"))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "glm-5.3-flash@eu")
        #expect(json["store"] as? Bool == false)
        let messages = try #require(json["messages"] as? [[String: String]])
        #expect(messages.map { $0["role"] } == ["system", "user"])
        let input = try #require(messages.last?["content"])
        let transcript = try #require(JSONSerialization.jsonObject(with: Data(input.utf8)) as? [String: Any])
        #expect(Set(transcript.keys) == ["sentences", "preferences"])
        let sentences = try #require(transcript["sentences"] as? [[String: Any]])
        #expect(Set(try #require(sentences.first).keys) == ["id", "text", "cutDuration"])
        #expect(sentences.first?["text"] as? String == "A complete example.")
        let format = try #require(json["response_format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let definition = try #require(format["json_schema"] as? [String: Any])
        #expect(definition["strict"] as? Bool == true)
        let schema = try #require(definition["schema"] as? [String: Any])
        #expect(schema["additionalProperties"] as? Bool == false)
    }

    @Test("Refuses credentials to arbitrary URLs or models outside GLM 5.3 Flash", arguments: [
        ("http://router.eu.requesty.ai/v1", "glm-5.3-flash@eu"),
        ("https://example.com/v1", "glm-5.3-flash@eu"),
        ("https://router.eu.requesty.ai.evil.example/v1", "glm-5.3-flash@eu"),
        ("https://user:password@router.eu.requesty.ai/v1", "glm-5.3-flash@eu"),
        ("https://router.eu.requesty.ai/v1?key=bad", "glm-5.3-flash@eu"),
        ("https://router.eu.requesty.ai/v1", "openai/gpt-5"),
        ("https://router.eu.requesty.ai/v1", "policy/fallback"),
        ("https://router.eu.requesty.ai/v1", "anthropic/claude"),
        ("https://router.eu.requesty.ai/v1", "glm-5.3-flashx"),
    ])
    func rejectsUnsafeConfiguration(url: String, model: String) {
        #expect(throws: RequestySelectionError.self) {
            try RequestyConfiguration(environment: ["REQUESTY_API_KEY": "test-key", "REQUESTY_BASE_URL": url, "REQUESTY_MODEL": model])
        }
    }

    @Test("Allows exact GLM 5.3 Flash EU and provider IDs", arguments: [
        "glm-5.3-flash@eu", "sference/glm-5.3-flash", "lyceum/glm-5.3-flash",
    ])
    func allowsGLM(model: String) throws {
        let config = try RequestyConfiguration(apiKey: "test-key", baseURL: "https://router.eu.requesty.ai/v1", model: model)
        #expect(config.model == model)
    }

    @Test("Parses completed GLM chat output into real clips")
    func parsesCompletedResponse() throws {
        let data = Data(#"{"choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"{\"clips\":[{\"startSentenceID\":0,\"endSentenceID\":0}]}"}}]}"#.utf8)
        let clips = try RequestySelector.decode(data, in: spoken, options: SelectionOptions())
        #expect(clips.first?.sentenceIDs == [0])
    }

    @Test("Never accepts unfinished output, refusals or echoed server errors", arguments: [
        #"{"choices":[{"finish_reason":"length","message":{"content":"{\"clips\":[]}"}}]}"#,
        #"{"choices":[{"finish_reason":"stop","message":{"refusal":"private-marker","content":null}}]}"#,
        #"{"choices":[]}"#,
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
