import SwiftUI

@main
struct FamilyHubApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isAuthenticated {
                    MainTabView()
                        .environmentObject(authViewModel)
                } else {
                    LoginView()
                        .environmentObject(authViewModel)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .unauthorizedResponse)) { _ in
                Task { await authViewModel.logout() }
            }
        }
    }
}

extension Notification.Name {
    static let unauthorizedResponse = Notification.Name("unauthorizedResponse")
}
