import Foundation
import Combine

/// Checks GitHub for a newer copyparty-sfx.py and downloads it into Application
/// Support, where PythonRuntime.activeSFXURL will then prefer it.
@MainActor
final class UpdateService: ObservableObject {

    enum Status: Equatable {
        case idle
        case checking
        case upToDate(current: String)
        case updateAvailable(current: String, latest: String)
        case downloading(Double)
        case installed(version: String)
        case error(String)
    }

    @Published var status: Status = .idle
    @Published var currentVersion: String = "—"
    @Published var latestVersion: String?
    @Published var lastChecked: Date?
    @Published private(set) var didInitialRefresh = false

    private let releasesAPI = URL(string: "https://api.github.com/repos/9001/copyparty/releases/latest")!
    private let sfxDownloadURL = URL(string: "https://github.com/9001/copyparty/releases/latest/download/copyparty-sfx.py")!
    private let changelogURL = URL(string: "https://github.com/9001/copyparty/releases/latest")!

    var releaseNotesURL: URL { changelogURL }

    /// Probe the bundled/active sfx for its version off the main thread (the
    /// probe spawns a process and must not block the UI).
    func refreshCurrentVersion() async {
        let v = await Task.detached { PythonRuntime.activeVersion() }.value
        currentVersion = v ?? "unknown"
        didInitialRefresh = true
    }

    struct GHRelease: Decodable {
        let tag_name: String
        let html_url: String?
    }

    func checkForUpdates() async {
        status = .checking
        await refreshCurrentVersion()
        defer { lastChecked = Date() }
        do {
            var req = URLRequest(url: releasesAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.setValue("CopyParty.app", forHTTPHeaderField: "User-Agent")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                status = .error("GitHub returned an unexpected response.")
                return
            }
            let release = try JSONDecoder().decode(GHRelease.self, from: data)
            let latest = normalize(release.tag_name)
            latestVersion = latest

            if compareVersions(currentVersion, latest) < 0 {
                status = .updateAvailable(current: currentVersion, latest: latest)
            } else {
                status = .upToDate(current: currentVersion)
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func downloadLatest() async {
        status = .downloading(0)
        do {
            let (tempURL, resp) = try await URLSession.shared.download(from: sfxDownloadURL)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                status = .error("Download failed.")
                return
            }
            let dest = PythonRuntime.downloadedSFXURL
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tempURL, to: dest)

            await refreshCurrentVersion()
            status = .installed(version: currentVersion)
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Version helpers

    private func normalize(_ tag: String) -> String {
        var t = tag.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("v") { t.removeFirst() }
        return t
    }

    /// Returns -1 if a < b, 0 if equal, 1 if a > b (semantic, dot-separated).
    func compareVersions(_ a: String, _ b: String) -> Int {
        let pa = normalize(a).split(separator: ".").map { Int($0) ?? 0 }
        let pb = normalize(b).split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}
