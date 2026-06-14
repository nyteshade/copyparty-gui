import Foundation

/// One port that can't be bound, with a free port to use instead.
struct PortConflict: Identifiable, Hashable {
    let id = UUID()
    let label: String      // "HTTP", "FTP", …
    let current: Int
    let suggested: Int
    let reason: String     // "in use" / "needs root"
}

/// Detects port conflicts for a server's protocol settings and proposes free
/// replacements, so the app can offer to fix them instead of failing.
enum PortResolver {

    static func conflicts(in p: ProtocolSettings) -> [PortConflict] {
        var taken = Set<Int>()            // ports already kept or newly suggested
        var result: [PortConflict] = []

        for listener in p.plannedListeners {
            let status = PortChecker.check(port: listener.port, udp: listener.udp, host: p.listenIP)
            switch status {
            case .available, .unknown:
                taken.insert(listener.port)
            case .inUse, .needsPrivilege:
                // Start the search above privileged range for privileged ports.
                let from = status == .needsPrivilege ? max(listener.port + 3000, 1024)
                                                      : listener.port + 1
                let suggestion = PortChecker.firstAvailable(
                    from: from, host: p.listenIP, udp: listener.udp, excluding: taken)
                taken.insert(suggestion)
                result.append(PortConflict(
                    label: listener.label,
                    current: listener.port,
                    suggested: suggestion,
                    reason: status == .needsPrivilege ? "needs root" : "in use"))
            }
        }
        return result
    }

    /// Apply a single remap to the settings.
    static func apply(_ c: PortConflict, to p: inout ProtocolSettings) {
        switch c.label {
        case "HTTP":
            if let i = p.httpPorts.firstIndex(of: c.current) { p.httpPorts[i] = c.suggested }
        case "FTP":  p.ftpPort = c.suggested
        case "FTPS": p.ftpsPort = c.suggested
        case "SFTP": p.sftpPort = c.suggested
        case "TFTP": p.tftpPort = c.suggested
        case "SMB":  p.smbPort = c.suggested
        default: break
        }
    }

    static func applyAll(_ conflicts: [PortConflict], to p: inout ProtocolSettings) {
        for c in conflicts { apply(c, to: &p) }
    }

    /// Human-readable summary for an alert / log line.
    static func summary(_ conflicts: [PortConflict]) -> String {
        conflicts.map { "• \($0.label) port \($0.current) (\($0.reason)) → \($0.suggested)" }
            .joined(separator: "\n")
    }
}
