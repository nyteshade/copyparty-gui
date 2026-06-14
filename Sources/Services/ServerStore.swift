import Foundation
import Combine

/// App-wide state: the list of configured server instances (persisted as JSON)
/// plus their live process controllers.
@MainActor
final class ServerStore: ObservableObject {

    @Published var servers: [ServerInstance] = [] {
        didSet { scheduleSave() }
    }
    @Published var selection: ServerInstance.ID?

    private var controllers: [UUID: ServerController] = [:]
    private var saveWorkItem: DispatchWorkItem?

    private var storeURL: URL {
        PythonRuntime.supportDirectory.appendingPathComponent("servers.json")
    }

    init() {
        load()
        if servers.isEmpty {
            servers = [.makeDefault(name: "My Files")]
        }
        selection = servers.first?.id
        // Honor autoStart flags on launch.
        for s in servers where s.autoStart {
            controller(for: s.id).start(server: s)
        }
    }

    // MARK: - Controllers

    func controller(for id: UUID) -> ServerController {
        if let c = controllers[id] { return c }
        let c = ServerController(serverID: id)
        controllers[id] = c
        return c
    }

    func server(id: UUID) -> ServerInstance? {
        servers.first { $0.id == id }
    }

    /// Binding-friendly index lookup for editing in place.
    func index(of id: UUID) -> Int? {
        servers.firstIndex { $0.id == id }
    }

    // MARK: - Mutations

    func addServer() {
        let new = ServerInstance.makeDefault(name: "New Server")
        servers.append(new)
        selection = new.id
    }

    func duplicate(_ id: UUID) {
        guard var copy = server(id: id) else { return }
        copy.id = UUID()
        copy.name += " copy"
        copy.autoStart = false
        servers.append(copy)
        selection = copy.id
    }

    func delete(_ id: UUID) {
        controllers[id]?.stop()
        controllers[id] = nil
        servers.removeAll { $0.id == id }
        if selection == id { selection = servers.first?.id }
    }

    // MARK: - Lifecycle helpers

    func start(_ id: UUID) {
        guard let s = server(id: id) else { return }
        controller(for: id).start(server: s)
    }

    func stop(_ id: UUID) {
        controllers[id]?.stop()
    }

    func restart(_ id: UUID) {
        guard let s = server(id: id) else { return }
        controller(for: id).restart(server: s)
    }

    /// Stop everything (called on app termination).
    func stopAll() {
        for c in controllers.values { c.stop() }
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.save() }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(servers)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("CopyParty: failed to save servers — \(error)")
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL) else { return }
        if let decoded = try? JSONDecoder().decode([ServerInstance].self, from: data) {
            servers = decoded
        }
    }
}
