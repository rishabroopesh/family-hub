import Foundation

final class InsightsService {
    static let shared = InsightsService()
    private let client = APIClient.shared

    func getDaily() async throws -> Insight {
        return try await client.request(Endpoints.insightDaily)
    }

    func getWeekly() async throws -> Insight {
        return try await client.request(Endpoints.insightWeekly)
    }

    func refreshDaily() async throws -> Insight {
        return try await client.request(Endpoints.insightDailyRefresh, method: "POST")
    }

    func refreshWeekly() async throws -> Insight {
        return try await client.request(Endpoints.insightWeeklyRefresh, method: "POST")
    }

    func summarize(insightType: String, content: String) async throws -> [String] {
        let endpoint = insightType == "daily" ? Endpoints.insightDailySummarize : Endpoints.insightWeeklySummarize
        let body = try JSONEncoder().encode(["content": content])
        let response: BulletSummaryResponse = try await client.request(endpoint, method: "POST", body: body)
        return response.bullets
    }
}
