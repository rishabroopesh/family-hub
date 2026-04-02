import Foundation

struct Course: Codable, Identifiable {
    let id: String
    let name: String
    let section: String?
    let description: String?
    let teacherName: String?
    let alternateLink: String?
    let lastSyncedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name, section, description
        case teacherName = "teacher_name"
        case alternateLink = "alternate_link"
        case lastSyncedAt = "last_synced_at"
    }
}

struct Coursework: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let workType: String?
    let dueDate: String?
    let dueTime: String?
    let maxPoints: Double?
    let alternateLink: String?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case workType = "work_type"
        case dueDate = "due_date"
        case dueTime = "due_time"
        case maxPoints = "max_points"
        case alternateLink = "alternate_link"
    }

    var dueDateFormatted: String? {
        guard let dateStr = dueDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateStr) else { return nil }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
    }

    var dueDateTime: Date? {
        guard let dateStr = dueDate else { return nil }
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: dateStr)
    }

    var isOverdue: Bool {
        guard let date = dueDateTime else { return false }
        return date < Date()
    }
}

struct SyncLog: Codable, Identifiable {
    let id: String
    let status: String
    let coursesSynced: Int
    let courseworkSynced: Int
    let syncType: String
    let startedAt: String
    let completedAt: String?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case id, status
        case coursesSynced = "courses_synced"
        case courseworkSynced = "coursework_synced"
        case syncType = "sync_type"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case errorMessage = "error_message"
    }

    var statusEmoji: String {
        switch status {
        case "success": return "✅"
        case "failed": return "❌"
        case "started": return "🔄"
        default: return "⏳"
        }
    }
}
