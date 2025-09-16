import Foundation

struct Script: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var isRunning: Bool = false
    var lastOutput: String = ""

    init(id: UUID = UUID(), name: String, command: String, isRunning: Bool = false) {
        self.id = id
        self.name = name
        self.command = command
        self.isRunning = isRunning
    }
}

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var scripts: [Script]
    var packageManager: PackageManager?  // nil means use global default

    init(
        id: UUID = UUID(), name: String, path: String, scripts: [Script] = [],
        packageManager: PackageManager? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.scripts = scripts
        self.packageManager = packageManager
    }

    /// Returns the effective package manager for this project (override or global default)
    func effectivePackageManager(globalDefault: PackageManager) -> PackageManager {
        return packageManager ?? globalDefault
    }
}

enum PackageManager: String, Codable, CaseIterable, Identifiable {
    case npm
    case npx
    case yarn
    case pnpm
    case bun

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .npm: return "npm"
        case .npx: return "npx"
        case .yarn: return "yarn"
        case .pnpm: return "pnpm"
        case .bun: return "bun"
        }
    }

    /// Build the shell command to run a package script
    func commandToRun(script: String) -> String {
        switch self {
        case .npm:
            return "npm run \(script)"
        case .npx:
            // npx executes binaries; for script names this may not work in some repos
            // but provided as a user option per preference.
            return "npx \(script)"
        case .yarn:
            return "yarn run \(script)"
        case .pnpm:
            return "pnpm run \(script)"
        case .bun:
            return "bun run \(script)"
        }
    }
}

struct Preferences: Codable, Equatable {
    var showNotifications: Bool = true
    var packageManager: PackageManager = .npm
}

final class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var activeLog: ScriptLogState? = nil
    @Published var preferences: Preferences = Preferences()

    static let shared = AppState()

    private init() {
        loadProjects()
        loadPreferences()
    }

    // MARK: - Projects
    func loadProjects() {
        if let data = try? Data(contentsOf: storageURL),
            let decoded = try? JSONDecoder().decode([Project].self, from: data)
        {
            self.projects = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(projects) {
            try? data.write(to: storageURL)
        }
    }

    private var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appDir = dir.appendingPathComponent("Daihon", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("projects.json")
    }

    // MARK: - Preferences
    func loadPreferences() {
        if let data = try? Data(contentsOf: preferencesURL),
            let decoded = try? JSONDecoder().decode(Preferences.self, from: data)
        {
            self.preferences = decoded
        }
    }

    func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            try? data.write(to: preferencesURL)
        }
    }

    private var preferencesURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appDir = dir.appendingPathComponent("Daihon", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("preferences.json")
    }
}

struct ScriptLogState: Identifiable, Equatable {
    let id = UUID()
    let projectID: UUID
    let scriptID: UUID
    var title: String
}
