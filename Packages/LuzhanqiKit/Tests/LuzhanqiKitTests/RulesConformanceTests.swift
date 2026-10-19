import Foundation
import Testing
@testable import LuzhanqiKit

// Conformance tests: the engine is checked against an independent reference
// implementation of the rules. The reference board is parsed from the diagram
// in RULES.md (not from Board.swift), and the reference move generator uses a
// different method (direction stepping for straight railroad runs, path search
// for engineers) from the engine's precomputed lines and bitmasks.

/// The board as drawn in RULES.md. Squares are (rank 1...12, file 0...4).
struct ReferenceBoard {
    enum Link { case road, rail }

    struct DiagramError: Error, CustomStringConvertible {
        let description: String
    }

    private(set) var stations: [Position: Station] = [:]
    /// Symmetric: every one-step connection and whether it is railroad.
    private(set) var links: [Position: [Position: Link]] = [:]

    /// Parses the diagram in a rulebook at the repository root (RULES.md or RULES.zh.md).
    static func load(_ file: String = "RULES.md") throws -> ReferenceBoard {
        let rules = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: file)
        return try ReferenceBoard(markdown: String(contentsOf: rules, encoding: .utf8))
    }

    init(markdown: String) throws {
        // The board is the code block containing rank 12's station row.
        guard let diagram = markdown.components(separatedBy: "```").first(where: { $0.contains("12    o") }) else {
            throw DiagramError(description: "board diagram not found")
        }
        let column = { (file: Int) in 9 + 4 * file }  // character offset of a file's stations
        var previousRank: Int?
        var connector: [Character]?
        for rawLine in diagram.components(separatedBy: "\n") {
            let line = Array(rawLine.padding(toLength: max(rawLine.count, 40), withPad: " ", startingAt: 0))
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard let first = trimmed.first, first.isNumber, let rank = Int(trimmed.prefix(while: \.isNumber)) else {
                if previousRank != nil { connector = line }
                continue
            }
            for file in 0..<5 {
                let p = Self.square(rank, file)
                switch line[column(file)] {
                case "o": stations[p] = .post
                case "C": stations[p] = .camp
                case "H": stations[p] = .headquarters
                case let other: throw DiagramError(description: "unknown station '\(other)' at \(p.name)")
                }
                if file < 4 {
                    switch line[column(file) + 1] {
                    case "─": link(p, Self.square(rank, file + 1), .road)
                    case "═": link(p, Self.square(rank, file + 1), .rail)
                    case let other: throw DiagramError(description: "unknown link '\(other)' right of \(p.name)")
                    }
                }
            }
            if let above = previousRank {
                guard above == rank + 1, let connector else { throw DiagramError(description: "bad row order at rank \(rank)") }
                for file in 0..<5 {
                    switch connector[column(file)] {
                    case "│": link(Self.square(above, file), Self.square(rank, file), .road)
                    case "║": link(Self.square(above, file), Self.square(rank, file), .rail)
                    case "^", " ": break
                    case let other: throw DiagramError(description: "unknown vertical '\(other)' below rank \(above)")
                    }
                    guard file < 4 else { continue }
                    switch connector[column(file) + 2] {
                    case "\\": link(Self.square(above, file), Self.square(rank, file + 1), .road)
                    case "/": link(Self.square(above, file + 1), Self.square(rank, file), .road)
                    case " ": break
                    case let other: throw DiagramError(description: "unknown diagonal '\(other)' below rank \(above)")
                    }
                }
            }
            previousRank = rank
            connector = nil
            if rank == 1 { break }
        }
        guard stations.count == 60 else { throw DiagramError(description: "diagram has \(stations.count) stations") }
    }

    private mutating func link(_ a: Position, _ b: Position, _ kind: Link) {
        links[a, default: [:]][b] = kind
        links[b, default: [:]][a] = kind
    }

    static func square(_ rank: Int, _ file: Int) -> Position {
        Position(name: "\(Board.files[file])\(rank)")!
    }

    static func rankAndFile(_ p: Position) -> (rank: Int, file: Int) { (Board.rows - p.row, p.col) }

    // MARK: Reference movement rules

    /// Where the piece on `from` may move or attack, straight from the rulebook.
    func destinations(_ pieces: [Position: Piece], from: Position) -> Set<Position> {
        guard let piece = pieces[from],
              piece.rank != .landmine, piece.rank != .flag,       // never move
              stations[from] != .headquarters                       // stuck in HQ
        else { return [] }
        func canEnter(_ p: Position) -> Bool {
            guard let occupant = pieces[p] else { return true }
            return occupant.side != piece.side && stations[p] != .camp  // no attacking into camps
        }
        // Any one step along a road or railroad (including camp diagonals).
        var result = Set(links[from, default: [:]].keys.filter(canEnter))

        if piece.rank == .engineer {
            // Any railroad path through empty squares, ending empty or on an enemy.
            var frontier = [from]
            var seen: Set<Position> = [from]
            while let current = frontier.popLast() {
                for (next, kind) in links[current, default: [:]] where kind == .rail && !seen.contains(next) {
                    seen.insert(next)
                    if pieces[next] == nil {
                        result.insert(next)
                        frontier.append(next)
                    } else if canEnter(next) {
                        result.insert(next)
                    }
                }
            }
        } else {
            // Straight railroad runs: keep stepping the same direction while the
            // track continues and the way is clear.
            let (rank, file) = Self.rankAndFile(from)
            for (dr, df) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                var (r, f) = (rank, file)
                var current = from
                while (1...12).contains(r + dr), (0...4).contains(f + df) {
                    let next = Self.square(r + dr, f + df)
                    guard links[current]?[next] == .rail else { break }
                    if pieces[next] != nil {
                        if canEnter(next) { result.insert(next) }
                        break
                    }
                    result.insert(next)
                    (r, f, current) = (r + dr, f + df, next)
                }
            }
        }
        return result
    }

    func legalMoves(_ pieces: [Position: Piece], side: Side) -> Set<Move> {
        Set(pieces.filter { $0.value.side == side }.flatMap { from, _ in
            destinations(pieces, from: from).map { Move(from, $0) }
        })
    }
}

