import Foundation

/// A copyparty user account (`[accounts]` section / `-a user:pass`).
struct Account: Codable, Identifiable, Hashable {
    var id = UUID()
    var username: String = ""
    var password: String = ""
}
