import SwiftUI
import AppKit

struct AppsSidebarView: View {
    @ObservedObject var state = AppState.shared
    @State private var searchText = ""
    @State private var expandedDirectories: Set<UUID> = []
    @State private var isAddMenuShowing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))

                TextField("Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Projects list
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(filteredItems, id: \.id) { item in
                        sidebarItem(item, level: 0)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()

            // Bottom toolbar
            HStack(spacing: 4) {
                Menu {
                    Button("Add Project...") {
                        addSingleProject()
                    }

                    Button("Add Directory of Projects...") {
                        addDirectoryOfProjects()
                    }

                    Divider()

                    Button("New Directory") {
                        createNewDirectory()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .help("Add Project or Directory")

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(width: 240)
    }
    
    private func sidebarItem(_ item: SidebarItem, level: Int) -> AnyView {
        switch item {
        case .project(let project):
            return AnyView(
                ProjectRowView(
                    project: project,
                    isSelected: state.selectedProject?.id == project.id,
                    level: level
                )
                .onTapGesture {
                    state.selectedProject = project
                }
            )
            
        case .directory(let directory):
            return AnyView(
                VStack(spacing: 1) {
                    DirectoryRowView(
                        directory: directory,
                        isExpanded: expandedDirectories.contains(directory.id),
                        level: level,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if expandedDirectories.contains(directory.id) {
                                    expandedDirectories.remove(directory.id)
                                } else {
                                    expandedDirectories.insert(directory.id)
                                }
                            }
                        }
                    )
                    
                    if expandedDirectories.contains(directory.id) {
                        ForEach(directory.children, id: \.id) { child in
                            sidebarItem(child, level: level + 1)
                        }
                    }
                }
            )
        }
    }
    
    private var filteredItems: [SidebarItem] {
        guard !searchText.isEmpty else { return state.sidebarItems }
        return filterItems(state.sidebarItems, searchText: searchText.lowercased())
    }
    
    private func filterItems(_ items: [SidebarItem], searchText: String) -> [SidebarItem] {
        var result: [SidebarItem] = []
        
        for item in items {
            switch item {
            case .project(let project):
                if project.name.lowercased().contains(searchText) ||
                   project.path.lowercased().contains(searchText) {
                    result.append(item)
                }
            case .directory(let directory):
                let filteredChildren = filterItems(directory.children, searchText: searchText)
                if !filteredChildren.isEmpty || directory.name.lowercased().contains(searchText) {
                    var updatedDir = directory
                    updatedDir.children = filteredChildren
                    result.append(.directory(updatedDir))
                    // Auto-expand directories when searching
                    expandedDirectories.insert(directory.id)
                }
            }
        }
        
        return result
    }
    
    private func addSingleProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"
        
        if panel.runModal() == .OK, let url = panel.url {
            let scripts = detectScripts(at: url)
            let project = Project(
                name: url.lastPathComponent,
                path: url.path,
                scripts: scripts
            )
            state.sidebarItems.append(.project(project))
            state.saveSidebarItems()
        }
    }
    
    private func addDirectoryOfProjects() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Directory"
        panel.message = "Select a directory containing multiple projects"
        
        if panel.runModal() == .OK, let url = panel.url {
            let directory = scanForProjects(at: url)
            if !directory.children.isEmpty {
                state.sidebarItems.append(.directory(directory))
                state.saveSidebarItems()
                expandedDirectories.insert(directory.id)
            }
        }
    }
    
    private func createNewDirectory() {
        let directory = Directory(name: "New Directory")
        state.sidebarItems.append(.directory(directory))
        state.saveSidebarItems()
        expandedDirectories.insert(directory.id)
    }
    
    private func scanForProjects(at url: URL) -> Directory {
        let directory = Directory(name: url.lastPathComponent)
        
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: nil
        ) else {
            return directory
        }
        
        var projects: [Project] = []
        let maxDepth = 2 // Only scan 2 levels deep
        
        for case let fileURL as URL in enumerator {
            let depth = fileURL.pathComponents.count - url.pathComponents.count
            if depth > maxDepth {
                enumerator.skipDescendants()
                continue
            }
            
            // Check if this directory contains package.json
            let packagePath = fileURL.appendingPathComponent("package.json")
            if FileManager.default.fileExists(atPath: packagePath.path) {
                let scripts = detectScripts(at: fileURL)
                if !scripts.isEmpty {
                    let project = Project(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        scripts: scripts
                    )
                    projects.append(project)
                    enumerator.skipDescendants()
                }
            }
        }
        
        var updatedDirectory = directory
        updatedDirectory.children = projects.map { .project($0) }
        return updatedDirectory
    }
    
    private func detectScripts(at url: URL) -> [Script] {
        let packagePath = url.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packagePath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = obj["scripts"] as? [String: Any]
        else { return [] }
        
        return scripts.keys.sorted().map { Script(name: $0, command: $0) }
    }
}

struct ProjectRowView: View {
    let project: Project
    let isSelected: Bool
    let level: Int
    @ObservedObject var processManager = ProcessManager.shared
    
    private var hasRunningScripts: Bool {
        project.scripts.contains { processManager.running[$0.id] != nil }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .secondary)
                .symbolRenderingMode(.hierarchical)

            Text(project.name)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer()

            if hasRunningScripts {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .padding(.leading, CGFloat(level * 16))
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct DirectoryRowView: View {
    let directory: Directory
    let isExpanded: Bool
    let level: Int
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .medium))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 14, height: 14)
                .foregroundColor(.secondary)

            Image(systemName: isExpanded ? "folder.fill" : "folder.fill")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)

            Text(directory.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text("\(directory.children.count)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(NSColor.quaternaryLabelColor))
                )
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .padding(.leading, CGFloat(level * 16))
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}