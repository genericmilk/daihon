import AppKit
import Combine
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var state = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.projects) { project in
                        ProjectRow(project: project)
                    }
                }
                .padding(8)
            }
            Divider()
            HStack {
                Button("Preferences") { state.showingPreferences = true }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding(8)
        }
        .frame(width: 320, height: 480)
        .sheet(isPresented: $state.showingPreferences) {
            PreferencesView()
                .frame(minWidth: 560, minHeight: 420)
        }
        .sheet(item: $state.activeLog) { item in
            LogWindowView(logState: item)
                .frame(minWidth: 700, minHeight: 400)
        }
    }
}

struct ProjectRow: View {
    @ObservedObject var state = AppState.shared
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.name)
                .font(.headline)
            ForEach(project.scripts) { script in
                ScriptRow(project: project, script: script)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ScriptRow: View {
    @ObservedObject var state = AppState.shared
    let project: Project
    let script: Script
    @State private var isRunning: Bool = false

    var body: some View {
        HStack {
            Text(script.name)
            Spacer()
            Menu(isRunning ? "Stop" : "Start") {
                if isRunning {
                    Button("Stop") { stop() }
                } else {
                    Button("Start") { start() }
                }
                Button("Logs") { openLogs() }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .onAppear { isRunning = ProcessManager.shared.logsPublisher(for: script.id) != nil }
    }

    func start() {
        ProcessManager.shared.start(script: script, in: project)
        isRunning = true
    }

    func stop() {
        ProcessManager.shared.stop(scriptID: script.id)
        isRunning = false
    }

    func openLogs() {
        state.activeLog = ScriptLogState(
            projectID: project.id, scriptID: script.id, title: "\(project.name) • \(script.name)")
    }
}
