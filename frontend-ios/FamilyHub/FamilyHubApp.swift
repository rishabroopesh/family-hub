import SwiftUI

@main
struct FamilyHubApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @AppStorage("darkModeEnabled") private var darkModeEnabled = false

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
            .preferredColorScheme(darkModeEnabled ? .dark : .light)
            .onReceive(NotificationCenter.default.publisher(for: .unauthorizedResponse)) { _ in
                Task { await authViewModel.logout() }
            }
        }
    }
}

extension Notification.Name {
    static let unauthorizedResponse = Notification.Name("unauthorizedResponse")
}
