import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedTab: InsightTab = .daily
    @State private var dailyShowBullets = false
    @State private var weeklyShowBullets = false

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
                                emptyMessage: "Tap refresh to generate today's insight.",
                                showBullets: $dailyShowBullets
                            )
                        case .weekly:
                            insightCard(
                                insight: viewModel.weeklyInsight,
                                isLoading: viewModel.isLoadingWeekly,
                                emptyMessage: "Tap refresh to generate this week's insight.",
                                showBullets: $weeklyShowBullets
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

    // MARK: - Card

    @ViewBuilder
    private func insightCard(
        insight: Insight?,
        isLoading: Bool,
        emptyMessage: String,
        showBullets: Binding<Bool>
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
                    // View toggle button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBullets.wrappedValue.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showBullets.wrappedValue ? "text.alignleft" : "list.bullet")
                            Text(showBullets.wrappedValue ? "Paragraph" : "Bullets")
                                .font(.caption)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.1))
                        .foregroundColor(.indigo)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Divider()

                // Content
                if showBullets.wrappedValue {
                    let bullets = toBullets(insight.content)
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color.indigo)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(bullet)
                                    .font(.body)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Text(insight.content)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
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

    // MARK: - Bullet parsing

    /// Splits a paragraph into individual sentences to use as bullet points.
    private func toBullets(_ text: String) -> [String] {
        var bullets: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if char == "." || char == "!" || char == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count > 12 {
                    bullets.append(trimmed)
                }
                current = ""
            }
        }

        // Capture any trailing text without a terminal punctuation mark
        let remainder = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if remainder.count > 12 {
            bullets.append(remainder)
        }

        return bullets
    }
}
