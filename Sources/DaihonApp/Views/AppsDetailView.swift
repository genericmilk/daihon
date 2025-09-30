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
            Image(systemName: "folder.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 8) {
                Text("Select a project")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Choose a project from the sidebar to view its details\nand controls")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func projectDetailView(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                projectHeader(project)

                // Project Info
                projectInfoSection(project)

                // Scripts Section
                scriptsSection(project)

                // Actions Section
                actionsSection(project)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func projectHeader(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.largeTitle)
                .fontWeight(.bold)

            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(project.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fontDesign(.monospaced)

                Button {
                    revealInFinder(project)
                } label: {
                    Image(systemName: "arrow.forward.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
    }
    
    private func projectInfoSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Project Information", systemImage: "info.circle")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Package Manager
                HStack {
                    Text("Package Manager:")
                        .foregroundColor(.secondary)

                    Spacer()

                    Menu {
                        Button {
                            updatePackageManager(nil, for: project)
                        } label: {
                            HStack {
                                Text("Global Default (\(state.preferences.packageManager.displayName))")
                                if project.packageManager == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        ForEach(PackageManager.allCases) { pm in
                            Button {
                                updatePackageManager(pm, for: project)
                            } label: {
                                HStack {
                                    Text(pm.displayName)
                                    if project.packageManager == pm {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(displayPackageManager(for: project))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Divider()

                // Script count
                HStack {
                    Text("Scripts:")
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(project.scripts.count) available")
                }
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    private func scriptsSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Scripts", systemImage: "play.circle")
                    .font(.headline)

                Spacer()

                Button("Rescan") {
                    rescanScripts(for: project)
                }
                .buttonStyle(.plain)
            }

            if project.scripts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)

                    Text("No scripts found. Click 'Rescan' to import commands from package.json.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 8) {
                    ForEach(project.scripts) { script in
                        ScriptRow(script: script, project: project)
                    }
                }
            }
        }
    }
    
    private func actionsSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Actions", systemImage: "gearshape")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    stopAllScripts(for: project)
                } label: {
                    Label("Stop All Scripts", systemImage: "stop.circle")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!hasRunningScripts(project))
                .opacity(hasRunningScripts(project) ? 1.0 : 0.5)

                Button {
                    restartAllScripts(for: project)
                } label: {
                    Label("Restart All", systemImage: "arrow.clockwise.circle")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!hasRunningScripts(project))
                .opacity(hasRunningScripts(project) ? 1.0 : 0.5)

                Spacer()
            }
        }
    }
    
    private func displayPackageManager(for project: Project) -> String {
        project.packageManager?.displayName ?? "Global Default (\(state.preferences.packageManager.displayName))"
    }
    
    private func updatePackageManager(_ pm: PackageManager?, for project: Project) {
        guard var updatedProject = state.allProjects.first(where: { $0.id == project.id }) else { return }
        updatedProject.packageManager = pm
        updateProject(updatedProject)
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
    
    private func revealInFinder(_ project: Project) {
        let url = URL(fileURLWithPath: project.path, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func hasRunningScripts(_ project: Project) -> Bool {
        project.scripts.contains { processManager.running[$0.id] != nil }
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
                    .font(.title3)
                    .foregroundStyle(isRunning ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .help(isRunning ? "Stop script" : "Start script")

            VStack(alignment: .leading, spacing: 3) {
                Text(script.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(script.command)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            if isRunning {
                Button("Logs") {
                    viewLogs()
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .scaleEffect(isRunning ? 2 : 1)
                            .opacity(isRunning ? 0 : 1)
                            .animation(
                                Animation.easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false),
                                value: isRunning
                            )
                    )
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            if isRunning {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.3), lineWidth: 1)
            }
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