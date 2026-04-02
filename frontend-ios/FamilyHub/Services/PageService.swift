import Foundation

final class PageService {
    static let shared = PageService()
    private let client = APIClient.shared

    func getPages(workspaceId: Int) async throws -> [Page] {
        return try await client.request("\(Endpoints.pages)?workspace=\(workspaceId)")
    }

    func getPage(id: String) async throws -> Page {
        return try await client.request(Endpoints.page(id))
    }

    func createPage(_ request: CreatePageRequest) async throws -> Page {
        let body = try JSONEncoder().encode(request)
        return try await client.request(Endpoints.pages, method: "POST", body: body)
    }

    func updatePage(id: String, request: UpdatePageRequest) async throws -> Page {
        let body = try JSONEncoder().encode(request)
        return try await client.request(Endpoints.page(id), method: "PATCH", body: body)
    }

    func deletePage(id: String) async throws {
        try await client.requestVoid(Endpoints.page(id), method: "DELETE")
    }
}
