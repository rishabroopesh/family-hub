import SwiftUI
import UIKit

// MARK: - Editor block types

enum EditorBlockType: String, CaseIterable {
    case paragraph = "paragraph"
    case heading1  = "heading1"
    case heading2  = "heading2"
    case checklist = "checklist"
    case code      = "code"

    var displayName: String {
        switch self {
        case .paragraph: return "Text"
        case .heading1:  return "Heading 1"
        case .heading2:  return "Heading 2"
        case .checklist: return "Checklist"
        case .code:      return "Code"
        }
    }

    var systemImage: String {
        switch self {
        case .paragraph: return "text.alignleft"
        case .heading1:  return "textformat.size.larger"
        case .heading2:  return "textformat.size"
        case .checklist: return "checkmark.square"
        case .code:      return "chevron.left.forwardslash.chevron.right"
        }
    }

    var uiFont: UIFont {
        switch self {
        case .heading1: return .systemFont(ofSize: 26, weight: .bold)
        case .heading2: return .systemFont(ofSize: 20, weight: .semibold)
        case .code:     return .monospacedSystemFont(ofSize: 14, weight: .regular)
        default:        return .preferredFont(forTextStyle: .body)
        }
    }

    var supportsRichText: Bool {
        switch self {
        case .paragraph, .heading1, .heading2: return true
        case .checklist, .code: return false
        }
    }
}

// MARK: - Editor block model

struct EditorBlock: Identifiable {
    var id = UUID()
    var type: EditorBlockType
    var attributedText: NSAttributedString
    var isChecked: Bool = false

    init(type: EditorBlockType = .paragraph) {
        self.type = type
        self.attributedText = NSAttributedString(string: "", attributes: [.font: type.uiFont, .foregroundColor: UIColor.label])
    }

    init(type: EditorBlockType, attributedText: NSAttributedString, isChecked: Bool = false) {
        self.type = type
        self.attributedText = attributedText
        self.isChecked = isChecked
    }

    func toPageBlock() -> PageBlock {
        switch type {
        case .checklist:
            return PageBlock(id: nil, type: "checklist", content: [
                BlockContent(type: "text",    text: attributedText.string),
                BlockContent(type: "checked", text: isChecked ? "true" : "false")
            ])
        case .code:
            return PageBlock(id: nil, type: "code", content: [
                BlockContent(type: "text", text: attributedText.string)
            ])
        default:
            let rtf = (try? attributedText
                .data(from: NSRange(location: 0, length: attributedText.length),
                      documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                .base64EncodedString()) ?? attributedText.string
            return PageBlock(id: nil, type: type.rawValue, content: [
                BlockContent(type: "rtf", text: rtf)
            ])
        }
    }

    static func blocks(from page: Page) -> [EditorBlock] {
        guard let apiBlocks = page.content, !apiBlocks.isEmpty else { return [EditorBlock()] }
        var result: [EditorBlock] = []
        for block in apiBlocks {
            if (block.type == "task_list" || block.type == "todo") && (block.content == nil || block.content!.isEmpty) { continue }
            if block.type == "code" && (block.content == nil || block.content!.isEmpty) { continue }
            switch block.type {
            case "heading1": result.append(richTextBlock(type: .heading1, from: block))
            case "heading2": result.append(richTextBlock(type: .heading2, from: block))
            case "paragraph": result.append(richTextBlock(type: .paragraph, from: block))
            case "checklist", "task_item":
                let text    = block.content?.first(where: { $0.type == "text" })?.text ?? block.toPlainText()
                let checked = block.content?.first(where: { $0.type == "checked" })?.text == "true"
                let attr    = NSAttributedString(string: text, attributes: [.font: EditorBlockType.checklist.uiFont, .foregroundColor: UIColor.label])
                result.append(EditorBlock(type: .checklist, attributedText: attr, isChecked: checked))
            case "code", "code_content":
                let text = block.content?.first(where: { $0.type == "text" })?.text ?? block.toPlainText()
                let attr = NSAttributedString(string: text, attributes: [.font: EditorBlockType.code.uiFont, .foregroundColor: UIColor.label])
                result.append(EditorBlock(type: .code, attributedText: attr))
            default:
                let text = block.toPlainText()
                if !text.isEmpty {
                    let attr = NSAttributedString(string: text, attributes: [.font: EditorBlockType.paragraph.uiFont, .foregroundColor: UIColor.label])
                    result.append(EditorBlock(type: .paragraph, attributedText: attr))
                }
            }
        }
        return result.isEmpty ? [EditorBlock()] : result
    }

    private static func richTextBlock(type: EditorBlockType, from block: PageBlock) -> EditorBlock {
        if let rtfStr = block.content?.first(where: { $0.type == "rtf" })?.text,
           let data = Data(base64Encoded: rtfStr),
           let attr = try? NSAttributedString(data: data,
                                               options: [.documentType: NSAttributedString.DocumentType.rtf],
                                               documentAttributes: nil) {
            // RTF encodes colors as absolute values (black), which is invisible in dark mode.
            // Strip the foreground color so UITextView uses its adaptive label color.
            let mutable = NSMutableAttributedString(attributedString: attr)
            let full = NSRange(location: 0, length: mutable.length)
            mutable.removeAttribute(.foregroundColor, range: full)
            return EditorBlock(type: type, attributedText: mutable)
        }
        let text = block.toPlainText()
        let attr = NSAttributedString(string: text, attributes: [.font: type.uiFont, .foregroundColor: UIColor.label])
        return EditorBlock(type: type, attributedText: attr)
    }
}

// MARK: - Focus coordinator

final class EditorFocusCoordinator: ObservableObject {
    weak var focusedTextView: UITextView?

