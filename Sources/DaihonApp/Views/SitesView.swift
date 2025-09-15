import AppKit
import SwiftUI

struct SitesView: View {
    @ObservedObject var state = AppState.shared
    @State private var draftProjects: [Project] = []
    @ObservedObject var processManager = ProcessManager.shared
    @State private var alert: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sites").font(.title2).bold()
                Spacer()
                Button("Add Site") { addProject() }
            }
            List {
                ForEach($draftProjects) { $project in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                TextField("Name", text: $project.name)
                                TextField("Path", text: $project.path)
                            }
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach($project.scripts) { $script in
                                        let isRunning = processManager.running[script.id] != nil
                                        Button(action: {
                                            toggleScript(script, for: project)
                                        }) {
                                            Text(script.name).padding(4)
                                                .background(
                                                    isRunning ? Color.green.opacity(0.5) : Color.gray.opacity(0.15)
                                                )
                                                .cornerRadius(4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        Spacer()
                        Button(action: {
                            if let index = draftProjects.firstIndex(where: { $0.id == project.id }) {
                                draftProjects.remove(at: index)
                            }
                        }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.red)
                    }
                }
                .onDelete { idx in draftProjects.remove(atOffsets: idx) }
            }
            HStack(alignment: .center) {
                Spacer()
                Button("Cancel") { close(false) }
                Button("Save") { close(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .onAppear { draftProjects = state.projects }
        .alert(item: Binding(get: { alert.map { SitesAlertItem(msg: $0) } }, set: { _ in alert = nil }))
        { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    func toggleScript(_ script: Script, for project: Project) {
        if processManager.running[script.id] != nil {
            processManager.stop(scriptID: script.id)
        } else {
            processManager.start(script: script, in: project)
            let logState = ScriptLogState(
                projectID: project.id, scriptID: script.id, title: "\(project.name): \(script.name)")
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

    func close(_ save: Bool) {
        if save {
            state.projects = draftProjects
            state.save()
        }
        SitesWindowController.shared.close()
    }
}

struct SitesAlertItem: Identifiable {
    let id = UUID()
    let msg: String
}
