import LuzhanqiKit
import SwiftUI

/// Shows the bundled rulebook (RULES.md or RULES.zh.md), so the app and the
/// repository share one rulebook per language. Three parts are drawn instead of
/// printed: the board diagram becomes the real board with a legend, the piece
/// table becomes the actual pieces, and the movement rules get example boards
/// (inserted before the Battles section).
struct RulesView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let strings = settings.strings
        ScrollViewReader { reader in
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(MarkdownBlock.parse(Self.load(strings)).enumerated()), id: \.offset) { _, block in
                    switch block {
                    case let .code(text) where text.contains("12    o"):
                        RulesBoard(strings: strings).accessibilityIdentifier("rules.board")
                    case let .table(rows) where ["Piece", "棋子"].contains(rows.first?.first ?? ""):
                        PieceList(strings: strings).id("pieces").accessibilityIdentifier("rules.pieces")
                    case let .heading(_, text) where text == strings.battlesHeading:
                        MovementExamples(strings: strings).id("examples").accessibilityIdentifier("rules.examples")
                        MarkdownBlockView(block: block)
                    default:
                        MarkdownBlockView(block: block)
                    }
                }
            }
            .padding()
        }
        #if DEBUG
        // Screenshots: launch with `-demo rules -rulesAnchor pieces|examples`.
        .onAppear {
            let args = CommandLine.arguments
            if let i = args.firstIndex(of: "-rulesAnchor"), i + 1 < args.count {
                reader.scrollTo(args[i + 1], anchor: .top)
            }
        }
        #endif
        }
        .foregroundStyle(Palette.ink)
        .background(Palette.paperHi.ignoresSafeArea())
        .navigationTitle(strings.rules)
        .navigationBarTitleDisplayMode(.inline)
        // Opened from the dark home screen, the bar still matches the paper page.
        .toolbarBackground(Palette.paperHi, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    private static func load(_ strings: Strings) -> String {
        guard let url = Bundle.main.url(forResource: strings.rulesResource, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return strings.rulesUnavailable
        }
        return text
    }
}

/// The empty board, drawn by the game's own renderer, with a legend.
private struct RulesBoard: View {
    let strings: Strings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardView(viewer: .red, pieces: [], strings: strings)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Palette.ink.opacity(0.35), radius: 8, y: 5)
            FlowLegend(items: [
                (AnyView(legendLine(rail: true)), strings.legendRailroad),
                (AnyView(legendLine(rail: false)), strings.legendRoad),
                (AnyView(Circle().fill(Palette.camp).overlay(Circle().stroke(Palette.ink, lineWidth: 1)).frame(width: 12, height: 12)), strings.legendCamp),
                (AnyView(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6).fill(Palette.headquarters)
                    .overlay(UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6).stroke(Palette.ink, lineWidth: 1)).frame(width: 13, height: 11)),
                 strings.legendHeadquarters),
                (AnyView(RoundedRectangle(cornerRadius: 2).fill(Palette.riverMid).frame(width: 20, height: 10)), strings.legendFrontier),
            ])
        }
        .padding(.vertical, 4)
    }

    private func legendLine(rail: Bool) -> some View {
        ZStack {
            Capsule().fill(rail ? Palette.rail : Palette.inkSoft).frame(width: 22, height: rail ? 5 : 1.5)
            if rail {
                Rectangle().fill(Palette.paperHi).frame(width: 22, height: 2).mask(
                    HStack(spacing: 3) { ForEach(0..<4, id: \.self) { _ in Rectangle().frame(width: 3) } })
            }
        }
    }
}

private struct FlowLegend: View {
    let items: [(AnyView, String)]

    var body: some View {
        // Two columns keep the legend tidy at phone width.
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 6) {
                    item.0.frame(width: 24)
                    Text(item.1).font(.caption.weight(.semibold))
                }
            }
        }
    }
}

/// Every piece with its art, what the art shows, and how many each side has.
private struct PieceList: View {
    let strings: Strings

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Rank.allCases, id: \.self) { rank in
                HStack(spacing: 10) {
                    PieceTile(side: .red, rank: rank, strings: strings).frame(width: 62)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(strings.rank(rank)).font(.subheadline.weight(.bold))
                        Text(strings.pieceArt(rank)).font(.caption).foregroundStyle(Palette.ink.opacity(0.65))
                    }
                    Spacer(minLength: 0)
                    Text("×\(rank.count)").font(.subheadline.weight(.bold)).monospacedDigit()
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.ink.opacity(0.05)))
    }
}

/// Small boards with the movement rules drawn on them.
private struct MovementExamples: View {
    let strings: Strings

