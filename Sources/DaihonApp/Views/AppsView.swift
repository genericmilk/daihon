import AppKit
import SwiftUI

struct AppsView: View {
    @ObservedObject var state = AppState.shared
    @State private var draftProjects: [Project] = []
    @ObservedObject var processManager = ProcessManager.shared
    @State private var alert: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apps")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Manage project locations, package managers, and scripts.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    addProject()
                } label: {
                    Label("Add App", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                let columns = [GridItem(.adaptive(minimum: 340), spacing: 16)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    ForEach($draftProjects) { $project in
                        projectCard(for: $project)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .ignoresSafeArea()
        }
        .onAppear { draftProjects = state.projects }
        .onDisappear { saveProjects() }
        .alert(
            item: Binding(get: { alert.map { AppsAlertItem(msg: $0) } }, set: { _ in alert = nil })
        ) { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    private func projectCard(for project: Binding<Project>) -> some View {
        let displayPackageManager = project.wrappedValue.packageManager?.displayName
            ?? "Global Default (\(state.preferences.packageManager.displayName))"

        return VStack(alignment: .leading, spacing: 16) {
            projectCardHeader(for: project, displayPackageManager: displayPackageManager)
            Divider()
            scriptsSection(for: project)
            projectCardFooter(for: project)
        }
        .padding(18)
        .glassPanel(radius: 14)
        .transition(.opacity.combined(with: .scale))
    }

    @ViewBuilder
    private func projectCardHeader(for project: Binding<Project>, displayPackageManager: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Name", text: project.name)
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .onChange(of: project.wrappedValue.name) { _ in saveProjects() }

                HStack(spacing: 8) {
                    TextField("Path", text: project.path)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .onChange(of: project.wrappedValue.path) { _ in saveProjects() }

                    Menu {
                        Button("Browse…") { chooseDirectory(for: project) }
                        Button("Reveal in Finder") { revealInFinder(project.wrappedValue) }
                    } label: {
                        Image(systemName: "folder")
                            .frame(width: 28, height: 28)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 12) {
                packageManagerMenu(for: project, displayTitle: displayPackageManager)

                Button(role: .destructive) {
                    removeProject(project.wrappedValue)
                } label: {
                    Label("Remove", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }

    @ViewBuilder
    private func scriptsSection(for project: Binding<Project>) -> some View {
        let scriptColumns = [GridItem(.adaptive(minimum: 140), spacing: 8)]
        if project.wrappedValue.scripts.isEmpty {
            Text("No scripts detected. Rescan to import commands from package.json.")
                .font(.footnote)
                .foregroundColor(.secondary)
        } else {
            LazyVGrid(columns: scriptColumns, alignment: .leading, spacing: 8) {
                ForEach(project.wrappedValue.scripts) { script in
                    scriptButton(script, project: project.wrappedValue)
                }
            }
        }
    }

    private func packageManagerMenu(for project: Binding<Project>, displayTitle: String) -> some View {
        Menu {
            Button {
                project.wrappedValue.packageManager = nil
                saveProjects()
            } label: {
                menuRow(
                    title: "Global Default (\(state.preferences.packageManager.displayName))",
                    isSelected: project.wrappedValue.packageManager == nil
                )
            }

            Divider()

            ForEach(PackageManager.allCases) { pm in
                Button {
                    project.wrappedValue.packageManager = pm
                    saveProjects()
                } label: {
                    menuRow(title: pm.displayName, isSelected: project.wrappedValue.packageManager == pm)
                }
            }
        } label: {
            Label(displayTitle, systemImage: "shippingbox")
                .font(.footnote)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }

    private func menuRow(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
    }

    private func projectCardFooter(for project: Binding<Project>) -> some View {
        HStack(spacing: 12) {
            Button {
                rescanScripts(for: project)
            } label: {
                Label("Rescan Scripts", systemImage: "arrow.clockwise")
            }

            Button {
                revealInFinder(project.wrappedValue)
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }

            Spacer()
        }
        .buttonStyle(.borderless)
        .font(.footnote)
        .controlSize(.small)
    }

    private func scriptButton(_ script: Script, project: Project) -> some View {
        let isRunning = processManager.running[script.id] != nil

        return Button {
            toggleScript(script, for: project)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isRunning ? Color.accentColor : Color.secondary.opacity(0.6))
                    .frame(width: 8, height: 8)
                Text(script.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isRunning ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isRunning ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isRunning)
    }

    private func removeProject(_ project: Project) {
        guard let index = draftProjects.firstIndex(where: { $0.id == project.id }) else { return }
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            draftProjects.remove(at: index)
        }
        saveProjects()
    }

    private func rescanScripts(for project: Binding<Project>) {
        let path = project.wrappedValue.path
        guard !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        project.wrappedValue.scripts = detectScripts(at: url)
        saveProjects()
    }

    private func chooseDirectory(for project: Binding<Project>) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if !project.wrappedValue.path.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: project.wrappedValue.path, isDirectory: true)
        }
        if panel.runModal() == .OK, let url = panel.url {
            project.wrappedValue.path = url.path
            if project.wrappedValue.name.isEmpty {
                project.wrappedValue.name = url.lastPathComponent
            }
            project.wrappedValue.scripts = detectScripts(at: url)
            saveProjects()
        }
    }

    private func revealInFinder(_ project: Project) {
        guard !project.path.isEmpty else { return }
        let url = URL(fileURLWithPath: project.path, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func toggleScript(_ script: Script, for project: Project) {
        if processManager.running[script.id] != nil {
            processManager.stop(scriptID: script.id)
        } else {
            processManager.start(script: script, in: project)
            let logState = ScriptLogState(
                projectID: project.id, scriptID: script.id, title: "\(project.name): \(script.name)"
            )
            state.activeLog = logState
            LogWindowController.shared.show(logState: logState)
        }
    }

    func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.lastPathComponent
            let scripts = detectScripts(at: url)
            draftProjects.append(Project(name: name, path: url.path, scripts: scripts))
            saveProjects()
        }
    }

    func detectScripts(at url: URL) -> [Script] {
        let pkgPath = url.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: pkgPath),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let scripts = obj["scripts"] as? [String: Any]
        else { return [] }
        return scripts.keys.sorted().map { Script(name: $0, command: $0) }
    }

    private func saveProjects() {
        state.projects = draftProjects
        state.save()
    }
}

struct AppsAlertItem: Identifiable {
    let id = UUID()
    let msg: String
}
