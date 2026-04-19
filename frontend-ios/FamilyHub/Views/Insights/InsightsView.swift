import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedTab: InsightTab = .daily

    enum InsightTab: String, CaseIterable {
        case daily  = "Today"
        case weekly = "This Week"

        var insightType: String {
            switch self {
            case .daily:  return "daily"
            case .weekly: return "weekly"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Gradient header
                HStack {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .gradientForeground()
                    Text("Insights")
                        .font(.title2.bold())
                        .gradientForeground()
                    Spacer()
                    Button {
                        Task {
                            switch selectedTab {
                            case .daily:  await viewModel.loadDaily(forceRefresh: true)
                            case .weekly: await viewModel.loadWeekly(forceRefresh: true)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppTheme.accentGradient)
                    }
                    .disabled(viewModel.isLoadingDaily || viewModel.isLoadingWeekly)
                }
                .padding(.horizontal)
                .padding(.top, 8)

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
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.callout)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.orange.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                            .cornerRadius(10)
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
            .navigationBarHidden(true)
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

    // MARK: - Markdown rendering

    private func renderedContent(_ content: String) -> some View {
        let paragraphs = content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return VStack(alignment: .leading, spacing: 14) {
            ForEach(0..<paragraphs.count, id: \.self) { index in
                parseBoldMarkdown(paragraphs[index])
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func parseBoldMarkdown(_ text: String) -> Text {
        let parts = text.components(separatedBy: "**")
        var result = Text(parts[0])
        for i in 1..<parts.count {
            if i % 2 == 1 {
                result = result + Text(parts[i]).bold().foregroundColor(.purple)
            } else {
                result = result + Text(parts[i])
            }
        }
        return result
    }

    // MARK: - Card

    @ViewBuilder
    private func insightCard(
        insight: Insight?,
        isLoading: Bool,
        emptyMessage: String
    ) -> some View {
        if isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.purple)
                    .scaleEffect(1.2)
                Text("Asking Claude for insights...")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else if let insight = insight {
            VStack(alignment: .leading, spacing: 12) {
                // Header row
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(AppTheme.accentGradient)
                    Text(insight.generatedAtFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let count = insight.contextSummary.totalUpcomingAssignments {
                        VibrantBadge(text: "\(count) assignments", icon: "book.fill")
                    }
                }

                Rectangle()
                    .fill(AppTheme.accentGradient)
                    .frame(height: 1.5)
                    .opacity(0.5)

                renderedContent(insight.content)
            }
            .accentCard()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .gradientForeground()
                Text(emptyMessage)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }
}