    var body: some View {
        let examples = strings.movementExamples
        VStack(alignment: .leading, spacing: 16) {
            example(examples[0], pieces: [piece(10, 0, .red, .colonel)], arrows: [
                BoardArrow(path: [Position(10, 0), Position(1, 0)], tone: .gold),
                BoardArrow(path: [Position(1, 0), Position(1, 2)], tone: .red, dashed: true, blocked: true),
            ])
            example(examples[1], pieces: [piece(10, 2, .red, .engineer)], arrows: [
                BoardArrow(path: [Position(10, 2), Position(10, 0), Position(6, 0), Position(6, 2), Position(5, 2), Position(5, 4), Position(1, 4)], tone: .jade),
            ])
            example(examples[2], pieces: [piece(8, 2, .red, .lieutenant), piece(8, 3, .blue, .general)], arrows: [
                BoardArrow(path: [Position(8, 3), Position(8, 2)], tone: .red, dashed: true, blocked: true),
            ])
        }
    }

    private func piece(_ row: Int, _ col: Int, _ side: Side, _ rank: Rank) -> BoardPiece {
        BoardPiece(id: row * 5 + col, side: side, rank: rank, position: Position(row, col))
    }

    private func example(_ text: (title: String, caption: String), pieces: [BoardPiece], arrows: [BoardArrow]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BoardView(viewer: .red, pieces: pieces, strings: strings, arrows: arrows)
                .frame(width: 130)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Palette.ink.opacity(0.3), radius: 5, y: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Heading(text: text.title, size: 15)
                Text(text.caption).font(.footnote)
            }
        }
    }
}

/// The small subset of Markdown that RULES.md uses.
enum MarkdownBlock: Hashable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list(items: [String], numbered: Bool)
    case code(String)
    case table([[String]])

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var i = 0
        func collect(while condition: (String) -> Bool) -> [String] {
            var out: [String] = []
            while i < lines.count, condition(lines[i]) {
                out.append(lines[i])
                i += 1
            }
            return out
        }
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                i += 1
            } else if trimmed.hasPrefix("```") {
                i += 1
                let code = collect { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }
                i += 1
                blocks.append(.code(code.joined(separator: "\n")))
            } else if trimmed.hasPrefix("#") {
                let level = trimmed.prefix { $0 == "#" }.count
                blocks.append(.heading(level: level, text: trimmed.dropFirst(level).trimmingCharacters(in: .whitespaces)))
                i += 1
            } else if trimmed.hasPrefix("|") {
                let rows = collect { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
                    .map { row in
                        row.trimmingCharacters(in: .whitespaces)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
                            .components(separatedBy: "|")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                    }
                    .filter { cells in !cells.allSatisfy { $0.allSatisfy { "-:".contains($0) } } }
                blocks.append(.table(rows))
            } else if trimmed.hasPrefix("- ") {
                let items = collect { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- ") }
                blocks.append(.list(items: items.map { String($0.trimmingCharacters(in: .whitespaces).dropFirst(2)) }, numbered: false))
            } else if isNumbered(trimmed) {
                let items = collect { isNumbered($0.trimmingCharacters(in: .whitespaces)) }
                blocks.append(.list(items: items.map { $0.split(separator: ".", maxSplits: 1)[1].trimmingCharacters(in: .whitespaces) }, numbered: true))
            } else {
                let paragraph = collect { line in
                    let t = line.trimmingCharacters(in: .whitespaces)
                    return !t.isEmpty && !t.hasPrefix("#") && !t.hasPrefix("|") && !t.hasPrefix("- ") && !t.hasPrefix("```")
                }
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
            }
        }
        return blocks
    }

    private static func isNumbered(_ line: String) -> Bool {
        guard let dot = line.firstIndex(of: ".") else { return false }
        return !line[..<dot].isEmpty && line[..<dot].allSatisfy(\.isNumber)
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Heading(text: text, size: level == 1 ? 26 : level == 2 ? 20 : 16)
                .padding(.top, level == 1 ? 0 : 8)
        case let .paragraph(text):
            inline(text)
        case let .list(items, numbered):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(numbered ? "\(index + 1)." : "•").monospacedDigit()
                        inline(item)
                    }
                }
            }
        case let .code(text):
            ScrollView(.horizontal) {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
            }
            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        case let .table(rows):
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            inline(cell)
                                .font(index == 0 ? .footnote.bold() : .footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if index == 0 { Divider() }
                }
            }
            .padding(10)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return Text((try? AttributedString(markdown: text, options: options)) ?? AttributedString(text))
    }
}