    func applyBold()   { toggleTrait(.traitBold) }
    func applyItalic() { toggleTrait(.traitItalic) }

    func applyUnderline() {
        guard let tv = focusedTextView, tv.selectedRange.length > 0 else { return }
        let range = tv.selectedRange
        let current = tv.textStorage.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int ?? 0
        tv.textStorage.addAttribute(.underlineStyle, value: current == 0 ? NSUnderlineStyle.single.rawValue : 0, range: range)
    }

    // Applies a new font to the entire focused text view, updating typing attributes so new text matches.
    func applyFont(_ font: UIFont, strippingFormatting: Bool = false) {
        guard let tv = focusedTextView else { return }
        let full = NSRange(location: 0, length: tv.textStorage.length)
        if strippingFormatting {
            tv.attributedText = NSAttributedString(string: tv.textStorage.string, attributes: [.font: font, .foregroundColor: UIColor.label])
        } else {
            tv.textStorage.addAttribute(.font, value: font, range: full)
        }
        tv.typingAttributes = [.font: font, .foregroundColor: UIColor.label]
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = focusedTextView, tv.selectedRange.length > 0 else { return }
        let range = tv.selectedRange
        var allHave = true
        tv.textStorage.enumerateAttribute(.font, in: range) { val, _, stop in
            let f = (val as? UIFont) ?? .preferredFont(forTextStyle: .body)
            if !f.fontDescriptor.symbolicTraits.contains(trait) { allHave = false; stop.pointee = true }
        }
        tv.textStorage.beginEditing()
        tv.textStorage.enumerateAttribute(.font, in: range) { val, r, _ in
            let base = (val as? UIFont) ?? .preferredFont(forTextStyle: .body)
            var traits = base.fontDescriptor.symbolicTraits
            if allHave { traits.remove(trait) } else { traits.insert(trait) }
            if let desc = base.fontDescriptor.withSymbolicTraits(traits) {
                tv.textStorage.addAttribute(.font, value: UIFont(descriptor: desc, size: base.pointSize), range: r)
            }
        }
        tv.textStorage.endEditing()
    }
}

// MARK: - Rich text UITextView wrapper

// UITextView subclass that surfaces backspace presses while the cursor is at position 0
// (used to merge the current block into the one above, Notion-style).
final class EditorTextView: UITextView {
    var onBackspaceAtStart: (() -> Void)?

