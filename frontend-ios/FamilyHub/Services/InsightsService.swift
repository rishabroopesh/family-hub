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
}
