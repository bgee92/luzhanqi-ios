import Foundation
import LuzhanqiKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case chinese

    var id: Self { self }

    /// Each language's name written in that language, for the picker.
    var nativeName: String { self == .english ? "English" : "中文" }

    var locale: Locale { Locale(identifier: self == .english ? "en" : "zh-Hans") }

    /// The phone's language if it is Chinese, otherwise English.
    static var deviceDefault: AppLanguage {
        Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .chinese : .english
    }
}

/// Every user-facing string, in English and Simplified Chinese.
///
/// Players pick the language on the home screen, independently of the phone's
/// language, so this is a plain table rather than a String Catalog (which
/// follows the system language). Each entry keeps both translations side by
/// side so they are easy to review together. Chinese uses full-width
/// punctuation (，。：！？（）“”).
struct Strings {
    let language: AppLanguage

    private var english: Bool { language == .english }
    private func t(_ en: String, _ zh: String) -> String { english ? en : zh }

    // MARK: Game vocabulary

    func side(_ side: Side) -> String { side == .red ? t("Red", "红方") : t("Blue", "蓝方") }

    func rank(_ rank: Rank) -> String { english ? rank.englishName : rank.chineseName }

    /// The short label printed on a piece: the Chinese name, or a standard
    /// English military abbreviation that fits beside the insignia.
    func pieceLabel(_ rank: Rank) -> String {
        guard english else { return rank.chineseName }
        return ["FM", "GEN", "MG", "BG", "COL", "MAJ", "CPT", "LT", "ENG", "BOMB", "MINE", "FLAG"][rank.rawValue]
    }

    /// What the art on a piece shows (for the rules page).
    func pieceArt(_ rank: Rank) -> String {
        switch rank {
        case .fieldMarshal: t("Three stars: General (上将)", "三星（上将）")
        case .general: t("Two stars: Lieutenant General (中将)", "两星（中将）")
        case .majorGeneral: t("One star: Major General (少将)", "一星（少将）")
        case .brigadier: t("Two bars, four stars: Senior Colonel (大校)", "两杠四星（大校）")
        case .colonel: t("Two bars, three stars: Colonel (上校)", "两杠三星（上校）")
        case .major: t("Two bars, one star: Major (少校)", "两杠一星（少校）")
        case .captain: t("One bar, three stars: Captain (上尉)", "一杠三星（上尉）")
        case .lieutenant: t("One bar, one star: Second Lieutenant (少尉)", "一杠一星（少尉）")
        case .engineer: t("Crossed pick and shovel", "交叉的镐和锹")
        case .bomb: t("A bomb with a lit fuse", "点燃引信的炸弹")
        case .landmine: t("Yellow warning sign with a mine", "黄色警告牌与地雷")
        case .flag: t("The 八一 army flag", "八一军旗")
        }
    }

    func difficulty(_ difficulty: Difficulty) -> String {
        switch difficulty {
        case .easy: t("Easy", "简单")
        case .medium: t("Medium", "中等")
        case .hard: t("Hard", "困难")
        }
    }

    /// Text drawn on headquarters and camp stations.
    var headquartersMark: String { t("HQ", "大本营") }
    var campMark: String { t("CAMP", "行营") }
    var pieceUnknown: String { t("hidden piece", "未知棋子") }

    func pieceAccessibility(side: Side, rank: Rank?, at position: Position) -> String {
        let name = rank.map(self.rank) ?? pieceUnknown
        return english ? "\(self.side(side)) \(name) at \(position.name)" : "\(position.name)：\(self.side(side))\(name)"
    }

    // MARK: Common

    var rules: String { t("Rules", "规则") }
    var settings: String { t("Settings", "设置") }
    var done: String { t("Done", "完成") }
    var cancel: String { t("Cancel", "取消") }
    var languageLabel: String { t("Language", "语言") }

    // MARK: Home