/// Battle results written out with the official rank numbers (司令 40 … 工兵 32).
func referenceOutcome(attacker: Rank, defender: Rank, explosiveMines: Bool) -> Outcome {
    let number: [Rank: Int] = [
        .fieldMarshal: 40, .general: 39, .majorGeneral: 38, .brigadier: 37, .colonel: 36,
        .major: 35, .captain: 34, .lieutenant: 33, .engineer: 32,
    ]
    switch (attacker, defender) {
    case (_, .flag): return .flagCaptured
    case (.bomb, _), (_, .bomb): return .bothRemoved
    case (.engineer, .landmine): return .attackerWon
    case (_, .landmine): return explosiveMines ? .bothRemoved : .defenderWon
    default:
        let a = number[attacker]!, d = number[defender]!
        return a > d ? .attackerWon : a < d ? .defenderWon : .bothRemoved
    }
}

func pieceMap(_ state: GameState) -> [Position: Piece] {
    var pieces = [Position: Piece]()
    for p in Board.allPositions { if let piece = state[p] { pieces[p] = piece } }
    return pieces
}

/// A random, not necessarily setup-legal, position: any pieces anywhere.
func randomPosition(using rng: inout SeededGenerator) -> [Position: Piece] {
    let count = Int.random(in: 1...45, using: &rng)
    var pieces = [Position: Piece]()
    for p in Board.allPositions.shuffled(using: &rng).prefix(count) {
        // Favour engineers so corner-turning paths get plenty of coverage.
        let rank = Bool.random(using: &rng) && Int.random(in: 0..<3, using: &rng) == 0
            ? Rank.engineer : Rank.allCases.randomElement(using: &rng)!
        pieces[p] = Piece(id: p.index, side: Bool.random(using: &rng) ? .red : .blue, rank: rank)
    }
    return pieces
}

