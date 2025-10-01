import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

enum ProjectItem: Identifiable, Hashable, Codable {
    case project(Project)
    case group(ProjectGroup)

    var id: AnyHashable {
        switch self {
        case .project(let project):
            return project.id
        case .group(let group):
            return group.id
        }
    }

    var name: String {
        switch self {
        case .project(let project):
            return project.name
        case .group(let group):
            return group.name
        }
    }
    
    // Codable conformance
    enum CodingKeys: CodingKey {
        case project, group
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let project = try container.decodeIfPresent(Project.self, forKey: .project) {
            self = .project(project)
        } else if let group = try container.decodeIfPresent(ProjectGroup.self, forKey: .group) {
            self = .group(group)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid ProjectItem"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .project(let project):
            try container.encode(project, forKey: .project)
        case .group(let group):
            try container.encode(group, forKey: .group)
        }
    }
}

struct ProjectGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var children: [ProjectItem]

    init(id: UUID = UUID(), name: String, children: [ProjectItem] = []) {
        self.id = id
        self.name = name
        self.children = children
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

    /// Build the shell command with custom binary path if provided
    func commandToRun(script: String, customPath: String = "") -> String {
        let binaryName = displayName
        let fullPath = customPath.isEmpty ? binaryName : customPath

        switch self {
        case .npm:
            return "\(fullPath) run \(script)"
        case .npx:
            return "\(fullPath) \(script)"
        case .yarn:
            return "\(fullPath) run \(script)"
        case .pnpm:
            return "\(fullPath) run \(script)"
        case .bun:
            return "\(fullPath) run \(script)"
        }
    }
}

struct Directory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var children: [SidebarItem]

    init(id: UUID = UUID(), name: String, children: [SidebarItem] = []) {
        self.id = id
        self.name = name
        self.children = children
    }
}

enum SidebarItem: Identifiable, Codable, Hashable {
    case project(Project)
    case directory(Directory)

    var id: UUID {
        switch self {
        case .project(let project):
            return project.id
        case .directory(let directory):
            return directory.id
        }
    }

    var name: String {
        switch self {
        case .project(let project):
            return project.name
        case .directory(let directory):
            return directory.name
        }
    }
    
    enum CodingKeys: CodingKey {
        case project, directory
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let project = try container.decodeIfPresent(Project.self, forKey: .project) {
            self = .project(project)
        } else if let directory = try container.decodeIfPresent(Directory.self, forKey: .directory) {
            self = .directory(directory)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid SidebarItem"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .project(let project):
            try container.encode(project, forKey: .project)
        case .directory(let directory):
            try container.encode(directory, forKey: .directory)
        }
    }
}

struct Preferences: Codable, Equatable {
    var showNotifications: Bool = true
    var packageManager: PackageManager = .npm
    var npmBinaryPath: String = ""
    var yarnBinaryPath: String = ""
    var pnpmBinaryPath: String = ""
    var bunBinaryPath: String = ""

    /// Get the custom binary path for a package manager
    func customBinaryPath(for packageManager: PackageManager) -> String {
        switch packageManager {
        case .npm, .npx:
            return npmBinaryPath
        case .yarn:
            return yarnBinaryPath
        case .pnpm:
            return pnpmBinaryPath
        case .bun:
            return bunBinaryPath
        }
    }
}

final class AppState: ObservableObject {
    @Published var sidebarItems: [SidebarItem] = []
    @Published var selectedProject: Project? = nil
    @Published var activeLog: ScriptLogState? = nil
    @Published var preferences: Preferences = Preferences()

    static let shared = AppState()

    private init() {
        loadSidebarItems()
        loadPreferences()
        migrateOldProjectsIfNeeded()
    }
    
    private func migrateOldProjectsIfNeeded() {
        let oldProjectsURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Daihon", isDirectory: true)
            .appendingPathComponent("projects.json")
        
        guard FileManager.default.fileExists(atPath: oldProjectsURL.path),
              sidebarItems.isEmpty else { return }
        
        if let data = try? Data(contentsOf: oldProjectsURL),
           let oldProjects = try? JSONDecoder().decode([Project].self, from: data) {
            sidebarItems = oldProjects.map { .project($0) }
            saveSidebarItems()
            try? FileManager.default.removeItem(at: oldProjectsURL)
        }
    }

    var allProjects: [Project] {
        return collectProjects(from: sidebarItems)
    }
    
    private func collectProjects(from items: [SidebarItem]) -> [Project] {
        var projects: [Project] = []
        for item in items {
            switch item {
            case .project(let project):
                projects.append(project)
            case .directory(let directory):
                projects.append(contentsOf: collectProjects(from: directory.children))
            }
        }
        return projects
    }
    
    var projects: [Project] {
        get { allProjects }
        set {
            sidebarItems = newValue.map { .project($0) }
            saveSidebarItems()
        }
    }
    
    // MARK: - Projects
    func loadSidebarItems() {
        if let data = try? Data(contentsOf: storageURL),
            let decoded = try? JSONDecoder().decode([SidebarItem].self, from: data)
        {
            self.sidebarItems = decoded
        }
    }

    func findAndRemove(_ item: SidebarItem) -> SidebarItem? {
        var removedItem: SidebarItem? = nil
        sidebarItems = findAndRemove(item, in: sidebarItems, removedItem: &removedItem)
        return removedItem
    }

    private func findAndRemove(_ item: SidebarItem, in items: [SidebarItem], removedItem: inout SidebarItem?) -> [SidebarItem] {
        var newItems = items
        if let index = newItems.firstIndex(where: { $0.id == item.id }) {
            removedItem = newItems.remove(at: index)
            return newItems
        }

        for i in 0..<newItems.count {
            if case .directory(var dir) = newItems[i] {
                let originalChildren = dir.children
                dir.children = findAndRemove(item, in: dir.children, removedItem: &removedItem)
                if originalChildren.count != dir.children.count {
                    newItems[i] = .directory(dir)
                    break
                }
            }
        }

        return newItems
    }

    func insert(_ item: SidebarItem, at path: [UUID], index: Int) {
        sidebarItems = insert(item, at: path, index: index, in: sidebarItems)
    }

    private func insert(_ item: SidebarItem, at path: [UUID], index: Int, in items: [SidebarItem]) -> [SidebarItem] {
        if path.isEmpty {
            var newItems = items
            newItems.insert(item, at: index)
            return newItems
        }

        var newItems = items
        let id = path.first!
        let remainingPath = Array(path.dropFirst())

        if let idx = newItems.firstIndex(where: { $0.id == id }) {
            if case .directory(var dir) = newItems[idx] {
                dir.children = insert(item, at: remainingPath, index: index, in: dir.children)
                newItems[idx] = .directory(dir)
            }
        }

        return newItems
    }

    func saveSidebarItems() {
        if let data = try? JSONEncoder().encode(sidebarItems) {
            try? data.write(to: storageURL)
        }
    }

    private var storageURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appDir = dir.appendingPathComponent("Daihon", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("sidebar.json")
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
