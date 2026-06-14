import Foundation

/// copyparty permission letters. A user's access to a volume is one or more
/// of these combined (e.g. `rw`, `rwmd`, `wG`).
enum Permission: String, CaseIterable, Identifiable, Codable {
    case read = "r"      // browse + download
    case write = "w"     // upload
    case move = "m"      // move / rename
    case delete = "d"    // delete
    case get = "g"       // download by exact URL, no browsing
    case upget = "G"     // get + see own upload's filekey
    case admin = "a"     // admin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        case .move: return "Move/Rename"
        case .delete: return "Delete"
        case .get: return "Get (no listing)"
        case .upget: return "Upget"
        case .admin: return "Admin"
        }
    }
}

/// One row of a volume's `accs:` block: a permission combo granted to a set of
/// principals. A principal is a username, or `*` for everyone (incl. anonymous).
struct AccessRule: Codable, Identifiable, Hashable {
    var id = UUID()
    /// Ordered permission letters, e.g. ["r","w"] -> "rw".
    var permissions: [Permission] = [.read]
    /// Usernames, or the single token "*".
    var principals: [String] = ["*"]

    /// The permission letters concatenated (config `accs:` key), e.g. "rwmd".
    var permissionKey: String {
        // Preserve a stable, copyparty-friendly ordering.
        let order: [Permission] = [.read, .write, .move, .delete, .get, .upget, .admin]
        return order.filter { permissions.contains($0) }.map(\.rawValue).joined()
    }

    var principalsString: String {
        principals.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// A mounted directory: maps a URL path to a filesystem path, with per-user
/// access rules and optional volflags.
struct Volume: Codable, Identifiable, Hashable {
    var id = UUID()
    /// URL mount point, e.g. "/" or "/music".
    var urlPath: String = "/"
    /// Absolute filesystem path being shared.
    var fsPath: String = ""
    var access: [AccessRule] = [AccessRule()]
    /// Volume-specific flags, e.g. "e2d", "nodupe", "fk:4".
    var flags: [String] = []

    var displayName: String {
        urlPath.isEmpty ? "/" : urlPath
    }
}