    override func deleteBackward() {
        if selectedRange.location == 0 && selectedRange.length == 0 {
            onBackspaceAtStart?()
            return
        }
        super.deleteBackward()
    }
}

struct RichTextView: UIViewRepresentable {
    // Value (not binding) — the UITextView is the source of truth while editing.
    var attributedText: NSAttributedString
    var defaultFont: UIFont
    var isEditable: Bool = true
    var autocorrection: UITextAutocorrectionType = .default
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var containerInsetLeft: CGFloat = 12
    var containerInsetRight: CGFloat = 12
    var focusCoordinator: EditorFocusCoordinator
    var onFocus: (() -> Void)?
    var onChange: (() -> Void)?
    var onEndEditing: ((NSAttributedString) -> Void)?
    var onSplit: ((NSAttributedString, NSAttributedString) -> Void)?
    var onMergeUp: (() -> Void)?
    var splitsOnReturn: Bool = true
    var shouldFocus: Bool = false
    var cursorOffsetOnFocus: Int? = nil
    var onFocusConsumed: (() -> Void)?
    @Binding var height: CGFloat

    static let minBlockHeight: CGFloat = 22

    func makeUIView(context: Context) -> UITextView {
        let tv = EditorTextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainer.lineFragmentPadding = 0
        // Stop the text view from insisting on its intrinsic content width: long lines
        // would otherwise blow past the screen instead of wrapping.
        tv.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        applyTextViewSettings(to: tv)
        // Do NOT set allowsEditingTextAttributes — it causes the system to inject bold
        // typing attributes unexpectedly. Formatting is handled exclusively by the toolbar.
        tv.textColor = .label
        let initial = attributedText.length > 0
            ? attributedText
            : NSAttributedString(string: "", attributes: [.font: defaultFont, .foregroundColor: UIColor.label])
        tv.attributedText = initial
        tv.typingAttributes = [.font: defaultFont, .foregroundColor: UIColor.label]
        let coordinator = context.coordinator
        tv.onBackspaceAtStart = { [weak coordinator] in
            coordinator?.parent.onMergeUp?()
        }
        if shouldFocus {
            applyFocus(to: tv)
        }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Always refresh the coordinator's `parent` so callbacks read current closures/state.
        context.coordinator.parent = self
        // Refresh per-block-type settings (insets / keyboard behavior) so e.g. converting
        // a code block back to a paragraph immediately re-enables autocorrect.
        let needsKeyboardReload = tv.autocorrectionType != autocorrection || tv.autocapitalizationType != autocapitalization
        applyTextViewSettings(to: tv)
        if needsKeyboardReload && tv.isFirstResponder {
            tv.reloadInputViews()
        }
        if !context.coordinator.isEditing {
            let incoming = attributedText.length > 0
                ? attributedText
                : NSAttributedString(string: "", attributes: [.font: defaultFont, .foregroundColor: UIColor.label])
            if tv.attributedText != incoming {
                tv.attributedText = incoming
                tv.typingAttributes = [.font: defaultFont, .foregroundColor: UIColor.label]
            }
            tv.isEditable = isEditable
            refreshHeight(tv)
        } else {
            refreshHeight(tv)
        }
        if shouldFocus && !tv.isFirstResponder {
            applyFocus(to: tv)
        }
    }

    private func applyTextViewSettings(to tv: UITextView) {
        tv.textContainerInset = UIEdgeInsets(top: 1, left: containerInsetLeft, bottom: 1, right: containerInsetRight)
        tv.autocorrectionType = autocorrection
        tv.autocapitalizationType = autocapitalization
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    private func applyFocus(to tv: UITextView) {
        let offset = cursorOffsetOnFocus
        DispatchQueue.main.async {
            tv.becomeFirstResponder()
            let len = tv.textStorage.length
            let target = max(0, min(offset ?? 0, len))
            tv.selectedRange = NSRange(location: target, length: 0)
            onFocusConsumed?()
        }
    }

    private func refreshHeight(_ tv: UITextView) {
        DispatchQueue.main.async {
            let w = tv.frame.width > 0 ? tv.frame.width : UIScreen.main.bounds.width - 32
            let h = max(tv.sizeThatFits(CGSize(width: w, height: .infinity)).height, Self.minBlockHeight)
            if abs(self.height - h) > 1 { self.height = h }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextView
        var isEditing = false
        init(_ parent: RichTextView) { self.parent = parent }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard parent.splitsOnReturn, text == "\n", let onSplit = parent.onSplit else { return true }
            let storage = tv.textStorage
            let total = storage.length
            let location = max(0, min(range.location, total))
            let cursorEnd = max(location, min(range.location + range.length, total))
            let before = storage.attributedSubstring(from: NSRange(location: 0, length: location))
            let after = storage.attributedSubstring(from: NSRange(location: cursorEnd, length: total - cursorEnd))
            tv.attributedText = before
            let w = tv.frame.width > 0 ? tv.frame.width : UIScreen.main.bounds.width - 32
            parent.height = max(tv.sizeThatFits(CGSize(width: w, height: .infinity)).height, RichTextView.minBlockHeight)
            onSplit(before, after)
            return false
        }

        func textViewDidChange(_ tv: UITextView) {
            parent.onChange?()
            let w = tv.frame.width > 0 ? tv.frame.width : UIScreen.main.bounds.width - 32
            parent.height = max(tv.sizeThatFits(CGSize(width: w, height: .infinity)).height, RichTextView.minBlockHeight)
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            isEditing = true
            parent.focusCoordinator.focusedTextView = tv
            parent.onFocus?()
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            isEditing = false
            parent.onEndEditing?(tv.attributedText)
        }
    }
}

// MARK: - Page editor

struct PageEditorView: View {
    let pageId: String
    @EnvironmentObject var pagesViewModel: PagesViewModel

