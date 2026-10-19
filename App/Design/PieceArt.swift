import LuzhanqiKit
import SwiftUI

/// Piece illustrations, drawn in code so they stay sharp at any size.
///
/// Officers show only what tells their Chinese army (PLA) rank apart, using the
/// rank each role holds in real life: gold stars alone for generals, two bars and
/// stars for field officers, one bar and stars for company officers. The special
/// pieces show what they are, and face-down pieces show the 八一 army emblem.
enum PieceArt {
    /// (bars, stars) for each officer: 司令 上将, 军长 中将, 师长 少将, 旅长 大校,
    /// 团长 上校, 营长 少校, 连长 上尉, 排长 少尉.
    static func insignia(_ rank: Rank) -> (bars: Int, stars: Int)? {
        switch rank {
        case .fieldMarshal: (0, 3)
        case .general: (0, 2)
        case .majorGeneral: (0, 1)
        case .brigadier: (2, 4)
        case .colonel: (2, 3)
        case .major: (2, 1)
        case .captain: (1, 3)
        case .lieutenant: (1, 1)
        default: nil
        }
    }

    /// Draws the art for `rank`, fitted inside `rect`.
    static func draw(_ rank: Rank, in rect: CGRect, context: GraphicsContext) {
        if let mark = insignia(rank) {
            rankMark(bars: mark.bars, stars: mark.stars, in: space(CGSize(width: 60, height: 100), rect, context))
            return
        }
        let c = space(CGSize(width: 100, height: 100), rect, context)
        switch rank {
        case .engineer: pickAndShovel(c)
        case .bomb: bomb(c)
        case .landmine: mineWarning(c)
        case .flag: bayiFlag(c)
        default: break
        }
    }

