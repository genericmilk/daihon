import AppKit
import Combine
import SwiftUI

struct LogWindowView: View {
    let logState: ScriptLogState
    @State private var logText: AttributedString = ""
    @State private var cancellable: AnyCancellable?

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
        .onAppear { subscribe() }
        .onDisappear { cancellable?.cancel() }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Clear") { logText = "" }
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
        } else {
            logText = "No running process."
        }
    }
}
