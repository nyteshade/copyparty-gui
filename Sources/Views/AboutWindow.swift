import SwiftUI
import AppKit

/// Lazily-created custom About window, shown from the "About CopyParty" menu
/// item. Built as an AppKit-hosted window so it can be summoned directly from a
/// menu-command action.
@MainActor
final class AboutWindowController {
    static let shared = AboutWindowController()
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(rootView: AboutView())
        let win = NSWindow(contentViewController: hosting)
        win.title = "About CopyParty"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.setContentSize(NSSize(width: 380, height: 500))
        win.center()
        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            VStack(spacing: 2) {
                Text("CopyParty").font(.title.weight(.bold))
                Text("Version \(version) (build \(build))")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Text("A native macOS GUI for the copyparty file server, with a self-contained Python runtime.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 4) {
                Text("© 2026 Brielle Harrison. All rights reserved.")
                Text("Directed and co-authored using Anthropic's Claude Opus 4.8.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Divider()

            VStack(spacing: 4) {
                Text("APP ICON")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text("“A-Side” cassette tape icon by barkerbaggies")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    Link("SoftIcons", destination: URL(string: "https://www.softicons.com/object-icons/cassette-tape-icons-by-barkerbaggies/a-side-icon")!)
                    Text("·").foregroundStyle(.tertiary)
                    Link("DeviantArt", destination: URL(string: "https://www.deviantart.com/barkerbaggies")!)
                }
                .font(.caption2)
                Link("Licensed under CC BY-NC-SA 3.0 Unported",
                     destination: URL(string: "https://creativecommons.org/licenses/by-nc-sa/3.0/")!)
                    .font(.caption2)
            }

            Spacer(minLength: 0)

            Link("copyparty by @9001 on GitHub",
                 destination: URL(string: "https://github.com/9001/copyparty")!)
                .font(.caption2)
        }
        .padding(24)
        .frame(width: 380, height: 500)
    }
}
