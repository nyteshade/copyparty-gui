import SwiftUI
import AppKit

// MARK: - Color helpers

extension Color {
    /// Solid sRGB from a 0xRRGGBB literal.
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
    /// Appearance-adaptive color (light vs dark) from two hex literals.
    init(lightHex: UInt, darkHex: UInt) {
        self = Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? darkHex : lightHex)
        })
    }
}

extension NSColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Palette
//
// Only the SIDEBAR is cassette-yellow (identical in light & dark, so its text is
// always dark ink). The rest of the chrome is a near-neutral cool light/dark
// that complements the warm sidebar and lets standard label colors keep full
// contrast. Accents are the icon's cobalt blue.

enum Theme {
    // Cassette yellow
    static let yellow = Color(hex: 0xF7CE46)        // brand primary (labels/highlights)
    static let sidebarTop = Color(hex: 0xF8D24E)
    static let sidebarBottom = Color(hex: 0xEFBE2A)
    static var sidebar: LinearGradient {
        LinearGradient(colors: [sidebarTop, sidebarBottom], startPoint: .top, endPoint: .bottom)
    }
    /// Crisp, fully-opaque dark inks for text on the bright yellow sidebar
    /// (semantic .secondary grays wash out on saturated yellow).
    static let sidebarInk = Color(hex: 0x1A1400)          // ~near-black, primary
    static let sidebarInkSecondary = Color(hex: 0x4A3A0A) // dark amber, secondary
    /// Hairline divider on yellow.
    static let sidebarLine = Color(hex: 0x241B00).opacity(0.18)
    /// Selected-row fill (cobalt) — drawn by us so it's identical whether or not
    /// the window is focused, with white text on top.
    static let selectionFill = Color(hex: 0x2F58C0)

    // Neutral, faintly-cool chrome for the detail pane.
    static let detailBG = Color(lightHex: 0xEEF0F4, darkHex: 0x1E2023)
    static let windowBG = detailBG

    // Accents (icon cobalt)
    static let actionBlue = Color(hex: 0x2F58C0)
    static let accent = Color(lightHex: 0x2A50B8, darkHex: 0x8FB0F2)
    static let magenta = Color(lightHex: 0xC40070, darkHex: 0xFF5BA6)
}

// MARK: - Glossy skeuomorphic yellow sidebar surface

struct GlossySidebar: View {
    var body: some View {
        ZStack {
            // 1. Perceptible "lit plastic" body gradient — lighter on the left,
            //    deepening to the right (lit from the left, not a button bevel).
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0xFBDA5E), location: 0.00),
                    .init(color: Color(hex: 0xF6CE46), location: 0.16),
                    .init(color: Color(hex: 0xEEBE2E), location: 0.72),
                    .init(color: Color(hex: 0xE3AC1B), location: 1.00),
                ],
                startPoint: .leading, endPoint: .trailing)

            // 2. Soft specular sheen down the lit (left) edge — the gloss.
            LinearGradient(
                colors: [.white.opacity(0.45), .white.opacity(0.08), .clear],
                startPoint: .leading, endPoint: UnitPoint(x: 0.5, y: 0.5))
                .blendMode(.softLight)
        }
        .overlay(alignment: .leading) {
            // Crisp specular highlight line along the lit left edge.
            Rectangle().fill(.white.opacity(0.45)).frame(width: 1)
        }
        .overlay(alignment: .trailing) {
            // A thin seam where the plastic meets the detail pane.
            Rectangle().fill(Color(hex: 0x7A5E12).opacity(0.28)).frame(width: 1)
        }
    }
}

// MARK: - Primary action button (cobalt)

struct CassetteButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                LinearGradient(colors: [Theme.actionBlue, Color(hex: 0x23459E)],
                               startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.22),
                    radius: configuration.isPressed ? 1 : 3, y: 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Subtle oversized cassette bleeding off the SE corner of the detail

struct CassetteWatermark: View {
    var body: some View {
        GeometryReader { geo in
            Image("Cassette")
                .resizable()
                .scaledToFit()
                .frame(width: max(geo.size.width, geo.size.height) * 0.9)
                .rotationEffect(.degrees(-10))
                .opacity(0.06)
                .offset(x: geo.size.width * 0.32, y: geo.size.height * 0.36)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottomTrailing)
        }
        .allowsHitTesting(false)
        .clipped()
    }
}

// MARK: - Host-window setup: neutral chrome + no auto-focus of text fields
//
// AppKit makes the first text field the first responder whenever the window
// becomes key, which silently "steals" keystrokes (and used to let a stray key
// rename the server). We clear the initial first responder so nothing is focused
// until the user actually clicks into a field.

struct WindowTinter: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.backgroundColor = NSColor(Theme.windowBG)
            window.titlebarAppearsTransparent = true
            // Let content (the sidebar's yellow) paint under the titlebar so the
            // sidebar runs full-height with the traffic lights sitting on yellow.
            window.initialFirstResponder = nil
            window.makeFirstResponder(nil)
            context.coordinator.observe(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator {
        private var token: NSObjectProtocol?
        func observe(_ window: NSWindow) {
            guard token == nil else { return }
            // On every activation, re-assert "no initial first responder" so AppKit
            // doesn't auto-focus a field. We don't force-clear focus, so clicking
            // straight into a field still works.
            token = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window, queue: .main
            ) { _ in
                window.initialFirstResponder = nil
            }
        }
        deinit { if let token { NotificationCenter.default.removeObserver(token) } }
    }
}
