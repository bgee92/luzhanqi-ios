import LuzhanqiKit
import SwiftUI

/// A piece as the board draws it; `rank` is nil when hidden from the viewer.
struct BoardPiece: Identifiable, Hashable {
    let id: Int
    let side: Side
    let rank: Rank?
    let position: Position
}

extension PlayerView {
    var boardPieces: [BoardPiece] {
        Board.allPositions.compactMap { p in
            self[p].map { BoardPiece(id: $0.id, side: $0.side, rank: $0.rank, position: p) }
        }
    }
}

/// An arrow drawn over the board, for the movement examples in the rules.
struct BoardArrow: Hashable {
    enum Tone: Hashable { case gold, jade, red }
    var path: [Position]
    var tone: Tone
    var dashed = false
    /// Draws a "not allowed" mark at the end of the path.
    var blocked = false
}

/// Maps board positions to points. The board is 500 × 806 design units: five
/// columns of 100 and thirteen rows of 62, the extra row being the frontier.
/// The viewer's side is always at the bottom.
struct BoardGeometry {
    static let designSize = CGSize(width: 500, height: 806)
    static let aspectRatio = designSize.width / designSize.height

    let size: CGSize
    let viewer: Side

    /// Points per design unit.
    var unit: CGFloat { size.width / Self.designSize.width }
    var columnWidth: CGFloat { 100 * unit }
    var rowHeight: CGFloat { 62 * unit }

    func center(of p: Position) -> CGPoint {
        let d = Self.designCenter(of: p, viewer: viewer)
        return CGPoint(x: d.x * unit, y: d.y * unit)
    }

    static func designCenter(of p: Position, viewer: Side) -> CGPoint {
        let row = viewer == .red ? p.row : Board.rows - 1 - p.row
        let col = viewer == .red ? p.col : Board.cols - 1 - p.col
        let slot = row <= Board.frontierRow ? row : row + 1
        return CGPoint(x: CGFloat(col) * 100 + 50, y: CGFloat(slot) * 62 + 31)
    }

    func position(at point: CGPoint) -> Position? {
        Board.allPositions.first { p in
            let c = center(of: p)
            return abs(c.x - point.x) <= columnWidth / 2 && abs(c.y - point.y) <= rowHeight / 2
        }
    }

    /// Pieces are 88 × 54 design units.
    var pieceSize: CGSize { CGSize(width: 88 * unit, height: 54 * unit) }
}

struct BoardView: View {
    let viewer: Side
    let pieces: [BoardPiece]
    var selected: Position?
    /// Squares the selected piece can reach: empty ones get a dot, enemy ones a pulsing ring.
    var targets: Set<Position> = []
    var lastMove: Move?
    var strings: Strings
    /// Pieces drawn faded (during deployment: pieces that can't swap with the selection).
    var dimmed: Set<Position> = []
    /// A half of the board to shade (the enemy half during deployment).
    var shadedHalf: Side?
    var arrows: [BoardArrow] = []
    var onTap: ((Position) -> Void)?

