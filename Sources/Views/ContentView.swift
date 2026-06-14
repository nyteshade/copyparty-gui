import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: ServerStore

    var body: some View {
        NavigationSplitView {
            ServerSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 340)
        } detail: {
            if let id = store.selection, store.server(id: id) != nil {
                ServerDetailView(serverID: id)
                    .id(id)
            } else {
                ContentUnavailableView(
                    "No Server Selected",
                    systemImage: "externaldrive.badge.wifi",
                    description: Text("Select a server on the left, or create a new one.")
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
