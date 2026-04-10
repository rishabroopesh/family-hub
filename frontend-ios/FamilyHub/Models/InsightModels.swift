import Foundation

struct Insight: Codable, Identifiable {
    let id: String
    let insightType: String
    let content: String
    let contextSummary: ContextSummary
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case insightType = "insight_type"
        case content
        case contextSummary = "context_summary"
        case generatedAt = "generated_at"
    }

    var generatedAtFormatted: String {
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = parser.date(from: generatedAt)
            ?? ISO8601DateFormatter().date(from: generatedAt) else {
            return generatedAt
        }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: date)
    }
}

struct ContextSummary: Codable {
    let totalUpcomingAssignments: Int?
    let courseCount: Int?
    let windowDays: Int?

    enum CodingKeys: String, CodingKey {
        case totalUpcomingAssignments = "total_upcoming_assignments"
        case courseCount = "course_count"
        case windowDays = "window_days"
    }
}
