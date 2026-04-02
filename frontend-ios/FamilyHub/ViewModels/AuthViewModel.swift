import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var currentWorkspaceId: Int?
    @Published var isLoading = false
    @Published var error: String?

    private let service = AuthService.shared
    private let client = APIClient.shared

    init() {
        isAuthenticated = client.token != nil
        if isAuthenticated {
            Task { await loadProfile() }
        }
    }

    func login(username: String, password: String) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.login(username: username, password: password)
            client.saveToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            await loadWorkspace()
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func register(username: String, email: String, password: String, password2: String) async {
        isLoading = true
        error = nil
        do {
            let response = try await service.register(
                username: username, email: email,
                password: password, password2: password2
            )
            client.saveToken(response.token)
            currentUser = response.user
            isAuthenticated = true
            await loadWorkspace()
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func logout() async {
        try? await service.logout()
        client.deleteToken()
        currentUser = nil
        currentWorkspaceId = nil
        isAuthenticated = false
    }

    func loadProfile() async {
        do {
            currentUser = try await service.getProfile()
            await loadWorkspace()
        } catch {
            // Token likely invalid
            client.deleteToken()
            isAuthenticated = false
        }
    }

    private func loadWorkspace() async {
        do {
            let workspaces = try await service.getWorkspaces()
            currentWorkspaceId = workspaces.first(where: { $0.isPersonal })?.id ?? workspaces.first?.id
        } catch {
            // Workspace load failure is non-fatal
        }
    }
}
