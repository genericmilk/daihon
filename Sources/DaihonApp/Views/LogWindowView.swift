import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

struct LogWindowView: View {
    let logState: ScriptLogState
    @State private var logText: AttributedString = ""
    @State private var plainLogText: String = ""
    @State private var cancellable: AnyCancellable?
    @ObservedObject private var processManager = ProcessManager.shared
    private let bottomAnchorID = "log-bottom-anchor"
    @State private var alert: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header styled to match app design
            HStack(spacing: 12) {
                Text(logState.title)
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: clearLogs) {
                        Label("Clear", systemImage: "trash")
                    }
                    Button(action: copyLogs) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button(action: saveLogs) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.primary.opacity(0.06)),
                alignment: .bottom
            )

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
        .alert(
            item: Binding(get: { alert.map { LogAlertItem(msg: $0) } }, set: { _ in alert = nil })
        ) { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    func subscribe() {
        if let pub = ProcessManager.shared.logsPublisher(for: logState.scriptID) {
            cancellable = pub.receive(on: DispatchQueue.main).sink { chunk in
                plainLogText.append(chunk)
                var s = AttributedString(chunk)
                s.font = .system(.body, design: .monospaced)
                logText.append(s)
            }
        }
    }

    private func loadPersisted() {
        let existing = LogStore.shared.read(
            projectID: logState.projectID, scriptID: logState.scriptID)
        var s = AttributedString(existing)
        s.font = .system(.body, design: .monospaced)
        logText = s
        plainLogText = existing
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        // Defer to next runloop to ensure layout is updated before scrolling
        DispatchQueue.main.async {
            // Avoid extra animations during heavy log output to reduce UI jank
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0
                proxy.scrollTo(bottomAnchorID, anchor: .bottom)
            })
        }
    }

    private func clearLogs() {
        LogStore.shared.clear(projectID: logState.projectID, scriptID: logState.scriptID)
        logText = ""
        plainLogText = ""
    }

    private func copyLogs() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(plainLogText, forType: .string)
    }

    private func saveLogs() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = defaultLogFileName()
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [
                UTType(filenameExtension: "log") ?? .plainText, .plainText,
            ]
        }
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try plainLogText.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                alert = "Failed to save log: \(error.localizedDescription)"
            }
        }
    }

    private func defaultLogFileName() -> String {
        let base = logState.title
            .replacingOccurrences(of: " • ", with: "-")
            .replacingOccurrences(of: ": ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        return "\(base)-\(df.string(from: Date())).log"
    }
}

struct LogAlertItem: Identifiable {
    let id = UUID()
    let msg: String
}
