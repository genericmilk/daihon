import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var state = AppState.shared
    @State private var draftProjects: [Project] = []
    @State private var alert: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projects").font(.title2).bold()
                Spacer()
                Button("Add Project") { addProject() }
            }
            List {
                ForEach($draftProjects) { $project in
                    VStack(alignment: .leading) {
                        HStack {
                            TextField("Name", text: $project.name)
                            TextField("Path", text: $project.path)
                        }
                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(project.scripts) { s in
                                    Text(s.name).padding(4).background(Color.gray.opacity(0.15))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                .onDelete { idx in draftProjects.remove(atOffsets: idx) }
            }
            HStack {
                Spacer()
                Button("Cancel") { close(false) }
                Button("Save") { close(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .onAppear { draftProjects = state.projects }
        .alert(item: Binding(get: { alert.map { AlertItem(msg: $0) } }, set: { _ in alert = nil }))
        { a in
            Alert(title: Text("Error"), message: Text(a.msg))
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
        state.showingPreferences = false
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let msg: String
}
