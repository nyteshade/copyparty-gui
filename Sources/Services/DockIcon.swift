import AppKit

/// macOS 26 ("Tahoe") masks every bundle app icon into the rounded-rect
/// "squircle" shape. Our app icon is a full-bleed, transparent cassette — the
/// mask clips it into an awkward tile. Assigning the Dock icon *programmatically*
/// at launch bypasses that system masking, so the Dock shows the real artwork.
///
/// On older macOS (no squircle) this simply re-asserts the same icon, which is a
/// harmless no-op; the bundle's AppIcon (and A-Side.icns) already render bare.
enum DockIcon {
    static func applyUnmaskedIcon() {
        let candidates = [
            Bundle.main.url(forResource: "A-Side", withExtension: "icns"),
            Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
        ].compactMap { $0 }

        for url in candidates {
            if let image = NSImage(contentsOf: url) {
                NSApplication.shared.applicationIconImage = image
                return
            }
        }
    }
}