    @State private var title = ""
    @State private var icon = "📄"
    @State private var blocks: [EditorBlock] = [EditorBlock()]
    @State private var focusedBlockId: UUID?
    @State private var pendingFocusId: UUID?
    @State private var pendingCursorOffset: Int?
    @State private var showIconPicker = false
    @StateObject private var focus = EditorFocusCoordinator()
    @Environment(\.dismiss) var dismiss

    private let commonEmojis = ["📄","📝","📚","🏠","🎯","💡","⭐","🔴","🟢","🔵","🟡","📅","✅","🎓","🔬","📊"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerView
                        Divider().padding(.horizontal)
                        blocksView
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: focusedBlockId) { _, id in
                    if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
                }
            }

            formattingBar.background(.bar)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if pagesViewModel.isSaving {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Button("Save") { Task { await saveNow() } }
                }
            }
        }
        .onAppear { loadPage() }
        .onDisappear { Task { await saveNow() } }
    }

    // MARK: Header

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { showIconPicker.toggle() } label: {
                Text(icon).font(.system(size: 40))
            }
            .popover(isPresented: $showIconPicker) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(commonEmojis, id: \.self) { emoji in
                        Button(emoji) { icon = emoji; showIconPicker = false }.font(.title)
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
    }

    // MARK: Blocks

    private var blocksView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Use ForEach over values (not bindings) to avoid index-out-of-range crashes
            // when the array mutates. Mutations go through explicit callbacks.
            ForEach(blocks) { block in
                BlockRowView(
                    block: block,
                    isFocused: focusedBlockId == block.id,
                    focus: focus,
                    shouldFocus: pendingFocusId == block.id,
                    cursorOffsetOnFocus: pendingFocusId == block.id ? pendingCursorOffset : nil,
                    onFocus: { focusedBlockId = block.id },
                    onChange: scheduleAutoSave,
                    onEndEditing: { newText in syncText(id: block.id, text: newText) },
                    onCheckToggle: { toggleCheck(id: block.id) },
                    onDelete: { deleteBlock(id: block.id) },
                    onSplit: { before, after in splitBlock(id: block.id, before: before, after: after) },
                    onMergeUp: { mergeUp(id: block.id) },
                    onFocusConsumed: {
                        pendingFocusId = nil
                        pendingCursorOffset = nil
                    }
                )
                .id(block.id)
            }

            Button { addBlock(after: blocks.last?.id) } label: {
                Color.clear.frame(maxWidth: .infinity, minHeight: 80)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 16)
    }

    // MARK: Formatting toolbar

    private var formattingBar: some View {
        let focused = blocks.first(where: { $0.id == focusedBlockId })
        let richOk  = focused?.type.supportsRichText == true

        return VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    // Style picker
                    Menu {
                        ForEach([EditorBlockType.paragraph, .heading1, .heading2], id: \.rawValue) { t in
                            Button { changeType(to: t) } label: {
                                Label(t.displayName, systemImage: t.systemImage)
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "textformat")
                            Text(richTextLabel(for: focused?.type)).font(.caption)
                            Image(systemName: "chevron.down").font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                    .disabled(focused == nil)

                    toolbarDivider

                    ToolbarIconButton(icon: "bold",      label: "Bold")      { focus.applyBold() }      .disabled(!richOk)
                    ToolbarIconButton(icon: "italic",    label: "Italic")    { focus.applyItalic() }    .disabled(!richOk)
                    ToolbarIconButton(icon: "underline", label: "Underline") { focus.applyUnderline() } .disabled(!richOk)

                    toolbarDivider

                    ToolbarIconButton(icon: "checkmark.square",                        label: "Checklist") { changeType(to: .checklist) }
                    ToolbarIconButton(icon: "chevron.left.forwardslash.chevron.right", label: "Code")      { changeType(to: .code) }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    private var toolbarDivider: some View {
        Divider().frame(height: 22).padding(.horizontal, 4)
    }

    private func richTextLabel(for type: EditorBlockType?) -> String {
        guard let type, type.supportsRichText else { return "Text" }
        return type.displayName
    }

    // MARK: Block mutations

    private func syncText(id: UUID, text: NSAttributedString) {
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx].attributedText = text
        }
    }

    private func toggleCheck(id: UUID) {
        if let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks[idx].isChecked.toggle()
            scheduleAutoSave()
        }
    }

    private func changeType(to newType: EditorBlockType) {
        guard let idx = blocks.firstIndex(where: { $0.id == focusedBlockId }) else { return }
        // Sync the latest text from UITextView before mutating
        if let tv = focus.focusedTextView {
            blocks[idx].attributedText = tv.attributedText
        }
        let plain = blocks[idx].attributedText.string
        blocks[idx].type = newType
        blocks[idx].attributedText = NSAttributedString(string: plain, attributes: [.font: newType.uiFont, .foregroundColor: UIColor.label])
        focus.applyFont(newType.uiFont, strippingFormatting: !newType.supportsRichText)
        scheduleAutoSave()
    }

    private func addBlock(after id: UUID?, type: EditorBlockType = .paragraph) {
        let newBlock = EditorBlock(type: type)
        if let id, let idx = blocks.firstIndex(where: { $0.id == id }) {
            blocks.insert(newBlock, at: idx + 1)
        } else {
            blocks.append(newBlock)
        }
        focusedBlockId = newBlock.id
        pendingFocusId = newBlock.id
        scheduleAutoSave()
    }

    // Backspace at the start of a block merges it into the previous block (Notion-style).
    // The merged text adopts the previous block's style; cursor lands at the join point.
    private func mergeUp(id: UUID) {
        guard let idx = blocks.firstIndex(where: { $0.id == id }), idx > 0 else { return }
        var currentText = blocks[idx].attributedText
        if focusedBlockId == id, let tv = focus.focusedTextView {
            currentText = tv.attributedText
        }
        let prevIdx = idx - 1
        let prevType = blocks[prevIdx].type
        let prevText = blocks[prevIdx].attributedText
        let joinOffset = prevText.length

        let merged = NSMutableAttributedString(attributedString: prevText)
        merged.append(restyleAfterText(currentText, forType: prevType))

        blocks[prevIdx].attributedText = merged
        let prevId = blocks[prevIdx].id
        blocks.remove(at: idx)
        focusedBlockId = prevId
        pendingFocusId = prevId
        pendingCursorOffset = joinOffset
        scheduleAutoSave()
    }

    // Splits the block at the cursor: keeps `before` in the current block, creates a new
    // paragraph (or checklist) below carrying `after`, and moves focus there. Used when
    // the user presses Return so each visual line becomes its own styleable block.
    private func splitBlock(id: UUID, before: NSAttributedString, after: NSAttributedString) {
        guard let idx = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks[idx].attributedText = before
        let currentType = blocks[idx].type
        let newType: EditorBlockType = (currentType == .checklist) ? .checklist : .paragraph
        let restyled = restyleAfterText(after, forType: newType)
        let newBlock = EditorBlock(type: newType, attributedText: restyled)
        blocks.insert(newBlock, at: idx + 1)
        focusedBlockId = newBlock.id
        pendingFocusId = newBlock.id
        scheduleAutoSave()
    }

    // Re-baselines the inherited font to the new block's size while preserving bold/italic traits.
    private func restyleAfterText(_ text: NSAttributedString, forType type: EditorBlockType) -> NSAttributedString {
        let baseFont = type.uiFont
        if text.length == 0 {
            return NSAttributedString(string: "", attributes: [.font: baseFont, .foregroundColor: UIColor.label])
        }
        let mutable = NSMutableAttributedString(attributedString: text)
        let full = NSRange(location: 0, length: mutable.length)
        mutable.enumerateAttribute(.font, in: full) { val, range, _ in
            let oldFont = (val as? UIFont) ?? baseFont
            let traits = oldFont.fontDescriptor.symbolicTraits
            let desc = baseFont.fontDescriptor.withSymbolicTraits(traits) ?? baseFont.fontDescriptor
            mutable.addAttribute(.font, value: UIFont(descriptor: desc, size: baseFont.pointSize), range: range)
        }
        return mutable
    }

    private func deleteBlock(id: UUID) {
        guard blocks.count > 1, let idx = blocks.firstIndex(where: { $0.id == id }) else { return }
        blocks.remove(at: idx)
        focusedBlockId = blocks[max(0, idx - 1)].id
        scheduleAutoSave()
    }

    // MARK: Persistence

    // Grabs the latest text from the active UITextView so in-progress edits are always saved.
    private func currentBlocks() -> [EditorBlock] {
        var snapshot = blocks
        if let tv = focus.focusedTextView,
           let id  = focusedBlockId,
           let idx = snapshot.firstIndex(where: { $0.id == id }) {
            snapshot[idx].attributedText = tv.attributedText
        }
        return snapshot
    }

    private func scheduleAutoSave() {
        let saved = currentBlocks().map { $0.toPageBlock() }
        Task { await pagesViewModel.updatePage(id: pageId, title: title, content: saved) }
    }

    private func saveNow() async {
        let saved = currentBlocks().map { $0.toPageBlock() }
        await pagesViewModel.saveNow(id: pageId, title: title, content: saved)
    }

    private func loadPage() {
        Task {
            await pagesViewModel.loadPage(id: pageId)
            guard let page = pagesViewModel.selectedPage else { return }
            title  = page.title
            icon   = page.icon ?? "📄"
            blocks = EditorBlock.blocks(from: page)
        }
    }
}

