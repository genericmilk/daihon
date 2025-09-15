import Combine
import Foundation

final class ProcessManager: ObservableObject {
    static let shared = ProcessManager()

    struct RunningProcess {
        let process: Process
        let outputPipe: Pipe
        let errorPipe: Pipe
        let logSubject: PassthroughSubject<String, Never>
    }

    @Published private(set) var running: [UUID: RunningProcess] = [:]  // key: Script.id

    private init() {}

    func start(script: Script, in project: Project) {
        guard running[script.id] == nil else { return }

        let process = Process()
        process.currentDirectoryURL = URL(fileURLWithPath: project.path)
        process.launchPath = "/bin/zsh"
        // Build command based on preferred package manager and merge stderr to stdout
        let pm = AppState.shared.preferences.packageManager
        let baseCmd = pm.commandToRun(script: escape(script.command))
        process.arguments = ["-lc", "\(baseCmd) 2>&1"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let subject = PassthroughSubject<String, Never>()

        let outHandle = outputPipe.fileHandleForReading
        let errHandle = errorPipe.fileHandleForReading

        outHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                subject.send(str)
            }
        }

        errHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                subject.send(str)
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                subject.send("\n— process exited —\n")
                subject.send(completion: .finished)
                self?.running.removeValue(forKey: script.id)
            }
        }

        do {
            try process.run()
            running[script.id] = RunningProcess(
                process: process, outputPipe: outputPipe, errorPipe: errorPipe, logSubject: subject)
        } catch {
            subject.send("Failed to start: \(error.localizedDescription)\n")
            subject.send(completion: .finished)
        }
    }

    func stop(scriptID: UUID) {
        guard let r = running[scriptID] else { return }
        r.process.terminate()
        r.process.waitUntilExit()
        running.removeValue(forKey: scriptID)
    }

    func logsPublisher(for scriptID: UUID) -> AnyPublisher<String, Never>? {
        running[scriptID]?.logSubject.eraseToAnyPublisher()
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
