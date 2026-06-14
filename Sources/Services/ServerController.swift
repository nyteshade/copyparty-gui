import Foundation
import Combine

/// Owns the lifecycle of one running copyparty process: launches the bundled
/// Python with the generated config, streams output into a live log, and tracks
/// run state. One controller per ServerInstance.
@MainActor
final class ServerController: ObservableObject {

    enum State: Equatable {
        case stopped
        case starting
        case running(pid: Int32)
        case failed(String)

        var isActive: Bool {
            switch self {
            case .running, .starting: return true
            case .stopped, .failed: return false
            }
        }
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var log: String = ""

    let serverID: UUID
    private var process: Process?
    private var stdoutPipe: Pipe?
    private let maxLogBytes = 256 * 1024

    init(serverID: UUID) {
        self.serverID = serverID
    }

    var isRunning: Bool { state.isActive }

    /// Directory holding this instance's generated config + working files.
    private var workDir: URL {
        let dir = PythonRuntime.supportDirectory
            .appendingPathComponent("instances/\(serverID.uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var configURL: URL { workDir.appendingPathComponent("copyparty.conf") }

    // MARK: - Control

    func start(server: ServerInstance) {
        guard !state.isActive else { return }
        do {
            try PythonRuntime.validate()
        } catch {
            appendLine("error: \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
            return
        }

        // Pre-flight: copyparty aborts entirely if any listener can't bind, so
        // check every planned port first and refuse with a clear message.
        if let problem = preflightPorts(server.protocols) {
            appendLine("error: cannot start — port problem:")
            appendLine(problem)
            appendLine("Fix it in Ports & Protocols (change the port or disable that protocol), then Start again.")
            state = .failed("port conflict")
            return
        }

        // Write the config file.
        let conf = ConfigWriter.config(for: server)
        do {
            try conf.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            appendLine("error: could not write config — \(error.localizedDescription)")
            state = .failed("config write failed")
            return
        }

        log = ""
        appendLine("$ python copyparty-sfx.py -c \(configURL.lastPathComponent)")
        appendLine("# config:\n\(conf)")

        let proc = Process()
        proc.executableURL = PythonRuntime.pythonURL
        proc.arguments = [PythonRuntime.activeSFXURL.path, "-c", configURL.path]
        proc.currentDirectoryURL = workDir
        // Unbuffered python so logs stream live.
        var env = ProcessInfo.processInfo.environment
        env["PYTHONUNBUFFERED"] = "1"
        proc.environment = env

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.append(text) }
        }

        proc.terminationHandler = { [weak self] p in
            Task { @MainActor in self?.handleTermination(p) }
        }

        do {
            state = .starting
            try proc.run()
            self.process = proc
            self.stdoutPipe = pipe
            state = .running(pid: proc.processIdentifier)
            appendLine("# started (pid \(proc.processIdentifier))")
        } catch {
            appendLine("error: failed to launch — \(error.localizedDescription)")
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            state = .stopped
            return
        }
        appendLine("# stopping…")
        proc.terminate()
        // Escalate to SIGKILL if it doesn't exit promptly.
        let pid = proc.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if proc.isRunning { kill(pid, SIGKILL) }
        }
    }

    func restart(server: ServerInstance) {
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.start(server: server)
        }
    }

    /// Returns a human-readable description of the first unbindable port, or nil
    /// if every planned listener looks bindable.
    private func preflightPorts(_ p: ProtocolSettings) -> String? {
        var lines: [String] = []
        for l in p.plannedListeners {
            switch PortChecker.check(port: l.port, udp: l.udp, host: p.listenIP) {
            case .available, .unknown:
                continue
            case .inUse:
                lines.append("  • port \(l.port) (\(l.label)) is already in use by another process")
            case .needsPrivilege:
                lines.append("  • port \(l.port) (\(l.label)) needs administrator privileges — ports below 1024 require root; use a higher port (e.g. \(l.port + 3000))")
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    // MARK: - Internals

    private func handleTermination(_ proc: Process) {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        let code = proc.terminationStatus
        if proc.terminationReason == .uncaughtSignal {
            appendLine("# terminated (signal)")
        } else {
            appendLine("# exited (code \(code))")
        }
        // Code 0 or terminate-by-signal after a stop() is a clean stop.
        if case .failed = state {} else { state = .stopped }
        self.process = nil
        self.stdoutPipe = nil
    }

    private func append(_ text: String) {
        log += text
        if log.utf8.count > maxLogBytes {
            log = String(log.suffix(maxLogBytes / 2))
        }
    }

    private func appendLine(_ line: String) {
        append(line.hasSuffix("\n") ? line : line + "\n")
    }
}
