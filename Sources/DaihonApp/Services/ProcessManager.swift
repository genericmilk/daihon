import Combine
import Darwin
import Foundation

#if DEBUG
    private var debugLogCount = 0
    private let maxDebugLogs = 500  // Limit debug logs for ProcessManager

    private func debugLog(_ message: String) {
        debugLogCount += 1
        if debugLogCount <= maxDebugLogs {
            print("[DEBUG ProcessManager] \(message)")
        } else if debugLogCount == maxDebugLogs + 1 {
            print("[DEBUG ProcessManager] Debug logging limit reached, suppressing further logs")
        }
    }
#else
    private func debugLog(_ message: String) {}
#endif

final class ProcessManager: ObservableObject {
    static let shared = ProcessManager()

    struct RunningProcess {
        let process: Process
        let outputPipe: Pipe
        let errorPipe: Pipe
    }

    @Published private(set) var running: [UUID: RunningProcess] = [:]  // key: Script.id
    private var subjects: [UUID: PassthroughSubject<String, Never>] = [:]

    private init() {}

    func start(script: Script, in project: Project) {
        guard running[script.id] == nil else { return }

        debugLog("Starting script: \(script.id) in project: \(project.path)")

        // Move process setup and launch to background thread to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.currentDirectoryURL = URL(fileURLWithPath: project.path)
            process.launchPath = "/bin/zsh"
            // Build command based on project's package manager (or global default)
            let pm = project.effectivePackageManager(
                globalDefault: AppState.shared.preferences.packageManager)
            let customPath = AppState.shared.preferences.customBinaryPath(for: pm)
            let baseCmd = pm.commandToRun(
                script: self.escape(script.command), customPath: customPath)
            // Keep stdout and stderr separate; we already pipe both below
            process.arguments = ["-lc", "\(baseCmd)"]

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Reuse a persistent subject so the UI doesn't lose subscription across restarts
            let subject = self.subject(for: script.id)

            let outHandle = outputPipe.fileHandleForReading
            let errHandle = errorPipe.fileHandleForReading

            // Announce start in persistent log (single entry)
            LogStore.shared.appendBoundary(
                "process started", projectID: project.id, scriptID: script.id)

            // Ensure file handle operations happen on background queues
            let outputQueue = DispatchQueue(
                label: "ProcessManager.output.\(script.id)", qos: .userInitiated)
            let errorQueue = DispatchQueue(
                label: "ProcessManager.error.\(script.id)", qos: .userInitiated)

            outHandle.readabilityHandler = { handle in
                outputQueue.async {
                    autoreleasepool {
                        let startTime = Date()
                        let data = handle.availableData
                        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                            // Persist first, then emit to subscribers
                            LogStore.shared.append(str, projectID: project.id, scriptID: script.id)
                            subject.send(str)
                            let duration = Date().timeIntervalSince(startTime)
                            debugLog(
                                "Output chunk processed in \(String(format: "%.3f", duration))s: \(data.count) bytes"
                            )
                        }
                    }
                }
            }

            errHandle.readabilityHandler = { handle in
                errorQueue.async {
                    autoreleasepool {
                        let startTime = Date()
                        let data = handle.availableData
                        if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                            LogStore.shared.append(str, projectID: project.id, scriptID: script.id)
                            subject.send(str)
                            let duration = Date().timeIntervalSince(startTime)
                            debugLog(
                                "Error chunk processed in \(String(format: "%.3f", duration))s: \(data.count) bytes"
                            )
                        }
                    }
                }
            }

            process.terminationHandler = { [weak self] _ in
                DispatchQueue.main.async {
                    LogStore.shared.appendBoundary(
                        "process exited", projectID: project.id, scriptID: script.id)
                    subject.send("\n— process exited —\n")
                    // Clean up handlers and mark not running
                    outHandle.readabilityHandler = nil
                    errHandle.readabilityHandler = nil
                    self?.running.removeValue(forKey: script.id)
                }
            }

            do {
                // Launch process on background thread to avoid blocking main thread
                try process.run()
                debugLog("Process launched successfully for script: \(script.id)")

                // Update running processes on main thread
                DispatchQueue.main.async {
                    self.running[script.id] = RunningProcess(
                        process: process, outputPipe: outputPipe, errorPipe: errorPipe)
                }
            } catch {
                debugLog("Failed to start process for script: \(script.id), error: \(error)")
                subject.send("Failed to start: \(error.localizedDescription)\n")
            }
        }
    }

    func stop(scriptID: UUID) {
        guard let r = running[scriptID] else { return }

        debugLog("Stopping script: \(scriptID)")

        // Move process termination to background thread to avoid blocking main thread
        DispatchQueue.global(qos: .utility).async {
            // Stop reading immediately to avoid further UI/log churn
            r.outputPipe.fileHandleForReading.readabilityHandler = nil
            r.errorPipe.fileHandleForReading.readabilityHandler = nil

            // Ask the process to terminate gracefully
            r.process.terminate()

            // Safety net: if it hasn't exited after a short delay, force kill
            let process = r.process
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) {
                if process.isRunning {
                    let pid = process.processIdentifier
                    if pid > 0 {
                        debugLog("Force killing process \(pid) for script: \(scriptID)")
                        _ = Darwin.kill(pid, SIGKILL)
                    }
                }
            }
            // Do not block the main thread with waitUntilExit(); cleanup occurs in terminationHandler
        }
    }

    func restart(script: Script, in project: Project) {
        debugLog("Restarting script: \(script.id)")

        // Stop the script if it's running
        if running[script.id] != nil {
            stop(scriptID: script.id)
        }

        // Wait a brief moment to ensure cleanup, then start
        // Use a longer delay to ensure the stop operation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.start(script: script, in: project)
        }
    }

    func logsPublisher(for scriptID: UUID) -> AnyPublisher<String, Never>? {
        // Only expose a publisher when running to preserve existing isRunning checks elsewhere
        let isRunning = running[scriptID] != nil
        debugLog("Publisher requested for script \(scriptID), running: \(isRunning)")

        guard isRunning else { return nil }

        // Batch bursts of output to reduce UI updates while preserving content ordering
        return subject(for: scriptID)
            .collect(
                .byTimeOrCount(DispatchQueue.global(qos: .userInitiated), .milliseconds(80), 200)
            )
            .map { chunks in
                let result = chunks.joined()
                debugLog("Batched \(chunks.count) chunks into \(result.count) characters")
                return result
            }
            .eraseToAnyPublisher()
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func subject(for scriptID: UUID) -> PassthroughSubject<String, Never> {
        if let s = subjects[scriptID] { return s }
        let s = PassthroughSubject<String, Never>()
        subjects[scriptID] = s
        return s
    }
}
