import Foundation

final class AuthService {
    static let shared = AuthService()
    private let client = APIClient.shared

    func register(username: String, email: String, password: String, password2: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode([
            "username": username,
            "email": email,
            "password": password,
            "password2": password2,
        ])
        return try await client.request(Endpoints.register, method: "POST", body: body)
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        let body = try JSONEncoder().encode(["username": username, "password": password])
        return try await client.request(Endpoints.login, method: "POST", body: body)
    }

    func logout() async throws {
        try await client.requestVoid(Endpoints.logout, method: "POST")
    }

    func getProfile() async throws -> User {
        return try await client.request(Endpoints.me)
    }

    func getWorkspaces() async throws -> [Workspace] {
        return try await client.requestList(Endpoints.workspaces)
    }

    func getGoogleStatus() async throws -> GoogleStatusResponse {
        return try await client.request(Endpoints.googleStatus)
    }

    func getGoogleConnectURL() async throws -> String {
        let response: GoogleConnectResponse = try await client.request(Endpoints.googleConnect)
        return response.authUrl
    }

    func disconnectGoogle() async throws {
        try await client.requestVoid(Endpoints.googleDisconnect, method: "DELETE")
    }
}
