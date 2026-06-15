import SwiftUI
import AppKit

struct VolumesTab: View {
    @Binding var server: ServerInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Mounted Directories").font(.headline)
                Spacer()
                Button { addVolume() } label: { Label("Add Volume", systemImage: "plus") }
            }
            .padding(.bottom, 8)

            if server.volumes.isEmpty {
                ContentUnavailableView("No Volumes",
                    systemImage: "folder.badge.plus",
                    description: Text("Add a directory to share it."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach($server.volumes) { $vol in
                            VolumeEditor(volume: $vol, accounts: server.accounts) {
                                server.volumes.removeAll { $0.id == vol.id }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func addVolume() {
        var v = Volume()
        v.urlPath = server.volumes.isEmpty ? "/" : "/share\(server.volumes.count)"
        v.access = [AccessRule(permissions: [.read], principals: ["*"])]
        server.volumes.append(v)
    }
}

private struct VolumeEditor: View {
    @Binding var volume: Volume
    let accounts: [Account]
    let onDelete: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    LabeledContent("URL path") {
                        TextField("/music", text: $volume.urlPath)
                            .frame(maxWidth: 180)
                    }
                    Spacer()
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                HStack(spacing: 6) {
                    Text("Folder").frame(width: 70, alignment: .leading)
                    TextField("/path/to/folder", text: $volume.fsPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose…") { chooseFolder() }
                }

                Divider()

                HStack {
                    Text("Access").font(.subheadline.weight(.medium))
                    Spacer()
                    Button { addRule() } label: { Label("Add Rule", systemImage: "plus") }
                        .buttonStyle(.borderless)
                }
                ForEach($volume.access) { $rule in
                    AccessRuleRow(rule: $rule, accounts: accounts) {
                        volume.access.removeAll { $0.id == rule.id }
                    }
                }

                Divider()
                HStack(spacing: 6) {
                    Text("Flags").frame(width: 70, alignment: .leading)
                    TextField("e2d, nodupe, fk:4", text: flagsBinding)
                        .textFieldStyle(.roundedBorder)
                        .help("Comma-separated volume flags")
                }
            }
            .padding(6)
        }
    }

    private var flagsBinding: Binding<String> {
        Binding(
            get: { volume.flags.joined(separator: ", ") },
            set: { volume.flags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }

    private func addRule() {
        volume.access.append(AccessRule(permissions: [.read], principals: ["*"]))
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            volume.fsPath = url.path
            if volume.urlPath.isEmpty || volume.urlPath == "/" {
                // keep root; otherwise suggest a name
            }
        }
    }
}

private struct AccessRuleRow: View {
    @Binding var rule: AccessRule
    let accounts: [Account]
    let onDelete: () -> Void
    @State private var hovered: Permission?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Instant hover label (no tooltip delay) — primary yellow + shadow.
            Text(hovered.map { "\($0.rawValue.uppercased())  —  \($0.label)" } ?? " ")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.yellow)
                .shadow(color: .black.opacity(0.75), radius: 1, y: 0.5)
                .frame(height: 13, alignment: .leading)
                .animation(.easeOut(duration: 0.08), value: hovered)

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(Permission.allCases) { perm in chip(perm) }
                }
                Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.caption)
                TextField("* or user1, user2", text: principalsBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func chip(_ perm: Permission) -> some View {
        let on = rule.permissions.contains(perm)
        return Text(perm.rawValue.uppercased())
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .frame(width: 26, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(on ? Theme.actionBlue : Color.secondary.opacity(0.12)))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(on ? .clear : Color.secondary.opacity(0.5), lineWidth: 1))
            .foregroundStyle(on ? Color.white : Color.secondary)
            .shadow(color: on ? Theme.actionBlue.opacity(0.45) : .clear, radius: 2, y: 1)
            .contentShape(Rectangle())
            .onTapGesture { toggle(perm) }
            .onHover { inside in
                if inside { hovered = perm } else if hovered == perm { hovered = nil }
            }
    }

    private func toggle(_ perm: Permission) {
        if rule.permissions.contains(perm) {
            rule.permissions.removeAll { $0 == perm }
        } else {
            rule.permissions.append(perm)
        }
    }

    private var principalsBinding: Binding<String> {
        Binding(
            get: { rule.principals.joined(separator: ", ") },
            set: { rule.principals = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        )
    }
}
