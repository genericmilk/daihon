import SwiftUI
import AppKit

struct AppsSidebarView: View {
    @ObservedObject var state = AppState.shared
    @State private var searchText = ""
    @State private var expandedDirectories: Set<UUID> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredItems, id: \.id) { item in
                        sidebarRow(item: item, level: 0)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(TahoeSidebarBackground())
        .navigationTitle("Projects")
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            // Search
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .compatGlassEffect(in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
            
            // Add button
            HStack {
                Spacer()
                
                Menu {
                    Button("Add Project...") {
                        addSingleProject()
                    }
                    Button("Add Directory...") {
                        addDirectoryOfProjects()
                    }
                    Button("New Directory") {
                        createNewDirectory()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .frame(width: 24, height: 24)
                        .contentShape(Circle())
                }
                .menuStyle(.borderlessButton)
                .buttonStyle(.plain)
                .compatGlassEffect(in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
    
    private func sidebarRow(item: SidebarItem, level: Int) -> AnyView {
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
                VStack(spacing: 0) {
                    DirectoryRowView(
                        directory: directory,
                        isExpanded: expandedDirectories.contains(directory.id),
                        level: level,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
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
                            sidebarRow(item: child, level: level + 1)
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
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else {
            return directory
        }
        
        var projects: [Project] = []
        
        for case let fileURL as URL in enumerator {
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
                .frame(width: 16)

            Text(project.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            if hasRunningScripts {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
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
                .font(.system(size: 10, weight: .medium))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .frame(width: 12, height: 12)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.2), value: isExpanded)

            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(directory.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(directory.children.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color(NSColor.quaternaryLabelColor))
                )
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .padding(.leading, CGFloat(level * 16))
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}