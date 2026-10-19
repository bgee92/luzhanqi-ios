import LuzhanqiKit
import SwiftUI

/// Red lacquer, the primary action.
struct LacquerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Palette.cream)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [Color(hex: 0xC94430), Palette.redDeep], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.18), lineWidth: 1).padding(0.5))
                    .shadow(color: Palette.redDeep.opacity(0.6), radius: 4, y: 3)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Dark ink, a secondary action on paper.
struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Palette.cream)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 12).fill(Palette.ink))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// An outlined button on paper.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).stroke(Palette.ink.opacity(0.3), lineWidth: 1.5))
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

/// A paper card, used on the home screen and for the game-over panel.
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.paperHi).shadow(color: .black.opacity(0.35), radius: 10, y: 6))
            .foregroundStyle(Palette.ink)
    }
}

/// A square red seal stamp with one or two characters.
struct Seal: View {
    let text: String
    var size: CGFloat = 34
    var filled = false
    var font: Font?

    var body: some View {
        Text(text)
            .font(font ?? AppFont.serif(size * 0.44))
            .foregroundStyle(filled ? Palette.cream : Palette.red)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.18).fill(filled ? Palette.red : .clear))
            .overlay(RoundedRectangle(cornerRadius: size * 0.18).stroke(Palette.red, lineWidth: filled ? 0 : 2))
            .rotationEffect(.degrees(-7))
    }
}

/// A round icon button on paper.
struct IconBubble: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: 34, height: 34)
            .background(Circle().fill(Palette.ink.opacity(0.1)))
    }
}

/// A small drawing of one piece's insignia, for difficulty choices and lists.
struct InsigniaMark: View {
    let rank: Rank

    var body: some View {
        Canvas { context, size in
            PieceArt.draw(rank, in: CGRect(origin: .zero, size: size), context: context)
        }
    }
}

/// A heading in the current language's display face.
struct Heading: View {
    let text: String
    var size: CGFloat = 17
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Text(text).font(AppFont.heading(size, settings.language))
    }
}
