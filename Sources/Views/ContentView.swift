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
        // Keep the native sidebar toggle in the structure — removing it via
        // .toolbar(removing:) flips macOS 26's sidebar to an inset floating panel
        // and the full-height yellow bleed is lost. Instead we hide the native
        // toggle's view at the AppKit level (HideNativeSidebarToggle) and drive
        // the same action from our own control in the detail header.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ServerSidebar()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 340)
                .background(HideNativeSidebarToggle())
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
