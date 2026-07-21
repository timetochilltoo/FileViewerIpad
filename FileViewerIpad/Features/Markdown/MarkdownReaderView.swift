import SwiftUI

struct MarkdownReaderView: View {
    let text: String

    private var blocks: [MarkdownBlock] {
        MarkdownBlockParser.parse(text)
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(text)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
                .textSelection(.enabled)
                .accessibilityIdentifier("markdown-content")
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
        }
        .background(Color(uiColor: .systemBackground))
        .accessibilityIdentifier("markdown-reader")
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            Text(inlineMarkdown(text))
                .font(headingFont(level))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .padding(.top, level == 1 ? 8 : 2)
        case let .paragraph(text):
            Text(inlineMarkdown(text))
                .font(.body)
        case let .unorderedItem(text):
            listRow(marker: "•", text: text)
        case let .orderedItem(number, text):
            listRow(marker: "\(number).", text: text)
        case let .taskItem(isComplete, text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isComplete ? "checkmark.square.fill" : "square")
                    .foregroundStyle(
                        isComplete ? Color.accentColor : Color.secondary
                    )
                Text(inlineMarkdown(text))
            }
        case let .quote(text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary)
                    .frame(width: 4)
                Text(inlineMarkdown(text))
                    .foregroundStyle(.secondary)
            }
        case let .code(language, text):
            VStack(alignment: .leading, spacing: 6) {
                if let language {
                    Text(language.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    Text(text)
                        .font(.system(.body, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(12)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        case let .table(rows):
            ScrollView(.horizontal) {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                        GridRow {
                            ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                                Text(inlineMarkdown(cell))
                                    .fontWeight(rowIndex == 0 ? .semibold : .regular)
                            }
                        }
                        if rowIndex == 0 {
                            Divider()
                        }
                    }
                }
                .padding(12)
            }
            .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        case .thematicBreak:
            Divider()
        }
    }

    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker)
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(.secondary)
            Text(inlineMarkdown(text))
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .largeTitle
        case 2: .title
        case 3: .title2
        case 4: .title3
        default: .headline
        }
    }
}
