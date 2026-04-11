import Foundation

enum PageType: String, CaseIterable {
    case page      = "page"
    case taskList  = "task_list"
    case todo      = "todo"
    case code      = "code"

    var displayName: String {
        switch self {
        case .page:     return "Page"
        case .taskList: return "Task List"
        case .todo:     return "Todo"
        case .code:     return "Code"
        }
    }

    var systemImage: String {
        switch self {
        case .page:     return "doc.text"
        case .taskList: return "checklist"
        case .todo:     return "checkmark.circle"
        case .code:     return "chevron.left.forwardslash.chevron.right"
        }
    }

    var defaultEmoji: String {
        switch self {
        case .page:     return "📄"
        case .taskList: return "✅"
        case .todo:     return "☑️"
        case .code:     return "💻"
        }
    }
}

struct Page: Codable, Identifiable {
    let id: String
    let title: String
    let icon: String?
    let content: [PageBlock]?
    let parentPage: String?
    let position: Int
    let isArchived: Bool
    let isFavorite: Bool
    let childPages: [Page]?
    let workspace: Int?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, title, icon, content, position, workspace
        case parentPage = "parent_page"
        case isArchived = "is_archived"
        case isFavorite = "is_favorite"
        case childPages = "child_pages"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct PageBlock: Codable {
    let id: String?
    let type: String
    let content: [BlockContent]?

    func toPlainText() -> String {
        content?.compactMap { $0.text }.joined() ?? ""
    }
}

struct BlockContent: Codable {
    let type: String?
    let text: String?
}

struct CreatePageRequest: Codable {
    let workspace: Int
    let title: String
    let icon: String?
    let content: [PageBlock]
    let parentPage: String?

    enum CodingKeys: String, CodingKey {
        case workspace, title, icon, content
        case parentPage = "parent_page"
    }
}

struct UpdatePageRequest: Codable {
    let title: String?
    let content: [PageBlock]?
    let icon: String?
    let isFavorite: Bool?

    enum CodingKeys: String, CodingKey {
        case title, content, icon
        case isFavorite = "is_favorite"
    }
}
