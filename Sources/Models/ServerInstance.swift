import Foundation

/// Global / indexing options that map to copyparty's `[global]` section.
struct GlobalOptions: Codable, Hashable {
    var serverName: String = ""            // --name
    var indexUploads: Bool = false         // e2dsa (scan + index on startup)
    var indexTags: Bool = false            // e2ts (media tags)
    var disableThumbnails: Bool = false    // --no-thumb (thumbs are on by default)
    var requireUsername: Bool = false      // --usernames
    var maxClients: Int = 1024             // -nc
    /// Free-form extra CLI flags appended verbatim to [global], one per line.
    var extraFlags: String = ""
}

/// A single copyparty server: its own process, ports, volumes, users and flags.
/// Multiple instances run concurrently to serve different directories on
/// different ports.
struct ServerInstance: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String = "New Server"
    var autoStart: Bool = false
    var protocols = ProtocolSettings()
    var volumes: [Volume] = []
    var accounts: [Account] = []
    var global = GlobalOptions()

    /// A fresh instance pre-populated with a sensible default volume.
    static func makeDefault(name: String = "New Server") -> ServerInstance {
        var s = ServerInstance()
        s.name = name
        var vol = Volume()
        vol.urlPath = "/"
        vol.fsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Public").path
        vol.access = [AccessRule(permissions: [.read], principals: ["*"])]
        s.volumes = [vol]
        return s
    }
}
