import SwiftUI

struct AdvancedTab: View {
    @Binding var server: ServerInstance
    @EnvironmentObject var updates: UpdateService
    @State private var showConfig = false

    var body: some View {
        Form {
            Section("Indexing & Behavior") {
                TextField("Server display name", text: $server.global.serverName)
                    .help("Shown top-left in the web UI and in mDNS announcements (--name)")
                Toggle("Index files on startup (e2dsa)", isOn: $server.global.indexUploads)
                    .help("Scan volumes into the upload database — enables search & dedupe")
                Toggle("Index media tags (e2ts)", isOn: $server.global.indexTags)
                    .help("Read music/media metadata into the index")
                Toggle("Disable thumbnails", isOn: $server.global.disableThumbnails)
                Toggle("Start this server automatically when the app launches", isOn: $server.autoStart)
                Stepper(value: $server.global.maxClients, in: 1...65535, step: 64) {
                    Text("Max clients: \(server.global.maxClients)")
                }
            }

            Section("Extra flags") {
                TextEditor(text: $server.global.extraFlags)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 70)
                Text("Advanced copyparty config lines, one per line — appended verbatim to [global]. e.g. `df: 4g`")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("copyparty Engine") {
                LabeledContent("Installed version", value: updates.currentVersion)
                if let latest = updates.latestVersion {
                    LabeledContent("Latest on GitHub", value: latest)
                }
                updateStatusRow
                HStack {
                    Button("Check for Updates") {
                        Task { await updates.checkForUpdates() }
                    }
                    if case .updateAvailable = updates.status {
                        Button("Download & Install") {
                            Task { await updates.downloadLatest() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Link("Release notes", destination: updates.releaseNotesURL)
                        .font(.callout)
                }
            }

            Section {
                DisclosureGroup("Preview generated config file", isExpanded: $showConfig) {
                    ScrollView {
                        Text(ConfigWriter.config(for: server))
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 240)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .task { if !updates.didInitialRefresh { await updates.refreshCurrentVersion() } }
    }

    @ViewBuilder
    private var updateStatusRow: some View {
        switch updates.status {
        case .idle: EmptyView()
        case .checking: Label("Checking…", systemImage: "arrow.triangle.2.circlepath")
        case .upToDate: Label("Up to date", systemImage: "checkmark.circle").foregroundStyle(.green)
        case .updateAvailable(_, let latest):
            Label("Update available: \(latest)", systemImage: "arrow.down.circle").foregroundStyle(.blue)
        case .downloading(let p):
            ProgressView(value: p) { Text("Downloading…") }
        case .installed(let v):
            Label("Installed \(v) — restart running servers to apply", systemImage: "checkmark.seal").foregroundStyle(.green)
        case .error(let m):
            Label(m, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
        }
    }
}
