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
        VStack(spacing: 16) {
            Image(systemName: "folder.fill")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 6) {
                Text("Select a project")
                    .font(.title3)
                    .fontWeight(.medium)

                Text("Choose a project from the sidebar to view its details\nand controls")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func projectDetailView(_ project: Project) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                projectHeader(project)

                // Project Info
                projectInfoSection(project)

                // Scripts Section
                scriptsSection(project)

                // Actions Section
                actionsSection(project)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private func projectHeader(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.title)
                .fontWeight(.semibold)

            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Text(project.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fontDesign(.monospaced)

                Button {
                    revealInFinder(project)
                } label: {
                    Image(systemName: "arrow.forward.circle")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")
            }
        }
    }
    
    private func projectInfoSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Project Information", systemImage: "info.circle")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                // Package Manager
                HStack {
                    Text("Package Manager:")
                        .font(.system(size: 12))
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
                        HStack(spacing: 3) {
                            Text(displayPackageManager(for: project))
                                .font(.system(size: 12))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Divider()

                // Script count
                HStack {
                    Text("Scripts:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(project.scripts.count) available")
                        .font(.system(size: 12))
                }
            }
            .padding(14)
            .compatGlassEffectThick(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        }
    }
    
    private func scriptsSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Scripts", systemImage: "play.circle")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button("Rescan") {
                    rescanScripts(for: project)
                }
                .font(.system(size: 12))
                .buttonStyle(.plain)
            }

            if project.scripts.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)

                    Text("No scripts found. Click 'Rescan' to import commands from package.json.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 6) {
                    ForEach(project.scripts) { script in
                        ScriptRow(script: script, project: project)
                    }
                }
            }
        }
    }
    
    private func actionsSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Actions", systemImage: "gearshape")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 8) {
                Button {
                    stopAllScripts(for: project)
                } label: {
                    Label("Stop All Scripts", systemImage: "stop.circle")
                        .font(.system(size: 12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .compatGlassEffect(in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
                .disabled(!hasRunningScripts(project))
                .opacity(hasRunningScripts(project) ? 1.0 : 0.5)

                Button {
                    restartAllScripts(for: project)
                } label: {
                    Label("Restart All", systemImage: "arrow.clockwise.circle")
                        .font(.system(size: 12))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .compatGlassEffect(in: Capsule())
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
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
        HStack(spacing: 10) {
            Button {
                toggleScript()
            } label: {
                Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isRunning ? .red : .accentColor)
            }
            .buttonStyle(.plain)
            .help(isRunning ? "Stop script" : "Start script")

            VStack(alignment: .leading, spacing: 2) {
                Text(script.name)
                    .font(.system(size: 13, weight: .medium))

                Text(script.command)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fontDesign(.monospaced)
            }

            Spacer()

            if isRunning {
                Button("Logs") {
                    viewLogs()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)

                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .overlay(
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
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
        .compatGlassEffectThick(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            if isRunning {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
            }
        }
        .shadow(color: isRunning ? Color.accentColor.opacity(0.15) : .black.opacity(0.08), radius: 8, y: 2)
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