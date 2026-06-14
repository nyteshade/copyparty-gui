import SwiftUI

struct ServerSidebar: View {
    @EnvironmentObject var store: ServerStore

    var body: some View {
        List(selection: $store.selection) {
            Section("Servers") {
                ForEach(store.servers) { server in
                    SidebarRow(serverID: server.id)
                        .tag(server.id)
                        .contextMenu {
                            Button("Duplicate") { store.duplicate(server.id) }
                            Button("Export…") { store.exportWithPanel(serverIDs: [server.id]) }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(server.id) }
                        }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    EngineStatusView()
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                Divider()
                HStack {
                    Button { store.addServer() } label: {
                        Label("Add Server", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    if let id = store.selection {
                        Button(role: .destructive) { store.delete(id) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(8)
            }
            .background(.bar)
        }
    }
}

private struct SidebarRow: View {
    @EnvironmentObject var store: ServerStore
    let serverID: UUID

    var body: some View {
        let server = store.server(id: serverID)
        let controller = store.controller(for: serverID)
        HStack(spacing: 8) {
            StatusDot(state: controller.state)
            VStack(alignment: .leading, spacing: 1) {
                Text(server?.name ?? "—")
                    .lineLimit(1)
                Text(subtitle(server))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if controller.isRunning {
                Button { store.stop(serverID) } label: {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.borderless)
                .help("Stop")
            } else {
                Button { store.requestStart(serverID) } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
                .help("Start")
            }
        }
        .padding(.vertical, 2)
    }

    private func subtitle(_ server: ServerInstance?) -> String {
        guard let server else { return "" }
        let ports = server.protocols.httpPorts.map(String.init).joined(separator: ",")
        let n = server.volumes.count
        return "port \(ports) · \(n) volume\(n == 1 ? "" : "s")"
    }
}

struct StatusDot: View {
    let state: ServerController.State
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .help(text)
    }
    private var color: Color {
        switch state {
        case .running: return .green
        case .starting: return .yellow
        case .failed: return .red
        case .stopped: return .secondary
        }
    }
    private var text: String {
        switch state {
        case .running(let pid): return "Running (pid \(pid))"
        case .starting: return "Starting…"
        case .failed(let m): return "Failed: \(m)"
        case .stopped: return "Stopped"
        }
    }
}
