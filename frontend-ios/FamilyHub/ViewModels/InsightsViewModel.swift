import Foundation
import Combine

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var dailyInsight: Insight?
    @Published var weeklyInsight: Insight?
    @Published var isLoadingDaily = false
    @Published var isLoadingWeekly = false
    @Published var dailyBullets: [String]?
    @Published var weeklyBullets: [String]?
    @Published var isLoadingDailyBullets = false
    @Published var isLoadingWeeklyBullets = false
    @Published var error: String?

    private let service = InsightsService.shared

    func loadDaily(forceRefresh: Bool = false) async {
        isLoadingDaily = true
        error = nil
        do {
            dailyInsight = forceRefresh
                ? try await service.refreshDaily()
                : try await service.getDaily()
            if forceRefresh { dailyBullets = nil }
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingDaily = false
    }

    func loadWeekly(forceRefresh: Bool = false) async {
        isLoadingWeekly = true
        error = nil
        do {
            weeklyInsight = forceRefresh
                ? try await service.refreshWeekly()
                : try await service.getWeekly()
            if forceRefresh { weeklyBullets = nil }
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingWeekly = false
    }

    /// Lazily fetches Claude-generated bullet points for the given tab.
    /// No-ops if bullets are already loaded or a request is in flight.
    func loadBullets(for insightType: String) async {
        switch insightType {
        case "daily":
            guard let insight = dailyInsight, dailyBullets == nil, !isLoadingDailyBullets else { return }
            isLoadingDailyBullets = true
            do {
                dailyBullets = try await service.summarize(insightType: "daily", content: insight.content)
            } catch let e as APIError {
                error = e.errorDescription
            } catch {
                self.error = error.localizedDescription
            }
            isLoadingDailyBullets = false
        case "weekly":
            guard let insight = weeklyInsight, weeklyBullets == nil, !isLoadingWeeklyBullets else { return }
            isLoadingWeeklyBullets = true
            do {
                weeklyBullets = try await service.summarize(insightType: "weekly", content: insight.content)
            } catch let e as APIError {
                error = e.errorDescription
            } catch {
                self.error = error.localizedDescription
            }
            isLoadingWeeklyBullets = false
        default:
            break
        }
    }
}
