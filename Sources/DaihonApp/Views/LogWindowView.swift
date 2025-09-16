import AppKit
import Combine
import SwiftUI

struct LogWindowView: View {
    let logState: ScriptLogState
    @State private var logText: AttributedString = ""
    @State private var cancellable: AnyCancellable?
    @ObservedObject private var processManager = ProcessManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(logState.title).font(.headline)
                Spacer()
            }
            .padding(8)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("bottom")
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: logText) { _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
        .onAppear {
            loadPersisted()
            subscribe()
        }
        .onDisappear { cancellable?.cancel() }
        .onReceive(processManager.$running) { _ in
            // When the process restarts, re-subscribe to new publisher
            cancellable?.cancel()
            subscribe()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Clear") {
                    LogStore.shared.clear(projectID: logState.projectID, scriptID: logState.scriptID)
                    logText = ""
                }
            }
        }
    }

    func subscribe() {
        if let pub = ProcessManager.shared.logsPublisher(for: logState.scriptID) {
            cancellable = pub.receive(on: DispatchQueue.main).sink { chunk in
                var s = AttributedString(chunk)
                s.font = .system(.body, design: .monospaced)
                logText.append(s)
            }
        }
    }

    private func loadPersisted() {
        let existing = LogStore.shared.read(projectID: logState.projectID, scriptID: logState.scriptID)
        var s = AttributedString(existing)
        s.font = .system(.body, design: .monospaced)
        logText = s
    }
}
