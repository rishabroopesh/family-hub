import SwiftUI

// MARK: - Task Item

struct TaskItem: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isChecked: Bool

    init(id: UUID = UUID(), text: String = "", isChecked: Bool = false) {
        self.id = id
        self.text = text
        self.isChecked = isChecked
    }
}

// MARK: - Page Editor

struct PageEditorView: View {
    let pageId: String
    @EnvironmentObject var pagesViewModel: PagesViewModel
    @State private var title = ""
    @State private var content = ""
    @State private var icon = "📄"
    @State private var pageType: PageType = .page
    @State private var taskItems: [TaskItem] = []
    @State private var showIconPicker = false
    @Environment(\.dismiss) var dismiss

    let commonEmojis = ["📄", "📝", "📚", "🏠", "🎯", "💡", "⭐", "🔴", "🟢", "🔵", "🟡", "📅", "✅", "🎓", "🔬", "📊"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            Divider()
            contentView
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    if pagesViewModel.isSaving {
                        ProgressView().scaleEffect(0.7)
                    }
                    Button("Save") {
                        Task { await saveNow() }
                    }
                    .disabled(pagesViewModel.isSaving)
                }
            }
        }
        .onAppear { loadPage() }
        .onDisappear {
            Task { await saveNow() }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { showIconPicker.toggle() } label: {
                Text(icon).font(.system(size: 40))
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

            VStack(alignment: .leading, spacing: 4) {
                TextField("Page title", text: $title, axis: .vertical)
                    .font(.title.bold())
                    .onChange(of: title) { scheduleAutoSave() }

                Label(pageType.displayName, systemImage: pageType.systemImage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch pageType {
        case .taskList:
            TaskListEditorView(items: $taskItems, style: .square)
                .onChange(of: taskItems) { scheduleAutoSave() }
        case .todo:
            TaskListEditorView(items: $taskItems, style: .circle)
                .onChange(of: taskItems) { scheduleAutoSave() }
        case .code:
            CodeEditorView(content: $content)
                .onChange(of: content) { scheduleAutoSave() }
        case .page:
            pageMarkdownEditor
        }
    }

    private var pageMarkdownEditor: some View {
        VStack(spacing: 0) {
            TextEditor(text: $content)
                .font(.body)
                .padding(.horizontal)
                .onChange(of: content) { scheduleAutoSave() }

            Divider()

            HStack(spacing: 20) {
                FormatButton(label: "**B**", action: { wrapSelection("**") })
                FormatButton(label: "# H",   action: { insertAtLineStart("# ") })
                FormatButton(label: "• List", action: { insertAtLineStart("- ") })
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
    }

    // MARK: - Persistence

    private func buildBlocks() -> [PageBlock] {
        switch pageType {
        case .taskList, .todo:
            let marker = PageBlock(id: nil, type: pageType.rawValue, content: [])
            let itemBlocks = taskItems.map { item in
                PageBlock(
                    id: nil,
                    type: "task_item",
                    content: [
                        BlockContent(type: "text",    text: item.text),
                        BlockContent(type: "checked", text: item.isChecked ? "true" : "false")
                    ]
                )
            }
            return [marker] + itemBlocks

        case .code:
            return [
                PageBlock(id: nil, type: "code", content: []),
                PageBlock(id: nil, type: "code_content", content: [BlockContent(type: "text", text: content)])
            ]

        case .page:
            return content.components(separatedBy: "\n\n").map { text in
                PageBlock(id: nil, type: "paragraph", content: [BlockContent(type: "text", text: text)])
            }
        }
    }

    private func scheduleAutoSave() {
        let blocks = buildBlocks()
        Task { await pagesViewModel.updatePage(id: pageId, title: title, content: blocks) }
    }

    private func saveNow() async {
        await pagesViewModel.saveNow(id: pageId, title: title, content: buildBlocks())
    }

    private func loadPage() {
        Task {
            await pagesViewModel.loadPage(id: pageId)
            guard let page = pagesViewModel.selectedPage else { return }

            title = page.title
            icon  = page.icon ?? "📄"

            // Detect page type from the first block's type field
            let firstType = page.content?.first?.type ?? ""
            pageType = PageType(rawValue: firstType) ?? .page

            switch pageType {
            case .taskList, .todo:
                taskItems = page.content?.dropFirst().compactMap { block -> TaskItem? in
                    guard block.type == "task_item" else { return nil }
                    let text    = block.content?.first(where: { $0.type == "text" })?.text ?? ""
                    let checked = block.content?.first(where: { $0.type == "checked" })?.text == "true"
                    return TaskItem(text: text, isChecked: checked)
                } ?? []
                if taskItems.isEmpty { taskItems = [TaskItem()] }

            case .code:
                content = page.content?
                    .first(where: { $0.type == "code_content" })?
                    .content?.first?.text ?? ""

            case .page:
                content = page.content?.map { $0.toPlainText() }.joined(separator: "\n\n") ?? ""
            }
        }
    }

    // MARK: - Markdown helpers

    private func wrapSelection(_ marker: String) {
        content += marker + "text" + marker
    }

    private func insertAtLineStart(_ prefix: String) {
        content += "\n" + prefix
    }
}

// MARK: - Task List Editor

enum CheckboxStyle { case square, circle }

struct TaskListEditorView: View {
    @Binding var items: [TaskItem]
    let style: CheckboxStyle
    @FocusState private var focusedId: UUID?

    private var accentColor: Color { style == .circle ? .green : .accentColor }
    private var checkedImage: String { style == .circle ? "checkmark.circle.fill" : "checkmark.square.fill" }
    private var uncheckedImage: String { style == .circle ? "circle" : "square" }
    private var addLabel: String { style == .circle ? "Add To-Do" : "Add Item" }

    var body: some View {
        List {
            ForEach($items) { $item in
                HStack(spacing: 12) {
                    Button {
                        item.isChecked.toggle()
                    } label: {
                        Image(systemName: item.isChecked ? checkedImage : uncheckedImage)
                            .font(.title3)
                            .foregroundColor(item.isChecked ? accentColor : Color(.tertiaryLabel))
                            .animation(.easeInOut(duration: 0.15), value: item.isChecked)
                    }
                    .buttonStyle(.plain)

                    TextField("Item", text: $item.text, axis: .vertical)
                        .strikethrough(item.isChecked, color: .secondary)
                        .foregroundColor(item.isChecked ? .secondary : .primary)
                        .focused($focusedId, equals: item.id)
                        .onSubmit { addItemAfter(item) }
                }
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { items.removeAll { $0.id == item.id } }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button(action: addItem) {
                Label(addLabel, systemImage: "plus.circle")
                    .foregroundColor(accentColor)
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    private func addItem() {
        let new = TaskItem()
        withAnimation { items.append(new) }
        focusedId = new.id
    }

    private func addItemAfter(_ item: TaskItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let new = TaskItem()
        withAnimation { items.insert(new, at: idx + 1) }
        focusedId = new.id
    }
}

// MARK: - Code Editor

struct CodeEditorView: View {
    @Binding var content: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if content.isEmpty {
                Text("// Start writing code...")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(Color(.placeholderText))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
            TextEditor(text: $content)
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.none)
                .autocorrectionDisabled(true)
                .padding(.horizontal, 12)
        }
        .background(Color(.systemGroupedBackground).opacity(0.4))
    }
}

// MARK: - Format Button

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
