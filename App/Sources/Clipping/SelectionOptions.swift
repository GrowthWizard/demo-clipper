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

    enum Destination: String, CaseIterable, Identifiable, Sendable {
        case linkedIn = "LinkedIn · useful professional insights"
        case general = "General · stories and insights"
        var id: String { rawValue }
        var instruction: String {
            switch self {
            case .linkedIn: "Select useful professional insights for organic LinkedIn posts. Prefer a concrete user problem and a reasoned improvement or practical lesson. Reject generic aspirations, color preferences, UI walkthroughs, praise and internal acquisition/social-posting plans. Minimal post context may identify the case, but cannot supply a missing argument."
            case .general: "Select original self-contained stories, explanations or insights with a clear setup and payoff. A visible demonstration may be needed, but explicitly label it as requiring visual context."
            }
        }
    }

    var destination = Destination.linkedIn
    var audience = "Product and marketing decision-makers improving digital user experiences"
    var contentGoal = "Demonstrate sound judgment through a concrete problem, reasoned decision and transferable takeaway."
    var candidateLimit: Int { min(12, max(6, count + 3)) }

    var provider = Provider.local
    var count = 5
    var maximumDuration = 60.0
    var focus = Focus.balanced
    var instructions = ""
    // Optional CLI override; the GUI uses its API fields and Keychain settings.
    var model = ""

    func validate() throws {
        guard (1...10).contains(count), maximumDuration.isFinite,
              (10...60).contains(maximumDuration), instructions.count <= 4_000,
              !audience.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, audience.count <= 1_000,
              !contentGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, contentGoal.count <= 1_500 else {
            throw RequestySelectionError.invalidSelection
        }
    }
}
