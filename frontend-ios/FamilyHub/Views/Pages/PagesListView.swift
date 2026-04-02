import SwiftUI

struct PagesListView: View {
    @EnvironmentObject var pagesViewModel: PagesViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showNewPage = false
    @State private var newPageTitle = ""
    @State private var selectedPageId: String?

    var body: some View {
        NavigationStack {
            Group {
                if pagesViewModel.isLoading && pagesViewModel.pages.isEmpty {
                    ProgressView("Loading pages...")
                } else if pagesViewModel.pages.isEmpty {
                    ContentUnavailableView(
                        "No Pages Yet",
                        systemImage: "doc.text",
                        description: Text("Tap + to create your first page.")
                    )
                } else {
                    List {
                        ForEach(pagesViewModel.pages) { page in
                            PageRowView(page: page, selectedPageId: $selectedPageId, depth: 0)
                                .environmentObject(pagesViewModel)
                                .environmentObject(authViewModel)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                let page = pagesViewModel.pages[index]
                                guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                                Task { await pagesViewModel.deletePage(id: page.id, workspaceId: workspaceId) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pages")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showNewPage = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                await pagesViewModel.loadPages(workspaceId: workspaceId)
            }
            .onAppear {
                guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                Task { await pagesViewModel.loadPages(workspaceId: workspaceId) }
            }
            .alert("New Page", isPresented: $showNewPage) {
                TextField("Page title", text: $newPageTitle)
                Button("Create") {
                    guard let workspaceId = authViewModel.currentWorkspaceId else { return }
                    Task {
                        let page = await pagesViewModel.createPage(workspaceId: workspaceId, title: newPageTitle)
                        if let page = page { selectedPageId = page.id }
                        newPageTitle = ""
                    }
                }
                Button("Cancel", role: .cancel) { newPageTitle = "" }
            }
            .navigationDestination(item: $selectedPageId) { pageId in
                PageEditorView(pageId: pageId)
                    .environmentObject(pagesViewModel)
            }
        }
    }
}

struct PageRowView: View {
    let page: Page
    @Binding var selectedPageId: String?
    let depth: Int
    @EnvironmentObject var pagesViewModel: PagesViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if depth > 0 {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: CGFloat(depth) * 16)
                }
                if let children = page.childPages, !children.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 4))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                }

                Button(action: { selectedPageId = page.id }) {
                    HStack {
                        Text(page.icon ?? "📄")
                        Text(page.title.isEmpty ? "Untitled" : page.title)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        if page.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)

            if isExpanded, let children = page.childPages {
                ForEach(children) { child in
                    PageRowView(page: child, selectedPageId: $selectedPageId, depth: depth + 1)
                        .environmentObject(pagesViewModel)
                        .environmentObject(authViewModel)
                }
            }
        }
    }
}
