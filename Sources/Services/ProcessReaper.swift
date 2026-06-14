import Foundation
import Darwin

/// Ensures bundled copyparty child processes never outlive the app.
///
/// SwiftUI's `.onDisappear` and even `applicationWillTerminate` don't run when
/// the app receives SIGTERM (e.g. `pkill`), so a running server would orphan and
/// keep its port bound. This reaper:
///   1. tracks every live child PID (persisted to disk),
///   2. terminates them on quit / SIGTERM / SIGINT,
///   3. reaps leftovers from a previous run that was hard-killed (SIGKILL).
enum ProcessReaper {
    private static let lock = NSLock()
    private static var pids = Set<Int32>()
    private static var signalSources: [DispatchSourceSignal] = []

    private static var pidFileURL: URL {
        PythonRuntime.supportDirectory.appendingPathComponent("running.pids")
    }

    // MARK: - Tracking

    static func register(_ pid: Int32) {
        lock.lock(); defer { lock.unlock() }
        pids.insert(pid)
        persistLocked()
    }

    static func unregister(_ pid: Int32) {
        lock.lock(); defer { lock.unlock() }
        pids.remove(pid)
        persistLocked()
    }

    /// Terminate every tracked child. Delivered synchronously so the signal
    /// lands before the app exits; children handle SIGTERM and shut down even
    /// after we're gone.
    static func terminateAll() {
        lock.lock(); let snapshot = pids; lock.unlock()
        for pid in snapshot { kill(pid, SIGTERM) }
    }

    private static func persistLocked() {
        let text = pids.map(String.init).joined(separator: "\n")
        try? text.write(to: pidFileURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Lifecycle

    /// On launch, kill any copyparty children left over from a previous run.
    static func reapOrphansFromPreviousRun() {
        defer {
            try? FileManager.default.removeItem(at: pidFileURL)
            lock.lock(); pids.removeAll(); lock.unlock()
        }
        guard let text = try? String(contentsOf: pidFileURL, encoding: .utf8) else { return }
        for line in text.split(whereSeparator: \.isNewline) {
            guard let pid = Int32(line.trimmingCharacters(in: .whitespaces)) else { continue }
            if isOurCopyparty(pid) { kill(pid, SIGTERM) }
        }
    }

    /// Catch SIGTERM/SIGINT (default disposition would terminate us without any
    /// cleanup) and tear down children first.
    static func installTerminationHandlers() {
        for sig in [SIGTERM, SIGINT] {
            signal(sig, SIG_IGN)  // disable default so the dispatch source receives it
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                terminateAll()
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }

    /// True ONLY if `pid` is alive AND its command line is unmistakably a
    /// copyparty launched from a CopyParty.app bundle — i.e. our own child.
    /// This guards against PID reuse and guarantees we never signal an unrelated
    /// process (e.g. some other copyparty the user runs themselves).
    private static func isOurCopyparty(_ pid: Int32) -> Bool {
        guard kill(pid, 0) == 0 else { return false }   // must be alive
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/ps")
        proc.arguments = ["-p", "\(pid)", "-o", "command="]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do { try proc.run(); proc.waitUntilExit() } catch { return false }
        let cmd = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        // Both must be present: the copyparty sfx AND a CopyParty.app resource path.
        return cmd.contains("copyparty-sfx.py")
            && cmd.contains("CopyParty.app/Contents/Resources")
    }
}
