import SwiftUI

struct ProtocolsTab: View {
    @Binding var server: ServerInstance

    var body: some View {
        Form {
            Section("HTTP / HTTPS") {
                TextField("Listen ports", text: portsBinding)
                    .help("Comma-separated, e.g. 3923, 8080")
                TextField("Listen address", text: $server.protocols.listenIP)
                    .help("0.0.0.0 = all interfaces; 127.0.0.1 = localhost only")
                Picker("TLS", selection: $server.protocols.tlsMode) {
                    ForEach(TLSMode.allCases) { Text($0.label).tag($0) }
                }
                if server.protocols.tlsMode != .httpOnly {
                    TextField("TLS cert path (optional)", text: $server.protocols.certPath)
                        .help("Concatenated key+cert PEM. Leave blank to auto-generate a self-signed cert.")
                    Toggle("Disable automatic self-signed certificate", isOn: $server.protocols.disableAutoCert)
                }
            }

            Section("WebDAV") {
                Toggle("Enable WebDAV", isOn: $server.protocols.webdavEnabled)
                Toggle("Require authentication for all folders", isOn: $server.protocols.webdavForceAuth)
                    .disabled(!server.protocols.webdavEnabled)
                Text("WebDAV is served on the HTTP/HTTPS ports above.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("FTP") {
                Toggle("Enable FTP", isOn: $server.protocols.ftpEnabled)
                if server.protocols.ftpEnabled {
                    portField("FTP port", $server.protocols.ftpPort)
                }
                Toggle("Enable FTPS (explicit TLS)", isOn: $server.protocols.ftpsEnabled)
                if server.protocols.ftpsEnabled {
                    portField("FTPS port", $server.protocols.ftpsPort)
                }
                if server.protocols.ftpEnabled || server.protocols.ftpsEnabled {
                    TextField("NAT address (optional)", text: $server.protocols.ftpNAT)
                        .help("Public address for passive-mode connections behind NAT")
                    TextField("Passive port range (optional)", text: $server.protocols.ftpPassiveRange)
                        .help("e.g. 12000-12099")
                }
            }

            Section("SFTP") {
                Toggle("Enable SFTP", isOn: $server.protocols.sftpEnabled)
                if server.protocols.sftpEnabled {
                    portField("SFTP port", $server.protocols.sftpPort)
                    Toggle("Allow password authentication", isOn: $server.protocols.sftpAllowPassword)
                    Text("SFTP is provided by the bundled paramiko library.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("TFTP") {
                Toggle("Enable TFTP", isOn: $server.protocols.tftpEnabled)
                if server.protocols.tftpEnabled {
                    portField("TFTP port", $server.protocols.tftpPort)
                    Text("Port 69 is the standard TFTP port but requires running as root; 3969 is a safe alternative.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("SMB (experimental)") {
                Toggle("Enable SMB", isOn: $server.protocols.smbEnabled)
                if server.protocols.smbEnabled {
                    Toggle("Allow writes over SMB", isOn: $server.protocols.smbWritable)
                    portField("SMB port", $server.protocols.smbPort)
                    Label("SMB in copyparty is experimental and insecure. macOS already uses the standard port 445 (and binding it needs root), so this defaults to 3945 — connect with smb://host:3945.",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Section("Discovery") {
                Toggle("Enable Zeroconf (mDNS + SSDP)", isOn: $server.protocols.zeroconfEnabled)
                Toggle("Announce services over mDNS", isOn: $server.protocols.mdnsAnnounce)
                Toggle("Print QR code to log on start", isOn: $server.protocols.showQR)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func portField(_ label: String, _ value: Binding<Int>) -> some View {
        TextField(label, value: value, format: .number.grouping(.never))
            .frame(maxWidth: 220)
    }

    private var portsBinding: Binding<String> {
        Binding(
            get: { server.protocols.httpPorts.map(String.init).joined(separator: ", ") },
            set: {
                server.protocols.httpPorts = $0.split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            }
        )
    }
}