    var appTitle: String { "陆战棋" }
    var appSubtitle: String { t("Luzhanqi · Land Battle Chess", "又称军棋 · 两人对弈") }
    var resumeGame: String { t("Resume saved game", "继续上次的对局") }
    var playComputer: String { t("Play the computer", "人机对战") }
    var difficultyLabel: String { t("Difficulty", "难度") }
    var humanMovesFirst: String { t("I move first (Red)", "我先走（红方）") }
    var newComputerGame: String { t("Start game", "开始对战") }
    var newPassAndPlay: String { t("Two players", "双人同机对战") }
    var passAndPlayShort: String { t("Pass one phone between turns.", "两人轮流使用同一部手机。") }
    var start: String { t("Start", "开始") }

    // MARK: Settings

    var openPieces: String { t("Open pieces (明棋)", "明棋（所有棋子公开）") }
    var explosiveMines: String { t("Explosive landmines", "地雷同归于尽") }
    var wrongHeadquartersReveal: String { t("Taking the empty HQ reveals the Flag", "攻占空大本营时亮军旗") }
    var drawLimit: String { t("Draw after no battles for", "无交战判和") }
    var drawNever: String { t("Never", "不判和") }
    func turns(_ n: Int) -> String { t("\(n) turns", "\(n) 步") }
    var settingsFooter: String {
        t("Rule changes apply to new games. See Rules → Variants for details.",
          "规则改动在新对局中生效。详见“规则”中的“变体规则”一节。")
    }

    // MARK: Deployment

    var quit: String { t("Quit", "退出") }
    func deployTitle(_ side: Side) -> String { t("\(self.side(side)) · Deploy", "\(self.side(side)) · 布阵") }
    var ready: String { t("Ready", "就绪") }
    var deployHint: String {
        t("Tap two pieces to swap them. Pieces that can't swap are faded.",
          "点击两枚棋子交换位置。不能交换的棋子会变淡。")
    }
    /// The setup rules, shown as chips under the deployment board.
    var setupChips: [String] {
        [t("Flag → HQ", "军旗 → 大本营"), t("Mines → back 2 rows", "地雷 → 后两排"), t("No bombs in front row", "炸弹不上第一排")]
    }
    var shuffle: String { t("Shuffle", "随机布阵") }
    var suggested: String { t("Suggested", "推荐布阵") }

    func violation(_ violation: SetupViolation) -> String {
        switch violation {
        case .outsideOwnHalf: t("That square is not in your half.", "该位置不在己方阵地内。")
        case .campMustStartEmpty: t("Camps must start empty.", "布阵时行营必须空着。")
        case .flagOutsideHeadquarters: t("The Flag must start in a headquarters.", "军旗必须放在大本营。")
        case .landmineOutsideBackRows: t("Landmines must start in the back two rows.", "地雷只能放在最后两排。")
        case .bombInFrontRow: t("Bombs cannot start in the front row.", "炸弹不能放在第一排。")
        case .emptySquare: t("Both squares must hold your pieces.", "两个位置都必须有己方棋子。")
        }
    }

    // MARK: Handoff

    func passTo(_ side: Side) -> String { t("Pass to \(self.side(side))", "请把手机交给\(self.side(side))") }
    func handoffDeploy(_ side: Side) -> String { t("\(self.side(side)), it's time to deploy your army.", "\(self.side(side))，请布阵。") }
    func handoffMove(_ side: Side) -> String { t("\(self.side(side)), it's your move.", "\(self.side(side))，轮到你走棋了。") }
    var handoffPrivacy: String { t("Make sure the other player isn't looking.", "请确认对方没有在看屏幕。") }
    func handoffReady(_ side: Side) -> String { t("I'm \(self.side(side)) — show my pieces", "我是\(self.side(side))，显示我的棋子") }

    // MARK: Game screen

