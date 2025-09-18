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
    @State private var isPersistedLogTruncated = false
    private let persistedTailLimit = 512 * 1024
    private let persistedTailLabel = ByteCountFormatter.string(
        fromByteCount: Int64(512 * 1024), countStyle: .file)

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isPersistedLogTruncated {
                    truncatedNotice
                }

                ScrollViewReader { proxy in
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(logText)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 12)
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
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.primary.opacity(0.025))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(20)
            .glassPanel(radius: 16)
            .padding(.horizontal, 18)
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
                .ignoresSafeArea()
        }
        .alert(
            item: Binding(get: { alert.map { LogAlertItem(msg: $0) } }, set: { _ in alert = nil })
        ) { a in
            Alert(title: Text("Error"), message: Text(a.msg))
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label {
                Text(logState.title)
                    .font(.system(size: 16, weight: .semibold))
            } icon: {
                Image(systemName: "terminal")
                    .font(.system(size: 16, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .labelStyle(.titleAndIcon)

            Spacer()

            HStack(spacing: 8) {
                headerButton(systemName: "trash", help: "Clear log", action: clearLogs)
                headerButton(systemName: "doc.on.doc", help: "Copy log", action: copyLogs)
                headerButton(
                    systemName: "square.and.arrow.down", help: "Save log", action: saveLogs)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private var truncatedNotice: some View {
        Label {
            Text("Showing last \(persistedTailLabel) of saved log (older entries truncated)")
        } icon: {
            Image(systemName: "info.circle")
                .symbolVariant(.fill)
        }
        .font(.footnote)
        .foregroundColor(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func headerButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
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
        let projectID = logState.projectID
        let scriptID = logState.scriptID
        let limit = persistedTailLimit
        isPersistedLogTruncated = false
        DispatchQueue.global(qos: .userInitiated).async {
            let result = LogStore.shared.readTail(
                projectID: projectID, scriptID: scriptID, maxBytes: limit)
            DispatchQueue.main.async {
                self.isPersistedLogTruncated = result.truncated
                self.plainLogText = result.text
                var s = AttributedString(result.text)
                s.font = .system(.body, design: .monospaced)
                self.logText = s
            }
        }
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
        isPersistedLogTruncated = false
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
