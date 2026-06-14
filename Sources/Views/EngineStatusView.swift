import SwiftUI

/// Always-visible indicator for the bundled copyparty engine: shows the current
/// version and update state at a glance, with a popover for details + actions.
struct EngineStatusView: View {
    @EnvironmentObject var updates: UpdateService
    @State private var showPopover = false

    var body: some View {
        Button { showPopover.toggle() } label: {
            HStack(spacing: 5) {
                statusIcon.frame(width: 13, height: 13)
                Text(versionLabel)
                    .font(.caption)
                    .foregroundStyle(Theme.sidebarInkSecondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(helpText)
        .popover(isPresented: $showPopover, arrowEdge: .top) {
            popover.padding(16).frame(width: 290)
        }
        .task {
            if !updates.didInitialRefresh { await updates.refreshCurrentVersion() }
        }
    }

    private var versionLabel: String {
        switch updates.currentVersion {
        case "—": return "copyparty…"
        case "unknown": return "copyparty (unknown)"
        default: return "copyparty \(updates.currentVersion)"
        }
    }

    private var helpText: String {
        switch updates.status {
        case .idle: return "Click to check for copyparty updates"
        case .checking: return "Checking for updates…"
        case .upToDate: return "copyparty is up to date"
        case .updateAvailable(_, let l): return "Update available: \(l)"
        case .downloading: return "Downloading update…"
        case .installed: return "Update installed — restart servers to apply"
        case .error(let m): return "Update check failed: \(m)"
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch updates.status {
        case .checking, .downloading:
            ProgressView().controlSize(.small).scaleEffect(0.55)
        case .upToDate:
            badge("checkmark.circle.fill", fill: Color(hex: 0x1B7A37))
        case .updateAvailable:
            badge("arrow.down.circle.fill", fill: Color(hex: 0x1F5FD0)).symbolEffect(.pulse)
        case .installed:
            badge("checkmark.seal.fill", fill: Color(hex: 0x1B7A37))
        case .error:
            badge("exclamationmark.triangle.fill", fill: Color(hex: 0xC2410C))
        case .idle:
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(Theme.sidebarInkSecondary)
        }
    }

    /// A status glyph with a white symbol on a darker, saturated fill plus a soft
    /// dark edge — so it pops against the bright yellow sidebar.
    private func badge(_ name: String, fill: Color) -> some View {
        Image(systemName: name)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, fill)
            .shadow(color: .black.opacity(0.4), radius: 0.5, y: 0.5)
    }

    // MARK: - Popover

    @ViewBuilder
    private var popover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("copyparty engine").font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 4) {
                GridRow {
                    Text("Installed").foregroundStyle(.secondary)
                    Text(updates.currentVersion).fontWeight(.medium)
                }
                GridRow {
                    Text("Latest").foregroundStyle(.secondary)
                    Text(updates.latestVersion ?? "—").fontWeight(.medium)
                }
                if let when = updates.lastChecked {
                    GridRow {
                        Text("Checked").foregroundStyle(.secondary)
                        Text(when, format: .relative(presentation: .named))
                    }
                }
            }
            .font(.callout)

            statusBanner

            Divider()

            HStack {
                Button {
                    Task { await updates.checkForUpdates() }
                } label: {
                    Label("Check Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(isBusy)

                if case .updateAvailable = updates.status {
                    Button {
                        Task { await updates.downloadLatest() }
                    } label: {
                        Label("Update", systemImage: "arrow.down.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                Link("Notes", destination: updates.releaseNotesURL).font(.caption)
            }
        }
    }

    private var isBusy: Bool {
        if case .checking = updates.status { return true }
        if case .downloading = updates.status { return true }
        return false
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch updates.status {
        case .idle:
            Label("Not checked yet", systemImage: "questionmark.circle")
                .foregroundStyle(.secondary)
        case .checking:
            Label("Checking GitHub…", systemImage: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
        case .upToDate:
            Label("You're on the latest version.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .updateAvailable(_, let latest):
            Label("Version \(latest) is available.", systemImage: "arrow.down.circle.fill")
                .foregroundStyle(.blue)
        case .downloading(let p):
            ProgressView(value: p) { Text("Downloading…") }
        case .installed(let v):
            Label("Installed \(v). Restart running servers to apply.", systemImage: "checkmark.seal.fill")
                .foregroundStyle(.green)
        case .error(let m):
            Label(m, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}
