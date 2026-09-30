import Foundation

struct SelectionOptions: Sendable, Equatable {
    enum Provider: String, CaseIterable, Identifiable, Sendable {
        case local = "On this Mac"
        case requesty = "GLM 5.3 Flash via Requesty"
        var id: String { rawValue }
    }
    enum Focus: String, CaseIterable, Identifiable, Sendable {
        case balanced = "Best moments"
        case context = "Complete thoughts"
        case hook = "Bold statements"
        var id: String { rawValue }

        var instruction: String {
            switch self {
            case .balanced: "Choose compelling, self-contained moments with a strong opening and clear payoff."
            case .context: "Prefer a complete argument, explanation or miniature story. Include the setup needed to understand its conclusion."
            case .hook: "Prefer surprising, provocative or quotable statements that grab attention immediately. Include their qualification and explanation so the excerpt faithfully represents the speaker."
            }
        }
    }

    var provider = Provider.local
    var count = 5
    var maximumDuration = 60.0
    var focus = Focus.balanced
    var instructions = ""
    // Optional CLI override; the GUI uses its API fields and Keychain settings.
    var model = ""

    func validate() throws {
        guard (1...10).contains(count), maximumDuration.isFinite,
              (10...60).contains(maximumDuration), instructions.count <= 4_000 else {
            throw RequestySelectionError.invalidSelection
        }
    }
}
