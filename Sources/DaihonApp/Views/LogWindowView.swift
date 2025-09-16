import AppKit
import Combine
import SwiftUI

struct LogWindowView: View {
    let logState: ScriptLogState
    @State private var logText: AttributedString = ""
    @State private var cancellable: AnyCancellable?
    @ObservedObject private var processManager = ProcessManager.shared
    private let bottomAnchorID = "log-bottom-anchor"

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
                    VStack(alignment: .leading, spacing: 0) {
                        Text(logText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        // Invisible anchor at the end for robust autoscroll
                        Color.clear.frame(height: 1).id(bottomAnchorID)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color.clear)
                .onAppear { scrollToBottom(proxy) }
                .onChange(of: logText) { _ in
                    scrollToBottom(proxy)
                }
            }
        }
        .padding(12)
        .glassPanel(radius: 16)
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

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        // Defer to next runloop to ensure layout is updated before scrolling
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.1)) {
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            }
        }
    }
}