    var enemyLosses: String { t("Enemy losses", "敌方损失") }
    var yourLosses: String { t("Your losses", "我方损失") }
    var moveLog: String { t("Move log", "行棋记录") }
    var resign: String { t("Resign", "认输") }
    var confirmResign: String { t("Resign this game?", "确定要认输吗？") }
    var home: String { t("Home", "返回主页") }
    var saveAndQuit: String { t("Save & quit", "保存并退出") }
    var gameOver: String { t("Game over", "对局结束") }
    var computerThinking: String { t("Computer is thinking…", "电脑思考中…") }
    var yourMove: String { t("Your move", "轮到你走棋") }
    func toMove(_ side: Side) -> String { t("\(self.side(side)) to move", "轮到\(self.side(side))走棋") }
    func endTurn(passingTo side: Side) -> String { t("Done — pass to \(self.side(side))", "完成，交给\(self.side(side))") }
    var rematch: String { t("Rematch", "再来一局") }
    var referee: String { t("Referee", "裁判") }
    var enemyLost: String { t("Enemy losses", "敌方损失") }
    var youLost: String { t("Your losses", "我方损失") }
    var moves: String { t("Moves", "步数") }

    /// The headline on the game-over card, from `viewer`'s side of the table.
    func verdict(_ result: GameResult, viewer: Side, humanSide: Side?) -> (title: String, seal: String) {
        guard let winner = result.winner else { return (t("Draw", "和棋"), "和") }
        if humanSide == nil, case .win = result { return (t("\(side(winner)) wins", "\(side(winner))获胜"), "胜") }
        return winner == viewer ? (t("Victory", "你赢了"), "胜") : (t("Defeat", "你输了"), "败")
    }
    func youAre(_ side: Side) -> String { t("You are \(self.side(side))", "你是\(self.side(side))") }

    func outcome(_ outcome: Outcome) -> String {
        switch outcome {
        case .moved: ""
        case .attackerWon: t("attacker won", "进攻方胜")
        case .defenderWon: t("defender won", "防守方胜")
        case .bothRemoved: t("both removed", "同归于尽")
        case .flagCaptured: t("flag captured", "夺得军旗")
        }
    }

    /// What `viewer` is told about a move. `ownPieces` names the viewer's
    /// pieces; enemy ranks are never named.
    func announcement(_ record: PublicMoveRecord, viewer: Side, ownPieces: [Int: Rank]) -> String {
        let to = record.move.to.name
        let from = record.move.from.name
        let somePiece = t("piece", "棋子")
        var text: String
        if record.side == viewer {
            let mine = ownPieces[record.attackerID].map(rank) ?? somePiece
            switch record.outcome {
            case .moved: text = t("Your \(mine) moved from \(from) to \(to).", "你的\(mine)从 \(from) 走到 \(to)。")
            case .attackerWon: text = t("Your \(mine) won the battle at \(to).", "你的\(mine)在 \(to) 取胜。")
            case .defenderWon: text = t("Your \(mine) was defeated at \(to).", "你的\(mine)在 \(to) 被击败。")
            case .bothRemoved: text = t("Your \(mine) and the enemy piece at \(to) were both removed.",
                                        "你的\(mine)与 \(to) 的敌方棋子同归于尽。")
            case .flagCaptured: text = t("You captured the enemy Flag!", "你夺得了敌方军旗！")
            }
        } else {
            let enemy = side(record.side)
            let theirs = record.defenderID.flatMap { ownPieces[$0] }.map(rank) ?? somePiece
            switch record.outcome {
            case .moved: text = t("\(enemy) moved from \(from) to \(to).", "\(enemy)从 \(from) 走到 \(to)。")
            case .attackerWon: text = t("\(enemy) took your \(theirs) at \(to).", "\(enemy)吃掉了你在 \(to) 的\(theirs)。")
            case .defenderWon: text = t("Your \(theirs) at \(to) held off an attack.", "你在 \(to) 的\(theirs)挡住了进攻。")
            case .bothRemoved: text = t("Your \(theirs) at \(to) and the attacker were both removed.", "你在 \(to) 的\(theirs)与进攻方同归于尽。")
            case .flagCaptured: text = t("\(enemy) captured your Flag.", "\(enemy)夺得了你的军旗。")
            }
        }
        if record.revealedFlags.contains(viewer.opponent) { text += t(" The enemy Flag is revealed!", "敌方军旗位置已暴露！") }
        if record.revealedFlags.contains(viewer) { text += t(" Your Flag's location is now known.", "你的军旗位置已暴露。") }
        return text
    }

