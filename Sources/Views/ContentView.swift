import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ServerStore
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ServerSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 340)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            if let id = store.selection, store.server(id: id) != nil {
                ServerDetailView(serverID: id, onToggleSidebar: toggleSidebar)
                    .id(id)
            } else {
                ContentUnavailableView(
                    "No Server Selected",
                    systemImage: "externaldrive.badge.wifi",
                    description: Text("Select a server on the left, or create a new one.")
                )
                .background(
                    ZStack { Theme.detailBG; CassetteWatermark() }.ignoresSafeArea()
                )
            }
        }
        .alert(
            "Port already in use",
            isPresented: Binding(
                get: { store.pendingConflict != nil },
                set: { if !$0 { store.cancelPendingStart() } }
            ),
            presenting: store.pendingConflict
        ) { _ in
            Button("Fix & Start") { store.confirmStartWithFix() }
            Button("Cancel", role: .cancel) { store.cancelPendingStart() }
        } message: { pc in
            Text("\(pc.serverName) can't use these ports right now:\n\n\(PortResolver.summary(pc.conflicts))\n\nCopyParty can switch to the free ports shown and start.")
        }
    }
}
