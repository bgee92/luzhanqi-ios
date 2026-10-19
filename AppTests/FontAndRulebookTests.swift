import CoreText
import Foundation
import LuzhanqiKit
import Testing
@testable import Luzhanqi

/// The bundled fonts are subsets; any character missing from them silently falls
/// back to the system font. These tests catch text added without re-running
/// Tools/subset_fonts.py.
@Suite struct FontCoverageTests {
    func font(_ file: String) throws -> CTFont {
        let url = try #require(Bundle.main.url(forResource: file, withExtension: "ttf"), "\(file).ttf is not in the app bundle")
        let descriptor = try #require((CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor])?.first)
        return CTFontCreateWithFontDescriptor(descriptor, 20, nil)
    }

    func missing(_ text: String, in font: CTFont) -> Set<Character> {
        Set(text.filter(\.isCJK).filter { character in
            let utf16 = Array(String(character).utf16)
            var glyphs = [CGGlyph](repeating: 0, count: utf16.count)
            return !CTFontGetGlyphsForCharacters(font, utf16, &glyphs, utf16.count)
        })
    }

    @Test func serifCoversAllChineseText() throws {
        let serif = try font("NotoSerifSC-Black-Subset")
        let chineseUI = catalog(Strings(language: .chinese)).map(\.text).joined()
        let englishQuotes = catalog(Strings(language: .english)).map(\.text).joined()
        let rulebook = try String(contentsOf: #require(Bundle.main.url(forResource: "RULES.zh", withExtension: "md")), encoding: .utf8)
        let gaps = missing(chineseUI + englishQuotes + rulebook + "八一", in: serif)
        #expect(gaps.isEmpty, "Missing from the serif subset (run Tools/subset_fonts.py): \(String(gaps.sorted()))")
    }

    @Test func brushCoversTitleAndSeals() throws {
        let brush = try font("MaShanZheng-Subset")
        let gaps = missing("陆战棋胜败和", in: brush)
        #expect(gaps.isEmpty, "Missing from the brush subset: \(String(gaps.sorted()))")
    }

    @Test func fontsRegisterUnderTheNamesTheAppUses() {
        AppFont.registerBundledFonts()
        for name in [AppFont.serifName, AppFont.brushName, AppFont.displayName] {
            let font = CTFontCreateWithName(name as CFString, 12, nil)
            #expect(CTFontCopyPostScriptName(font) as String == name, "\(name) is not registered")
        }
    }
}

/// The rules page renders the bundled rulebooks and swaps in drawn parts at
/// specific places; these tests keep the rulebooks and the page in step.
@Suite struct RulebookTests {
    func blocks(_ language: AppLanguage) throws -> [MarkdownBlock] {
        let url = try #require(Bundle.main.url(forResource: Strings(language: language).rulesResource, withExtension: "md"))
        return MarkdownBlock.parse(try String(contentsOf: url, encoding: .utf8))
    }

    @Test(arguments: AppLanguage.allCases)
    func rulebookHasTheHooksTheRulesPageReplaces(language: AppLanguage) throws {
        let parsed = try blocks(language)
        let strings = Strings(language: language)
        #expect(parsed.contains { if case let .code(text) = $0 { text.contains("12    o") } else { false } }, "board diagram")
        #expect(parsed.contains { if case let .table(rows) = $0 { ["Piece", "棋子"].contains(rows.first?.first ?? "") } else { false } }, "piece table")
        #expect(parsed.contains { if case let .heading(_, text) = $0 { text == strings.battlesHeading } else { false } }, "Battles heading")
    }

    @Test func bothRulebooksHaveTheSameStructure() throws {
        func shape(_ blocks: [MarkdownBlock]) -> [String] {
            blocks.map {
                switch $0 {
                case let .heading(level, _): "h\(level)"
                case let .table(rows): "table\(rows.count)x\(rows.first?.count ?? 0)"
                case let .list(items, numbered): "\(numbered ? "ol" : "ul")\(items.count)"
                case .code: "code"
                case .paragraph: "p"
                }
            }.filter { $0 != "p" }
        }
        #expect(shape(try blocks(.english)) == shape(try blocks(.chinese)))
    }