// MARK: - Block row

struct BlockRowView: View {
    let block: EditorBlock
    let isFocused: Bool
    let focus: EditorFocusCoordinator
    let shouldFocus: Bool
    let cursorOffsetOnFocus: Int?
    let onFocus: () -> Void
    let onChange: () -> Void
    let onEndEditing: (NSAttributedString) -> Void
    let onCheckToggle: () -> Void
    let onDelete: () -> Void
    let onSplit: (NSAttributedString, NSAttributedString) -> Void
    let onMergeUp: () -> Void
    let onFocusConsumed: () -> Void

    @State private var height: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if block.type == .checklist {
                Button(action: onCheckToggle) {
                    Image(systemName: block.isChecked ? "checkmark.square.fill" : "square")
                        .foregroundColor(block.isChecked ? .accentColor : Color(.tertiaryLabel))
                        .font(.body)
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
                .padding(.leading, 12)
            }

            if block.type == .code {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.5))
                    .frame(width: 3)
                    .padding(.leading, 12)
                    .padding(.vertical, 2)
            }

            RichTextView(
                attributedText: block.attributedText,
                defaultFont: block.type.uiFont,
                isEditable: true,
                autocorrection: block.type == .code ? .no : .default,
                autocapitalization: block.type == .code ? .none : .sentences,
                containerInsetLeft: block.type == .checklist ? 6 : 12,
                focusCoordinator: focus,
                onFocus: onFocus,
                onChange: onChange,
                onEndEditing: onEndEditing,
                onSplit: block.type == .code ? nil : onSplit,
                onMergeUp: onMergeUp,
                splitsOnReturn: block.type != .code,
                shouldFocus: shouldFocus,
                cursorOffsetOnFocus: cursorOffsetOnFocus,
                onFocusConsumed: onFocusConsumed,
                height: $height
            )
            .frame(height: height)
            .opacity(block.isChecked && block.type == .checklist ? 0.4 : 1)
        }
        .background(block.type == .code ? Color(.systemGroupedBackground).opacity(0.6) : .clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Toolbar button

struct ToolbarIconButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .frame(width: 38, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .accessibilityLabel(label)
    }
}
