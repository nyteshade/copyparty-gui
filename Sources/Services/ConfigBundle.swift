import Foundation
import AppKit
import UniformTypeIdentifiers

/// A portable, versioned snapshot of one or more server setups. This is what
/// "Export Configuration…" writes and "Import Configuration…" reads, so a single
/// file can carry several servers — each with multiple volumes/endpoints, users,
/// and protocol settings.
struct ConfigBundle: Codable {
    var format: String = ConfigBundle.formatID
    var version: Int = 1
    var exportedAt: Date = Date()
    var servers: [ServerInstance]

    static let formatID = "copyparty-app-config"
}

extension ServerStore {

    private static var jsonEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Encode the given servers (or all of them) as a portable bundle.
    func encodeBundle(serverIDs: [UUID]? = nil) -> Data? {
        let chosen: [ServerInstance]
        if let ids = serverIDs {
            chosen = servers.filter { ids.contains($0.id) }
        } else {
            chosen = servers
        }
        let bundle = ConfigBundle(servers: chosen)
        return try? Self.jsonEncoder.encode(bundle)
    }

    /// Decode a bundle (or a bare server array) and append it, giving every
    /// imported server a fresh id so re-imports never collide. Returns the count.
    @discardableResult
    func importBundle(data: Data) -> Int {
        var incoming: [ServerInstance] = []
        if let bundle = try? Self.jsonDecoder.decode(ConfigBundle.self, from: data) {
            incoming = bundle.servers
        } else if let arr = try? Self.jsonDecoder.decode([ServerInstance].self, from: data) {
            incoming = arr
        } else {
            return 0
        }
        let refreshed = incoming.map { server -> ServerInstance in
            var s = server
            s.id = UUID()
            s.autoStart = false
            return s
        }
        guard !refreshed.isEmpty else { return 0 }
        servers.append(contentsOf: refreshed)
        selection = refreshed.first?.id
        return refreshed.count
    }

    // MARK: - Panels

    func exportWithPanel(serverIDs: [UUID]? = nil) {
        guard let data = encodeBundle(serverIDs: serverIDs) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultExportName(serverIDs: serverIDs)
        panel.canCreateDirectories = true
        panel.title = "Export CopyParty Configuration"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    func importWithPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Import CopyParty Configuration"
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            importBundle(data: data)
        }
    }

    private func defaultExportName(serverIDs: [UUID]?) -> String {
        if let ids = serverIDs, ids.count == 1, let s = server(id: ids[0]) {
            let safe = s.name.replacingOccurrences(of: "/", with: "-")
            return "\(safe).copyparty.json"
        }
        return "copyparty-config.json"
    }
}
