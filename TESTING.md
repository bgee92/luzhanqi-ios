# Testing

Luzhanqi has three layers of automated tests plus a written review of every piece of player-facing text. All of them run from one command:

```sh
xcodebuild test -project Luzhanqi.xcodeproj -scheme Luzhanqi \
  -destination 'platform=iOS Simulator,name=Luzhanqi Tests'
```

The `Luzhanqi Tests` simulator is a dedicated iPhone 17 created only for tests, so a test run never disturbs the simulator you use from Xcode. Create it once with:

```sh
xcrun simctl create "Luzhanqi Tests" "iPhone 17"
```

In Xcode, choose **Product → Test** (⌘U) with any iPhone simulator selected.

| Layer | Target | Framework | What it covers | Run just this layer |
|---|---|---|---|---|
| Game engine and AI | `LuzhanqiKitTests` (Swift package) | Swift Testing | Rules, movement, battles, setup, hidden information, the computer opponent | `swift test --package-path Packages/LuzhanqiKit` (no simulator needed) |
| App logic and text | `LuzhanqiTests` | Swift Testing | Settings, game flow, every string in both languages, fonts, rulebooks, board geometry | add `-only-testing:LuzhanqiTests` |
| User interface | `LuzhanqiUITests` | XCTest UI testing | Every screen driven by taps, as a player would | add `-only-testing:LuzhanqiUITests` |

To run one suite or test, name it: `-only-testing:LuzhanqiTests/StringsTests`, or `swift test --package-path Packages/LuzhanqiKit --filter CombatTests`.

## 1. Game engine and AI (`Packages/LuzhanqiKit/Tests`)

| Suite | What it checks |
|---|---|
| `BoardTests` | Station counts, camps and headquarters, frontier crossings, camp diagonals, railroads, square names |
| `SetupTests` | Placement rules (Flag, mines, bombs, camps), wrong piece counts, random deployments, swap validation |
| `MovementTests` | Road steps, straight railroad runs, Engineers turning corners, mountains, camps, immobile pieces, illegal moves rejected |
| `CombatTests` | Every battle outcome, Flag capture, Field Marshal and empty-HQ reveals, no-move loss, draws |
| `PlayerViewTests` | Hidden ranks stay hidden, Open mode, legal moves from a player's view, saving and loading |
| `RulesConformanceTests` | The engine against an independent reference built from the `RULES.md` board diagram: every piece on every square, 4,000 random positions, every from/to pair on 250 positions, every attacker/defender pair, 60 full games |
| `BeliefsTests`, `AIPlayerTests` | What the computer deduces about hidden pieces, legal computer setups, taking a revealed Flag, avoiding known losing attacks, Hard beating Easy |

## 2. App logic and text (`AppTests`)

| Suite | What it checks |
|---|---|
| `AppSettingsTests` | First-launch defaults, every setting persisting across launches, settings becoming game rules, language names and locales |
| `GameControllerTests` | Deployment (selecting, swapping, refused swaps with a reason, Shuffle, Suggested), starting a game, the computer moving first or replying, taps that aren't moves changing nothing, resigning, autosave and resume, every pass-and-play hand-off, announcement tone |
| `StringsTests` | Every string the app can show, in both languages (see below) |
| `FontCoverageTests` | Every Chinese character the app or rulebook uses exists in the bundled fonts, and the fonts register under the names the code uses |
| `RulebookTests` | Both rulebooks parse; the rules page finds the board diagram, piece table and Battles heading it replaces; the English and Chinese rulebooks have the same structure; tables are rectangular; Settings names match the rulebook's Variants table |
| `BoardGeometryTests` | Square positions, Blue's rotated view, every square surviving a tap round trip, the river not being a square, distinct insignia for all eight officers |

### Text checks (`StringsTests`)

`catalog()` lists every string `Strings` can produce, including every move announcement (mover, outcome, known or hidden piece, Flag reveals) and every game result (winner, reason, and computer vs. pass-and-play). A test reads `App/Strings.swift` and fails if a new string isn't in the catalog, so new text can't skip these checks:

- **Both languages:** every string exists in both languages and is actually translated. No empty text, stray or double spaces, or unfilled placeholders.
- **English:**
  - No Chinese characters or Chinese punctuation, except where Chinese is deliberately quoted (such as 明棋).
  - Sentences start with a capital and end with `.`, `!` or `?`; labels and buttons have no full stop.
  - Announcements have no repeated words.
