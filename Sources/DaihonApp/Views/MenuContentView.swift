import AppKit
import Combine
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var state = AppState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project selector
            if !state.projects.isEmpty {
                Picker("Project", selection: Binding(
                    get: { state.selectedProjectID ?? state.projects.first?.id ?? UUID() },
                    set: { state.selectedProjectID = $0 }
                )) {
                    ForEach(state.projects) { project in
                        Text(project.name).tag(project.id)
                    }
                }
                .pickerStyle(.automatic)
                .padding([.top, .horizontal], 8)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let sel = state.selectedProjectID, let proj = state.projects.first(where: { $0.id == sel }) {
                        ProjectRow(project: proj)
                    } else if let first = state.projects.first { // fallback
                        ProjectRow(project: first)
                    } else {
                        Text("No projects configured")
                            .foregroundColor(.secondary)
                            .padding(8)
                    }
                }
                .padding(8)
            }
            Divider()
            HStack {
                Button("Preferences") { PreferencesWindowController.shared.show() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .padding(8)
        }
        .frame(width: 320, height: 480)
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
    @State private var selectedIndex: Int = 0

    private enum ScriptAction: CaseIterable {
        case start, stop, logs
        var title: String {
            switch self {
            case .start: return "Start"
            case .stop: return "Stop"
            case .logs: return "Logs"
            }
        }
    }

    private var actions: [ScriptAction] {
        if isRunning {
            return [.stop, .logs]
        } else {
            return [.start, .logs]
        }
    }

    var body: some View {
        HStack {
            Text(script.name)
            Spacer()
            Picker("", selection: $selectedIndex) {
                ForEach(0..<actions.count, id: \.self) { index in
                    Text(actions[index].title).tag(index)
                }
            }
            .labelsHidden()
            .pickerStyle(.automatic)  // macOS popup style
            .frame(width: 90)
            .onChange(of: selectedIndex) { newValue in
                guard newValue < actions.count else { return }
                let action = actions[newValue]
                switch action {
                case .start: start()
                case .stop: stop()
                case .logs: openLogs()
                }
                // Always reset to primary action (index 0) for consistent labeling
                selectedIndex = 0
            }
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
