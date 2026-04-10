import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedTab: InsightTab = .daily

    enum InsightTab: String, CaseIterable {
        case daily = "Today"
        case weekly = "This Week"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(InsightTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = viewModel.error {
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }

                        switch selectedTab {
                        case .daily:
                            insightCard(
                                insight: viewModel.dailyInsight,
                                isLoading: viewModel.isLoadingDaily,
                                emptyMessage: "Tap refresh to generate today's insight."
                            )
                        case .weekly:
                            insightCard(
                                insight: viewModel.weeklyInsight,
                                isLoading: viewModel.isLoadingWeekly,
                                emptyMessage: "Tap refresh to generate this week's insight."
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            switch selectedTab {
                            case .daily: await viewModel.loadDaily(forceRefresh: true)
                            case .weekly: await viewModel.loadWeekly(forceRefresh: true)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoadingDaily || viewModel.isLoadingWeekly)
                }
            }
            .task {
                if viewModel.dailyInsight == nil {
                    await viewModel.loadDaily()
                }
            }
            .onChange(of: selectedTab) { _, newTab in
                Task {
                    if newTab == .weekly && viewModel.weeklyInsight == nil {
                        await viewModel.loadWeekly()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func insightCard(insight: Insight?, isLoading: Bool, emptyMessage: String) -> some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                Text("Asking Claude for insights…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else if let insight = insight {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.indigo)
                    Text(insight.generatedAtFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let count = insight.contextSummary.totalUpcomingAssignments {
                        Text("\(count) assignments")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.indigo.opacity(0.15))
                            .foregroundColor(.indigo)
                            .cornerRadius(6)
                    }
                }

                Text(insight.content)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        } else {
            Text(emptyMessage)
                .font(.callout)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
        }
    }
}
