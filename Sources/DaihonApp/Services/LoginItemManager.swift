import Foundation

final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    private init() {}

    // MARK: Public API
    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: agentPlistURL.path)
    }

    func setEnabled(_ enable: Bool) async throws {
        if enable {
            try writePlist()
            try await loadAgent()
        } else {
            _ = try? await unloadAgent()
            try removePlist()
        }
    }

    // MARK: Paths & Label
    private let label = "com.genericmilk.daihon.launchagent"

    private var agentPlistURL: URL {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("LaunchAgents")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(label).plist")
    }

    private var appBundleURL: URL? {
        // Prefer the app bundle when running from Daihon.app
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" { return bundleURL }
        return nil
    }

    // MARK: Plist I/O
    private func writePlist() throws {
        let dict: [String: Any]
        if let appURL = appBundleURL {
            // Use `open -a <App.app>` to launch the bundle properly in the GUI session
            dict = [
                "Label": label,
                "RunAtLoad": true,
                "ProgramArguments": [
                    "/usr/bin/open",
                    "-a",
                    appURL.path
                ],
            ]
        } else if let exeURL = Bundle.main.executableURL {
            // Fallback: Launch the executable directly (when not running from a .app bundle)
            dict = [
                "Label": label,
                "RunAtLoad": true,
                "Program": exeURL.path
            ]
        } else {
            throw NSError(domain: label, code: 2)
        }

        let data = try PropertyListSerialization.data(
            fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: agentPlistURL, options: .atomic)
    }

    private func removePlist() throws {
        try FileManager.default.removeItem(at: agentPlistURL)
    }

    // MARK: launchctl
    @discardableResult
    private func loadAgent() async throws -> Int32 {
        // `launchctl bootstrap gui/$UID <plist>` is the modern API
        // If already bootstrapped, this will error; that's fine.
        let uid = getuid()
        return try await runLaunchctl(["bootstrap", "gui/\(uid)", agentPlistURL.path])
    }

    @discardableResult
    private func unloadAgent() async throws -> Int32 {
        let uid = getuid()
        return try await runLaunchctl(["bootout", "gui/\(uid)/\(label)"])
    }

    @discardableResult
    private func runLaunchctl(_ args: [String]) async throws -> Int32 {
        return try await withCheckedThrowingContinuation { continuation in
            Task.detached {
                do {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                    proc.arguments = ["-lc", ([("/bin/launchctl")] + args).joined(separator: " ")]
                    try proc.run()
                    proc.waitUntilExit()
                    continuation.resume(returning: proc.terminationStatus)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
