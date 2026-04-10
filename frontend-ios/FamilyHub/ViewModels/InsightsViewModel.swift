import Foundation
import Combine

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var dailyInsight: Insight?
    @Published var weeklyInsight: Insight?
    @Published var isLoadingDaily = false
    @Published var isLoadingWeekly = false
    @Published var error: String?

    private let service = InsightsService.shared

    func loadDaily(forceRefresh: Bool = false) async {
        isLoadingDaily = true
        error = nil
        do {
            dailyInsight = forceRefresh
                ? try await service.refreshDaily()
                : try await service.getDaily()
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
        } catch let e as APIError {
            error = e.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoadingWeekly = false
    }
}
