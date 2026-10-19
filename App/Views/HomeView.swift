import LuzhanqiKit
import SwiftUI

struct HomeView: View {
    let start: (GameController) -> Void
    /// Whether a saved game exists. Owned by the caller, which re-checks it
    /// whenever a game screen closes (onAppear doesn't run again then).
    let hasSave: Bool
    @Environment(AppSettings.self) private var settings
    @State private var showingSettings = false

    var body: some View {
        @Bindable var settings = settings
        let strings = settings.strings
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    hero(strings)
                    VStack(spacing: 12) {
                        LanguageToggle(language: $settings.language)
                        if hasSave {
                            Button {
                                if let game = GameController.resume() { start(game) }
                            } label: {
                                Label(strings.resumeGame, systemImage: "play.fill")
                            }
                            .buttonStyle(LacquerButtonStyle())
                            .accessibilityIdentifier("home.resume")
                        }
                        computerCard(strings, difficulty: $settings.difficulty, movesFirst: $settings.humanMovesFirst)
                        PaperCard {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Heading(text: strings.newPassAndPlay)
                                    Text(strings.passAndPlayShort).font(.footnote).foregroundStyle(Palette.ink.opacity(0.7))
                                }
                                Spacer(minLength: 0)
                                Button(strings.start) { begin(.passAndPlay) }.buttonStyle(InkButtonStyle())
                                    .accessibilityIdentifier("home.startPassAndPlay")
                            }
                        }
                        HStack(spacing: 28) {
                            NavigationLink { RulesView() } label: { Label(strings.rules, systemImage: "book") }
                                .accessibilityIdentifier("home.rules")
                            Button { showingSettings = true } label: { Label(strings.settings, systemImage: "gearshape") }
                                .accessibilityIdentifier("home.settings")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.cream.opacity(0.85))
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 28)
            }
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(edges: .top)
            .background(Palette.night.ignoresSafeArea())
            // Titles the back button on pushed screens (otherwise the system's English "Back").
            .navigationTitle(strings.appTitle)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingSettings) { SettingsView().preferredColorScheme(.light) }
        }
        // The home screen is night-dark, so the status bar text is light.
        .preferredColorScheme(.dark)
    }

    /// A tilted board under the brush-script title.
    private func hero(_ strings: Strings) -> some View {
        ZStack(alignment: .bottom) {
            BoardView(viewer: .red, pieces: Self.heroPieces, strings: strings)
                .frame(width: 330)
                .rotation3DEffect(.degrees(46), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.55)
                .scaleEffect(1.3, anchor: .top)
                .frame(height: 320, alignment: .top)
                .clipped()
                // Fade the board into the night at the top (under the status bar) and behind the title.
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0.12),
                                             .init(color: .black, location: 0.34),
                                             .init(color: .black, location: 0.5),
                                             .init(color: .black.opacity(0.25), location: 0.78),
                                             .init(color: .clear, location: 0.96)],
                                     startPoint: .top, endPoint: .bottom))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                HStack(alignment: .center, spacing: 10) {
                    Text(strings.appTitle)
                        .font(AppFont.brush(66))
                        .foregroundStyle(Palette.cream)
                        .shadow(color: .black.opacity(0.6), radius: 8, y: 3)
                    Text("军\n棋")
                        .font(AppFont.serif(15))
                        .lineSpacing(1)
                        .foregroundStyle(Palette.cream)
                        .padding(.horizontal, 5).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Palette.red))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                }
                Text(strings.appSubtitle)
                    .font(.caption.weight(.semibold))
                    .tracking(strings.language == .chinese ? 4 : 1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cream.opacity(0.7))
            }
            .padding(.bottom, 8)
        }
        .frame(height: 320)
    }

    private func computerCard(_ strings: Strings, difficulty: Binding<Difficulty>, movesFirst: Binding<Bool>) -> some View {
        PaperCard {
            HStack(alignment: .firstTextBaseline) {
                Heading(text: strings.playComputer)
                Spacer()
                Text(strings.difficultyLabel).font(.caption).foregroundStyle(Palette.ink.opacity(0.65))
            }
            HStack(spacing: 8) {
                ForEach([(Difficulty.easy, Rank.lieutenant), (.medium, .colonel), (.hard, .fieldMarshal)], id: \.0) { level, rank in
                    let chosen = difficulty.wrappedValue == level
                    Button { difficulty.wrappedValue = level } label: {
                        VStack(spacing: 4) {
                            InsigniaMark(rank: rank).frame(width: 30, height: 30)
                            Text(strings.difficulty(level)).font(.footnote.weight(.bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(chosen ? Palette.red : Palette.ink)
                        .background(RoundedRectangle(cornerRadius: 12).fill(chosen ? Palette.red.opacity(0.08) : .clear))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(chosen ? Palette.red : Palette.ink.opacity(0.2), lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                    .accessibilityIdentifier("home.difficulty.\(level.rawValue)")
                }
            }
            Toggle(strings.humanMovesFirst, isOn: movesFirst)
                .accessibilityIdentifier("home.moveFirst")
                .font(.subheadline.weight(.semibold))
                .tint(Palette.jade)
            Button(strings.newComputerGame) {
                begin(.computer(human: movesFirst.wrappedValue ? .red : .blue, difficulty: difficulty.wrappedValue))
            }
            .buttonStyle(LacquerButtonStyle())
            .accessibilityIdentifier("home.startComputer")
        }
    }

    private func begin(_ mode: GameMode) {
        GameController.deleteSave()
        start(GameController(mode: mode, rules: settings.rules))
    }

    /// A decorative mid-game position for the hero board.
    private static let heroPieces: [BoardPiece] = {
        let hidden = [(0, 0), (0, 2), (1, 1), (1, 3), (2, 4), (3, 0), (4, 2), (5, 1), (5, 4)]
        let red: [(Int, Int, Rank)] = [(6, 0, .general), (6, 3, .engineer), (7, 4, .bomb), (8, 1, .fieldMarshal), (9, 2, .colonel),
                                       (10, 0, .landmine), (10, 3, .major), (11, 1, .flag), (11, 2, .landmine)]
        return hidden.map { BoardPiece(id: $0.0 * 5 + $0.1, side: .blue, rank: nil, position: Position($0.0, $0.1)) }
            + red.map { BoardPiece(id: $0.0 * 5 + $0.1, side: .red, rank: $0.2, position: Position($0.0, $0.1)) }
    }()
}

/// English | 中文, styled for the dark home screen. Each option is written in its own language.
private struct LanguageToggle: View {
    @Binding var language: AppLanguage

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppLanguage.allCases) { option in
                Button { language = option } label: {
                    Text(option.nativeName)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(language == option ? Palette.ink : Palette.cream.opacity(0.7))
                        .background(RoundedRectangle(cornerRadius: 9).fill(language == option ? Palette.cream : .clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(language == option ? .isSelected : [])
                .accessibilityIdentifier("home.language.\(option.rawValue)")
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cream.opacity(0.1)))
    }
}

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        let strings = settings.strings
        NavigationStack {
            Form {
                Section(strings.languageLabel) {
                    Picker(strings.languageLabel, selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { Text($0.nativeName) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.language")
                }
                Section {
                    Toggle(strings.openPieces, isOn: $settings.openPieces)
                        .accessibilityIdentifier("settings.openPieces")
                    Toggle(strings.explosiveMines, isOn: $settings.explosiveMines)
                        .accessibilityIdentifier("settings.explosiveMines")
                    Toggle(strings.wrongHeadquartersReveal, isOn: $settings.wrongHeadquartersReveal)
                        .accessibilityIdentifier("settings.wrongHeadquartersReveal")
                    Picker(strings.drawLimit, selection: $settings.noBattleDrawLimit) {
                        Text(strings.drawNever).tag(0)
                        ForEach([40, 60, 100], id: \.self) { Text(strings.turns($0)).tag($0) }
                    }
                    .accessibilityIdentifier("settings.drawLimit")
                } header: {
                    Text(strings.rules)
                } footer: {
                    Text(strings.settingsFooter)
                }
            }
            .tint(Palette.red)
            .navigationTitle(strings.settings)
            .toolbar { Button(strings.done) { dismiss() }.accessibilityIdentifier("settings.done") }
        }
    }
}
