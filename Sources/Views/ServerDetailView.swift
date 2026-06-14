import SwiftUI
import AppKit

struct ServerDetailView: View {
    @EnvironmentObject var store: ServerStore
    let serverID: UUID
    @State private var tab: Tab = .volumes

    enum Tab: String, CaseIterable, Identifiable {
        case volumes = "Volumes"
        case protocols = "Ports & Protocols"
        case users = "Users"
        case advanced = "Advanced"
        case log = "Log"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .volumes: return "folder"
            case .protocols: return "network"
            case .users: return "person.2"
            case .advanced: return "gearshape"
            case .log: return "terminal"
            }
        }
    }

    var body: some View {
        if let idx = store.index(of: serverID) {
            let server = $store.servers[idx]
            let controller = store.controller(for: serverID)

            VStack(spacing: 0) {
                header(server: server, controller: controller)
                Divider()
                TabView(selection: $tab) {
                    VolumesTab(server: server).tabItem { Label(Tab.volumes.rawValue, systemImage: Tab.volumes.icon) }.tag(Tab.volumes)
                    ProtocolsTab(server: server).tabItem { Label(Tab.protocols.rawValue, systemImage: Tab.protocols.icon) }.tag(Tab.protocols)
                    UsersTab(server: server).tabItem { Label(Tab.users.rawValue, systemImage: Tab.users.icon) }.tag(Tab.users)
                    AdvancedTab(server: server).tabItem { Label(Tab.advanced.rawValue, systemImage: Tab.advanced.icon) }.tag(Tab.advanced)
                    LogTab(controller: controller).tabItem { Label(Tab.log.rawValue, systemImage: Tab.log.icon) }.tag(Tab.log)
                }
                .padding()
            }
        } else {
            Text("Server not found.")
        }
    }

    @ViewBuilder
    private func header(server: Binding<ServerInstance>, controller: ServerController) -> some View {
        HStack(spacing: 12) {
            TextField("Server name", text: server.name)
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .frame(maxWidth: 320)

            StatusDot(state: controller.state)
            statusText(controller.state)
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                openInBrowser(server.wrappedValue)
            } label: {
                Label("Open", systemImage: "safari")
            }
            .help("Open the HTTP interface in your browser")
            .disabled(!controller.isRunning)

            if controller.isRunning {
                Button { store.restart(serverID) } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                Button(role: .destructive) { store.stop(serverID) } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button {
                    store.start(serverID)
                    tab = .log
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func statusText(_ state: ServerController.State) -> some View {
        switch state {
        case .running(let pid): Text("Running · pid \(pid)")
        case .starting: Text("Starting…")
        case .stopped: Text("Stopped")
        case .failed(let m): Text("Failed: \(m)").foregroundStyle(.red)
        }
    }

    private func openInBrowser(_ server: ServerInstance) {
        let scheme = server.protocols.tlsMode == .httpsOnly ? "https" : "http"
        let port = server.protocols.primaryHTTPPort
        if let url = URL(string: "\(scheme)://127.0.0.1:\(port)/") {
            NSWorkspace.shared.open(url)
        }
    }
}
