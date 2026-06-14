import SwiftUI
import AppKit

struct LogTab: View {
    @ObservedObject var controller: ServerController

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                StatusDot(state: controller.state)
                Text(stateLabel).font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button { copyLog() } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(.borderless)
            }
            .padding(.bottom, 6)

            ScrollViewReader { proxy in
                ScrollView {
                    Text(controller.log.isEmpty ? "Server not started.\nPress Start to launch copyparty." : controller.log)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .id("logEnd")
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: controller.log) { _, _ in
                    withAnimation(.linear(duration: 0.1)) {
                        proxy.scrollTo("logEnd", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var stateLabel: String {
        switch controller.state {
        case .running(let pid): return "Running · pid \(pid)"
        case .starting: return "Starting…"
        case .stopped: return "Stopped"
        case .failed(let m): return "Failed: \(m)"
        }
    }

    private func copyLog() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(controller.log, forType: .string)
    }
}
