import Foundation
import LuzhanqiKit
import Testing
@testable import Luzhanqi

/// One piece of user-facing text, with what kind of text it is so the right
/// grammar and punctuation rules apply.
struct TextEntry {
    enum Kind {
        /// Buttons, titles, labels: no closing full stop.
        case label
        /// Full sentences: must end with sentence punctuation.
        case sentence
        /// Not prose (markdown, seals): only basic checks.
        case other
    }

    let name: String
    let text: String
    let kind: Kind
    /// English text that legitimately quotes Chinese (rank names, 明棋, the title).
    var allowsChinese = false
}

/// Every string `Strings` can produce, in one language. `stringsCatalogCoversEveryMember`
/// fails if a new member is added to Strings.swift without being listed here.
func catalog(_ s: Strings) -> [TextEntry] {
    var e: [TextEntry] = []
    func add(_ name: String, _ text: String, _ kind: TextEntry.Kind = .label, allowsChinese: Bool = false) {
        e.append(TextEntry(name: name, text: text, kind: kind, allowsChinese: allowsChinese))
    }
    for side in Side.allCases {
        add("side", s.side(side))
        add("deployTitle", s.deployTitle(side))
        add("passTo", s.passTo(side))
        add("handoffDeploy", s.handoffDeploy(side), .sentence)
        add("handoffMove", s.handoffMove(side), .sentence)
        add("handoffReady", s.handoffReady(side))
        add("toMove", s.toMove(side))
        add("endTurn", s.endTurn(passingTo: side))
        add("youAre", s.youAre(side))
        for rank in [Rank.colonel, nil] {
            add("pieceAccessibility", s.pieceAccessibility(side: side, rank: rank, at: Position(name: "c4")!))
        }
    }
    for rank in Rank.allCases {
        add("rank", s.rank(rank))
        add("pieceLabel", s.pieceLabel(rank))
        add("pieceArt", s.pieceArt(rank), allowsChinese: true)
    }
    for level in Difficulty.allCases { add("difficulty", s.difficulty(level)) }
    for violation in [SetupViolation.outsideOwnHalf, .campMustStartEmpty, .flagOutsideHeadquarters,
                      .landmineOutsideBackRows, .bombInFrontRow, .emptySquare] {
        add("violation", s.violation(violation), .sentence)
    }
    for outcome in [Outcome.attackerWon, .defenderWon, .bothRemoved, .flagCaptured] { add("outcome", s.outcome(outcome)) }
    for n in [40, 60, 100] { add("turns", s.turns(n)) }
    for chip in s.setupChips { add("setupChips", chip) }
    for example in s.movementExamples {
        add("movementExamples", example.title)
        add("movementExamples", example.caption, .sentence)
    }
    for (name, text) in [
        ("headquartersMark", s.headquartersMark), ("campMark", s.campMark), ("pieceUnknown", s.pieceUnknown),
        ("rules", s.rules), ("settings", s.settings), ("done", s.done), ("cancel", s.cancel),
        ("languageLabel", s.languageLabel), ("appSubtitle", s.appSubtitle), ("resumeGame", s.resumeGame),
        ("playComputer", s.playComputer), ("difficultyLabel", s.difficultyLabel), ("humanMovesFirst", s.humanMovesFirst),
        ("newComputerGame", s.newComputerGame), ("newPassAndPlay", s.newPassAndPlay), ("start", s.start),
        ("explosiveMines", s.explosiveMines), ("wrongHeadquartersReveal", s.wrongHeadquartersReveal),
        ("drawLimit", s.drawLimit), ("drawNever", s.drawNever), ("quit", s.quit), ("ready", s.ready),
        ("shuffle", s.shuffle), ("suggested", s.suggested), ("enemyLosses", s.enemyLosses), ("yourLosses", s.yourLosses),
        ("moveLog", s.moveLog), ("resign", s.resign), ("home", s.home), ("saveAndQuit", s.saveAndQuit),
        ("gameOver", s.gameOver), ("computerThinking", s.computerThinking), ("yourMove", s.yourMove),
        ("rematch", s.rematch), ("referee", s.referee), ("enemyLost", s.enemyLost), ("youLost", s.youLost),
        ("moves", s.moves), ("legendRailroad", s.legendRailroad), ("legendRoad", s.legendRoad),
        ("legendCamp", s.legendCamp), ("legendHeadquarters", s.legendHeadquarters), ("legendFrontier", s.legendFrontier),
        ("battlesHeading", s.battlesHeading),
    ] {
        add(name, text)
    }
    add("appTitle", s.appTitle, .other, allowsChinese: true)
    add("openPieces", s.openPieces, allowsChinese: true)
    add("passAndPlayShort", s.passAndPlayShort, .sentence)
    add("settingsFooter", s.settingsFooter, .sentence)
    add("deployHint", s.deployHint, .sentence)
    add("handoffPrivacy", s.handoffPrivacy, .sentence)
    add("confirmResign", s.confirmResign, .sentence)
    add("rulesUnavailable", s.rulesUnavailable, .other)

    // Every announcement: mover × outcome × known/unknown rank × flag reveals.
    let ownPieces: [Int: Rank] = [1: .colonel, 2: .captain]
    for viewer in Side.allCases {
        for mover in Side.allCases {
            for outcome in [Outcome.moved, .attackerWon, .defenderWon, .bothRemoved, .flagCaptured] {
                for ids in [(1, 2), (9, 8)] {
                    for revealed in [Set<Side>(), [viewer], [viewer.opponent], [.red, .blue]] {
                        let record = PublicMoveRecord(side: mover, move: Move(notation: "a6-a7")!, attackerID: ids.0,
                                                      defenderID: outcome == .moved ? nil : ids.1, outcome: outcome, revealedFlags: revealed)
                        add("announcement", s.announcement(record, viewer: viewer, ownPieces: ownPieces), .sentence)
                    }
                }
            }
        }
    }
    // Every result and verdict: winner × reason × who the human is (nil = pass-and-play).
    let results: [GameResult] = Side.allCases.flatMap { side in
        [WinReason.flagCaptured, .opponentCannotMove, .resignation].map { GameResult.win(side, $0) }
    } + [.draw(.neitherSideCanMove), .draw(.noBattleLimit)]
    for result in results {
        for human in [Side.red, .blue, nil] {
            add("result", s.result(result, humanSide: human, drawLimit: 60), .sentence)
            let verdict = s.verdict(result, viewer: human ?? .red, humanSide: human)
            add("verdict", verdict.title)
            add("verdict", verdict.seal, .other, allowsChinese: true)
        }
    }
    return e
}