    var body: some View {
        GeometryReader { proxy in
            let g = BoardGeometry(size: proxy.size, viewer: viewer)
            ZStack(alignment: .topLeading) {
                BoardBackground(viewer: viewer, language: strings.language).equatable()
                underlay(g)
                ForEach(pieces) { piece in
                    PieceTile(side: piece.side, rank: piece.rank, strings: strings, dimmed: dimmed.contains(piece.position))
                        .frame(width: g.pieceSize.width, height: g.pieceSize.height)
                        .scaleEffect(piece.position == selected ? 1.06 : 1)
                        .position(g.center(of: piece.position))
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityElement()
                        .accessibilityLabel(strings.pieceAccessibility(side: piece.side, rank: piece.rank, at: piece.position))
                        .accessibilityIdentifier("piece.\(piece.position.name)")
                }
                overlay(g)
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                if let onTap, let p = g.position(at: location) { onTap(p) }
            }
            .animation(.easeInOut(duration: 0.25), value: pieces)
        }
        .aspectRatio(BoardGeometry.aspectRatio, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("board")
    }

    /// Highlights drawn under the pieces.
    @ViewBuilder
    private func underlay(_ g: BoardGeometry) -> some View {
        let u = g.unit
        if let lastMove {
            ForEach([lastMove.from, lastMove.to], id: \.self) { p in
                RoundedRectangle(cornerRadius: 10 * u)
                    .fill(Palette.gold.opacity(0.38))
                    .frame(width: 96 * u, height: 60 * u)
                    .position(g.center(of: p))
            }
        }
        if let selected {
            RoundedRectangle(cornerRadius: 11 * u)
                .fill(Palette.gold)
                .frame(width: 98 * u, height: 62 * u)
                .blur(radius: 4 * u)
                .position(g.center(of: selected))
        }
        // A piece sheltering in a camp gets a green ring: it can't be attacked.
        ForEach(pieces.filter { Board.station(at: $0.position) == .camp }) { piece in
            RoundedRectangle(cornerRadius: 11 * u)
                .stroke(Palette.jade, lineWidth: 3.5 * u)
                .frame(width: 96 * u, height: 61 * u)
                .position(g.center(of: piece.position))
        }
    }

    /// Markers drawn over the pieces.
    @ViewBuilder
    private func overlay(_ g: BoardGeometry) -> some View {
        let u = g.unit
        if let shadedHalf {
            let top = (shadedHalf == .blue) == (viewer == .red)
            Rectangle()
                .fill(Palette.ground.opacity(0.45))
                .frame(width: g.size.width, height: 6 * 62 * u)
                .position(x: g.size.width / 2, y: top ? 3 * 62 * u : (7 * 62 + 3 * 62) * u)
                .allowsHitTesting(false)
        }
        if let selected {
            RoundedRectangle(cornerRadius: 10 * u)
                .stroke(Palette.gold, lineWidth: 3.5 * u)
                .frame(width: 93 * u, height: 59 * u)
                .scaleEffect(1.06)
                .position(g.center(of: selected))
                .allowsHitTesting(false)
        }
        ForEach(Array(targets), id: \.self) { p in
            Group {
                if pieces.contains(where: { $0.position == p }) {
                    AttackRing(unit: u)
                } else {
                    Circle()
                        .fill(Palette.jade)
                        .overlay(Circle().stroke(Palette.cream, lineWidth: 3 * u))
                        .frame(width: 22 * u, height: 22 * u)
                }
            }
            .position(g.center(of: p))
            .allowsHitTesting(false)
        }
        if !arrows.isEmpty {
            Canvas { context, _ in
                for arrow in arrows { draw(arrow, g, context) }
            }
            .allowsHitTesting(false)
        }
    }

    private func draw(_ arrow: BoardArrow, _ g: BoardGeometry, _ context: GraphicsContext) {
        let u = g.unit
        let points = arrow.path.map(g.center(of:))
        guard points.count > 1 else { return }
        let color: Color = switch arrow.tone {
        case .gold: Palette.gold
        case .jade: Palette.jade
        case .red: Palette.vermilion
        }
        var line = Path()
        line.addLines(points)
        context.stroke(line, with: .color(Color(hex: 0x2A1A10).opacity(0.35)),
                       style: StrokeStyle(lineWidth: 13 * u, lineCap: .round, lineJoin: .round))
        context.stroke(line, with: .color(color),
                       style: StrokeStyle(lineWidth: 8 * u, lineCap: .round, lineJoin: .round, dash: arrow.dashed ? [14 * u, 10 * u] : []))
        let end = points[points.count - 1], before = points[points.count - 2]
        if arrow.blocked {
            let mark = Path(ellipseIn: CGRect(x: end.x - 17 * u, y: end.y - 17 * u, width: 34 * u, height: 34 * u))
            context.fill(mark, with: .color(Palette.cream))
            context.stroke(mark, with: .color(Palette.vermilion), lineWidth: 3 * u)
            var cross = Path()
            cross.move(to: CGPoint(x: end.x - 7 * u, y: end.y - 7 * u)); cross.addLine(to: CGPoint(x: end.x + 7 * u, y: end.y + 7 * u))
            cross.move(to: CGPoint(x: end.x + 7 * u, y: end.y - 7 * u)); cross.addLine(to: CGPoint(x: end.x - 7 * u, y: end.y + 7 * u))
            context.stroke(cross, with: .color(Palette.vermilion), style: StrokeStyle(lineWidth: 4 * u, lineCap: .round))
        } else {
            let angle = atan2(end.y - before.y, end.x - before.x)
            var head = Path()
            head.move(to: CGPoint(x: end.x + cos(angle) * 14 * u, y: end.y + sin(angle) * 14 * u))
            head.addLine(to: CGPoint(x: end.x + cos(angle + 2.4) * 14 * u, y: end.y + sin(angle + 2.4) * 14 * u))
            head.addLine(to: CGPoint(x: end.x + cos(angle - 2.4) * 14 * u, y: end.y + sin(angle - 2.4) * 14 * u))
            head.closeSubpath()
            context.fill(head, with: .color(color))
        }
    }
}

/// The pulsing dashed ring around an enemy piece the selection can attack.
private struct AttackRing: View {
    let unit: CGFloat
    @State private var dim = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RoundedRectangle(cornerRadius: 11 * unit)
            .stroke(Palette.vermilion, style: StrokeStyle(lineWidth: 4 * unit, dash: [10 * unit, 6 * unit]))
            .frame(width: 97 * unit, height: 62 * unit)
            .opacity(dim ? 0.35 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.8).repeatForever()) { dim = true }
            }
    }
}

