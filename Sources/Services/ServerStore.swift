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

    /// A start request that hit a port conflict and is awaiting the user's
    /// decision (drives the "Port already in use" alert in ContentView).
    struct PendingConflict: Identifiable {
        let id = UUID()
        let serverID: UUID
        let serverName: String
        let conflicts: [PortConflict]
    }
    @Published var pendingConflict: PendingConflict?

    private var controllers: [UUID: ServerController] = [:]
    private var saveWorkItem: DispatchWorkItem?

    private var storeURL: URL {
        PythonRuntime.supportDirectory.appendingPathComponent("servers.json")
    }

    init() {
        // Reap any orphans from a previous hard-killed run and reset the PID
        // file FIRST — before autostart registers this run's children, so the
        // reaper can never kill a child we're about to launch.
        ProcessReaper.reapOrphansFromPreviousRun()

        load()
        if servers.isEmpty {
            servers = [.makeDefault(name: "My Files")]
        }
        selection = servers.first?.id
        // Honor autoStart flags on launch. No user is present to confirm, so
        // auto-adjust any busy ports to free ones and note it in the log.
        for i in servers.indices where servers[i].autoStart {
            autoResolveAndStart(index: i)
        }
    }

    /// Used for autostart: silently remap any conflicting ports, log what
    /// changed, then start.
    private func autoResolveAndStart(index i: Int) {
        let conflicts = PortResolver.conflicts(in: servers[i].protocols)
        let controller = controller(for: servers[i].id)
        if !conflicts.isEmpty {
            PortResolver.applyAll(conflicts, to: &servers[i].protocols)
            controller.logNote("# auto-adjusted busy ports on launch:\n" + PortResolver.summary(conflicts))
        }
        controller.start(server: servers[i])
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

    /// Entry point for the UI Start buttons: if any port is in use, raise a
    /// pending conflict (the alert offers to fix it); otherwise start now.
    func requestStart(_ id: UUID) {
        guard let s = server(id: id) else { return }
        let conflicts = PortResolver.conflicts(in: s.protocols)
        if conflicts.isEmpty {
            controller(for: id).start(server: s)
        } else {
            pendingConflict = PendingConflict(serverID: id, serverName: s.name, conflicts: conflicts)
        }
    }

    /// User accepted the suggested free ports: apply them and start.
    func confirmStartWithFix() {
        guard let pc = pendingConflict, let idx = index(of: pc.serverID) else { return }
        PortResolver.applyAll(pc.conflicts, to: &servers[idx].protocols)
        let s = servers[idx]
        pendingConflict = nil
        controller(for: pc.serverID).start(server: s)
    }

    func cancelPendingStart() {
        pendingConflict = nil
    }

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