@Suite struct RulesConformanceTests {
    let reference: ReferenceBoard

    init() throws { reference = try ReferenceBoard.load() }

    // MARK: Board

    @Test func boardMatchesTheRulebookDiagram() {
        for p in Board.allPositions {
            #expect(Board.station(at: p) == reference.stations[p], "station at \(p)")
            let links = reference.links[p, default: [:]]
            #expect(Set(Board.roadNeighbors(of: p)) == Set(links.keys), "one-step links at \(p)")
            #expect(Set(Board.railNeighbors(of: p)) == Set(links.filter { $0.value == .rail }.keys), "railroad at \(p)")
        }
    }

    @Test func chineseRulebookShowsTheSameBoard() throws {
        let chinese = try ReferenceBoard.load("RULES.zh.md")
        #expect(chinese.stations == reference.stations)
        #expect(chinese.links == reference.links)
    }

    @Test func diagramEncodesTheOfficialLayout() {
        // Spot-check the parsed diagram itself against the written rules.
        let stations = reference.stations
        #expect(stations.values.filter { $0 == .camp }.count == 10)
        #expect(stations.values.filter { $0 == .headquarters }.count == 4)
        for side in Side.allCases {
            #expect(Board.homePositions(side).filter { stations[$0] == .post }.count == 23)
        }
        // Only files a, c, e cross the frontier, and all three by railroad.
        for file in 0..<5 {
            let link = reference.links[ReferenceBoard.square(6, file)]?[ReferenceBoard.square(7, file)]
            #expect(link == ([0, 2, 4].contains(file) ? .rail : nil))
        }
        // Every camp connects to all 8 neighbours; diagonals exist only at camps.
        for (p, links) in reference.links {
            for q in links.keys where p.row != q.row && p.col != q.col {
                #expect(stations[p] == .camp || stations[q] == .camp, "diagonal \(p)-\(q) without a camp")
            }
            if stations[p] == .camp { #expect(links.count == 8) }
        }
    }

    // MARK: Movement

    @Test func everyPieceOnEverySquareOfAnEmptyBoard() {
        for p in Board.allPositions {
            for rank in Rank.allCases {
                let pieces = [p: Piece(id: p.index, side: .red, rank: rank)]
                let state = GameState(pieces: pieces)
                #expect(Set(state.destinations(from: p)) == reference.destinations(pieces, from: p), "\(rank) on \(p)")
            }
        }
    }

    @Test func randomPositionsMatchTheReference() {
        var rng = SeededGenerator(seed: 2024)
        for _ in 0..<4000 {
            let pieces = randomPosition(using: &rng)
            let state = GameState(pieces: pieces)
            for side in Side.allCases {
                let engine = Set(state.legalMoves(for: side))
                let expected = reference.legalMoves(pieces, side: side)
                #expect(engine == expected, """
                    \(side) missing: \(expected.subtracting(engine).map(\.description).sorted()) \
                    extra: \(engine.subtracting(expected).map(\.description).sorted())
                    """)
                if engine != expected { return }
            }
        }
    }

    /// The gate the app actually uses: `apply` accepts exactly the reference
    /// moves and rejects every other from/to pair, and the hidden-information
    /// view offers the same moves without knowing enemy ranks.
    @Test func applyAcceptsExactlyTheLegalMoves() throws {
        var rng = SeededGenerator(seed: 77)
        for _ in 0..<250 {
            let pieces = randomPosition(using: &rng)
            let side: Side = Bool.random(using: &rng) ? .red : .blue
            let state = GameState(pieces: pieces, sideToMove: side)
            let legal = reference.legalMoves(pieces, side: side)
            #expect(Set(PlayerView(state, viewer: side).legalMoves()) == legal)
            for from in Board.allPositions {
                for to in Board.allPositions {
                    var copy = state
                    let move = Move(from, to)
                    if legal.contains(move) {
                        #expect(throws: Never.self, "\(move) should be legal") { try copy.apply(move) }
                    } else {
                        #expect(throws: GameError.self, "\(move) should be illegal") { try copy.apply(move) }
                    }
                }
            }
        }
    }

    // MARK: Battles

    @Test func everyBattlePairing() throws {
        for explosive in [false, true] {
            let rules = RuleOptions(explosiveMines: explosive)
            for attacker in Rank.allCases where attacker.isMovable {
                for defender in Rank.allCases {
                    let expected = referenceOutcome(attacker: attacker, defender: defender, explosiveMines: explosive)
                    var state = game(flags.with([
                        "a6": (.red, attacker), "a7": (.blue, defender),
                        "e2": (.red, .lieutenant), "e11": (.blue, .lieutenant),
                    ]), rules: rules)
                    let record = try state.apply(move("a6-a7"))
                    let label = "\(attacker) attacks \(defender), explosive mines \(explosive)"
                    #expect(record.outcome == expected, "\(label)")
                    // The board must reflect the result.
                    let occupant = state[pos("a7")]
                    switch expected {
                    case .attackerWon, .flagCaptured: #expect(occupant?.rank == attacker && occupant?.side == .red, "\(label)")
                    case .defenderWon: #expect(occupant?.rank == defender && occupant?.side == .blue, "\(label)")
                    case .bothRemoved: #expect(occupant == nil, "\(label)")
                    case .moved: Issue.record("battle reported as a plain move")
                    }
                    #expect(state[pos("a6")] == nil, "\(label): attacker left its square")
                    #expect((state.result == .win(.red, .flagCaptured)) == (defender == .flag), "\(label)")
                }
            }
        }
    }

    // MARK: Whole games

    /// Random games from legal setups to the end: every position's moves match
    /// the reference, turns alternate, and the game ends exactly when the rules say.
    @Test func randomGamesFollowTheRules() throws {
        var rng = SeededGenerator(seed: 99)
        var endings = [String: Int]()
        for _ in 0..<60 {
            var state = try GameState(red: Setup.random(for: .red, using: &rng),
                                      blue: Setup.random(for: .blue, using: &rng),
                                      rules: RuleOptions(noBattleDrawLimit: 0))
            var plies = 0
            while !state.isOver && plies < 2000 {
                let side = state.sideToMove
                let pieces = pieceMap(state)
                let legal = reference.legalMoves(pieces, side: side)
                #expect(Set(state.legalMoves()) == legal, "ply \(plies)")
                #expect(!legal.isEmpty, "the side to move must have a move unless the game is over")
                guard let move = legal.randomElement(using: &rng) else { break }
                let record = try state.apply(move)
                #expect(record.outcome == (pieces[move.to].map {
                    referenceOutcome(attacker: pieces[move.from]!.rank, defender: $0.rank, explosiveMines: false)
                } ?? .moved))
                #expect(state.isOver || state.sideToMove == side.opponent)
                plies += 1
            }
            switch state.result {
            case let .win(winner, .flagCaptured)?:
                #expect(!pieceMap(state).values.contains { $0.rank == .flag && $0.side == winner.opponent })
            case let .win(winner, .opponentCannotMove)?:
                #expect(reference.legalMoves(pieceMap(state), side: winner.opponent).isEmpty)
            case .draw(.neitherSideCanMove)?:
                #expect(reference.legalMoves(pieceMap(state), side: .red).isEmpty)
                #expect(reference.legalMoves(pieceMap(state), side: .blue).isEmpty)
            default:
                break
            }
            endings[String(describing: state.result), default: 0] += 1
            #expect(throws: GameError.self) { try state.apply(Move(pos("a1"), pos("a2"))) }
        }
        print("Random-game endings: \(endings)")
    }
}
