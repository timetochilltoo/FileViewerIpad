import SwiftUI

struct MarkdownReaderView: View {
    let text: String
    let search: SearchState
    let readingPosition: ReadingPosition
    let onReadingPositionChanged: (ReadingPosition) -> Void

    @State private var lastReportedLocation: Int?

    private var blocks: [PositionedMarkdownBlock] {
        Self.positionedBlocks(in: text)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(blocks) { positionedBlock in
                        blockView(
                            positionedBlock.block,
                            isActive: activeBlockIndex == positionedBlock.id
                        )
                        .id(positionedBlock.id)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.preference(
                                    key: MarkdownVisibleBlockPreferenceKey.self,
                                    value: [
                                        positionedBlock.id: geometry.frame(
                                            in: .named("markdown-scroll")
                                        ).minY
                                    ]
                                )
                            }
                        }
                    }
                }
                .textSelection(.enabled)
                .accessibilityIdentifier("markdown-content")
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .coordinateSpace(name: "markdown-scroll")
            .onAppear {
                restorePosition(using: proxy)
            }
            .onChange(of: readingPosition) { _, _ in
                restorePosition(using: proxy)
            }
            .onChange(of: search.navigationRequestID) { _, _ in
                guard search.matchCount > 0 else { return }
                proxy.scrollTo(activeBlockIndex, anchor: .center)
            }
            .onPreferenceChange(MarkdownVisibleBlockPreferenceKey.self) { values in
                reportVisiblePosition(values)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .accessibilityIdentifier("markdown-reader")
    }

    private var activeBlockIndex: Int {
        guard search.matchCount > 0 else { return 0 }
        let ranges = DocumentSearchIndex.ranges(in: text, query: search.query)
        guard !ranges.isEmpty else { return 0 }
        let index = DocumentSearchIndex.clampedMatchIndex(
            search.currentMatchIndex,
            count: ranges.count
        )
        let location = ranges[index].location
        return blocks.lastIndex(where: {
            $0.sourceUTF16Location <= location
        }) ?? 0
    }

    private func restorePosition(using proxy: ScrollViewProxy) {
        guard case let .markdown(position) = readingPosition,
              let target = blocks.lastIndex(where: {
                  $0.sourceUTF16Location <= position.visibleUTF16Location
              }) else {
            return
        }
        guard lastReportedLocation != position.visibleUTF16Location else {
            return
        }
        lastReportedLocation = position.visibleUTF16Location
        proxy.scrollTo(target, anchor: .top)
    }

    private func reportVisiblePosition(_ values: [Int: CGFloat]) {
        guard let visible = values
            .filter({ $0.value >= -20 })
            .min(by: { $0.value < $1.value }),
            blocks.indices.contains(visible.key) else {
            return
        }
        let location = blocks[visible.key].sourceUTF16Location
        guard lastReportedLocation != location else { return }
        lastReportedLocation = location
        onReadingPositionChanged(
            .markdown(
                MarkdownReadingPosition(
                    visibleUTF16Location: location,
                    fallbackScrollOffset: max(0, visible.value)
                )
            )
        )
    }

    @ViewBuilder
    private func blockView(
        _ block: MarkdownBlock,
        isActive: Bool
    ) -> some View {
        switch block {
        case let .heading(level, text):
            Text(inlineMarkdown(text))
                .font(headingFont(level))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .padding(.top, level == 1 ? 8 : 2)
                .blockSearchBackground(isActive: isActive)
        case let .paragraph(text):
            Text(inlineMarkdown(text))
                .font(.body)
                .blockSearchBackground(isActive: isActive)
        case let .unorderedItem(text):
            listRow(marker: "•", text: text, isActive: isActive)
        case let .orderedItem(number, text):
            listRow(marker: "\(number).", text: text, isActive: isActive)
        case let .taskItem(isComplete, text):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: isComplete ? "checkmark.square.fill" : "square")
                    .foregroundStyle(
                        isComplete ? Color.accentColor : Color.secondary
                    )
                Text(inlineMarkdown(text))
            }
            .blockSearchBackground(isActive: isActive)
        case let .quote(text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.secondary)
                    .frame(width: 4)
                Text(inlineMarkdown(text))
                    .foregroundStyle(.secondary)
            }
            .blockSearchBackground(isActive: isActive)
        case let .code(language, text):
            VStack(alignment: .leading, spacing: 6) {
                if let language {
                    Text(language.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    Text(inlineMarkdown(text))
                        .font(.system(.body, design: .monospaced))
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(12)
            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .blockSearchBackground(isActive: isActive)
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
            .blockSearchBackground(isActive: isActive)
        case .thematicBreak:
            Divider()
        }
    }

    private func inlineMarkdown(_ text: String) -> AttributedString {
        var attributed = (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )) ?? AttributedString(text)

        let query = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let match = attributed[searchRange].range(
            of: query,
            options: .caseInsensitive
        ) {
            attributed[match].backgroundColor = .yellow.opacity(0.35)
            guard match.upperBound < attributed.endIndex else { break }
            searchRange = match.upperBound..<attributed.endIndex
        }
        return attributed
    }

    private func listRow(
        marker: String,
        text: String,
        isActive: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(marker)
                .frame(width: 28, alignment: .trailing)
                .foregroundStyle(.secondary)
            Text(inlineMarkdown(text))
        }
        .blockSearchBackground(isActive: isActive)
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

    private static func positionedBlocks(in text: String) -> [PositionedMarkdownBlock] {
        let parsed = MarkdownBlockParser.parse(text)
        var cursor = text.startIndex
        return parsed.enumerated().map { index, block in
            let anchor = anchorText(for: block)
            let range = anchor.isEmpty
                ? nil
                : text.range(of: anchor, options: [.caseInsensitive], range: cursor..<text.endIndex)
            let start = range?.lowerBound ?? cursor
            if let range {
                cursor = range.upperBound
            }
            return PositionedMarkdownBlock(
                id: index,
                block: block,
                sourceUTF16Location: start.utf16Offset(in: text)
            )
        }
    }

    private static func anchorText(for block: MarkdownBlock) -> String {
        let value: String = switch block {
        case let .heading(_, text), let .paragraph(text), let .unorderedItem(text),
             let .taskItem(_, text), let .quote(text): text
        case let .orderedItem(_, text): text
        case let .code(_, text): text.components(separatedBy: .newlines).first ?? text
        case let .table(rows): rows.first?.first ?? ""
        case .thematicBreak: "---"
        }
        let firstLine = value.components(separatedBy: .newlines).first ?? value
        return String(firstLine.prefix(48))
    }
}

private struct PositionedMarkdownBlock: Identifiable {
    let id: Int
    let block: MarkdownBlock
    let sourceUTF16Location: Int
}

private struct MarkdownVisibleBlockPreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]

    static func reduce(
        value: inout [Int: CGFloat],
        nextValue: () -> [Int: CGFloat]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private extension View {
    @ViewBuilder
    func blockSearchBackground(isActive: Bool) -> some View {
        if isActive {
            self
                .padding(4)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        } else {
            self
        }
    }
}
