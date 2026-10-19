/// One side's starting arrangement: a rank on each of its 25 non-camp squares.
public typealias Deployment = [Position: Rank]

public enum Setup {
    /// The 25 squares a side must fill: its whole half except the camps.
    public static func slots(for side: Side) -> [Position] {
        Board.homePositions(side).filter { Board.station(at: $0) != .camp }
    }

    /// The setup rule `rank` would break on `position` for `side`, or nil if it may start there.
    public static func placementError(_ rank: Rank, at position: Position, for side: Side) -> SetupViolation? {
        guard Board.half(of: position) == side else { return .outsideOwnHalf }
        let station = Board.station(at: position)
        if station == .camp { return .campMustStartEmpty }
        let row = Board.localRow(side, position)
        switch rank {
        case .flag where station != .headquarters: return .flagOutsideHeadquarters
        case .landmine where row > 1: return .landmineOutsideBackRows
        case .bomb where row == Board.frontLocalRow: return .bombInFrontRow
        default: return nil
        }
    }

    /// Every rule `deployment` breaks, in English; empty if it is legal.
    public static func errors(in deployment: Deployment, for side: Side) -> [String] {
        var errors = deployment.sorted { $0.key < $1.key }.compactMap { position, rank in
            placementError(rank, at: position, for: side).map { "\(rank.englishName) on \(position.name): \($0)" }
        }
        var counts = [Rank: Int]()
        for rank in deployment.values { counts[rank, default: 0] += 1 }
        for rank in Rank.allCases where counts[rank, default: 0] != rank.count {
            errors.append("Expected \(rank.count) \(rank.englishName), found \(counts[rank, default: 0])")
        }
        return errors
    }

    /// `deployment` with the pieces on `a` and `b` exchanged, or the setup rule
    /// the swap would break.
    public static func swapping(_ a: Position, _ b: Position, in deployment: Deployment, for side: Side) -> Result<Deployment, SetupViolation> {
        guard let rankA = deployment[a], let rankB = deployment[b] else { return .failure(.emptySquare) }
        if let violation = placementError(rankA, at: b, for: side) ?? placementError(rankB, at: a, for: side) {
            return .failure(violation)
        }
        var swapped = deployment
        swapped[a] = rankB
        swapped[b] = rankA
        return .success(swapped)
    }

    /// A uniformly shuffled legal deployment.
    public static func random(for side: Side, using rng: inout some RandomNumberGenerator) -> Deployment {
        let slots = slots(for: side)
        var deployment = Deployment()
        func free(_ allowed: (Position) -> Bool) -> [Position] {
            slots.filter { deployment[$0] == nil && allowed($0) }
        }
        // Place the constrained ranks first, most constrained first.
        for rank in [Rank.flag, .landmine, .bomb] {
            for position in free({ placementError(rank, at: $0, for: side) == nil }).shuffled(using: &rng).prefix(rank.count) {
                deployment[position] = rank
            }
        }
        let rest = Rank.fullArmy.filter { ![.flag, .landmine, .bomb].contains($0) }.shuffled(using: &rng)
        for (position, rank) in zip(free { _ in true }, rest) {
            deployment[position] = rank
        }
        return deployment
    }
}

/// A broken setup rule. The app shows these in the player's language; the
/// English `description` is for logs and tests.
public enum SetupViolation: Error, Hashable, Sendable, CustomStringConvertible {
    case outsideOwnHalf
    case campMustStartEmpty
    case flagOutsideHeadquarters
    case landmineOutsideBackRows
    case bombInFrontRow
    /// A swap involving a square with no piece.
    case emptySquare

    public var description: String {
        switch self {
        case .outsideOwnHalf: "not in the side's own half"
        case .campMustStartEmpty: "camps start empty"
        case .flagOutsideHeadquarters: "the Flag must start in a headquarters"
        case .landmineOutsideBackRows: "landmines must start in the back two rows"
        case .bombInFrontRow: "bombs cannot start in the front row"
        case .emptySquare: "both squares must hold pieces"
        }
    }
}

/// SplitMix64: a small, fast, seedable generator for reproducible games and tests.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
