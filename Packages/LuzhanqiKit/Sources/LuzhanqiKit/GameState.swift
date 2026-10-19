/// What happened on one turn. Contains true ranks, so only the referee (the
/// app) and the moving player may see it; give everyone else `PlayerView`.
public struct MoveRecord: Hashable, Codable, Sendable {
    public let side: Side
    public let move: Move
    public let attacker: Piece
    public let defender: Piece?
    public let outcome: Outcome
    /// Sides whose Flag location became public because of this move.
    public let revealedFlags: Set<Side>
}

public enum GameResult: Hashable, Codable, Sendable {
    case win(Side, WinReason)
    case draw(DrawReason)

    public var winner: Side? {
        if case let .win(side, _) = self { return side }
        return nil
    }
}

public enum WinReason: String, Codable, Sendable {
    case flagCaptured
    case opponentCannotMove
    case resignation
}

public enum DrawReason: String, Codable, Sendable {
    case neitherSideCanMove
    case noBattleLimit
}

public enum GameError: Error, Hashable, Sendable {
    case gameOver
    case notYourPiece(Position)
    case illegalMove(Move)
    case invalidDeployment(Side, [String])
}

/// The complete, true state of a game. Value type: copy it freely.
public struct GameState: Codable, Sendable {
    /// Pieces indexed by `Position.index`.
    public private(set) var squares: [Piece?]
    public private(set) var sideToMove: Side
    public private(set) var history: [MoveRecord] = []
    /// Sides whose Flag location is public knowledge.
    public private(set) var flagRevealed: Set<Side> = []
    public private(set) var result: GameResult?
    public private(set) var pliesSinceBattle = 0
    public let rules: RuleOptions
    /// Search copies turn this off to avoid growing `history`.
    var recordsHistory = true

    /// A new game from two legal deployments. Red moves first.
    public init(red: Deployment, blue: Deployment, rules: RuleOptions = .standard) throws {
        var squares = [Piece?](repeating: nil, count: Board.count)
        for (side, deployment) in [(Side.red, red), (Side.blue, blue)] {
            let errors = Setup.errors(in: deployment, for: side)
            guard errors.isEmpty else { throw GameError.invalidDeployment(side, errors) }
            for (position, rank) in deployment {
                squares[position.index] = Piece(id: Piece.id(deployedAt: position), side: side, rank: rank)
            }
        }
        self.init(squares: squares, sideToMove: .red, rules: rules)
    }

    /// An arbitrary position, skipping setup rules (for tests, puzzles and AI search).
    public init(pieces: [Position: Piece], sideToMove: Side = .red, rules: RuleOptions = .standard) {
        var squares = [Piece?](repeating: nil, count: Board.count)
        for (position, piece) in pieces { squares[position.index] = piece }
        self.init(squares: squares, sideToMove: sideToMove, rules: rules)
    }

    init(squares: [Piece?], sideToMove: Side, rules: RuleOptions,
         flagRevealed: Set<Side> = [], pliesSinceBattle: Int = 0, recordsHistory: Bool = true) {
        self.squares = squares
        self.sideToMove = sideToMove
        self.rules = rules
        self.flagRevealed = flagRevealed
        self.pliesSinceBattle = pliesSinceBattle
        self.recordsHistory = recordsHistory
    }

    public subscript(position: Position) -> Piece? { squares[position.index] }

    public var isOver: Bool { result != nil }

    /// Plays `move` for the side to move.
    @discardableResult
    public mutating func apply(_ move: Move) throws -> MoveRecord {
        guard result == nil else { throw GameError.gameOver }
        guard let piece = self[move.from], piece.side == sideToMove else {
            throw GameError.notYourPiece(move.from)
        }
        guard destinationIndices(from: move.from.index).contains(move.to.index) else {
            throw GameError.illegalMove(move)
        }
        return perform(from: move.from.index, to: move.to.index)
    }

    public mutating func resign(_ side: Side) {
        guard result == nil else { return }
        result = .win(side.opponent, .resignation)
    }

    /// Plays a move already known to be legal.
    @discardableResult
    mutating func perform(from f: Int, to t: Int) -> MoveRecord {
        let attacker = squares[f]!
        let defender = squares[t]
        let mover = attacker.side
        squares[f] = nil

        var outcome = Outcome.moved
        var revealed: Set<Side> = []
        if let defender {
            outcome = Combat.resolve(attacker: attacker.rank, defender: defender.rank, rules: rules)
            switch outcome {
            case .attackerWon, .flagCaptured: squares[t] = attacker
            case .bothRemoved: squares[t] = nil
            case .defenderWon, .moved: break
            }
            pliesSinceBattle = 0
            let attackerLost = outcome == .defenderWon || outcome == .bothRemoved
            let defenderLost = outcome == .attackerWon || outcome == .bothRemoved
            if attackerLost && attacker.rank == .fieldMarshal { revealed.insert(attacker.side) }
            if defenderLost && defender.rank == .fieldMarshal { revealed.insert(defender.side) }
            if rules.wrongHeadquartersReveal, outcome == .attackerWon,
               Board.stations[t] == .headquarters, Board.half(of: Position(index: t)) == defender.side {
                revealed.insert(defender.side)
            }
            flagRevealed.formUnion(revealed)
        } else {
            squares[t] = attacker
            pliesSinceBattle += 1
        }

        let record = MoveRecord(side: mover, move: Move(Position(index: f), Position(index: t)),
                                attacker: attacker, defender: defender, outcome: outcome, revealedFlags: revealed)
        if recordsHistory { history.append(record) }
        sideToMove = mover.opponent

        if outcome == .flagCaptured {
            result = .win(mover, .flagCaptured)
        } else if !hasLegalMove(sideToMove) {
            result = hasLegalMove(mover) ? .win(mover, .opponentCannotMove) : .draw(.neitherSideCanMove)
        } else if rules.noBattleDrawLimit > 0 && pliesSinceBattle >= rules.noBattleDrawLimit {
            result = .draw(.noBattleLimit)
        }
        return record
    }
}
