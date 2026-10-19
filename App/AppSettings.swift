import Foundation
import LuzhanqiKit
import Observation

/// User preferences, persisted in UserDefaults.
@MainActor @Observable
final class AppSettings {
    var language: AppLanguage { didSet { save() } }
    var difficulty: Difficulty { didSet { save() } }
    var humanMovesFirst: Bool { didSet { save() } }
    var openPieces: Bool { didSet { save() } }
    var explosiveMines: Bool { didSet { save() } }
    var wrongHeadquartersReveal: Bool { didSet { save() } }
    var noBattleDrawLimit: Int { didSet { save() } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let standard = RuleOptions.standard
        language = defaults.string(forKey: "language").flatMap(AppLanguage.init(rawValue:)) ?? .deviceDefault
        difficulty = defaults.string(forKey: "difficulty").flatMap(Difficulty.init(rawValue:)) ?? .medium
        humanMovesFirst = defaults.object(forKey: "humanMovesFirst") as? Bool ?? true
        openPieces = defaults.object(forKey: "openPieces") as? Bool ?? standard.openPieces
        explosiveMines = defaults.object(forKey: "explosiveMines") as? Bool ?? standard.explosiveMines
        wrongHeadquartersReveal = defaults.object(forKey: "wrongHeadquartersReveal") as? Bool ?? standard.wrongHeadquartersReveal
        noBattleDrawLimit = defaults.object(forKey: "noBattleDrawLimit") as? Int ?? standard.noBattleDrawLimit
    }

    var rules: RuleOptions {
        RuleOptions(openPieces: openPieces, explosiveMines: explosiveMines,
                    wrongHeadquartersReveal: wrongHeadquartersReveal, noBattleDrawLimit: noBattleDrawLimit)
    }

    var strings: Strings { Strings(language: language) }

    private func save() {
        defaults.set(language.rawValue, forKey: "language")
        defaults.set(difficulty.rawValue, forKey: "difficulty")
        defaults.set(humanMovesFirst, forKey: "humanMovesFirst")
        defaults.set(openPieces, forKey: "openPieces")
        defaults.set(explosiveMines, forKey: "explosiveMines")
        defaults.set(wrongHeadquartersReveal, forKey: "wrongHeadquartersReveal")
        defaults.set(noBattleDrawLimit, forKey: "noBattleDrawLimit")
    }
}