@Suite struct StringsTests {
    static let english = catalog(Strings(language: .english))
    static let chinese = catalog(Strings(language: .chinese))

    // MARK: Coverage

    @Test func stringsCatalogCoversEveryMember() throws {
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().appending(path: "App/Strings.swift"), encoding: .utf8)
        let body = String(source[source.range(of: "struct Strings {")!.upperBound...])
        let declared = Set(body.matches(of: /\n    (?:var|func) (\w+)/).map { String($0.output.1) })
        let notText: Set<String> = ["english", "t", "rulesResource"]
        let covered = Set(Self.english.map(\.name))
        #expect(declared.subtracting(notText).subtracting(covered).isEmpty,
                "Add these Strings members to catalog(): \(declared.subtracting(notText).subtracting(covered).sorted())")
    }

    @Test func bothLanguagesHaveTheSameEntries() {
        #expect(Self.english.map(\.name) == Self.chinese.map(\.name))
    }

    @Test func everyEntryIsTranslated() {
        // Text that is deliberately identical in both languages.
        let shared: Set<String> = ["appTitle", "verdict"]
        for (en, zh) in zip(Self.english, Self.chinese) where !shared.contains(en.name) {
            #expect(en.text != zh.text, "\(en.name) is not translated: \(en.text)")
        }
    }

    // MARK: Shared rules

    @Test(arguments: [AppLanguage.english, .chinese])
    func textIsWellFormed(language: AppLanguage) {
        for entry in catalog(Strings(language: language)) {
            #expect(!entry.text.isEmpty, "\(entry.name) is empty")
            #expect(entry.text == entry.text.trimmingCharacters(in: .whitespacesAndNewlines), "\(entry.name) has stray spaces: '\(entry.text)'")
            #expect(!entry.text.contains("  "), "\(entry.name) has a double space: '\(entry.text)'")
            #expect(!entry.text.contains("\\("), "\(entry.name) has an unfilled placeholder")
        }
    }

    // MARK: English

    @Test func englishHasNoChineseOrFullWidthPunctuation() {
        for entry in Self.english {
            if !entry.allowsChinese {
                #expect(!entry.text.contains(where: \.isCJK), "\(entry.name) contains Chinese: \(entry.text)")
            }
            #expect(!entry.text.contains(where: { "，。：！？；、“”".contains($0) }), "\(entry.name) uses Chinese punctuation: \(entry.text)")
        }
    }

    @Test func englishSentencesAndLabelsArePunctuated() {
        for entry in Self.english {
            switch entry.kind {
            case .sentence:
                #expect(entry.text.last.map { ".!?".contains($0) } == true, "\(entry.name) should end with . ! or ?: \(entry.text)")
                #expect(entry.text.first.map { $0.isUppercase || $0.isNumber } == true, "\(entry.name) should start with a capital: \(entry.text)")
            case .label:
                #expect(entry.text.last != ".", "\(entry.name) is a label and shouldn't end with a full stop: \(entry.text)")
            case .other:
                break
            }
        }
    }

    @Test func englishAnnouncementsReadAsSentences() {
        for entry in Self.english where entry.name == "announcement" {
            // No repeated words ("the the") and sentences after the first start with a capital.
            let words = entry.text.lowercased().split(separator: " ")
            #expect(!zip(words, words.dropFirst()).contains { $0 == $1 }, "Repeated word: \(entry.text)")
            for match in entry.text.matches(of: /[.!?] (\w)/) {
                #expect(match.output.1.first?.isUppercase == true, "Lower-case sentence start: \(entry.text)")
            }
        }
    }

    // MARK: Chinese

    @Test func chineseUsesChinesePunctuationOnly() {
        for entry in Self.chinese where entry.kind != .other {
            #expect(!entry.text.contains(where: { ",.!?:;()\"".contains($0) }),
                    "\(entry.name) uses ASCII punctuation: \(entry.text)")
        }
    }

    @Test func chineseHasNoEnglishExceptSquareNames() {
        for entry in Self.chinese where entry.kind != .other {
            // Square names (a1 ... e12) and file letters (a, c, e) are the only Latin text allowed.
            let squares = try! NSRegularExpression(pattern: "(?<![A-Za-z])[a-e](?:1[0-2]|[1-9])?(?![A-Za-z])")
            let stripped = squares.stringByReplacingMatches(in: entry.text, range: NSRange(entry.text.startIndex..., in: entry.text), withTemplate: "")
            #expect(!stripped.contains(where: { $0.isASCII && $0.isLetter }), "\(entry.name) contains English: \(entry.text)")
        }
    }

    @Test func chineseSpacesOnlySeparateLatinOrDigits() {
        // Chinese doesn't use spaces between words; a space is only allowed next to a
        // square name or number (从 a4 走到 a5, 60 步) or around the · and → separators.
        for entry in Self.chinese where entry.kind != .other {
            let chars = Array(entry.text)
            for (i, c) in chars.enumerated() where c == " " {
                let neighbours = [i > 0 ? chars[i - 1] : nil, i + 1 < chars.count ? chars[i + 1] : nil].compactMap { $0 }
                #expect(neighbours.contains { ($0.isASCII && ($0.isLetter || $0.isNumber)) || "·→".contains($0) },
                        "\(entry.name) has a space between Chinese characters: '\(entry.text)'")
            }
        }
    }

    @Test func chineseSentencesEndWithChinesePunctuation() {
        for entry in Self.chinese where entry.kind == .sentence {
            #expect(entry.text.last.map { "。！？".contains($0) } == true, "\(entry.name) should end with 。！ or ？: \(entry.text)")
        }
        for entry in Self.chinese where entry.kind == .label {
            #expect(entry.text.last != "。", "\(entry.name) is a label and shouldn't end with 。: \(entry.text)")
        }
    }

    // MARK: Specific wording

    @Test func pieceLabelsAreDistinct() {
        for language in AppLanguage.allCases {
            let labels = Rank.allCases.map(Strings(language: language).pieceLabel)
            #expect(Set(labels).count == labels.count)
        }
    }

    @Test func resultsDoNotRepeatTheHeadline() {
        // The game-over card shows the verdict ("Victory", "你赢了") above the result line.
        for result in [GameResult.win(.red, .flagCaptured), .win(.blue, .resignation), .draw(.noBattleLimit)] {
            for language in AppLanguage.allCases {
                let s = Strings(language: language)
                let verdict = s.verdict(result, viewer: .red, humanSide: .red)
                #expect(!s.result(result, humanSide: .red, drawLimit: 60).contains(verdict.title))
            }
        }
    }

    @Test func announcementsNameOnlyTheViewersPieces() {
        let s = Strings(language: .english)
        // Blue's Captain (id 9) attacks Red's Colonel (id 1); Red must not learn it was a Captain.
        let record = PublicMoveRecord(side: .blue, move: Move(notation: "a7-a6")!, attackerID: 9, defenderID: 1,
                                      outcome: .attackerWon, revealedFlags: [])
        let text = s.announcement(record, viewer: .red, ownPieces: [1: .colonel])
        #expect(text == "Blue took your Colonel at a6.")
        #expect(!text.contains("Captain"))
    }

    @Test func sampleSentencesReadNaturally() {
        let en = Strings(language: .english), zh = Strings(language: .chinese)
        let move = PublicMoveRecord(side: .red, move: Move(notation: "a4-a5")!, attackerID: 1, defenderID: nil, outcome: .moved, revealedFlags: [])
        #expect(en.announcement(move, viewer: .red, ownPieces: [1: .colonel]) == "Your Colonel moved from a4 to a5.")
        #expect(zh.announcement(move, viewer: .red, ownPieces: [1: .colonel]) == "你的团长从 a4 走到 a5。")
        #expect(en.result(.win(.blue, .resignation), humanSide: .red, drawLimit: 60) == "You resigned.")
        #expect(zh.result(.win(.red, .flagCaptured), humanSide: nil, drawLimit: 60) == "红方夺得了蓝方的军旗。")
        #expect(en.result(.draw(.noBattleLimit), humanSide: .red, drawLimit: 40) == "40 turns in a row without a battle.")
    }
}

extension Character {
    var isCJK: Bool {
        unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) || (0x3400...0x4DBF).contains($0.value) }
    }
}
