import SwiftUI

@main
struct CopyPartyApp: App {
    @StateObject private var store = ServerStore()
    @StateObject private var updates = UpdateService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(updates)
                .frame(minWidth: 880, minHeight: 560)
                .onAppear { updates.refreshCurrentVersion() }
                .onDisappear { store.stopAll() }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About CopyParty") { AboutWindowController.shared.show() }
            }
            CommandGroup(after: .appInfo) {
                Button("Check for copyparty Updates…") {
                    Task { await updates.checkForUpdates() }
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Server") { store.addServer() }
                    .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Import Configuration…") { store.importWithPanel() }
                    .keyboardShortcut("o", modifiers: .command)
                Button("Export All Configurations…") { store.exportWithPanel() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Export Selected Server…") {
                    if let id = store.selection { store.exportWithPanel(serverIDs: [id]) }
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(store.selection == nil)
            }
        }
    }
}
