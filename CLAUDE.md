# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native iOS (SwiftUI, iOS 17+) Luzhanqi game: 1 player vs computer (3 levels) or pass-and-play on one phone, with hidden pieces refereed by the app. `RULES.md` is the player-facing rulebook. It is bundled into the app and rendered by `App/Views/RulesView.swift`, so when a rule changes in the engine, update RULES.md too. RulesView parses only a small subset of Markdown (headings, paragraphs, `-`/`1.` lists, fenced code, pipe tables).

## Commands

```sh
swift test --package-path Packages/LuzhanqiKit                         # all engine + AI tests
swift test --package-path Packages/LuzhanqiKit --filter CombatTests    # one suite
swift test --package-path Packages/LuzhanqiKit --filter "CombatTests/landmines"  # one test
xcodegen                                                                # regenerate Luzhanqi.xcodeproj from project.yml
xcodebuild -scheme Luzhanqi -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild test -project Luzhanqi.xcodeproj -scheme Luzhanqi -destination 'platform=iOS Simulator,name=Luzhanqi Tests'   # everything
#   add -only-testing:LuzhanqiTests (app logic + text) or -only-testing:LuzhanqiUITests (UI), or e.g. -only-testing:LuzhanqiTests/StringsTests
```

- **TESTING.md** documents every test layer, what each suite covers, and the text-review results. Read it before adding features.
- Run app and UI tests on the dedicated `Luzhanqi Tests` simulator (`xcrun simctl create "Luzhanqi Tests" "iPhone 17"`), never on the simulator the user runs from Xcode.
- UI tests launch the app with `-uiTesting` (clears settings and the saved game) and find controls by accessibility identifier (`home.startComputer`, `deploy.ready`, `game.status`, `piece.<square>`, `board`…). Keep identifiers when changing views.
- Refresh `Screenshots/` with `ScreenshotTests` (command in TESTING.md), not `simctl io screenshot`, which returns stale frames on a headless simulator.
- Every string in `Strings.swift` must be listed in `catalog()` in `AppTests/StringsTests.swift`. A test parses `Strings.swift` and fails otherwise; the catalog drives the English/Chinese grammar and punctuation checks.

- Engine and app-logic tests use Swift Testing (`import Testing`, `@Test`, `#expect`). UI tests use XCTest, which UI testing requires.
- `RulesConformanceTests` checks the engine against an independent reference implementation. **It parses the board diagram in RULES.md**, so the diagram's exact layout is load-bearing: stations are at character column 9 + 4×file, links are in between, and the connector lines hold `│ ║ \ / ^`. If you change the board rules, update the diagram and the reference generator in that file, not just the engine.
- The AI self-play test (`selfPlayIsLegalAndHardBeatsEasy`) takes about 30 s in debug.
- `Luzhanqi.xcodeproj` is generated; edit `project.yml`, never the project file.
- Without Xcode, you can still typecheck `App/` against the macOS SDK: `swift build` the package, then `swiftc -typecheck -parse-as-library -swift-version 6 -target arm64-apple-macos14 -I Packages/LuzhanqiKit/.build/debug/Modules App/*.swift App/Views/*.swift`. Expect errors only for iOS-only modifiers (`fullScreenCover`, `navigationBarTitleDisplayMode`). This misses definite-initialization errors, which only a real compile catches.

## Architecture

**`Packages/LuzhanqiKit`** is a pure Swift engine plus AI with no UI imports. The app depends on it as a local package.

