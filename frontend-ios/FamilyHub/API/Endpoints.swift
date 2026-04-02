import Foundation

struct Endpoints {
    // Auth
    static let register = "/api/v1/auth/register/"
    static let login = "/api/v1/auth/login/"
    static let logout = "/api/v1/auth/logout/"
    static let me = "/api/v1/auth/me/"
    static let googleConnect = "/api/v1/auth/google/connect/"
    static let googleDisconnect = "/api/v1/auth/google/disconnect/"
    static let googleStatus = "/api/v1/auth/google/status/"

    // Workspaces
    static let workspaces = "/api/v1/workspaces/"

    // Pages
    static let pages = "/api/v1/pages/"
    static func page(_ id: String) -> String { "/api/v1/pages/\(id)/" }

    // Calendar
    static let calendarEvents = "/api/v1/calendar/events/"
    static func calendarEvent(_ id: String) -> String { "/api/v1/calendar/events/\(id)/" }

    // Classroom
    static let classroomCourses = "/api/v1/classroom/courses/"
    static func classroomCourse(_ id: String) -> String { "/api/v1/classroom/courses/\(id)/" }
    static func classroomCoursework(_ courseId: String) -> String { "/api/v1/classroom/courses/\(courseId)/coursework/" }
    static let classroomSync = "/api/v1/classroom/sync/"
    static let classroomSyncStatus = "/api/v1/classroom/sync/status/"
    static let classroomSyncLogs = "/api/v1/classroom/sync/logs/"
}
