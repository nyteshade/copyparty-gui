import Foundation

/// Resolves paths to the embedded Python interpreter and the active
/// copyparty-sfx.py (a user-downloaded update takes precedence over the
/// bundled copy).
enum PythonRuntime {

    enum RuntimeError: LocalizedError {
        case pythonMissing
        case sfxMissing
        var errorDescription: String? {
            switch self {
            case .pythonMissing: return "Embedded Python runtime not found in the app bundle."
            case .sfxMissing: return "copyparty-sfx.py not found."
            }
        }
    }

    /// Contents/Resources inside the running .app.
    private static var resources: URL {
        Bundle.main.resourceURL ?? Bundle.main.bundleURL
    }

    /// Path to the bundled relocatable CPython.
    static var pythonURL: URL {
        resources.appendingPathComponent("python/bin/python3")
    }

    /// Bundled copyparty-sfx.py (shipped with the app).
    static var bundledSFXURL: URL {
        resources.appendingPathComponent("copyparty/copyparty-sfx.py")
    }

    /// Where downloaded sfx updates live.
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
            .appendingPathComponent("CopyParty", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// A downloaded update, if present.
    static var downloadedSFXURL: URL {
        supportDirectory.appendingPathComponent("copyparty-sfx.py")
    }

    /// The sfx that should actually be run: a downloaded update if present,
    /// else the bundled copy.
    static var activeSFXURL: URL {
        let dl = downloadedSFXURL
        if FileManager.default.fileExists(atPath: dl.path) { return dl }
        return bundledSFXURL
    }

    static func validate() throws {
        let fm = FileManager.default
        guard fm.isExecutableFile(atPath: pythonURL.path) else { throw RuntimeError.pythonMissing }
        guard fm.fileExists(atPath: activeSFXURL.path) else { throw RuntimeError.sfxMissing }
    }

    /// Run copyparty with the given args synchronously and return stdout+stderr.
    /// Used for `--version` probes. Not for the long-running server.
    @discardableResult
    static func runCopyparty(arguments: [String], timeout: TimeInterval = 20) throws -> String {
        let proc = Process()
        proc.executableURL = pythonURL
        proc.arguments = [activeSFXURL.path] + arguments
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()

        let deadline = Date().addingTimeInterval(timeout)
        while proc.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if proc.isRunning { proc.terminate() }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    /// Parse the copyparty version from its banner text, e.g.
    /// "[SFX]    this is: copyparty 1.20.16" or "copyparty v1.20.16 ...".
    static func parseVersion(from text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            if let r = line.range(of: "this is: copyparty ") {
                let tail = line[r.upperBound...].trimmingCharacters(in: .whitespaces)
                return tail.split(separator: " ").first.map(String.init)
            }
        }
        // Fallback: "copyparty v1.2.3"
        if let r = text.range(of: #"copyparty v?(\d+\.\d+\.\d+)"#, options: .regularExpression) {
            return text[r].replacingOccurrences(of: "copyparty ", with: "")
                .replacingOccurrences(of: "v", with: "")
        }
        return nil
    }

    /// Probe the active sfx for its version string.
    static func activeVersion() -> String? {
        guard let out = try? runCopyparty(arguments: ["--version"]) else { return nil }
        return parseVersion(from: out)
    }
}
