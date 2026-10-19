/// A set of ranks as a 12-bit mask.
struct RankSet: Hashable, Sendable {
    var bits: UInt16

    static let all = RankSet(bits: (1 << 12) - 1)
    static let movable = RankSet(Rank.allCases.filter(\.isMovable))

    init(bits: UInt16) { self.bits = bits }
    init(_ ranks: some Sequence<Rank>) { bits = ranks.reduce(0) { $0 | $1.bit } }

    func contains(_ rank: Rank) -> Bool { bits & rank.bit != 0 }
    var count: Int { bits.nonzeroBitCount }
    var isEmpty: Bool { bits == 0 }
    var ranks: [Rank] { Rank.allCases.filter(contains) }
    func intersection(_ other: RankSet) -> RankSet { RankSet(bits: bits & other.bits) }
}

/// What one side can deduce about every enemy piece from public information:
/// setup rules, how pieces have moved, battle results, reveals, and how many
/// of each rank exist. The AI never looks at hidden ranks directly.
public struct Beliefs: Sendable {
    public let viewer: Side
    /// Possible ranks for each enemy piece id, alive or removed.
    private(set) var candidates: [Int: RankSet]

    public init(_ view: PlayerView) {
        viewer = view.viewer
        let enemy = view.viewer.opponent
        var ids = Set(view.squares.compactMap { $0 }.filter { $0.side == enemy }.map(\.id))
        for record in view.history {
            if record.side == enemy { ids.insert(record.attackerID) } else if let id = record.defenderID { ids.insert(id) }
        }

        // Piece ids are their deployment squares, which constrains what they can be.
        var candidates = [Int: RankSet]()
        for id in ids where (0..<Board.count).contains(id) {
            let start = Position(index: id)
            let allowed = RankSet(Rank.allCases.filter { Setup.placementError($0, at: start, for: enemy) == nil })
            candidates[id] = allowed.isEmpty ? .all : allowed
        }
        for id in ids where candidates[id] == nil { candidates[id] = .all }
        self.candidates = candidates

        for record in view.history { learn(from: record, view: view) }
        for piece in view.squares.compactMap({ $0 }) where piece.side == enemy {
            if let rank = piece.rank { narrow(piece.id, to: RankSet([rank])) }
        }
        propagateCounts()
    }

    public func possibleRanks(of id: Int) -> [Rank] { candidates[id]?.ranks ?? Rank.allCases }

    /// The rank of `id` if it has been pinned down.
    public func knownRank(of id: Int) -> Rank? {
        guard let set = candidates[id], set.count == 1 else { return nil }
        return set.ranks[0]
    }

    private mutating func narrow(_ id: Int, to allowed: RankSet) {
        guard let current = candidates[id] else { return }
        let narrowed = current.intersection(allowed)
        // A contradiction means a variant rule we don't model; keep what we had.
        if !narrowed.isEmpty { candidates[id] = narrowed }
    }

    private mutating func learn(from record: PublicMoveRecord, view: PlayerView) {
        let enemyMoved = record.side == viewer.opponent
        if enemyMoved {
            narrow(record.attackerID, to: .movable)
            let (f, t) = (record.move.from.index, record.move.to.index)
            let straight = Board.road[f].contains(t) || Board.railLinesThrough[f].contains { $0.contains(t) }
            if !straight { narrow(record.attackerID, to: RankSet([.engineer])) }
        }
        guard record.outcome.isBattle, let defenderID = record.defenderID else { return }
        let (enemyID, ourID) = enemyMoved ? (record.attackerID, defenderID) : (defenderID, record.attackerID)
        guard let ours = view.ownPieces[ourID] else { return }
        // Keep exactly the enemy ranks that would have produced this result.
        let consistent = Rank.allCases.filter { rank in
            if enemyMoved {
                return rank.isMovable && Combat.resolve(attacker: rank, defender: ours, rules: view.rules) == record.outcome
            }
            return Combat.resolve(attacker: ours, defender: rank, rules: view.rules) == record.outcome
        }
        narrow(enemyID, to: RankSet(consistent))
    }

    /// Uses the fixed army composition: once every copy of a rank is pinned to
    /// specific pieces no other piece can have it, and if exactly as many
    /// pieces can have a rank as there are copies, they all must. (The second
    /// rule needs the whole army in view, which custom test positions lack.)
    private mutating func propagateCounts() {
        let fullArmy = candidates.count == Rank.fullArmy.count
        var changed = true
        while changed {
            changed = false
            for rank in Rank.allCases {
                let holders = candidates.filter { $0.value.contains(rank) }.map(\.key)
                let pinned = holders.filter { candidates[$0]!.count == 1 }
                if pinned.count >= rank.count {
                    for id in holders where candidates[id]!.count > 1 {
                        candidates[id]!.bits &= ~rank.bit
                        changed = true
                    }
                } else if fullArmy && holders.count == rank.count {
                    for id in holders where candidates[id]!.count > 1 {
                        candidates[id] = RankSet([rank])
                        changed = true
                    }
                }
            }
        }
    }

    /// A random rank for every enemy piece, consistent with the beliefs and the
    /// army composition whenever possible.
    public func sample(using rng: inout some RandomNumberGenerator) -> [Int: Rank] {
        let ids = candidates.keys.sorted()
        for _ in 0..<40 {
            var remaining = Rank.allCases.map(\.count)
            var assignment = [Int: Rank]()
            // Most constrained first, random among equals.
            let order = ids.shuffled(using: &rng).sorted { candidates[$0]!.count < candidates[$1]!.count }
            var ok = true
            for id in order {
                let options = candidates[id]!.ranks.filter { remaining[$0.rawValue] > 0 }
                guard let rank = weightedPick(options, weights: options.map { remaining[$0.rawValue] }, using: &rng) else {
                    ok = false
                    break
                }
                assignment[id] = rank
                remaining[rank.rawValue] -= 1
            }
            if ok { return assignment }
        }
        // Couldn't satisfy everything: fill in greedily, ignoring counts.
        return candidates.mapValues { $0.ranks.randomElement(using: &rng) ?? .lieutenant }
    }
}

func weightedPick<T>(_ items: [T], weights: [Int], using rng: inout some RandomNumberGenerator) -> T? {
    let total = weights.reduce(0, +)
    guard total > 0 else { return nil }
    var roll = Int.random(in: 0..<total, using: &rng)
    for (item, weight) in zip(items, weights) {
        if roll < weight { return item }
        roll -= weight
    }
    return nil
}
