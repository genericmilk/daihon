import Combine
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
        process.arguments = ["-lc", "\(baseCmd) 2>&1"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Reuse a persistent subject so the UI doesn't lose subscription across restarts
        let subject = self.subject(for: script.id)

        let outHandle = outputPipe.fileHandleForReading
        let errHandle = errorPipe.fileHandleForReading

        // Announce start in persistent log
        LogStore.shared.appendBoundary(
            "process started", projectID: project.id, scriptID: script.id)

        // Announce start in persistent log
        LogStore.shared.appendBoundary(
            "process started", projectID: project.id, scriptID: script.id)

        outHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                // Persist first, then emit to subscribers
                LogStore.shared.append(str, projectID: project.id, scriptID: script.id)
                subject.send(str)
            }
        }

        errHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                LogStore.shared.append(str, projectID: project.id, scriptID: script.id)
                subject.send(str)
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
        r.outputPipe.fileHandleForReading.readabilityHandler = nil
        r.errorPipe.fileHandleForReading.readabilityHandler = nil
        r.process.terminate()
        r.process.waitUntilExit()
        running.removeValue(forKey: scriptID)
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
        return subject(for: scriptID).eraseToAnyPublisher()
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