    @Test(arguments: AppLanguage.allCases)
    func tablesAreRectangular(language: AppLanguage) throws {
        for case let .table(rows) in try blocks(language) {
            #expect(Set(rows.map(\.count)).count == 1, "ragged table: \(rows.first ?? [])")
        }
    }

    @Test func parserHandlesEveryBlockType() {
        let parsed = MarkdownBlock.parse("""
        # Title

        Some **bold** text
        continued.

        - one
        - two

        1. first
        2. second

        | A | B |
        |---|---|
        | 1 | 2 |

        ```
        code
        ```
        """)
        #expect(parsed == [
            .heading(level: 1, text: "Title"),
            .paragraph("Some **bold** text continued."),
            .list(items: ["one", "two"], numbered: false),
            .list(items: ["first", "second"], numbered: true),
            .table([["A", "B"], ["1", "2"]]),
            .code("code"),
        ])
    }

    @Test func settingsFooterPointsAtARealSection() throws {
        // "See Rules → Variants" must name a heading that exists.
        for (language, heading) in [(AppLanguage.english, "Variants (Settings)"), (.chinese, "变体规则（设置）")] {
            #expect(try blocks(language).contains(.heading(level: 2, text: heading)))
        }
    }

    @Test(arguments: AppLanguage.allCases)
    func variantsTableNamesMatchTheSettingsScreen(language: AppLanguage) throws {
        let s = Strings(language: language)
        let names = try blocks(language).compactMap { block -> [String]? in
            guard case let .table(rows) = block, ["Option", "选项"].contains(rows.first?.first ?? "") else { return nil }
            return rows.dropFirst().map { $0[0].replacingOccurrences(of: "**", with: "") }
        }.first ?? []
        let expected = language == .english
            ? [s.openPieces, s.explosiveMines, s.wrongHeadquartersReveal, s.drawLimit]
            : ["明棋", s.explosiveMines, s.wrongHeadquartersReveal, s.drawLimit]
        #expect(names == expected)
    }
}

/// Board coordinates, used for drawing and for turning taps into squares.
@Suite struct BoardGeometryTests {
    @Test func designUnitsMatchTheBoardLayout() {
        let g = BoardGeometry(size: BoardGeometry.designSize, viewer: .red)
        #expect(g.unit == 1)
        #expect(g.center(of: Position(name: "a1")!) == CGPoint(x: 50, y: 775))
        #expect(g.center(of: Position(name: "e12")!) == CGPoint(x: 450, y: 31))
        #expect(g.center(of: Position(name: "c6")!).y == CGFloat(6 * 62 + 31 + 62))  // below the frontier row
        #expect(g.pieceSize == CGSize(width: 88, height: 54))
    }

    @Test func blueSeesTheBoardRotated() {
        let red = BoardGeometry(size: CGSize(width: 250, height: 403), viewer: .red)
        let blue = BoardGeometry(size: CGSize(width: 250, height: 403), viewer: .blue)
        for p in Board.allPositions {
            let r = red.center(of: p), b = blue.center(of: p)
            #expect(abs(r.x + b.x - 250) < 0.001 && abs(r.y + b.y - 403) < 0.001)
        }
    }

    @Test(arguments: Side.allCases)
    func everySquareRoundTripsThroughATap(viewer: Side) {
        let g = BoardGeometry(size: CGSize(width: 361, height: 581.9), viewer: viewer)
        for p in Board.allPositions {
            #expect(g.position(at: g.center(of: p)) == p)
        }
        #expect(g.position(at: CGPoint(x: 10, y: g.rowHeight * 6.5)) == nil)  // the river
    }

    @Test func officerInsigniaAreAllDifferent() {
        let marks = Rank.allCases.compactMap(PieceArt.insignia)
        #expect(marks.count == 8)
        #expect(Set(marks.map { "\($0.bars)-\($0.stars)" }).count == 8)
        for special in [Rank.engineer, .bomb, .landmine, .flag] { #expect(PieceArt.insignia(special) == nil) }
    }
}
