import SwiftUI

struct UsersTab: View {
    @Binding var server: ServerInstance

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("User Accounts").font(.headline)
                Spacer()
                Button { addUser() } label: { Label("Add User", systemImage: "person.badge.plus") }
            }
            .padding(.bottom, 8)

            if server.accounts.isEmpty {
                ContentUnavailableView("No Users",
                    systemImage: "person.crop.circle.badge.plus",
                    description: Text("copyparty allows anonymous access (via the `*` principal) until you add users.\nAdd accounts here, then grant them access in the Volumes tab."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(of: Binding<Account>.self) {
                    TableColumn("Username") { $acct in
                        TextField("username", text: $acct.username)
                            .textFieldStyle(.roundedBorder)
                    }
                    TableColumn("Password") { $acct in
                        SecureField("password", text: $acct.password)
                            .textFieldStyle(.roundedBorder)
                    }
                    TableColumn("") { $acct in
                        Button(role: .destructive) {
                            server.accounts.removeAll { $0.id == acct.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                    .width(40)
                } rows: {
                    ForEach($server.accounts) { $acct in
                        TableRow($acct)
                    }
                }
            }

            Toggle("Require username (not just password) to log in", isOn: $server.global.requireUsername)
                .padding(.top, 8)
        }
    }

    private func addUser() {
        server.accounts.append(Account(username: "user\(server.accounts.count + 1)", password: ""))
    }
}
