import AppKit
import Foundation

/// CLI launcher: LaunchServices needs explicit environment values. The key
/// arrives from the parent process, stays in memory and never enters argv.
@main
struct LaunchWithEnvironment {
    enum Failure: Error { case launch }

    @MainActor
    static func main() async {
        guard CommandLine.arguments.count == 2 else { exit(2) }
        let url = URL(filePath: CommandLine.arguments[1])
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = true
        let names = ["REQUESTY_API_KEY", "REQUESTY_BASE_URL", "REQUESTY_MODEL"]
        configuration.environment = ProcessInfo.processInfo.environment.filter { names.contains($0.key) }
        do {
            let pid = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<pid_t, any Error>) in
                NSWorkspace.shared.openApplication(at: url, configuration: configuration) { application, _ in
                    guard let application else {
                        continuation.resume(throwing: Failure.launch)
                        return
                    }
                    continuation.resume(returning: application.processIdentifier)
                }
            }
            print(pid)
        } catch {
            // Do not print NSWorkspace errors: they may carry launch options.
            fputs("Could not launch Clipper Requesty.\n", stderr)
            exit(1)
        }
    }
}
