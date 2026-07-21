import Foundation

enum MarkdownBlock: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case unorderedItem(String)
    case orderedItem(number: Int, text: String)
    case taskItem(isComplete: Bool, text: String)
    case quote(String)
    case code(language: String?, text: String)
    case table([[String]])
    case thematicBreak

}

enum MarkdownBlockParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: .newlines)
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []
        var index = 0

        func flushParagraph() {
            guard !paragraphLines.isEmpty else { return }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
            paragraphLines.removeAll(keepingCapacity: true)
        }

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                let languageText = String(trimmed.dropFirst(3))
                    .trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count,
                      !lines[index].trimmingCharacters(in: .whitespaces)
                        .hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                if index < lines.count {
                    index += 1
                }
                blocks.append(
                    .code(
                        language: languageText.isEmpty ? nil : languageText,
                        text: codeLines.joined(separator: "\n")
                    )
                )
                continue
            }

            if let table = parseTable(startingAt: index, lines: lines) {
                flushParagraph()
                blocks.append(.table(table.rows))
                index = table.nextIndex
                continue
            }

            if let heading = parseHeading(trimmed) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.thematicBreak)
            } else if let task = parseTask(trimmed) {
                flushParagraph()
                blocks.append(.taskItem(isComplete: task.isComplete, text: task.text))
            } else if let ordered = parseOrderedItem(trimmed) {
                flushParagraph()
                blocks.append(.orderedItem(number: ordered.number, text: ordered.text))
            } else if let unordered = parseUnorderedItem(trimmed) {
                flushParagraph()
                blocks.append(.unorderedItem(unordered))
            } else if trimmed.hasPrefix(">") {
                flushParagraph()
                blocks.append(
                    .quote(
                        String(trimmed.dropFirst())
                            .trimmingCharacters(in: .whitespaces)
                    )
                )
            } else {
                paragraphLines.append(trimmed)
            }

            index += 1
        }

        flushParagraph()
        return blocks
    }

    private static func parseHeading(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level),
              line.dropFirst(level).first == " " else {
            return nil
        }
        return (
            level,
            String(line.dropFirst(level + 1))
        )
    }

    private static func parseTask(_ line: String) -> (isComplete: Bool, text: String)? {
        let prefixes = ["- [ ] ": false, "- [x] ": true, "- [X] ": true]
        for (prefix, isComplete) in prefixes where line.hasPrefix(prefix) {
            return (isComplete, String(line.dropFirst(prefix.count)))
        }
        return nil
    }

    private static func parseUnorderedItem(_ line: String) -> String? {
        for prefix in ["- ", "* ", "+ "] where line.hasPrefix(prefix) {
            return String(line.dropFirst(prefix.count))
        }
        return nil
    }

    private static func parseOrderedItem(_ line: String) -> (number: Int, text: String)? {
        guard let separator = line.firstIndex(of: "."),
              let number = Int(line[..<separator]) else {
            return nil
        }
        let textStart = line.index(after: separator)
        guard textStart < line.endIndex, line[textStart] == " " else {
            return nil
        }
        return (
            number,
            String(line[line.index(after: textStart)...])
        )
    }

    private static func parseTable(
        startingAt index: Int,
        lines: [String]
    ) -> (rows: [[String]], nextIndex: Int)? {
        guard index + 1 < lines.count else { return nil }
        let header = tableCells(lines[index])
        let separator = tableCells(lines[index + 1])
        guard header.count >= 2,
              separator.count == header.count,
              separator.allSatisfy({ cell in
                  let rule = cell.trimmingCharacters(in: CharacterSet(charactersIn: ":- "))
                  return rule.isEmpty && cell.contains("-")
              }) else {
            return nil
        }

        var rows = [header]
        var nextIndex = index + 2
        while nextIndex < lines.count {
            let cells = tableCells(lines[nextIndex])
            guard cells.count == header.count else { break }
            rows.append(cells)
            nextIndex += 1
        }
        return (rows, nextIndex)
    }

    private static func tableCells(_ line: String) -> [String] {
        guard line.contains("|") else { return [] }
        var content = line.trimmingCharacters(in: .whitespaces)
        if content.hasPrefix("|") {
            content.removeFirst()
        }
        if content.hasSuffix("|") {
            content.removeLast()
        }
        return content
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
