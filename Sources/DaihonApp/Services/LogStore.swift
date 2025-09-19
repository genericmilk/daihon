import Foundation

#if DEBUG
    private func debugLog(_ message: String) {
        print("[DEBUG LogStore] \(message)")
    }
#else
    private func debugLog(_ message: String) {}
#endif

final class LogStore {
    static let shared = LogStore()

    private let fm = FileManager.default
    private let queue = DispatchQueue(label: "LogStore.serial")

    private init() {}

    // MARK: - Public API
    func append(_ text: String, projectID: UUID, scriptID: UUID) {
        let url = logURL(projectID: projectID, scriptID: scriptID)
        debugLog("Appending \(text.count) chars to log for script: \(scriptID)")
        queue.async {
            let startTime = Date()
            self.ensureParentDirectory(for: url)
            if let data = text.data(using: .utf8) {
                if self.fm.fileExists(atPath: url.path) {
                    do {
                        let handle = try FileHandle(forWritingTo: url)
                        defer { try? handle.close() }
                        try handle.seekToEnd()
                        try handle.write(contentsOf: data)
                        let duration = Date().timeIntervalSince(startTime)
                        debugLog("Append completed in \(String(format: "%.3f", duration))s")
                    } catch {
                        debugLog("Write error: \(error)")
                        // Ignore write errors for now to avoid UI disruption
                    }
                } else {
                    do {
                        try data.write(to: url)
                        let duration = Date().timeIntervalSince(startTime)
                        debugLog("New file write completed in \(String(format: "%.3f", duration))s")
                    } catch {
                        debugLog("New file write error: \(error)")
                        // Ignore write errors for now
                    }
                }
            }
        }
    }

    func read(projectID: UUID, scriptID: UUID) -> String {
        let url = logURL(projectID: projectID, scriptID: scriptID)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    func readTail(projectID: UUID, scriptID: UUID, maxBytes: Int) -> (text: String, truncated: Bool)
    {
        guard maxBytes > 0 else { return ("", false) }
        let url = logURL(projectID: projectID, scriptID: scriptID)
        guard fm.fileExists(atPath: url.path) else {
            debugLog("Log file does not exist for script: \(scriptID)")
            return ("", false)
        }

        let startTime = Date()
        debugLog("Reading tail of \(maxBytes) bytes for script: \(scriptID)")

        do {
            let attrs = try fm.attributesOfItem(atPath: url.path)
            if let sizeNumber = attrs[.size] as? NSNumber {
                let fileSize = sizeNumber.intValue
                debugLog("Log file size: \(fileSize) bytes")

                if fileSize <= maxBytes {
                    let result = read(projectID: projectID, scriptID: scriptID)
                    let duration = Date().timeIntervalSince(startTime)
                    debugLog("Full file read completed in \(String(format: "%.3f", duration))s")
                    return (result, false)
                }

                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }

                let offset = UInt64(max(0, fileSize - maxBytes))
                try handle.seek(toOffset: offset)
                var data = handle.readDataToEndOfFile()

                if offset > 0, let newlineIndex = data.firstIndex(of: UInt8(ascii: "\n")) {
                    let nextIndex = data.index(after: newlineIndex)
                    data = data.suffix(from: nextIndex)
                }

                let text = String(decoding: data, as: UTF8.self)
                let duration = Date().timeIntervalSince(startTime)
                debugLog(
                    "Tail read completed in \(String(format: "%.3f", duration))s, returned \(text.count) chars"
                )
                return (text, true)
            }
        } catch {
            debugLog("Read error: \(error)")
            // Intentionally fall through to return default below
        }

        return ("", false)
    }

    func clear(projectID: UUID, scriptID: UUID) {
        let url = logURL(projectID: projectID, scriptID: scriptID)
        queue.async {
            try? "".write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func appendBoundary(_ event: String, projectID: UUID, scriptID: UUID) {
        let stamp = Self.timestamp()
        append("\n— \(event) — \(stamp)\n", projectID: projectID, scriptID: scriptID)
    }

    // MARK: - Paths
    private func baseLogsDirectory() -> URL {
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("Daihon", isDirectory: true)
        let logsDir = appDir.appendingPathComponent("Logs", isDirectory: true)
        try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
        return logsDir
    }

    private func logURL(projectID: UUID, scriptID: UUID) -> URL {
        baseLogsDirectory()
            .appendingPathComponent(projectID.uuidString, isDirectory: true)
            .appendingPathComponent("\(scriptID.uuidString).log", isDirectory: false)
    }

    private func ensureParentDirectory(for url: URL) {
        let parent = url.deletingLastPathComponent()
        if !fm.fileExists(atPath: parent.path) {
            try? fm.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: Date())
    }
}
