import SwiftUI

struct PageEditorView: View {
    let pageId: String
    @EnvironmentObject var pagesViewModel: PagesViewModel
    @State private var title = ""
    @State private var content = ""
    @State private var icon = "📄"
    @State private var showIconPicker = false
    @Environment(\.dismiss) var dismiss

    let commonEmojis = ["📄", "📝", "📚", "🏠", "🎯", "💡", "⭐", "🔴", "🟢", "🔵", "🟡", "📅", "✅", "🎓", "🔬", "📊"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon + Title
            HStack(alignment: .top, spacing: 12) {
                Button(action: { showIconPicker.toggle() }) {
                    Text(icon)
                        .font(.system(size: 40))
                }
                .popover(isPresented: $showIconPicker) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(commonEmojis, id: \.self) { emoji in
                            Button(emoji) {
                                icon = emoji
                                showIconPicker = false
                            }
                            .font(.title)
                        }
                    }
                    .padding()
                    .frame(width: 220)
                }

                TextField("Page title", text: $title, axis: .vertical)
                    .font(.title.bold())
                    .onChange(of: title) { scheduleAutoSave() }
            }
            .padding()

            Divider()

            // Content Editor
            TextEditor(text: $content)
                .font(.body)
                .padding(.horizontal)
                .onChange(of: content) { scheduleAutoSave() }

            // Formatting Toolbar
            HStack(spacing: 20) {
                FormatButton(label: "**B**", action: { wrapSelection("**") })
                FormatButton(label: "# H", action: { insertAtLineStart("# ") })
                FormatButton(label: "• List", action: { insertAtLineStart("- ") })
                FormatButton(label: "☐ Todo", action: { insertAtLineStart("- [ ] ") })
                Spacer()
                if pagesViewModel.isSaving {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.7)
                        Text("Saving...").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGroupedBackground))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") {
                    Task { await saveNow() }
                }
                .disabled(pagesViewModel.isSaving)
            }
        }
        .onAppear { loadPage() }
        .onDisappear {
            // Flush any pending edits before navigating away
            Task { await saveNow() }
        }
    }

    private func saveNow() async {
        let blocks = content.components(separatedBy: "\n\n").map { text in
            PageBlock(id: nil, type: "paragraph", content: [BlockContent(type: "text", text: text)])
        }
        await pagesViewModel.saveNow(id: pageId, title: title, content: blocks)
    }

    private func loadPage() {
        Task {
            await pagesViewModel.loadPage(id: pageId)
            if let page = pagesViewModel.selectedPage {
                title = page.title
                icon = page.icon ?? "📄"
                content = page.content?.map { $0.toPlainText() }.joined(separator: "\n\n") ?? ""
            }
        }
    }

    private func scheduleAutoSave() {
        let blocks = content.components(separatedBy: "\n\n").map { text in
            PageBlock(id: nil, type: "paragraph", content: [BlockContent(type: "text", text: text)])
        }
        Task { await pagesViewModel.updatePage(id: pageId, title: title, content: blocks) }
    }

    private func wrapSelection(_ marker: String) {
        content += marker + "text" + marker
    }

    private func insertAtLineStart(_ prefix: String) {
        content += "\n" + prefix
    }
}

struct FormatButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
        }
        .buttonStyle(.plain)
    }
}
