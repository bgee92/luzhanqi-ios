/// Rule variants a game is played with. See RULES.md ("Variants").
public struct RuleOptions: Hashable, Codable, Sendable {
    /// Open (明棋) mode: every piece is visible to both players.
    public var openPieces: Bool
    /// A non-engineer attacking a landmine removes both pieces instead of
    /// leaving the mine in place.
    public var explosiveMines: Bool
    /// Capturing an enemy headquarters that does not hold the Flag reveals
    /// where the Flag is.
    public var wrongHeadquartersReveal: Bool
    /// Consecutive plies without a battle before the game is drawn; 0 disables.
    public var noBattleDrawLimit: Int

    public init(
        openPieces: Bool = false,
        explosiveMines: Bool = false,
        wrongHeadquartersReveal: Bool = true,
        noBattleDrawLimit: Int = 60
    ) {
        self.openPieces = openPieces
        self.explosiveMines = explosiveMines
        self.wrongHeadquartersReveal = wrongHeadquartersReveal
        self.noBattleDrawLimit = noBattleDrawLimit
    }

    public static let standard = RuleOptions()
}

public enum Outcome: String, Codable, Sendable {
    case moved
    case attackerWon
    case defenderWon
    case bothRemoved
    case flagCaptured

    public var isBattle: Bool { self != .moved }
}

enum Combat {
    /// The referee's decision when `attacker` moves onto `defender`.
    static func resolve(attacker: Rank, defender: Rank, rules: RuleOptions) -> Outcome {
        if defender == .flag { return .flagCaptured }
        if attacker == .bomb || defender == .bomb { return .bothRemoved }
        if defender == .landmine {
            if attacker == .engineer { return .attackerWon }
            return rules.explosiveMines ? .bothRemoved : .defenderWon
        }
        guard let a = attacker.power, let d = defender.power else {
            preconditionFailure("\(attacker) cannot attack")
        }
        return a > d ? .attackerWon : a < d ? .defenderWon : .bothRemoved
    }
}
