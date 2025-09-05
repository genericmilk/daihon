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

    init(id: UUID = UUID(), name: String, path: String, scripts: [Script] = []) {
        self.id = id
        self.name = name
        self.path = path
        self.scripts = scripts
    }
}

final class AppState: ObservableObject {
    @Published var projects: [Project] = []
    @Published var activeLog: ScriptLogState? = nil
    @Published var selectedProjectID: UUID? = nil

    static let shared = AppState()

    private init() {
        load()
    // Ensure there is an initial selection if projects exist
    if selectedProjectID == nil { selectedProjectID = projects.first?.id }
    }

    func load() {
        if let data = try? Data(contentsOf: storageURL),
            let decoded = try? JSONDecoder().decode([Project].self, from: data)
        {
            self.projects = decoded
            if selectedProjectID == nil { selectedProjectID = decoded.first?.id }
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
}

struct ScriptLogState: Identifiable, Equatable {
    let id = UUID()
    let projectID: UUID
    let scriptID: UUID
    var title: String
}