    /// The 八一 army emblem: a red star with a gold rim and 八一 in gold.
    static func drawEmblem(in rect: CGRect, context: GraphicsContext) {
        let c = space(CGSize(width: 100, height: 100), rect, context)
        let shape = star(CGPoint(x: 50, y: 53), 44)
        c.fill(shape, with: .color(Color(hex: 0xD8261B)))
        c.stroke(shape, with: metal(Palette.goldMetal, 9, 97), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
        var text = c
        // Sized to sit inside the star's red centre, clear of the gold rim.
        text.addFilter(.shadow(color: Color(hex: 0x5A0C06), radius: 0.8, x: 0, y: 1))
        text.draw(Text("八一").font(AppFont.serif(17)).foregroundColor(Color(hex: 0xFFD75E)), at: CGPoint(x: 50, y: 57))
    }

    // MARK: Officers

    private static func rankMark(bars: Int, stars: Int, in c: GraphicsContext) {
        let xs: [CGFloat] = bars == 2 ? [15, 45] : bars == 1 ? [30] : []
        for x in xs {
            let bar = Path(roundedRect: CGRect(x: x - 3, y: 4, width: 6, height: 92), cornerRadius: 2)
            c.fill(bar, with: metal(Palette.goldMetal, 4, 96))
            c.stroke(bar, with: .color(edge), lineWidth: 1.5)
        }
        let ys: [CGFloat] = switch stars {
        case 4: [14, 38, 62, 86]
        case 3: [19, 50, 81]
        case 2: [30, 70]
        default: [50]
        }
        let r: CGFloat = stars == 4 ? 12 : stars == 3 ? 14 : stars == 2 ? 16 : 18
        for y in ys {
            let shape = star(CGPoint(x: 30, y: y), r)
            c.fill(shape, with: metal(Palette.goldMetal, y - r, y + r))
            c.stroke(shape, with: .color(Color(hex: 0x1D1305).opacity(0.65)), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
        }
    }

    // MARK: Special pieces

    private static func pickAndShovel(_ c: GraphicsContext) {
        var shovel = rotated(c, degrees: 42)
        part(&shovel, Path(roundedRect: CGRect(x: 47, y: 12, width: 6, height: 56), cornerRadius: 2), Palette.goldMetal)
        part(&shovel, Path(roundedRect: CGRect(x: 41, y: 8, width: 18, height: 6), cornerRadius: 3), Palette.goldMetal)
        part(&shovel, Path { p in
            p.move(to: CGPoint(x: 37, y: 64)); p.addLine(to: CGPoint(x: 63, y: 64)); p.addLine(to: CGPoint(x: 63, y: 77))
            p.addQuadCurve(to: CGPoint(x: 50, y: 96), control: CGPoint(x: 63, y: 91))
            p.addQuadCurve(to: CGPoint(x: 37, y: 77), control: CGPoint(x: 37, y: 91)); p.closeSubpath()
        }, Palette.silverMetal)
        var pick = rotated(c, degrees: -42)
        part(&pick, Path(roundedRect: CGRect(x: 47, y: 22, width: 6, height: 72), cornerRadius: 2), Palette.goldMetal)
        part(&pick, Path { p in
            p.move(to: CGPoint(x: 14, y: 30)); p.addQuadCurve(to: CGPoint(x: 86, y: 30), control: CGPoint(x: 50, y: 6))
            p.addLine(to: CGPoint(x: 84, y: 37)); p.addQuadCurve(to: CGPoint(x: 16, y: 37), control: CGPoint(x: 50, y: 17)); p.closeSubpath()
        }, Palette.silverMetal)
    }

    private static func bomb(_ c: GraphicsContext) {
        let ball = Path(ellipseIn: CGRect(x: 17, y: 31, width: 58, height: 58))
        c.fill(ball, with: .radialGradient(Gradient(colors: [Color(hex: 0x5B5F68), Color(hex: 0x25272D), Color(hex: 0x0D0E11)]),
                                           center: CGPoint(x: 35, y: 48), startRadius: 0, endRadius: 44))
        c.stroke(ball, with: .color(edge), lineWidth: 2.5)
        var cap = rotated(c, degrees: 32, around: CGPoint(x: 62, y: 30))
        part(&cap, Path(roundedRect: CGRect(x: 53, y: 23, width: 18, height: 14), cornerRadius: 3), Palette.goldMetal)
        c.stroke(Path { p in p.move(to: CGPoint(x: 69, y: 25)); p.addQuadCurve(to: CGPoint(x: 87, y: 15), control: CGPoint(x: 75, y: 11)) },
                 with: .color(Color(hex: 0xE8D6A8)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        let spark = star(CGPoint(x: 88, y: 13), 10)
        c.fill(spark, with: .color(Color(hex: 0xFFCF3F)))
        c.stroke(spark, with: .color(Color(hex: 0xE2531C)), lineWidth: 2)
        let shine = rotated(c, degrees: -35, around: CGPoint(x: 36, y: 49))
        shine.fill(Path(ellipseIn: CGRect(x: 28, y: 43.5, width: 16, height: 11)), with: .color(.white.opacity(0.4)))
    }

    private static func mineWarning(_ c: GraphicsContext) {
        let sign = Path { p in
            p.move(to: CGPoint(x: 50, y: 6)); p.addLine(to: CGPoint(x: 96, y: 90)); p.addLine(to: CGPoint(x: 4, y: 90)); p.closeSubpath()
        }
        c.fill(sign, with: .color(Color(hex: 0xF6C21C)))
        c.stroke(sign, with: .color(Color(hex: 0x141414)), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        let dark = GraphicsContext.Shading.color(Color(hex: 0x141414))
        c.fill(Path(ellipseIn: CGRect(x: 22, y: 64, width: 56, height: 18)), with: dark)
        c.fill(Path(roundedRect: CGRect(x: 40, y: 58, width: 20, height: 10), cornerRadius: 3), with: dark)
        c.fill(Path(CGRect(x: 48, y: 42, width: 4, height: 17)), with: dark)
        rotated(c, degrees: -22, around: CGPoint(x: 42, y: 60)).fill(Path(CGRect(x: 40, y: 46, width: 3.5, height: 14)), with: dark)
        rotated(c, degrees: 22, around: CGPoint(x: 58, y: 60)).fill(Path(CGRect(x: 56.5, y: 46, width: 3.5, height: 14)), with: dark)
    }

    private static func bayiFlag(_ c: GraphicsContext) {
        var flag = c
        part(&flag, Path(roundedRect: CGRect(x: 13, y: 8, width: 7, height: 87), cornerRadius: 2.5), Palette.goldMetal)
        part(&flag, Path(ellipseIn: CGRect(x: 10, y: 0.5, width: 13, height: 13)), Palette.goldMetal)
        let cloth = Path { p in
            p.move(to: CGPoint(x: 20, y: 14))
            p.addCurve(to: CGPoint(x: 90, y: 13), control1: CGPoint(x: 40, y: 5), control2: CGPoint(x: 60, y: 24))
            p.addLine(to: CGPoint(x: 90, y: 55))
            p.addCurve(to: CGPoint(x: 20, y: 57), control1: CGPoint(x: 60, y: 66), control2: CGPoint(x: 40, y: 47))
            p.closeSubpath()
        }
        c.fill(cloth, with: .color(Color(hex: 0xE3261B)))
        c.stroke(cloth, with: .color(Palette.cream), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        c.fill(star(CGPoint(x: 34, y: 27), 9), with: metal(Palette.goldMetal, 18, 36))
        c.draw(Text("八一").font(AppFont.serif(12)).foregroundColor(Color(hex: 0xF2C94C)), at: CGPoint(x: 53, y: 27))
    }

    // MARK: Helpers

    private static let edge = Color(hex: 0x2A0F08).opacity(0.55)

    /// A context whose coordinates are `size` design units, aspect-fitted and centred in `rect`.
    private static func space(_ size: CGSize, _ rect: CGRect, _ context: GraphicsContext) -> GraphicsContext {
        var c = context
        let s = min(rect.width / size.width, rect.height / size.height)
        c.translateBy(x: rect.midX - size.width * s / 2, y: rect.midY - size.height * s / 2)
        c.scaleBy(x: s, y: s)
        return c
    }

    private static func rotated(_ c: GraphicsContext, degrees: Double, around center: CGPoint = CGPoint(x: 50, y: 50)) -> GraphicsContext {
        var r = c
        r.translateBy(x: center.x, y: center.y)
        r.rotate(by: .degrees(degrees))
        r.translateBy(x: -center.x, y: -center.y)
        return r
    }

    private static func part(_ c: inout GraphicsContext, _ path: Path, _ colors: [Color]) {
        let box = path.boundingRect
        c.fill(path, with: metal(colors, box.minY, box.maxY))
        c.stroke(path, with: .color(edge), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
    }

    private static func metal(_ colors: [Color], _ top: CGFloat, _ bottom: CGFloat) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colors), startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom))
    }

    static func star(_ center: CGPoint, _ r: CGFloat) -> Path {
        Path { p in
            for i in 0..<10 {
                let a = -Double.pi / 2 + Double(i) * .pi / 5
                let rr = i.isMultiple(of: 2) ? r : r * 0.42
                let point = CGPoint(x: center.x + rr * cos(a), y: center.y + rr * sin(a))
                i == 0 ? p.move(to: point) : p.addLine(to: point)
            }
            p.closeSubpath()
        }
    }
}

/// A lacquered piece tile, 88 × 54 design units: insignia in a slim column on
/// the left, the name on the right so neither covers the other. Hidden pieces
/// show the 八一 emblem.
struct PieceTile: View {
    let side: Side
    let rank: Rank?
    let strings: Strings
    var dimmed = false

    static let aspectRatio: CGFloat = 88 / 54

    var body: some View {
        Canvas { context, size in
            Self.draw(side: side, rank: rank, strings: strings, dimmed: dimmed, in: CGRect(origin: .zero, size: size), context: context)
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .shadow(color: Color(hex: 0x2A160C).opacity(0.45), radius: 1.5, y: 2)
    }

    static func draw(side: Side, rank: Rank?, strings: Strings, dimmed: Bool, in rect: CGRect, context: GraphicsContext) {
        var c = context
        let s = min(rect.width / 88, rect.height / 54)
        c.translateBy(x: rect.midX - 44 * s, y: rect.midY - 27 * s)
        c.scaleBy(x: s, y: s)

        let tile = Path(roundedRect: CGRect(x: 0, y: 0, width: 88, height: 54), cornerRadius: 8)
        let stops = Palette.lacquer(side)
        c.fill(tile, with: .linearGradient(
            Gradient(stops: [.init(color: stops[0], location: 0), .init(color: stops[1], location: 0.55), .init(color: stops[2], location: 1)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: 54)))
        c.fill(tile, with: .linearGradient(
            Gradient(stops: [.init(color: .white.opacity(0.38), location: 0), .init(color: .white.opacity(0), location: 0.45)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: 54)))
        c.stroke(Path(roundedRect: CGRect(x: 3, y: 3, width: 82, height: 48), cornerRadius: 6),
                 with: .color(Palette.cream.opacity(0.28)), lineWidth: 1)

        var art = c
        art.addFilter(.shadow(color: Color(hex: 0x1A0804).opacity(0.6), radius: 1, x: 0, y: 1.5))
        if let rank {
            PieceArt.draw(rank, in: CGRect(x: 3, y: 6, width: 30, height: 42), context: art)
            var label = c
            label.addFilter(.shadow(color: Color(hex: 0x320804).opacity(0.75), radius: 0.7, x: 0, y: 1))
            let name = strings.pieceLabel(rank)
            let font = strings.language == .chinese ? AppFont.serif(23) : AppFont.display(name.count > 3 ? 21 : 25)
            label.draw(Text(name).font(font).foregroundColor(Palette.cream), at: CGPoint(x: 58, y: 28))
        } else {
            PieceArt.drawEmblem(in: CGRect(x: 20, y: 3, width: 48, height: 48), context: art)
        }
        if dimmed { c.fill(tile, with: .color(Palette.ground.opacity(0.62))) }
    }
}
