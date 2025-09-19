import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

#if DEBUG
    private var debugLogCount = 0
    private let maxDebugLogs = 1000  // Limit debug logs to prevent spam

    private func debugLog(_ message: String) {
        debugLogCount += 1
        if debugLogCount <= maxDebugLogs {
            print("[DEBUG LogWindowView] \(message)")
        } else if debugLogCount == maxDebugLogs + 1 {
            print("[DEBUG LogWindowView] Debug logging limit reached, suppressing further logs")
        }
    }
#else
    private func debugLog(_ message: String) {}
#endif

struct LogWindowView: View {
    let logState: ScriptLogState
    @State private var plainLogText: String = ""
    @State private var cancellable: AnyCancellable?
    @ObservedObject private var processManager = ProcessManager.shared
    @State private var alert: String? = nil
    @State private var isPersistedLogTruncated = false
    private let persistedTailLimit = 512 * 1024
    private let persistedTailLabel = ByteCountFormatter.string(
        fromByteCount: Int64(512 * 1024), countStyle: .file)

    // Add memory limits for the in-memory log display
    private let inMemoryLimit = 1024 * 1024  // 1MB limit for in-memory display
    private let inMemoryTruncateSize = 512 * 1024  // Truncate to 512KB when limit exceeded

    // Batch text updates to reduce overhead
    @State private var pendingTextChunks: [String] = []
    @State private var isProcessingBatch = false
    private let batchTimeout: TimeInterval = 0.1  // 100ms batch window
    private let maxBatchSize = 50  // Maximum chunks to process in one batch

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isPersistedLogTruncated {
                    truncatedNotice
                }

                VStack(spacing: 0) {
                    LogTextView(text: $plainLogText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .padding(20)
            .glassPanel(radius: 16)
            .padding(.horizontal, 18)
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            debugLog("Starting log loading and subscription for script: \(logState.scriptID)")
            loadPersisted()
            subscribe()
        }
        .onDisappear {
            debugLog("LogWindowView disappearing for script: \(logState.scriptID)")
            cancellable?.cancel()
        }
        .onReceive(processManager.$running) { _ in
            // When the process restarts, re-subscribe to new publisher
            debugLog("Process state changed, re-subscribing for script: \(logState.scriptID)")
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

    private func headerButton(systemName: String, help: String, action: @escaping () -> Void)
        -> some View
    {
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
        debugLog("Setting up log subscription for script: \(logState.scriptID)")
        if let pub = ProcessManager.shared.logsPublisher(for: logState.scriptID) {
            cancellable =
                pub
                .receive(on: DispatchQueue.main)
                .sink { chunk in
                    debugLog("Received log chunk of \(chunk.count) characters")
                    self.appendLogChunk(chunk)
                }
        } else {
            debugLog("No publisher available for script: \(logState.scriptID)")
        }
    }

    private func appendLogChunk(_ chunk: String) {
        debugLog("Queuing chunk: \(chunk.count) chars for batched processing")

        // Add to batch queue
        pendingTextChunks.append(chunk)

        // Limit batch size to prevent excessive memory usage
        if pendingTextChunks.count > maxBatchSize {
            debugLog("Batch size limit reached, forcing immediate processing")
            if !isProcessingBatch {
                isProcessingBatch = true
                processPendingChunks()
            }
            return
        }

        // Process batch if not already processing
        if !isProcessingBatch {
            isProcessingBatch = true

            // Wait briefly to accumulate more chunks, then process the batch
            DispatchQueue.main.asyncAfter(deadline: .now() + batchTimeout) {
                self.processPendingChunks()
            }
        }
    }

    private func processPendingChunks() {
        guard !pendingTextChunks.isEmpty else {
            isProcessingBatch = false
            return
        }

        let startTime = Date()
        let chunksToProcess = pendingTextChunks
        pendingTextChunks.removeAll()

        let combinedChunk = chunksToProcess.joined()
        debugLog(
            "Processing batch of \(chunksToProcess.count) chunks, \(combinedChunk.count) total chars"
        )

        plainLogText.append(combinedChunk)

        // Check if we've exceeded the in-memory limit
        if plainLogText.utf8.count > inMemoryLimit {
            debugLog("Memory limit exceeded, truncating log")
            // Truncate to keep only the most recent content
            let targetSize = inMemoryTruncateSize
            let data = plainLogText.data(using: .utf8) ?? Data()

            if data.count > targetSize {
                let startIndex = data.count - targetSize
                let truncatedData = data.suffix(from: startIndex)

                // Find the first newline to avoid cutting mid-line
                if let newlineIndex = truncatedData.firstIndex(of: UInt8(ascii: "\n")) {
                    let fromNewline = truncatedData.suffix(from: newlineIndex + 1)
                    plainLogText = String(data: fromNewline, encoding: .utf8) ?? ""
                } else {
                    plainLogText = String(data: truncatedData, encoding: .utf8) ?? ""
                }

                // Update completed, no need for AttributedString processing
                let duration = Date().timeIntervalSince(startTime)
                debugLog(
                    "Log truncation and update completed in \(String(format: "%.3f", duration))s"
                )
                isProcessingBatch = false

                // Schedule next batch processing if there are pending chunks
                scheduleNextBatchProcessing()
            } else {
                isProcessingBatch = false
            }
        } else {
            // Normal case: text already appended, just finish processing
            let duration = Date().timeIntervalSince(startTime)
            debugLog("Batched log append completed in \(String(format: "%.3f", duration))s")
            isProcessingBatch = false

            // Schedule next batch processing if there are pending chunks
            scheduleNextBatchProcessing()
        }
    }

    private func scheduleNextBatchProcessing() {
        // Only schedule if there are pending chunks and we're not already processing
        guard !pendingTextChunks.isEmpty && !isProcessingBatch else { return }

        debugLog("Scheduling next batch processing - \(pendingTextChunks.count) chunks pending")

        // Use a small delay to prevent infinite loops and reduce CPU usage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if !self.isProcessingBatch && !self.pendingTextChunks.isEmpty {
                self.isProcessingBatch = true
                DispatchQueue.main.asyncAfter(deadline: .now() + self.batchTimeout) {
                    self.processPendingChunks()
                }
            }
        }
    }

