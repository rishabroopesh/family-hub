import Foundation
import Combine

@MainActor
final class PagesViewModel: ObservableObject {
    @Published var pages: [Page] = []
    @Published var selectedPage: Page?
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?

    private let service = PageService.shared
    private var autoSaveTask: Task<Void, Never>?

    func loadPages(workspaceId: Int) async {
        isLoading = true
        error = nil
        do {
            pages = try await service.getPages(workspaceId: workspaceId)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadPage(id: String) async {
        do {
            selectedPage = try await service.getPage(id: id)
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func createPage(workspaceId: Int, title: String, parentId: String? = nil, pageType: PageType = .page) async -> Page? {
        // For typed pages (task list, todo, code) the first block is a type marker.
        // Regular pages start with an empty paragraph.
        let initialBlock: PageBlock
        switch pageType {
        case .page:
            initialBlock = PageBlock(id: nil, type: "paragraph", content: [])
        default:
            initialBlock = PageBlock(id: nil, type: pageType.rawValue, content: [])
        }
        let request = CreatePageRequest(
            workspace: workspaceId,
            title: title.isEmpty ? "Untitled" : title,
            icon: pageType.defaultEmoji,
            content: [initialBlock],
            parentPage: parentId
        )
        do {
            let page = try await service.createPage(request)
            await loadPages(workspaceId: workspaceId)
            return page
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        return nil
    }

    func updatePage(id: String, title: String, content: [PageBlock]) async {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            await saveNow(id: id, title: title, content: content)
        }
    }

    func saveNow(id: String, title: String, content: [PageBlock]) async {
        autoSaveTask?.cancel()
        isSaving = true
        let request = UpdatePageRequest(title: title, content: content, icon: nil, isFavorite: nil)
        do {
            let updated = try await service.updatePage(id: id, request: request)
            selectedPage = updated
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    func deletePage(id: String, workspaceId: Int) async {
        do {
            try await service.deletePage(id: id)
            pages.removeAll { $0.id == id }
            if selectedPage?.id == id { selectedPage = nil }
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    func toggleFavorite(page: Page) async {
        let request = UpdatePageRequest(title: nil, content: nil, icon: nil, isFavorite: !page.isFavorite)
        do {
            _ = try await service.updatePage(id: page.id, request: request)
            await loadPages(workspaceId: page.workspace ?? 0)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
