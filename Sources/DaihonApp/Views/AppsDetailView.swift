import SwiftUI
import AppKit

struct AppsDetailView: View {
    @ObservedObject var state = AppState.shared
    @ObservedObject var processManager = ProcessManager.shared
    
    var body: some View {
        if let project = state.selectedProject {
            projectDetailView(project)
        } else {
            emptyStateView
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.tertiary)

            VStack(spacing: 8) {
                Text("No Project Selected")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Select a project from the sidebar to view its details")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TahoePrimaryBackground())
    }
    
    private func projectDetailView(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.title)
                                .fontWeight(.semibold)

                            HStack(spacing: 6) {
                                Image(systemName: "location")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)

                                Text(project.path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .fontDesign(.monospaced)

                                Button {
                                    revealInFinder(project)
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(hasRunningScripts(project) ? .green : .gray)
                                    .frame(width: 8, height: 8)
                                
                                Text(hasRunningScripts(project) ? "Running" : "Stopped")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(hasRunningScripts(project) ? .green : .secondary)
                            }
                            
                            Text("\(runningScriptsCount(project))/\(project.scripts.count) scripts")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Scripts
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Scripts")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("Rescan") {
                            rescanScripts(for: project)
                        }
                        .font(.system(size: 12))
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                    
                    if project.scripts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)

                            Text("No scripts found")
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(project.scripts) { script in
                                ScriptRow(script: script, project: project)
                            }
                        }
                    }
                }

                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ActionButton(
                            title: "Stop All",
                            icon: "stop.circle.fill",
                            color: .red,
                            isDisabled: !hasRunningScripts(project)
                        ) {
                            stopAllScripts(for: project)
                        }
                        
                        ActionButton(
                            title: "Restart All",
                            icon: "arrow.clockwise.circle.fill",
                            color: .orange,
                            isDisabled: !hasRunningScripts(project)
                        ) {
                            restartAllScripts(for: project)
                        }
                        
                        ActionButton(
                            title: "Open Terminal",
                            icon: "terminal.fill",
                            color: .blue
                        ) {
                            openInTerminal(project)
                        }
                        
                        ActionButton(
                            title: "Show in Finder",
                            icon: "folder.fill",
                            color: .green
                        ) {
                            revealInFinder(project)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(TahoePrimaryBackground())
    }
    
    private func hasRunningScripts(_ project: Project) -> Bool {
        project.scripts.contains { processManager.running[$0.id] != nil }
    }
    
    private func runningScriptsCount(_ project: Project) -> Int {
        project.scripts.filter { processManager.running[$0.id] != nil }.count
    }
    
    private func rescanScripts(for project: Project) {
        let url = URL(fileURLWithPath: project.path, isDirectory: true)
        let scripts = detectScripts(at: url)
        var updatedProject = project
        updatedProject.scripts = scripts
        updateProject(updatedProject)
    }
    
    private func detectScripts(at url: URL) -> [Script] {
        let packagePath = url.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packagePath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = obj["scripts"] as? [String: Any]
        else { return [] }
        
        return scripts.keys.sorted().map { Script(name: $0, command: $0) }
    }
    
    private func updateProject(_ project: Project) {
        func updateInItems(_ items: [SidebarItem]) -> [SidebarItem] {
            items.map { item in
                switch item {
                case .project(let p):
                    return p.id == project.id ? .project(project) : item
                case .directory(var dir):
                    dir.children = updateInItems(dir.children)
                    return .directory(dir)
                }
            }
        }
        
        state.sidebarItems = updateInItems(state.sidebarItems)
        state.selectedProject = project
        state.saveSidebarItems()
    }
    
    private func revealInFinder(_ project: Project) {
        let url = URL(fileURLWithPath: project.path, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func openInTerminal(_ project: Project) {
        let script = """
        tell application "Terminal"
            activate
            do script "cd '\(project.path)'"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var errorDict: NSDictionary?
            appleScript.executeAndReturnError(&errorDict)
        }
    }
    
    private func stopAllScripts(for project: Project) {
        for script in project.scripts {
            if processManager.running[script.id] != nil {
                processManager.stop(scriptID: script.id)
            }
        }
    }
    
    private func restartAllScripts(for project: Project) {
        let runningScripts = project.scripts.filter { processManager.running[$0.id] != nil }
        for script in runningScripts {
            processManager.stop(scriptID: script.id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                processManager.start(script: script, in: project)
            }
        }
    }
}

struct ScriptRow: View {
    let script: Script
    let project: Project
    @ObservedObject var processManager = ProcessManager.shared
    @ObservedObject var state = AppState.shared
    
    private var isRunning: Bool {
        processManager.running[script.id] != nil
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                toggleScript()
            } label: {
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(isRunning ? .red : .green)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(script.name)
                    .font(.system(size: 14, weight: .semibold))

                Text(script.command)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            if isRunning {
                Button("Logs") {
                    viewLogs()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(16)
        .compatGlassEffectThick(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isRunning ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1), lineWidth: 1)
        }
    }
    
    private func toggleScript() {
        if processManager.running[script.id] != nil {
            processManager.stop(scriptID: script.id)
        } else {
            processManager.start(script: script, in: project)
            viewLogs()
        }
    }
    
    private func viewLogs() {
        let logState = ScriptLogState(
            projectID: project.id,
            scriptID: script.id,
            title: "\(project.name): \(script.name)"
        )
        state.activeLog = logState
        LogWindowController.shared.show(logState: logState)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
    
    init(title: String, icon: String, color: Color, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isDisabled ? .secondary : color)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .compatGlassEffectThick(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isDisabled ? Color.primary.opacity(0.05) : color.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}