    /// Why the game ended, shown under the game-over headline (which already
    /// says who won), from the player's point of view.
    func result(_ result: GameResult, humanSide: Side?, drawLimit: Int) -> String {
        switch result {
        case let .win(winner, reason):
            let loser = winner.opponent
            // In a game against the computer, "you" is the human; in pass-and-play, sides are named.
            let humanWon = humanSide.map { $0 == winner }
            switch reason {
            case .flagCaptured:
                switch humanWon {
                case true?: return t("You captured the enemy Flag.", "你夺得了敌方军旗。")
                case false?: return t("The computer captured your Flag.", "电脑夺得了你的军旗。")
                case nil: return t("\(side(winner)) captured \(side(loser))'s Flag.", "\(side(winner))夺得了\(side(loser))的军旗。")
                }
            case .opponentCannotMove:
                switch humanWon {
                case true?: return t("The computer has no legal move left.", "电脑已无棋可走。")
                case false?: return t("You have no legal move left.", "你已无棋可走。")
                case nil: return t("\(side(loser)) has no legal move left.", "\(side(loser))已无棋可走。")
                }
            case .resignation:
                switch humanWon {
                case true?: return t("The computer resigned.", "电脑认输了。")
                case false?: return t("You resigned.", "你认输了。")
                case nil: return t("\(side(loser)) resigned.", "\(side(loser))认输了。")
                }
            }
        case .draw(.neitherSideCanMove):
            return t("Neither side has a legal move left.", "双方均已无棋可走。")
        case .draw(.noBattleLimit):
            return t("\(drawLimit) turns in a row without a battle.", "连续 \(drawLimit) 步没有交战。")
        }
    }

    // MARK: Rules

    var legendRailroad: String { t("Railroad", "铁路") }
    var legendRoad: String { t("Road", "公路") }
    var legendCamp: String { t("Camp", "行营") }
    var legendHeadquarters: String { t("HQ", "大本营") }
    var legendFrontier: String { t("Frontier: cross only at a, c and e", "前线：只能从 a、c、e 三列通过") }
    /// The rulebook heading the movement examples are shown before.
    var battlesHeading: String { t("Battles", "交战") }
    var movementExamples: [(title: String, caption: String)] {
        [
            (t("Railroads run straight", "铁路只能直行"),
             t("A Colonel can run the whole a-file in one move, but can't turn the corner at a11.",
               "团长一步可以沿 a 列铁路走到底，但不能在 a11 转弯。")),
            (t("Engineers turn corners", "工兵可以转弯"),
             t("An Engineer can follow any connected railroad through empty squares, turning corners and crossing the frontier.",
               "工兵可以沿相连的铁路经过空位任意转弯，并可越过前线。")),
            (t("Camps are safe", "行营不能被攻击"),
             t("Nothing can attack a piece in a camp. Here a General can't touch a Lieutenant sheltering at c4.",
               "行营中的棋子不能被攻击。图中军长无法攻击在 c4 行营里的排长。")),
        ]
    }

    /// The bundled rulebook for this language (RULES.md / RULES.zh.md).
    var rulesResource: String { english ? "RULES" : "RULES.zh" }
    var rulesUnavailable: String { t("# Rules\n\nThe rulebook could not be loaded.", "# 规则\n\n无法载入规则说明。") }
}
