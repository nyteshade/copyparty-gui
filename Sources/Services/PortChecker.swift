import Foundation
import Darwin

/// Pre-flight availability check for a TCP/UDP port. copyparty aborts the whole
/// process if any single listener fails to bind, so we validate every planned
/// listener up front and surface a clear message instead of a crash.
enum PortChecker {

    enum Status: Equatable {
        case available
        case inUse           // EADDRINUSE — something is already listening
        case needsPrivilege  // EACCES — privileged port (<1024) without root
        case unknown         // couldn't determine; let copyparty try
    }

    /// Attempt to bind `port` the same way a server would (SO_REUSEADDR set, so
    /// this mirrors what copyparty itself can bind). The socket is closed
    /// immediately; this only probes availability.
    static func check(port: Int, udp: Bool = false, host: String = "0.0.0.0") -> Status {
        let fd = socket(AF_INET, udp ? SOCK_DGRAM : SOCK_STREAM, 0)
        guard fd >= 0 else { return .unknown }
        defer { close(fd) }

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(UInt16(truncatingIfNeeded: port).bigEndian)
        let bindHost = (host.isEmpty || host == "0.0.0.0") ? "0.0.0.0" : host
        addr.sin_addr.s_addr = inet_addr(bindHost)

        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if result == 0 { return .available }

        switch errno {
        case EADDRINUSE: return .inUse
        case EACCES:     return .needsPrivilege
        default:         return .unknown
        }
    }

    /// Find the first bindable port at or after `start` (kept ≥ 1024 to avoid
    /// privileged ports), skipping any in `excluding` so multiple remaps don't
    /// collide with each other.
    static func firstAvailable(from start: Int,
                               host: String = "0.0.0.0",
                               udp: Bool = false,
                               excluding: Set<Int> = []) -> Int {
        var port = max(1024, start)
        while port <= 65535 {
            if !excluding.contains(port), check(port: port, udp: udp, host: host) == .available {
                return port
            }
            port += 1
        }
        return start
    }
}

