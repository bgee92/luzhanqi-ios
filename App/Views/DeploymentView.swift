import LuzhanqiKit
import SwiftUI

struct DeploymentView: View {
    let controller: GameController
    let side: Side
    let close: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let strings = settings.strings
        VStack(spacing: 8) {
            HStack {
                Button(strings.quit, action: close)
                    .accessibilityIdentifier("deploy.quit")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.red)
                Spacer()
                Heading(text: strings.deployTitle(side), size: 16)
                Spacer()
                Button(strings.ready) { controller.confirmDeployment() }
                    .accessibilityIdentifier("deploy.ready")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Palette.cream)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(LinearGradient(colors: [Palette.red, Palette.redDeep], startPoint: .top, endPoint: .bottom)))
            }
            .padding(.horizontal)

            // Always exactly two lines tall, so swapping pieces or showing an
            // error never moves the board; longer text shrinks to fit.
            Text(controller.setupViolation.map(strings.violation) ?? strings.deployHint)
                .font(.footnote)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.75)
                .accessibilityIdentifier("deploy.hint")
                .foregroundStyle(controller.setupViolation == nil ? Palette.ink.opacity(0.75) : Palette.vermilion)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

            BoardView(
                viewer: side,
                pieces: controller.draft.map { BoardPiece(id: $0.key.index, side: side, rank: $0.value, position: $0.key) },
                selected: controller.selected,
                strings: strings,
                dimmed: fadedPieces,
                shadedHalf: side.opponent,
                onTap: controller.tapDeployment
            )
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)

            HStack(spacing: 6) {
                ForEach(strings.setupChips, id: \.self) { chip in
                    Text(chip)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(Palette.ink.opacity(0.08)))
                }
            }
            .padding(.horizontal, 8)

            HStack(spacing: 10) {
                Button { controller.shuffleDraft() } label: { Label(strings.shuffle, systemImage: "shuffle") }
                    .accessibilityIdentifier("deploy.shuffle")
                Button { controller.suggestDraft() } label: { Label(strings.suggested, systemImage: "wand.and.stars") }
                    .accessibilityIdentifier("deploy.suggested")
            }
            .buttonStyle(GhostButtonStyle())
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .foregroundStyle(Palette.ink)
        .background(Palette.paperHi.ignoresSafeArea())
        .sensoryFeedback(.error, trigger: controller.setupViolation) { _, new in new != nil }
    }

    /// With a piece selected, the pieces it can't swap with are faded.
    private var fadedPieces: Set<Position> {
        guard let selected = controller.selected else { return [] }
        return Set(controller.draft.keys).subtracting(controller.swapTargets).subtracting([selected])
    }
}

struct HandoffView: View {
    let side: Side
    let isDeployment: Bool
    let ready: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let strings = settings.strings
        let colors = side == .red
            ? [Color(hex: 0xC4402C), Palette.red, Palette.redDeep]
            : [Color(hex: 0x2D4F9E), Palette.blue, Palette.blueDeep]
        ZStack {
            RadialGradient(colors: colors, center: UnitPoint(x: 0.5, y: 0.3), startRadius: 0, endRadius: 600)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Spacer()
                PieceTile(side: side, rank: nil, strings: strings)
                    .frame(width: 200)
                    .rotationEffect(.degrees(-7))
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 16)
                    .padding(.bottom, 24)
                    .accessibilityHidden(true)
                Heading(text: strings.passTo(side), size: 28)
                    .accessibilityIdentifier("handoff.title")
                    .multilineTextAlignment(.center)
                Text(isDeployment ? strings.handoffDeploy(side) : strings.handoffMove(side))
                    .font(.body)
                    .opacity(0.9)
                Text(strings.handoffPrivacy)
                    .font(.footnote)
                    .opacity(0.65)
                Spacer()
                Button(action: ready) {
                    Text(strings.handoffReady(side))
                        .font(.body.weight(.bold))
                        .foregroundStyle(side == .red ? Palette.red : Palette.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cream))
                        .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                }
                .accessibilityIdentifier("handoff.ready")
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .foregroundStyle(Palette.cream)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
    }
}
