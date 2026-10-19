import Foundation
import LuzhanqiKit
import Testing
@testable import Luzhanqi

@MainActor
@Suite struct AppSettingsTests {
    /// A private, empty defaults store for each test.
    func freshDefaults() -> UserDefaults {
        let name = "AppSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func defaultsOnFirstLaunch() {
        let settings = AppSettings(defaults: freshDefaults())
        #expect(settings.language == AppLanguage.deviceDefault)
        #expect(settings.difficulty == .medium)
        #expect(settings.humanMovesFirst)
        #expect(settings.rules == .standard)
    }

    @Test func everySettingPersists() {
        let defaults = freshDefaults()
        let settings = AppSettings(defaults: defaults)
        settings.language = .chinese
        settings.difficulty = .hard
        settings.humanMovesFirst = false
        settings.openPieces = true
        settings.explosiveMines = true
        settings.wrongHeadquartersReveal = false
        settings.noBattleDrawLimit = 0

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.language == .chinese)
        #expect(reloaded.difficulty == .hard)
        #expect(!reloaded.humanMovesFirst)
        #expect(reloaded.rules == RuleOptions(openPieces: true, explosiveMines: true, wrongHeadquartersReveal: false, noBattleDrawLimit: 0))
    }

    @Test func rulesReflectTheToggles() {
        let settings = AppSettings(defaults: freshDefaults())
        settings.explosiveMines = true
        settings.noBattleDrawLimit = 100
        #expect(settings.rules.explosiveMines)
        #expect(settings.rules.noBattleDrawLimit == 100)
        #expect(settings.strings.language == settings.language)
    }

    @Test func languagesHaveTheirOwnNamesAndLocales() {
        #expect(AppLanguage.english.nativeName == "English")
        #expect(AppLanguage.chinese.nativeName == "中文")
        #expect(AppLanguage.chinese.locale.identifier == "zh-Hans")
        #expect(Strings(language: .chinese).rulesResource == "RULES.zh")
    }
}