- `Board.swift`: topology. A `Position` is (row 0–11, col 0–4); Blue owns rows 0–5 and Red owns rows 6–11. The frontier sits between rows 5 and 6 and can only be crossed at cols 0/2/4. Internals use `Position.index` (row*5+col) and flat `[[Int]]` adjacency. Move generation uses `UInt64` square masks, which only works because `Board.count` (60) ≤ 64. Square names (`a1`…`e12`) count ranks up from Red's back row.
- `GameState`: the complete, true state (Codable, used for autosave). `apply(_:)` validates the move; internal `perform(from:to:)` skips validation and is what the AI search uses. Search copies set `recordsHistory = false`.
- `Combat.resolve` is the single source of battle outcomes. `Beliefs` also inverts it: it tries every rank to see which ones match an observed outcome.
- **`PlayerView` is the hidden-information boundary.** During play the UI and AI read only `PlayerView(state, viewer:)`, which hides enemy ranks and strips ranks from history (`PublicMoveRecord`). Don't hand `GameState` or `MoveRecord` to anything that shows or decides on behalf of one player. Legal moves for the viewer don't depend on enemy ranks, so `PlayerView.legalMoves()` determinizes enemy pieces with a placeholder rank.
- **Piece ids are the square index where the piece was deployed** (`Piece.id(deployedAt:)`). This is public information. `Beliefs` relies on it to apply setup rules (mines only in back rows, Flag only in an HQ, no bombs in the front row) to enemy pieces.
- `AI/`: `Beliefs` tracks a candidate `RankSet` per enemy piece from setup rules, movement (moving rules out Mine/Flag; turning a rail corner means Engineer), battle outcomes, and army counts. `AIPlayer`: Easy is a one-move heuristic. Medium and Hard use determinized search: they sample enemy ranks from `Beliefs`, score each move by the opponent's best reply using `Evaluator`, and average over samples within a time budget. `AIDeployer` builds computer setups.

**`App/`** is SwiftUI with `@Observable`, under Swift 6 strict concurrency.

- `GameController` (`@MainActor`) owns one game and its `Phase`: `.deploying(side)` → `.handoff(side)` → `.playing` → (pass-and-play: `.turnComplete` → `.handoff`) → `.over`. `viewer` is whose perspective the screen shows. The computer's move runs in `Task.detached` on a `PlayerView` snapshot. Each move autosaves to Application Support/SavedGame.json, and the save is deleted when the game ends.
- `GameFlowView` (in `LuzhanqiApp.swift`) switches screens on `phase`.
- `BoardView` draws the board, always with the viewer's side at the bottom. `BoardGeometry` maps positions to points. Everything is in 500 × 806 design units: five columns of 100, thirteen rows of 62 (the extra row is the frontier river), and pieces of 88 × 54. `BoardBackground` (terrain, river, bridges, palisades, sandbags) is a static `Canvas` marked `Equatable` so it isn't redrawn on every move.
- **Visual design lives in `App/Design/`:**
  - `Theme.swift`: the fixed `Palette` and `AppFont`.
  - `PieceArt.swift`: the piece art, drawn in code, and `PieceTile`. Officers show only their distinguishing PLA rank marks (bars and stars); the role-to-rank mapping is `PieceArt.insignia`.
  - `Components.swift`: button styles, cards and seals.
- **Fixed appearance:** the app has its own palette rather than following dark mode. Home is night-dark (`.preferredColorScheme(.dark)` for a light status bar); game screens, rules and settings force light.
- **Bundled fonts:** three OFL fonts (Noto Serif SC Black, Ma Shan Zheng, Big Shoulders Display ExtraBold) live in `App/Fonts/`, subset to the characters the app uses. They are registered at launch by `AppFont.registerBundledFonts()`, not through Info.plist. **After adding Chinese text to `Strings.swift` or `RULES.zh.md`, re-run `Tools/subset_fonts.py`** (see its docstring), or the new characters fall back to the system font.
- **Rules page:** `RulesView` renders the markdown rulebook but swaps in three drawn parts: the board diagram becomes a real `BoardView`, the piece table becomes `PieceTile`s, and movement-example boards appear before the Battles heading.
- `AppSettings` stores preferences and rule variants in UserDefaults. Rule variants become a `RuleOptions` when a new game starts.
- **Localization (English / Simplified Chinese):** players choose the language in the app (home screen or Settings), not through the iOS language. So `App/Strings.swift` is a plain table, not a String Catalog, with both translations side by side. All user-visible text goes through `settings.strings`; never put string literals in views. The engine returns typed values (`SetupViolation`, `Outcome`, `GameResult`), and only `Strings` turns them into words. Announcements are stored as data (`Announcement` = record + viewer) and worded at render time. The rulebook is `RULES.md` plus `RULES.zh.md`; the board diagram must stay identical in both (`chineseRulebookShowsTheSameBoard` checks this). Chinese text uses full-width punctuation. Debug screenshots: launch with `-language chinese -demo deploy|handoff|game|over|rules` (add `-rulesAnchor pieces|examples` to scroll the rules page).
