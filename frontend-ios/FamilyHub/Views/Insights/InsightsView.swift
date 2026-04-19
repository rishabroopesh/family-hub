import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var selectedTab: InsightTab = .daily
    @State private var dailyShowBullets = false
    @State private var weeklyShowBullets = false

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
                                emptyMessage: "Tap refresh to generate today's insight.",
                                showBullets: $dailyShowBullets,
                                bullets: viewModel.dailyBullets,
                                isLoadingBullets: viewModel.isLoadingDailyBullets
                            )
                        case .weekly:
                            insightCard(
                                insight: viewModel.weeklyInsight,
                                isLoading: viewModel.isLoadingWeekly,
                                emptyMessage: "Tap refresh to generate this week's insight.",
                                showBullets: $weeklyShowBullets,
                                bullets: viewModel.weeklyBullets,
                                isLoadingBullets: viewModel.isLoadingWeeklyBullets
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
            // Kick off bullet fetch as soon as the user switches to bullet view
            .onChange(of: dailyShowBullets) { _, on in
                if on { Task { await viewModel.loadBullets(for: "daily") } }
            }
            .onChange(of: weeklyShowBullets) { _, on in
                if on { Task { await viewModel.loadBullets(for: "weekly") } }
            }
        }
    }

    // MARK: - Card

    @ViewBuilder
    private func insightCard(
        insight: Insight?,
        isLoading: Bool,
        emptyMessage: String,
        showBullets: Binding<Bool>,
        bullets: [String]?,
        isLoadingBullets: Bool
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
                    // Paragraph ↔ Bullets toggle
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
                    if isLoadingBullets {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text("Summarizing with Claude…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                        .transition(.opacity)
                    } else if let bullets = bullets {
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
                    }
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
}
