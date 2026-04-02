import Foundation
import AuthenticationServices

@MainActor
final class ClassroomViewModel: ObservableObject {
    @Published var courses: [Course] = []
    @Published var courseworkByCourse: [String: [Coursework]] = [:]
    @Published var syncStatus: SyncLog?
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var error: String?
    @Published var googleConnected = false
    @Published var googleEmail: String?

    private let service = ClassroomService.shared
    private let authService = AuthService.shared

    func loadCourses() async {
        isLoading = true
        error = nil
        do {
            courses = try await service.getCourses()
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadCoursework(for courseId: String) async {
        do {
            courseworkByCourse[courseId] = try await service.getCoursework(courseId: courseId)
        } catch {
            // Non-fatal
        }
    }

    func triggerSync() async {
        isSyncing = true
        error = nil
        do {
            try await service.triggerSync()
            // Poll status after a delay to show updated result
            try await Task.sleep(nanoseconds: 3_000_000_000)
            await loadSyncStatus()
            await loadCourses()
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isSyncing = false
    }

    func loadSyncStatus() async {
        do {
            syncStatus = try await service.getSyncStatus()
        } catch {
            // No sync history yet
        }
    }

    func checkGoogleStatus() async {
        do {
            let status = try await authService.getGoogleStatus()
            googleConnected = status.connected
            googleEmail = status.googleEmail
        } catch {
            googleConnected = false
        }
    }

    func getGoogleConnectURL() async -> String? {
        do {
            return try await authService.getGoogleConnectURL()
        } catch {
            self.error = "Failed to get Google connect URL."
            return nil
        }
    }

    func disconnectGoogle() async {
        do {
            try await authService.disconnectGoogle()
            googleConnected = false
            googleEmail = nil
            courses = []
            courseworkByCourse = [:]
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
