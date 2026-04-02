import Foundation

struct CalendarEvent: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let startDatetime: String
    let endDatetime: String?
    let allDay: Bool
    let color: String?
    let eventType: String
    let classroomCoursework: String?
    let workspace: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, description, color, workspace
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case allDay = "all_day"
        case eventType = "event_type"
        case classroomCoursework = "classroom_coursework"
    }

    var startDate: Date? {
        ISO8601DateFormatter().date(from: startDatetime)
    }

    var endDate: Date? {
        endDatetime.flatMap { ISO8601DateFormatter().date(from: $0) }
    }

    var isClassroomEvent: Bool {
        eventType == "classroom"
    }

    var displayColor: String {
        if isClassroomEvent { return "#4285f4" }
        return color ?? "#6366f1"
    }
}

struct CreateEventRequest: Codable {
    let workspace: Int
    let title: String
    let description: String
    let startDatetime: String
    let endDatetime: String?
    let allDay: Bool
    let color: String

    enum CodingKeys: String, CodingKey {
        case workspace, title, description, color
        case startDatetime = "start_datetime"
        case endDatetime = "end_datetime"
        case allDay = "all_day"
    }
}
