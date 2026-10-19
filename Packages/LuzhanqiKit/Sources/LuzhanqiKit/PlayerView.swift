/// A piece as one player sees it: the rank is nil when it is hidden.
public struct VisiblePiece: Hashable, Sendable {
    public let id: Int
    public let side: Side
    public let rank: Rank?
}

/// A turn as announced by the referee: which pieces met and the result, but
/// never the ranks.
public struct PublicMoveRecord: Hashable, Sendable {
    public let side: Side
    public let move: Move
    public let attackerID: Int
    public let defenderID: Int?
    public let outcome: Outcome
    public let revealedFlags: Set<Side>

    public init(side: Side, move: Move, attackerID: Int, defenderID: Int?, outcome: Outcome, revealedFlags: Set<Side>) {
        self.side = side
        self.move = move
        self.attackerID = attackerID
        self.defenderID = defenderID
        self.outcome = outcome
        self.revealedFlags = revealedFlags
    }
}

/// Everything one side is allowed to know. The UI and the AI read the game
/// only through this during play, which is what keeps hidden ranks hidden.
public struct PlayerView: Sendable {
    public let viewer: Side
    public let squares: [VisiblePiece?]
    public let history: [PublicMoveRecord]
    /// Ranks of all the viewer's pieces by id, including ones already removed.
    public let ownPieces: [Int: Rank]
    public let sideToMove: Side
    public let result: GameResult?
    public let flagRevealed: Set<Side>
    public let pliesSinceBattle: Int
    public let rules: RuleOptions

    public init(_ state: GameState, viewer: Side) {
        self.viewer = viewer
        let revealAll = state.rules.openPieces || state.isOver
        squares = state.squares.map { piece in
            piece.map { p in
                let visible = revealAll || p.side == viewer || (p.rank == .flag && state.flagRevealed.contains(p.side))
                return VisiblePiece(id: p.id, side: p.side, rank: visible ? p.rank : nil)
            }
        }
        history = state.history.map {
            PublicMoveRecord(side: $0.side, move: $0.move, attackerID: $0.attacker.id,
                             defenderID: $0.defender?.id, outcome: $0.outcome, revealedFlags: $0.revealedFlags)
        }
        var own = [Int: Rank]()
        for piece in state.squares.compactMap({ $0 }) + state.history.flatMap({ [$0.attacker, $0.defender].compactMap { $0 } })
        where piece.side == viewer {
            own[piece.id] = piece.rank
        }
        ownPieces = own
        sideToMove = state.sideToMove
        result = state.result
        flagRevealed = state.flagRevealed
        pliesSinceBattle = state.pliesSinceBattle
        rules = state.rules
    }

    public subscript(position: Position) -> VisiblePiece? { squares[position.index] }

    /// A full game state in which every hidden piece is given the rank from
    /// `assigned` (keyed by piece id), or `placeholder` if it has none.
    public func determinized(assigning assigned: [Int: Rank] = [:], placeholder: Rank = .lieutenant) -> GameState {
        let pieces = squares.map { visible in
            visible.map { Piece(id: $0.id, side: $0.side, rank: $0.rank ?? assigned[$0.id] ?? placeholder) }
        }
        return GameState(squares: pieces, sideToMove: sideToMove, rules: rules,
                         flagRevealed: flagRevealed, pliesSinceBattle: pliesSinceBattle, recordsHistory: false)
    }

    /// The viewer's legal moves. These depend only on where pieces stand, never
    /// on enemy ranks, so a placeholder determinization is exact.
    public func legalMoves() -> [Move] {
        guard result == nil, sideToMove == viewer else { return [] }
        return determinized().legalMoves(for: viewer)
    }

    public func destinations(from position: Position) -> [Position] {
        guard result == nil, sideToMove == viewer, self[position]?.side == viewer else { return [] }
        return determinized().destinations(from: position)
    }
}
