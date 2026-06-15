import SwiftUI

struct ServerSidebar: View {
    @EnvironmentObject var store: ServerStore
    var onToggleSidebar: () -> Void = {}

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                Text("SERVERS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.sidebarInkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 2)

                ForEach(store.servers) { server in
                    SidebarRow(serverID: server.id)
                        .contextMenu {
                            Button("Duplicate") { store.duplicate(server.id) }
                            Button("Export…") { store.exportWithPanel(serverIDs: [server.id]) }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(server.id) }
                        }
                }
            }
            .padding(8)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Rectangle().fill(Theme.sidebarLine).frame(height: 1)
                HStack {
                    EngineStatusView()
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                Rectangle().fill(Theme.sidebarLine).frame(height: 1)
                HStack {
                    Button { store.addServer() } label: {
                        Label("Add Server", systemImage: "plus")
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.sidebarInk)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if let id = store.selection {
                        Button { store.delete(id) } label: {
                            Image(systemName: "trash").foregroundStyle(Theme.sidebarInk)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(10)
            }
            .background(Theme.sidebarBottom)
        }
        // Full-bleed glossy yellow behind everything (incl. under the titlebar
        // and to all edges) so the dark window background doesn't bleed through.
        .background(GlossySidebar().ignoresSafeArea())
        // Collapse control at the top-right, just below the titlebar drag band
        // (that band is an AppKit layer that eats clicks, so we can't sit a
        // working control inside it). Dark for contrast on the yellow.
        .overlay(alignment: .topTrailing) {
            Button(action: onToggleSidebar) {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.sidebarInk)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Collapse Sidebar")
            .padding(.trailing, 14)
            .padding(.top, 6)
        }
    }
}

private struct SidebarRow: View {
    @EnvironmentObject var store: ServerStore
    let serverID: UUID

    var body: some View {
        let server = store.server(id: serverID)
        let controller = store.controller(for: serverID)
        let selected = store.selection == serverID
        let primary = selected ? Color.white : Theme.sidebarInk
        let secondary = selected ? Color.white.opacity(0.88) : Theme.sidebarInkSecondary

        HStack(spacing: 8) {
            StatusDot(state: controller.state)
            VStack(alignment: .leading, spacing: 1) {
                Text(server?.name ?? "—")
                    .fontWeight(.semibold)
                    .foregroundStyle(primary)
                    .lineLimit(1)
                Text(subtitle(server))
                    .font(.caption)
                    .foregroundStyle(secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                controller.isRunning ? store.stop(serverID) : store.requestStart(serverID)
            } label: {
                Image(systemName: controller.isRunning ? "stop.fill" : "play.fill")
                    .foregroundStyle(primary)
            }
            .buttonStyle(.plain)
            .help(controller.isRunning ? "Stop" : "Start")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selected ? Theme.selectionFill : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { store.selection = serverID }
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
        case .stopped: return Color(hex: 0x8A8A8A)  // visible on both yellow and dark
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
