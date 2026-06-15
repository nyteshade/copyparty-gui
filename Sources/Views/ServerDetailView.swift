import SwiftUI
import AppKit

struct ServerDetailView: View {
    @EnvironmentObject var store: ServerStore
    let serverID: UUID
    var onToggleSidebar: () -> Void = {}
    var showSidebarToggle: Bool = false
    @State private var tab: Tab = .volumes
    @State private var editingName = false
    @FocusState private var nameFocused: Bool

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
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                Divider().opacity(0.3)

                tabBar()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider().opacity(0.25)

                tabContent(server: server, controller: controller)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(
                ZStack {
                    Theme.detailBG
                    CassetteWatermark()
                }
                .ignoresSafeArea()
            )
        } else {
            Text("Server not found.")
        }
    }

    /// Custom segmented control — full-contrast labels (the system picker's
    /// unselected text was too light on the dark chrome).
    @ViewBuilder
    private func tabBar() -> some View {
        HStack(spacing: 3) {
            ForEach(Tab.allCases) { t in
                tabSegment(t)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary, lineWidth: 0.5))
        )
    }

    @ViewBuilder
    private func tabSegment(_ t: Tab) -> some View {
        let selected = tab == t
        let fill: Color = selected ? Theme.selectionFill : .clear
        Text(t.rawValue)
            .font(.callout.weight(selected ? .semibold : .medium))
            .foregroundStyle(selected ? Color.white : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7).fill(fill))
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeOut(duration: 0.12)) { tab = t } }
    }

    @ViewBuilder
    private func tabContent(server: Binding<ServerInstance>, controller: ServerController) -> some View {
        switch tab {
        case .volumes:   VolumesTab(server: server).padding(20)
        case .protocols: ProtocolsTab(server: server)
        case .users:     UsersTab(server: server).padding(20)
        case .advanced:  AdvancedTab(server: server)
        case .log:       LogTab(controller: controller).padding(20)
        }
    }

    @ViewBuilder
    private func header(server: Binding<ServerInstance>, controller: ServerController) -> some View {
        HStack(spacing: 12) {
            if showSidebarToggle {
                Button(action: onToggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.borderless)
                .help("Show Sidebar")
            }

            // Name is a label by default; double-click (or the pencil) to rename,
            // so a stray click/keystroke when the window gains focus can't change it.
            if editingName {
                TextField("Server name", text: server.name)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: 320)
                    .focused($nameFocused)
                    .onSubmit { editingName = false }
                    .onChange(of: nameFocused) { _, focused in if !focused { editingName = false } }
                    .task { nameFocused = true }
            } else {
                HStack(spacing: 6) {
                    Text(server.wrappedValue.name.isEmpty ? "Untitled Server" : server.wrappedValue.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Button { editingName = true } label: {
                        Image(systemName: "pencil").font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .help("Rename server")
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editingName = true }
                .help("Double-click to rename")
            }

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
                    store.requestStart(serverID)
                    tab = .log
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(CassetteButtonStyle())
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
