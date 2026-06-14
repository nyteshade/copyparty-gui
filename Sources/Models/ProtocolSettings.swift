import Foundation

/// TLS behaviour for the HTTP listener.
enum TLSMode: String, Codable, CaseIterable, Identifiable {
    case auto        // default: serve both, auto self-signed cert
    case httpOnly    // --http-only (plaintext only)
    case httpsOnly   // --https-only (force TLS)
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Auto (HTTP + HTTPS)"
        case .httpOnly: return "HTTP only (plaintext)"
        case .httpsOnly: return "HTTPS only (force TLS)"
        }
    }
}

/// Connection-protocol configuration for one server instance. Maps directly to
/// copyparty CLI / config flags (see ConfigWriter).
struct ProtocolSettings: Codable, Hashable {
    // HTTP / HTTPS (always on; WebDAV rides on top)
    var httpPorts: [Int] = [3923]          // -p
    var listenIP: String = "0.0.0.0"       // -i
    var tlsMode: TLSMode = .auto
    var certPath: String = ""              // --cert (optional; blank = auto)
    var disableAutoCert: Bool = false      // --no-crt

    // WebDAV
    var webdavEnabled: Bool = true         // --no-dav disables
    var webdavForceAuth: Bool = false      // --dav-auth

    // FTP
    var ftpEnabled: Bool = false
    var ftpPort: Int = 3921                // --ftp
    var ftpsEnabled: Bool = false
    var ftpsPort: Int = 3990               // --ftps
    var ftpNAT: String = ""                // --ftp-nat
    var ftpPassiveRange: String = ""       // --ftp-pr (e.g. "12000-12099")

    // SFTP (requires bundled paramiko)
    var sftpEnabled: Bool = false
    var sftpPort: Int = 3922               // --sftp
    var sftpAllowPassword: Bool = true     // --sftp-pw (allow password auth, not just keys)

    // TFTP
    var tftpEnabled: Bool = false
    var tftpPort: Int = 3969               // --tftp

    // SMB (experimental, read-only by default)
    var smbEnabled: Bool = false           // --smb
    var smbWritable: Bool = false          // --smbw
    var smbPort: Int = 445                 // --smb-port

    // Zeroconf / mDNS discovery
    var zeroconfEnabled: Bool = false      // -z
    var mdnsAnnounce: Bool = false         // --zm

    // Console QR code on start
    var showQR: Bool = false               // --qr

    /// The primary HTTP port for "open in browser".
    var primaryHTTPPort: Int { httpPorts.first ?? 3923 }
}
