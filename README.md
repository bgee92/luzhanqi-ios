# 陆战棋 Luzhanqi for iPhone

A native SwiftUI version of Luzhanqi (Land Battle Chess / Army Chess). You can play the computer (Easy, Medium, Hard) or another person on the same phone (pass-and-play). Pieces are hidden from the opponent by default, with the app acting as referee; an Open (明棋) variant is in Settings.

The full rules are in [RULES.md](RULES.md), which is also bundled into the app's Rules screen.

## Requirements

- Xcode 16 or later (iOS 17+ deployment target)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

```sh
xcodegen                 # generates Luzhanqi.xcodeproj from project.yml
open Luzhanqi.xcodeproj
```

To run on your iPhone:

1. In Xcode, go to **Settings → Accounts** and add your Apple ID.
2. Select the **Luzhanqi** target and open **Signing & Capabilities**. Choose your team. If the bundle ID `com.bengee.Luzhanqi` is taken, change it in `project.yml`.
3. Plug in the phone. If iOS asks, enable **Developer Mode** (Settings → Privacy & Security). Then select the phone and press Run.

With a free Apple ID, the installed app expires after 7 days; run it from Xcode again to renew it.

## Tests

The game engine and AI live in a standalone Swift package. Its tests run with just the Command Line Tools:

```sh
swift test --package-path Packages/LuzhanqiKit
```
