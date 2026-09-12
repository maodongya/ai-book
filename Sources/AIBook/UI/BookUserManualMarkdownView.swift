import SwiftUI

// MARK: - Parser

private enum UserManualBlock: Identifiable {
    case documentTitle(String)
    case heading(level: Int, text: String)
    case paragraph(String)
    case blockquote([String])
    case bulletList([String])
    case table(headers: [String], rows: [[String]])
    case codeBlock(String)
    case rule

    var id: String {
        switch self {
        case .documentTitle(let text):
            return "title-\(text)"
        case .heading(let level, let text):
            return "h\(level)-\(text)"
        case .paragraph(let text):
            return "p-\(text.prefix(48))"
        case .blockquote(let lines):
            return "q-\(lines.joined().prefix(48))"
        case .bulletList(let items):
            return "ul-\(items.count)-\(items.first?.prefix(24) ?? "")"
        case .table(let headers, _):
            return "table-\(headers.joined())"
        case .codeBlock(let code):
            return "code-\(code.prefix(48))"
        case .rule:
            return "rule"
        }
    }
}

private enum BookUserManualMarkdownParser {
    static func blocks(from markdown: String) -> [UserManualBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [UserManualBlock] = []
        var index = 0

        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if trimmed == "---" || trimmed == "***" {
                blocks.append(.rule)
                index += 1
                continue
            }

            if trimmed.hasPrefix("```") {
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    let codeLine = lines[index]
                    if codeLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                        index += 1
                        break
                    }
                    codeLines.append(codeLine)
                    index += 1
                }
                blocks.append(.codeBlock(codeLines.joined(separator: "\n")))
                continue
            }

            if isTableRow(trimmed), let table = parseTable(lines: lines, start: index) {
                blocks.append(.table(headers: table.headers, rows: table.rows))
                index = table.nextIndex
                continue
            }

            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let text = String(trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces))
                if level == 1 {
                    blocks.append(.documentTitle(text))
                } else {
                    blocks.append(.heading(level: min(level, 4), text: text))
                }
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let quoteTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    guard quoteTrimmed.hasPrefix(">") else { break }
                    var content = String(quoteTrimmed.dropFirst())
                    if content.first == " " {
                        content = String(content.dropFirst())
                    }
                    quoteLines.append(content)
                    index += 1
                }
                blocks.append(.blockquote(quoteLines))
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var items: [String] = []
                while index < lines.count {
                    let itemTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                    if itemTrimmed.hasPrefix("- ") {
                        items.append(String(itemTrimmed.dropFirst(2)))
                        index += 1
                    } else if itemTrimmed.hasPrefix("* ") {
                        items.append(String(itemTrimmed.dropFirst(2)))
                        index += 1
                    } else {
                        break
                    }
                }
                blocks.append(.bulletList(items))
                continue
            }

            var paragraphLines: [String] = [trimmed]
            index += 1
            while index < lines.count {
                let next = lines[index].trimmingCharacters(in: .whitespaces)
                if next.isEmpty { break }
                if next.hasPrefix("#")
                    || next.hasPrefix(">")
                    || next.hasPrefix("- ")
                    || next.hasPrefix("* ")
                    || next.hasPrefix("```")
                    || isTableRow(next)
                    || next == "---"
                    || next == "***"
                {
                    break
                }
                paragraphLines.append(next)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: " ")))
        }

        return blocks
    }

    private static func isTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("|") && trimmed.contains("|")
    }

    private static func splitTableCells(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("|") { trimmed.removeFirst() }
        if trimmed.hasSuffix("|") { trimmed.removeLast() }
        return trimmed.split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func isSeparatorRow(_ cells: [String]) -> Bool {
        cells.allSatisfy { cell in
            cell.replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
                .isEmpty
        }
    }

    private static func parseTable(lines: [String], start: Int) -> (headers: [String], rows: [[String]], nextIndex: Int)? {
        guard start < lines.count, isTableRow(lines[start]) else { return nil }

        let headers = splitTableCells(lines[start])
        guard start + 1 < lines.count, isTableRow(lines[start + 1]) else { return nil }
        let separator = splitTableCells(lines[start + 1])
        guard isSeparatorRow(separator) else { return nil }

        var rows: [[String]] = []
        var index = start + 2
        while index < lines.count, isTableRow(lines[index]) {
            let row = splitTableCells(lines[index])
            if !isSeparatorRow(row) {
                rows.append(row)
            }
            index += 1
        }

        return (headers, rows, index)
    }
}

// MARK: - View

struct BookUserManualMarkdownView: View {
    let markdown: String

