import Combine
import Darwin
import Foundation

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

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.launchPath = "/bin/zsh"
        // Build command based on project's package manager (or global default)
        let pm = project.effectivePackageManager(
            globalDefault: AppState.shared.preferences.packageManager)
        let baseCmd = pm.commandToRun(script: escape(script.command))
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

        outHandle.readabilityHandler = { handle in
            autoreleasepool {
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    // Persist first, then emit to subscribers
                    LogStore.shared.append(str, projectID: project.id, scriptID: script.id)
                    subject.send(str)
                }
            }
        }

        errHandle.readabilityHandler = { handle in
            autoreleasepool {
                let data = handle.availableData
                if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                    LogStore.shared.append(str, projectID: project.id, scriptID: script.id)
                    subject.send(str)
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
            try process.run()
            running[script.id] = RunningProcess(
                process: process, outputPipe: outputPipe, errorPipe: errorPipe)
        } catch {
            subject.send("Failed to start: \(error.localizedDescription)\n")
        }
    }

    func stop(scriptID: UUID) {
        guard let r = running[scriptID] else { return }
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
                    _ = Darwin.kill(pid, SIGKILL)
                }
            }
        }
        // Do not block the main thread with waitUntilExit(); cleanup occurs in terminationHandler
    }

    func restart(script: Script, in project: Project) {
        // Stop the script if it's running
        if running[script.id] != nil {
            stop(scriptID: script.id)
        }

        // Wait a brief moment to ensure cleanup, then start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.start(script: script, in: project)
        }
    }

    func logsPublisher(for scriptID: UUID) -> AnyPublisher<String, Never>? {
        // Only expose a publisher when running to preserve existing isRunning checks elsewhere
        guard running[scriptID] != nil else { return nil }
        // Batch bursts of output to reduce UI updates while preserving content ordering
        return subject(for: scriptID)
            .collect(
                .byTimeOrCount(DispatchQueue.global(qos: .userInitiated), .milliseconds(80), 200)
            )
            .map { $0.joined() }
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