    private func loadPersisted() {
        let projectID = logState.projectID
        let scriptID = logState.scriptID
        let limit = min(persistedTailLimit, inMemoryLimit)  // Use smaller of the two limits
        isPersistedLogTruncated = false

        debugLog("Loading persisted log for script: \(scriptID), limit: \(limit) bytes")

        DispatchQueue.global(qos: .userInitiated).async {
            let startTime = Date()
            let result = LogStore.shared.readTail(
                projectID: projectID, scriptID: scriptID, maxBytes: limit)

            let duration = Date().timeIntervalSince(startTime)
            debugLog(
                "Persisted log loaded in \(String(format: "%.3f", duration))s, \(result.text.count) chars, truncated: \(result.truncated)"
            )

            DispatchQueue.main.async {
                self.isPersistedLogTruncated = result.truncated
                self.plainLogText = result.text
                debugLog("Persisted log UI update completed")
            }
        }
    }

    private func clearLogs() {
        debugLog("Clearing logs for script: \(logState.scriptID)")
        LogStore.shared.clear(projectID: logState.projectID, scriptID: logState.scriptID)
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

// High-performance text view using NSTextView instead of SwiftUI Text
struct LogTextView: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        // Configure text view for optimal performance
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.labelColor
        textView.textContainerInset = NSSize(width: 10, height: 12)

        // Configure for performance
        textView.isRichText = false
        textView.allowsUndo = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false

        // Configure scroll view
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.backgroundColor = NSColor.clear

        // Configure text container for word wrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Only update if text actually changed to avoid unnecessary work
        if textView.string != text {
            let oldScrollPosition = nsView.contentView.bounds.origin
            let wasAtBottom =
                oldScrollPosition.y >= (nsView.documentView?.bounds.height ?? 0)
                - nsView.contentSize.height - 10

            // Update text efficiently
            textView.string = text

            // Auto-scroll to bottom if we were already at the bottom
            if wasAtBottom {
                DispatchQueue.main.async {
                    textView.scrollToEndOfDocument(nil)
                }
            }
        }
    }
}
