import Foundation
import Testing

@Suite("Requesty app credentials")
struct RequestyCredentialsTests {
    @Test("A missing key leaves sensible router/model defaults but cannot send a request")
    func requiresKey() {
        let credentials = RequestyCredentials()
        #expect(credentials.baseURL == "https://router.eu.requesty.ai/v1")
        #expect(throws: RequestySelectionError.self) { try credentials.configuration() }
    }

    @Test("Keychain remembers, replaces and forgets only this test's item")
    func keychainRoundTrip() throws {
        let store = RequestyKeychain(service: "de.65creative.clipper.requesty.test.\(UUID().uuidString)")
        defer { try? store.remove() }
        #expect(try store.load() == nil)
        var credentials = RequestyCredentials(apiKey: "test-key-alpha")
        try store.save(credentials)
        #expect(try store.load()?.apiKey == "test-key-alpha")
        credentials.apiKey = "test-key-beta"
        credentials.model = "sference/glm-5.3-flash"
        try store.save(credentials)
        let replaced = try store.load()
        #expect(replaced?.apiKey == "test-key-beta")
        #expect(replaced?.model == "sference/glm-5.3-flash")
        try store.remove()
        #expect(try store.load() == nil)
    }
}
