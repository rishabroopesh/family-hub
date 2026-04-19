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
                            case .daily:  await viewModel.loadDaily(forceRefresh: true)
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

    // MARK: - Markdown rendering

    /// Parses **bold** markdown and renders numbered items with proper spacing.
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
                result = result + Text(parts[i]).bold()
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
                // Header row
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

                Divider()

                renderedContent(insight.content)
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
