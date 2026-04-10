import Foundation

final class ClassroomService {
    static let shared = ClassroomService()
    private let client = APIClient.shared

    func getCourses() async throws -> [Course] {
        return try await client.requestList(Endpoints.classroomCourses)
    }

    func getCoursework(courseId: String) async throws -> [Coursework] {
        return try await client.requestList(Endpoints.classroomCoursework(courseId))
    }

    func triggerSync() async throws {
        try await client.requestVoid(Endpoints.classroomSync, method: "POST")
    }

    func getSyncStatus() async throws -> SyncLog {
        return try await client.request(Endpoints.classroomSyncStatus)
    }

    func getSyncLogs() async throws -> [SyncLog] {
        return try await client.requestList(Endpoints.classroomSyncLogs)
    }
}
