/// Starting arrangements for the computer. Easy deploys at random; Medium and
/// Hard use a classic shape (Flag guarded by mines, bombs and senior officers
/// in the middle rows, engineers ready to advance) with randomized details.
enum AIDeployer {
    static func deployment(for side: Side, difficulty: Difficulty,
                           using rng: inout some RandomNumberGenerator) -> Deployment {
        guard difficulty != .easy else { return Setup.random(for: side, using: &rng) }

        let slots = Setup.slots(for: side)
        var deployment = Deployment()
        func at(_ row: Int, _ col: Int) -> Position { Board.toGlobal(side, localRow: row, col: col) }
        func place(_ rank: Rank, _ count: Int, preferringRows rows: ClosedRange<Int>) {
            for _ in 0..<count {
                let legal = slots.filter { deployment[$0] == nil && Setup.placementError(rank, at: $0, for: side) == nil }
                let preferred = legal.filter { rows.contains(Board.localRow(side, $0)) }
                guard let p = (preferred.isEmpty ? legal : preferred).randomElement(using: &rng) else { return }
                deployment[p] = rank
            }
        }

        let flagCol = Bool.random(using: &rng) ? 1 : 3
        deployment[at(0, flagCol)] = .flag
        let guards = [at(0, flagCol - 1), at(0, flagCol + 1), at(1, flagCol)].shuffled(using: &rng)
        let guarded = Int.random(in: 2...3, using: &rng)
        for p in guards.prefix(guarded) { deployment[p] = .landmine }
        place(.landmine, Rank.landmine.count - guarded, preferringRows: 0...1)  // often a decoy
        place(.bomb, Rank.bomb.count, preferringRows: 2...4)
        place(.fieldMarshal, 1, preferringRows: 2...4)
        place(.general, 1, preferringRows: 2...4)
        place(.engineer, Rank.engineer.count, preferringRows: 3...4)
        place(.majorGeneral, Rank.majorGeneral.count, preferringRows: 3...5)

        let rest = Rank.fullArmy.filter { [.brigadier, .colonel, .major, .captain, .lieutenant].contains($0) }
        for (p, rank) in zip(slots.filter { deployment[$0] == nil }.shuffled(using: &rng), rest.shuffled(using: &rng)) {
            deployment[p] = rank
        }
        return Setup.errors(in: deployment, for: side).isEmpty ? deployment : Setup.random(for: side, using: &rng)
    }
}
