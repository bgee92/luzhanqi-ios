import LuzhanqiKit
import SwiftUI

struct GameView: View {
    let controller: GameController
    let close: () -> Void
    let rematch: () -> Void
    @Environment(AppSettings.self) private var settings
    @State private var showingLog = false
    @State private var showingRules = false
    @State private var confirmingResign = false

    private var strings: Strings { settings.strings }

    var body: some View {
        if let view = controller.playerView {
            VStack(spacing: 4) {
                topBar
                LossTray(title: strings.enemyLosses, side: view.viewer.opponent, hiddenCount: enemyLosses(view), ranks: [])
                ZStack(alignment: .bottom) {
                    BoardView(
                        viewer: controller.viewer,
                        pieces: view.boardPieces,
                        selected: controller.selected,
                        targets: Set(controller.selected.map(view.destinations(from:)) ?? []),
                        lastMove: view.history.last?.move,
                        strings: strings,
                        onTap: controller.tapBoard
                    )
                    if controller.phase == .over {
                        LinearGradient(colors: [Palette.night.opacity(0), Palette.night.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 8)
                .frame(maxHeight: .infinity)
                LossTray(title: strings.yourLosses, side: view.viewer, hiddenCount: 0, ranks: ownLosses(view))
                bottomPanel(view)
            }
            .foregroundStyle(Palette.ink)
            .background(Palette.paperHi.ignoresSafeArea())
            .overlay(alignment: .bottom) {
                if controller.phase == .over, let result = controller.state?.result {
                    overCard(result, view)
                        .padding(12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.4), value: controller.phase == .over)
            .sensoryFeedback(trigger: controller.announcement) { _, new in
                switch new?.tone {
                case .good: .success
                case .bad: .error
                case .neutral: .impact(weight: .light)
                case nil: nil
                }
            }
            .sheet(isPresented: $showingLog) { MoveLogView(view: view) }
            .sheet(isPresented: $showingRules) { NavigationStack { RulesView() } }
            .confirmationDialog(strings.confirmResign, isPresented: $confirmingResign, titleVisibility: .visible) {
                Button(strings.resign, role: .destructive) { controller.resign() }
                Button(strings.cancel, role: .cancel) {}
            }
        }
    }

    private var topBar: some View {
        HStack {
            Menu {
                Button { showingLog = true } label: { Label(strings.moveLog, systemImage: "list.bullet") }
                    .accessibilityIdentifier("game.menu.log")
                if controller.phase != .over {
                    Button(role: .destructive) { confirmingResign = true } label: { Label(strings.resign, systemImage: "flag") }
                        .accessibilityIdentifier("game.menu.resign")
                }
                Button { close() } label: {
                    Label(controller.phase == .over ? strings.home : strings.saveAndQuit, systemImage: "house")
                }
                .accessibilityIdentifier("game.menu.quit")
            } label: {
                IconBubble(systemName: "line.3.horizontal")
            }
            .accessibilityIdentifier("game.menu")
            Spacer()
            statusPill
            Spacer()
            Button { showingRules = true } label: { IconBubble(systemName: "book") }
                .accessibilityLabel(strings.rules)
                .accessibilityIdentifier("game.rules")
        }
        .padding(.horizontal)
        .padding(.top, 2)
    }

    private var statusPill: some View {
        HStack(spacing: 7) {
            if controller.aiThinking {
                ProgressView().tint(Palette.cream).controlSize(.mini)
            } else {
                Circle()
                    .fill(controller.viewer == .red ? Palette.red : Palette.blue)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(Palette.cream.opacity(0.4), lineWidth: 2))
                    .accessibilityLabel(strings.youAre(controller.viewer))
            }
            Text(statusText)
        }
        .font(.footnote.weight(.bold))
        .foregroundStyle(Palette.cream)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(Capsule().fill(Palette.ink))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("game.status")
    }

    private var statusText: String {
        if controller.phase == .over { return strings.gameOver }
        if controller.aiThinking { return strings.computerThinking }
        if controller.canMove { return strings.yourMove }
        return controller.state.map { strings.toMove($0.sideToMove) } ?? ""
    }

    @ViewBuilder
    private func bottomPanel(_ view: PlayerView) -> some View {
        // Everything here has a fixed height, so moves never resize the board:
        // the slip always reserves two lines of text, and in pass-and-play the
        // end-turn button's space is kept for the whole game.
        VStack(spacing: 8) {
            ZStack {
                if let text = announcementText, controller.phase != .over {
                    HStack(spacing: 10) {
                        Seal(text: "裁")
                        VStack(alignment: .leading, spacing: 1) {
                            Text(strings.referee).font(.caption2.weight(.bold)).textCase(.uppercase).foregroundStyle(Palette.ink.opacity(0.6))
                            Text(text)
                                .font(.footnote)
                                .lineLimit(2, reservesSpace: true)
                                .minimumScaleFactor(0.7)
                                .foregroundStyle(color(for: controller.announcement?.tone))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Palette.cream))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Palette.ink.opacity(0.18), lineWidth: 1))
                    .shadow(color: Palette.ink.opacity(0.25), radius: 6, y: 4)
                    .id(controller.announcement?.id)
                    .transition(.opacity)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("game.slip")
                }
            }
            .frame(height: Self.slipHeight)
            if controller.mode == .passAndPlay {
                Button(strings.endTurn(passingTo: controller.viewer.opponent)) { controller.endTurn() }
                    .buttonStyle(LacquerButtonStyle())
                    .opacity(controller.phase == .turnComplete ? 1 : 0)
                    .disabled(controller.phase != .turnComplete)
                    .accessibilityIdentifier("game.endTurn")
                    .accessibilityHidden(controller.phase != .turnComplete)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: controller.announcement)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    /// Seal plus a caption line and two lines of text, with padding.
    private static let slipHeight: CGFloat = 70

    private func overCard(_ result: GameResult, _ view: PlayerView) -> some View {
        let verdict = strings.verdict(result, viewer: controller.viewer, humanSide: controller.humanSide)
        return VStack(spacing: 10) {
            Seal(text: verdict.seal, size: 64, filled: true, font: AppFont.brush(46))
                .padding(.top, -46)
            Heading(text: verdict.title, size: 24)
                .accessibilityIdentifier("game.over.title")
            Text(strings.result(result, humanSide: controller.humanSide, drawLimit: controller.rules.noBattleDrawLimit))
                .font(.footnote)
                .foregroundStyle(Palette.ink.opacity(0.75))
                .multilineTextAlignment(.center)
            HStack {
                tally(enemyLosses(view), strings.enemyLost)
                tally(ownLosses(view).count, strings.youLost)
                tally(view.history.count, strings.moves)
            }
            .padding(.vertical, 6)
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
            HStack(spacing: 10) {
                Button(strings.home, action: close).buttonStyle(GhostButtonStyle())
                    .accessibilityIdentifier("game.over.home")
                Button(strings.rematch, action: rematch).buttonStyle(LacquerButtonStyle())
                    .accessibilityIdentifier("game.over.rematch")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Palette.cream).shadow(color: .black.opacity(0.4), radius: 20, y: 10))
        .foregroundStyle(Palette.ink)
    }

    private func tally(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text("\(value)").font(.title3.weight(.bold)).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(Palette.ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    private var announcementText: String? {
        guard let announcement = controller.announcement, let view = controller.playerView else { return nil }
        return strings.announcement(announcement.record, viewer: announcement.viewer, ownPieces: view.ownPieces)
    }

    private func color(for tone: Announcement.Tone?) -> Color {
        switch tone {
        case .good: Palette.jade
        case .bad: Palette.vermilion
        default: Palette.ink
        }
    }

    private func ownLosses(_ view: PlayerView) -> [Rank] {
        let alive = Set(view.squares.compactMap { $0 }.filter { $0.side == view.viewer }.map(\.id))
        return view.ownPieces.filter { !alive.contains($0.key) }.map(\.value).sorted { $0.rawValue < $1.rawValue }
    }

    private func enemyLosses(_ view: PlayerView) -> Int {
        Rank.fullArmy.count - view.squares.compactMap { $0 }.filter { $0.side != view.viewer }.count
    }
}

/// Removed pieces as miniature tiles: your own by rank, the enemy's face down with a count.
private struct LossTray: View {
    let title: String
    let side: Side
    let hiddenCount: Int
    let ranks: [Rank]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.caption2.weight(.semibold)).foregroundStyle(Palette.ink.opacity(0.7))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    if hiddenCount > 0 {
                        ForEach(0..<min(hiddenCount, 3), id: \.self) { _ in
                            PieceTile(side: side, rank: nil, strings: settings.strings).frame(height: 18)
                        }
                        Text("×\(hiddenCount)").font(.caption.weight(.bold)).monospacedDigit()
                    }
                    ForEach(Array(ranks.enumerated()), id: \.offset) { _, rank in
                        PieceTile(side: side, rank: rank, strings: settings.strings).frame(height: 18)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(height: 24)
        .padding(.horizontal)
    }
}

private struct MoveLogView: View {
    let view: PlayerView
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(Array(view.history.enumerated().reversed()), id: \.offset) { index, record in
                HStack {
                    Text("\(index + 1).").monospacedDigit().foregroundStyle(.secondary)
                    Circle().fill(record.side == .red ? Palette.red : Palette.blue).frame(width: 10, height: 10)
                    Text(record.move.description).monospaced()
                    Spacer()
                    Text(settings.strings.outcome(record.outcome)).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("log.list")
            .navigationTitle(settings.strings.moveLog)
            .toolbar { Button(settings.strings.done) { dismiss() }.accessibilityIdentifier("log.done") }
        }
    }
}
