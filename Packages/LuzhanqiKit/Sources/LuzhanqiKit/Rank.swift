/// A piece type. Raw values are stable (they appear in saved games).
public enum Rank: Int, Codable, Sendable, CaseIterable {
    case fieldMarshal
    case general
    case majorGeneral
    case brigadier
    case colonel
    case major
    case captain
    case lieutenant
    case engineer
    case bomb
    case landmine
    case flag

    /// Combat strength for officers (9 = Field Marshal ... 1 = Engineer); nil
    /// for bomb, landmine and flag.
    public var power: Int? {
        rawValue <= Rank.engineer.rawValue ? 9 - rawValue : nil
    }

    public var isOfficer: Bool { power != nil }
    public var isMovable: Bool { self != .landmine && self != .flag }

    /// Number of these pieces in each army.
    public var count: Int { Rank.army[rawValue] }

    public var code: String {
        ["FM", "GN", "MG", "BG", "CO", "MJ", "CP", "LT", "EN", "BM", "LM", "FL"][rawValue]
    }

    public var englishName: String {
        ["Field Marshal", "General", "Major General", "Brigadier", "Colonel", "Major",
         "Captain", "Lieutenant", "Engineer", "Bomb", "Landmine", "Flag"][rawValue]
    }

    public var chineseName: String {
        ["司令", "军长", "师长", "旅长", "团长", "营长", "连长", "排长", "工兵", "炸弹", "地雷", "军旗"][rawValue]
    }

    /// Bit for this rank in a `RankSet`.
    var bit: UInt16 { 1 << UInt16(rawValue) }

    private static let army = [1, 1, 2, 2, 2, 2, 3, 3, 3, 2, 3, 1]

    /// All 25 ranks of one army, strongest first.
    public static let fullArmy: [Rank] = allCases.flatMap { Array(repeating: $0, count: $0.count) }
}

public struct Piece: Hashable, Codable, Sendable {
    /// Stable identity for the physical piece. It is derived from the square the
    /// piece was deployed on, which both players can see, so it reveals nothing.
    public let id: Int
    public let side: Side
    public let rank: Rank

    public init(id: Int, side: Side, rank: Rank) {
        self.id = id
        self.side = side
        self.rank = rank
    }

    /// The id given to a piece deployed on `position`.
    public static func id(deployedAt position: Position) -> Int { position.index }
}

public struct Move: Hashable, Codable, Sendable, CustomStringConvertible {
    public let from: Position
    public let to: Position

    public init(_ from: Position, _ to: Position) {
        self.from = from
        self.to = to
    }

    /// Parses "a4-a5" or "a4 a5".
    public init?(notation: String) {
        let parts = notation.split(whereSeparator: { $0 == "-" || $0 == " " })
        guard parts.count == 2, let from = Position(name: String(parts[0])),
              let to = Position(name: String(parts[1])) else { return nil }
        self.init(from, to)
    }

    public var description: String { "\(from.name)-\(to.name)" }
}
