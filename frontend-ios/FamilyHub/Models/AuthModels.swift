import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, username, email
        case avatarUrl = "avatar_url"
    }
}

struct AuthResponse: Codable {
    let user: User
    let token: String
}

struct GoogleStatusResponse: Codable {
    let connected: Bool
    let googleEmail: String?

    enum CodingKeys: String, CodingKey {
        case connected
        case googleEmail = "google_email"
    }
}

struct GoogleConnectResponse: Codable {
    let authUrl: String

    enum CodingKeys: String, CodingKey {
        case authUrl = "auth_url"
    }
}

struct Workspace: Codable, Identifiable {
    let id: Int
    let name: String
    let icon: String?
    let isPersonal: Bool
    let owner: Int

    enum CodingKeys: String, CodingKey {
        case id, name, icon, owner
        case isPersonal = "is_personal"
    }
}
