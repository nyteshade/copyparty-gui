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
    }
}