    private var blocks: [UserManualBlock] {
        BookUserManualMarkdownParser.blocks(from: markdown)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { offset, block in
                blockView(block)
                    .padding(.bottom, bottomSpacing(after: block, next: blocks[safe: offset + 1]))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bottomSpacing(after block: UserManualBlock, next: UserManualBlock?) -> CGFloat {
        switch block {
        case .documentTitle:
            return 22
        case .heading(let level, _):
            return level <= 2 ? 14 : 10
        case .rule:
            return 18
        case .table, .codeBlock, .blockquote:
            return 16
        case .bulletList, .paragraph:
            return next == nil ? 0 : (isTightFollow(block, next) ? 8 : 14)
        }
    }

    private func isTightFollow(_ current: UserManualBlock, _ next: UserManualBlock?) -> Bool {
        guard let next else { return false }
        switch (current, next) {
        case (.paragraph, .bulletList), (.paragraph, .paragraph):
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private func blockView(_ block: UserManualBlock) -> some View {
        switch block {
        case .documentTitle(let text):
            documentTitleView(text)
        case .heading(let level, let text):
            headingView(level: level, text: text)
        case .paragraph(let text):
            manualInlineText(text)
                .font(BookTheme.bodyFont)
                .foregroundStyle(BookTheme.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        case .blockquote(let lines):
            blockquoteView(lines)
        case .bulletList(let items):
            bulletListView(items)
        case .table(let headers, let rows):
            manualTableView(headers: headers, rows: rows)
        case .codeBlock(let code):
            codeBlockView(code)
        case .rule:
            manualDivider
        }
    }

    private func documentTitleView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            manualInlineText(text)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(BookTheme.ink)

            HStack(spacing: 8) {
                Capsule()
                    .fill(BookTheme.goldGradient)
                    .frame(width: 56, height: 3)
                Capsule()
                    .fill(BookTheme.gold.opacity(0.35))
                    .frame(width: 24, height: 3)
            }
        }
        .padding(.bottom, 4)
    }

    private func headingView(level: Int, text: String) -> some View {
        Group {
            switch level {
            case 2:
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(BookTheme.gold.opacity(0.85))
                        .frame(width: 4, height: 22)
                    manualInlineText(text)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(BookTheme.ink)
                }
                .padding(.top, 6)
            case 3:
                manualInlineText(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(BookTheme.ink)
                    .padding(.top, 4)
            default:
                manualInlineText(text)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BookTheme.inkSecondary)
                    .textCase(nil)
            }
        }
    }

    private func blockquoteView(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                manualInlineText(line)
                    .font(BookTheme.bodyFont)
                    .foregroundStyle(BookTheme.ink)
                    .lineSpacing(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            BookTheme.gold.opacity(0.10),
                            BookTheme.pageEdge.opacity(0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(BookTheme.gold.opacity(0.65))
                .frame(width: 3)
                .padding(.vertical, 10)
                .padding(.leading, 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(BookTheme.gold.opacity(0.18), lineWidth: 1)
        }
    }

    private func bulletListView(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(BookTheme.gold.opacity(0.75))
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    manualInlineText(item)
                        .font(BookTheme.bodyFont)
                        .foregroundStyle(BookTheme.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.leading, 2)
    }

    private func manualTableView(headers: [String], rows: [[String]]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    manualInlineText(header)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(BookTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(BookTheme.gold.opacity(0.14))
                        .overlay(alignment: .trailing) {
                            if index < headers.count - 1 {
                                Rectangle()
                                    .fill(BookTheme.gold.opacity(0.15))
                                    .frame(width: 1)
                            }
                        }
                }
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        manualInlineText(cell)
                            .font(.system(size: 13))
                            .foregroundStyle(BookTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(rowIndex.isMultiple(of: 2) ? Color.clear : BookTheme.pageEdge.opacity(0.28))
                            .overlay(alignment: .trailing) {
                                if colIndex < row.count - 1 {
                                    Rectangle()
                                        .fill(BookTheme.gold.opacity(0.08))
                                        .frame(width: 1)
                                }
                            }
                    }
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(BookTheme.gold.opacity(0.12))
                        .frame(height: 1)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(BookTheme.gold.opacity(0.22), lineWidth: 1)
        }
    }

    private func codeBlockView(_ code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(BookTheme.inkSecondary)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(BookTheme.pageEdge.opacity(0.65))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(BookTheme.inkMuted.opacity(0.25), lineWidth: 1)
        }
    }

    private var manualDivider: some View {
        HStack(spacing: 10) {
            manualDividerLine
            Image(systemName: "book.closed.fill")
                .font(.system(size: 9))
                .foregroundStyle(BookTheme.gold.opacity(0.55))
            manualDividerLine
        }
        .padding(.vertical, 4)
    }

    private var manualDividerLine: some View {
        LinearGradient(
            colors: [
                BookTheme.gold.opacity(0.02),
                BookTheme.gold.opacity(0.35),
                BookTheme.gold.opacity(0.02),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    @ViewBuilder
    private func manualInlineText(_ source: String) -> some View {
        if let attributed = try? AttributedString(
            markdown: source,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attributed)
        } else {
            Text(source)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
