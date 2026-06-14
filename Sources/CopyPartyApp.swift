import SwiftUI
import AppKit

/// App delegate: overrides the Dock icon at launch (see DockIcon) and makes sure
/// bundled copyparty child processes never outlive the app (see ProcessReaper).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIcon.applyUnmaskedIcon()
        // Orphan reaping happens in ServerStore.init (before autostart) so it
        // can't kill a child we're about to launch. Here we only arm the
        // shutdown handlers.
        ProcessReaper.installTerminationHandlers()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ProcessReaper.terminateAll()
    }

    // Quitting should not be blocked by running servers; tear them down.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        ProcessReaper.terminateAll()
        return .terminateNow
    }
}

@main
struct CopyPartyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ServerStore()
    @StateObject private var updates = UpdateService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(updates)
                .frame(minWidth: 880, minHeight: 560)
                .task { await updates.checkForUpdates() }
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