/// The battlefield: terrain with map contours and a few craters, the frontier
/// river with mountains, bridges and wire, then roads, railroads and stations
/// (camps ringed by palisades, headquarters flanked by sandbags).
struct BoardBackground: View, Equatable {
    let viewer: Side
    let language: AppLanguage

    var body: some View {
        Canvas { context, size in
            var c = context
            c.scaleBy(x: size.width / 500, y: size.height / 806)
            drawTerrain(c)
            drawFrontier(c)
            drawLinks(c)
            drawStations(c)
            let frame = Path(CGRect(x: 2.5, y: 2.5, width: 495, height: 801))
            c.stroke(frame, with: .color(Palette.ink), lineWidth: 5)
            c.stroke(Path(CGRect(x: 9, y: 9, width: 482, height: 788)), with: .color(Palette.ink.opacity(0.5)), lineWidth: 1.2)
        }
        .drawingGroup()
    }

    private func center(_ p: Position) -> CGPoint { BoardGeometry.designCenter(of: p, viewer: viewer) }

    private func drawTerrain(_ c: GraphicsContext) {
        c.fill(Path(CGRect(x: 0, y: 0, width: 500, height: 806)), with: .color(Palette.ground))
        // Soft olive patches, placed by a fixed seed so the board never changes.
        var seed: UInt64 = 0x5EED
        func next() -> CGFloat {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1)
        }
        for _ in 0..<26 {
            let x = next() * 500, y = next() * 806, r = 40 + next() * 70
            let tint = next() > 0.5 ? Color(hex: 0x7F8A4C) : Color(hex: 0xA08A55)
            c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.7, width: 2 * r, height: 1.4 * r)),
                   with: .radialGradient(Gradient(colors: [tint.opacity(0.16), tint.opacity(0)]),
                                         center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
        }
        for (i, y0) in [45.0, 120, 195, 270, 340, 470, 540, 615, 690, 765].enumerated() {
            var line = Path()
            for x in stride(from: 0.0, through: 500, by: 20) {
                let y = y0 + 9 * sin(x / 60 + Double(i) * 1.7) + 4 * sin(x / 23 + Double(i))
                x == 0 ? line.move(to: CGPoint(x: x, y: y)) : line.addLine(to: CGPoint(x: x, y: y))
            }
            c.stroke(line, with: .color(Palette.contour.opacity(0.16)), lineWidth: 1.1)
        }
        for point in [CGPoint(x: 100, y: 62), CGPoint(x: 400, y: 62), CGPoint(x: 100, y: 744), CGPoint(x: 300, y: 744)] {
            let crater = Path(ellipseIn: CGRect(x: point.x - 6.5, y: point.y - 6.5, width: 13, height: 13))
            c.fill(crater, with: .color(Color(hex: 0x7A6A4A).opacity(0.35)))
            c.stroke(crater, with: .color(Color(hex: 0xEFE4C0).opacity(0.6)), lineWidth: 1)
            c.fill(Path(ellipseIn: CGRect(x: point.x - 3.2, y: point.y - 3.2, width: 6.4, height: 6.4)), with: .color(Color(hex: 0x3F3322).opacity(0.4)))
        }
    }

    private func drawFrontier(_ c: GraphicsContext) {
        let top = 6.0 * 62, bottom = 7.0 * 62
        c.fill(Path(CGRect(x: 0, y: top, width: 500, height: 62)),
               with: .linearGradient(Gradient(colors: [Palette.riverEdge, Palette.riverMid, Palette.riverEdge]),
                                     startPoint: CGPoint(x: 0, y: top), endPoint: CGPoint(x: 0, y: bottom)))
        for y in [top + 18, top + 46] {
            var wave = Path()
            wave.move(to: CGPoint(x: 0, y: y))
            wave.addQuadCurve(to: CGPoint(x: 250, y: y), control: CGPoint(x: 125, y: y - 8))
            wave.addQuadCurve(to: CGPoint(x: 500, y: y), control: CGPoint(x: 375, y: y + 8))
            c.stroke(wave, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
        }
        for y in [top, bottom] {
            c.stroke(Path { p in p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: 500, y: y)) },
                     with: .color(Palette.bank), lineWidth: 3)
        }
        // Mountains on files b and d.
        for x in [150.0, 350.0] {
            let y = top + 31
            c.fill(ridge(x, y, [(-46, 22), (-30, -4), (-20, 6), (-4, -20), (10, 2), (24, -10), (46, 22)]),
                   with: .color(Palette.mountainBack.opacity(0.65)))
            c.fill(ridge(x, y, [(-38, 24), (-16, 3), (-5, 12), (14, -4), (40, 24)]),
                   with: .color(Palette.mountainFront.opacity(0.75)))
        }
        // Barbed wire along both banks, between the bridges.
        for y in [top + 6, bottom - 6] {
            for span in [(72.0, 228.0), (272.0, 428.0)] {
                var wire = Path()
                wire.move(to: CGPoint(x: span.0, y: y)); wire.addLine(to: CGPoint(x: span.1, y: y))
                for x in stride(from: span.0 + 4, to: span.1, by: 10) {
                    wire.move(to: CGPoint(x: x - 2, y: y - 2)); wire.addLine(to: CGPoint(x: x + 2, y: y + 2))
                    wire.move(to: CGPoint(x: x + 2, y: y - 2)); wire.addLine(to: CGPoint(x: x - 2, y: y + 2))
                }
                c.stroke(wire, with: .color(Color(hex: 0x3A2E24).opacity(0.55)), lineWidth: 1)
            }
        }
        // Rail bridges where files a, c and e cross.
        for x in [50.0, 250.0, 450.0] {
            let deck = Path(CGRect(x: x - 15, y: top - 4, width: 30, height: 70))
            c.fill(deck, with: .color(Palette.bridge))
            c.stroke(deck, with: .color(Palette.ink), lineWidth: 1.5)
            var planks = Path()
            for y in stride(from: top - 3, through: bottom + 3, by: 6) {
                planks.move(to: CGPoint(x: x - 15, y: y)); planks.addLine(to: CGPoint(x: x + 15, y: y))
            }
            c.stroke(planks, with: .color(Palette.ink.opacity(0.45)), lineWidth: 1)
        }
    }

    /// A closed mountain ridge from offsets relative to (x, y).
    private func ridge(_ x: Double, _ y: Double, _ offsets: [(Double, Double)]) -> Path {
        var path = Path()
        path.addLines(offsets.map { CGPoint(x: x + $0.0, y: y + $0.1) })
        path.closeSubpath()
        return path
    }

    private func drawLinks(_ c: GraphicsContext) {
        var roads = Path(), rails = Path()
        for p in Board.allPositions {
            for n in Board.roadNeighbors(of: p) where n > p {
                let isRail = Board.railNeighbors(of: p).contains(n)
                if isRail { rails.move(to: center(p)); rails.addLine(to: center(n)) } else { roads.move(to: center(p)); roads.addLine(to: center(n)) }
            }
        }
        c.stroke(roads, with: .color(Palette.inkSoft), lineWidth: 1.7)
        c.stroke(rails, with: .color(Palette.rail), lineWidth: 8)
        c.stroke(rails, with: .color(Palette.paperHi), style: StrokeStyle(lineWidth: 3.6, dash: [8, 7]))
    }

    private func drawStations(_ c: GraphicsContext) {
        let strings = Strings(language: language)
        let campLabel = strings.campMark
        let hqLabel = strings.headquartersMark
        for p in Board.allPositions {
            let o = center(p), x = o.x, y = o.y
            switch Board.station(at: p) {
            case .post:
                let box = Path(roundedRect: CGRect(x: x - 39, y: y - 24, width: 78, height: 48), cornerRadius: 6)
                c.fill(box, with: .color(Palette.paperHi))
                c.stroke(box, with: .color(Palette.ink), lineWidth: 1.7)
            case .camp:
                var stakes = Path()
                for a in stride(from: 0.0, to: 360, by: 20) {
                    let t = a * .pi / 180
                    stakes.move(to: CGPoint(x: x + 31 * cos(t), y: y + 31 * sin(t)))
                    stakes.addLine(to: CGPoint(x: x + 38.5 * cos(t), y: y + 38.5 * sin(t)))
                }
                c.stroke(stakes, with: .color(Palette.stake), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                let ring = Path(ellipseIn: CGRect(x: x - 33, y: y - 33, width: 66, height: 66))
                c.fill(ring, with: .color(Palette.camp))
                c.stroke(ring, with: .color(Palette.ink), lineWidth: 1.8)
                c.stroke(Path(ellipseIn: CGRect(x: x - 27, y: y - 27, width: 54, height: 54)),
                         with: .color(Palette.ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                c.draw(Text(campLabel).font(.system(size: 12, weight: .semibold)).foregroundColor(Palette.ink.opacity(0.45)), at: o)
            case .headquarters:
                for dx in [-49.0, 49.0] {
                    for (i, dy) in [-14.0, -2, 10, 22].enumerated() {
                        let bag = Path(ellipseIn: CGRect(x: x + dx + (i % 2 == 0 ? -2 : 2) - 5, y: y + dy - 6.5, width: 10, height: 13))
                        c.fill(bag, with: .color(Palette.sandbag))
                        c.stroke(bag, with: .color(Palette.sandbagEdge), lineWidth: 1)
                    }
                }
                let arch = Path { a in
                    a.move(to: CGPoint(x: x - 42, y: y + 27))
                    a.addLine(to: CGPoint(x: x - 42, y: y - 2))
                    a.addCurve(to: CGPoint(x: x + 42, y: y - 2), control1: CGPoint(x: x - 42, y: y - 35), control2: CGPoint(x: x + 42, y: y - 35))
                    a.addLine(to: CGPoint(x: x + 42, y: y + 27))
                    a.closeSubpath()
                }
                c.fill(arch, with: .color(Palette.headquarters))
                c.stroke(arch, with: .color(Palette.ink), lineWidth: 1.8)
                c.draw(Text(hqLabel).font(.system(size: 13, weight: .semibold)).foregroundColor(Palette.ink.opacity(0.5)),
                       at: CGPoint(x: x, y: y + 6))
            }
        }
    }
}