- **Chinese:**
  - Only full-width punctuation (，。：！？).
  - No English except square names (a1–e12) and file letters.
  - Spaces only next to square names, numbers, `·` or `→` (Chinese doesn't separate words with spaces).
  - Sentences end with 。！ or ？.
- **Meaning:**
  - Piece labels are distinct.
  - The game-over reason never repeats the headline.
  - Announcements never reveal an enemy piece's rank.
  - Representative sentences read exactly as intended.

## 3. User interface (`UITests`)

Each test launches the app with `-uiTesting`, which clears saved settings and any saved game, so every test starts from a clean install. Controls are found by accessibility identifier (such as `home.startComputer`, `deploy.ready`, `game.status`, and `piece.a6` for pieces), and empty squares are tapped by position on the `board` element.

| Test | Flow |
|---|---|
| `testHomeShowsEveryControl` | All home-screen controls are present; no Resume button on a clean install |
| `testLanguageSwitchTranslatesEverythingAndPersists` | Switching to 中文 translates the home screen, survives a relaunch, and carries into the deployment screen |
| `testSettingsPersistAcrossLaunches` | Toggling Open pieces and choosing "Never" for the draw rule survive a relaunch |
| `testDeploymentSwapsWithoutMovingTheBoard` | Shuffle, Suggested, a legal swap, and a refused Flag swap with its message, all without the board moving or resizing |
| `testFullGameAgainstTheComputer` | Ready → move → the computer replies → the move log lists both moves → rules open from the game → Save & quit → Resume, with the board size fixed throughout |
| `testResigningShowsDefeatAndRematchStartsANewGame` | Resign → confirm → "Defeat" and "You resigned." → Rematch returns to deployment |
| `testPassAndPlayHidesTheBoardBetweenTurns` | Both deployments with hand-offs, a move, "Done — pass to Blue", and the board hidden during every hand-off |
| `testRulesPageInBothLanguages` | The rules page shows the board, the piece list and the movement examples in English and Chinese |

## Text review

Every user-facing sentence in `App/Strings.swift`, `RULES.md` and `RULES.zh.md` was reviewed by reading it in context. Fixes made:

| Where | Before | After |
|---|---|---|
| Game-over card | Repeated the headline: "Victory" / "You win: the Flag was captured." (你赢了 / 你赢了：夺得军旗。) | Gives only the reason, from the player's side: "You captured the enemy Flag." (你夺得了敌方军旗。) |
| Resignation result | "You win by resignation." (suggested *you* resigned) | Names who resigned: "You resigned." / "The computer resigned." / "Blue resigned." |
| Move messages | "Your Colonel moved a4-a5." | "Your Colonel moved from a4 to a5." |
| Trades | "Your Colonel at a6 traded with the attacker." | "Your Colonel at a6 and the attacker were both removed." |
| Chinese messages | Coordinates run into the text: 从a4走到a5 | Spaced as in the rulebook: 从 a4 走到 a5 |
| Settings | "Wrong headquarters reveals Flag" | "Taking the empty HQ reveals the Flag" |
| Rulebook Variants table | Names differed from the Settings screen ("Explosive mines", "Wrong-HQ reveal", "0 disables it") | Uses the Settings names and options exactly |
| Rulebook, battles | "Lower one is removed; the winner occupies the square." (wrong when the defender wins) | "The lower-ranked one is removed. If the attacker wins, it moves onto the square." |
| Rulebook, Landmine | "Kills any attacker except an Engineer." (ignored Bombs) | "…except an Engineer; a Bomb destroys it along with itself." |
| Game-over tallies | "enemy lost", "you lost", "moves" | "Enemy losses", "Your losses", "Moves" |
| Rules legend and caption | "Frontier: cross at a, c, e"; "…across the frontier and around." | "Frontier: cross only at a, c and e"; "…turning corners and crossing the frontier." |
| Home subtitle (Chinese) | 两人对弈 · 暗棋裁判 (reads oddly) | 又称军棋 · 两人对弈 |
| Board labels | Hard-coded in the board drawing | Taken from `Strings`, like all other text |

Two unused strings were removed.

## When you change things

| If you change | Also do |
|---|---|
| Text in `Strings.swift` | Add any new member to `catalog()` in `AppTests/StringsTests.swift` (the coverage test will remind you) |
| Chinese text, in the app or `RULES.zh.md` | Re-run `Tools/subset_fonts.py` (`FontCoverageTests` fails until you do) |
| Board rules | Update the `RULES.md` diagram and the reference in `RulesConformanceTests` |
| A section of one rulebook | Make the same change in the other (`bothRulebooksHaveTheSameStructure`) |
| A screen's controls | Keep the accessibility identifiers the UI tests use |
