/// Board topology: stations, roads, railroads, and square notation.
///
/// Positions are (row, col) with row 0...11 and col 0...4. Rows 0-5 are Blue's
/// half (row 0 is Blue's back row); rows 6-11 are Red's half (row 11 is Red's
/// back row). The frontier lies between rows 5 and 6 and can only be crossed
/// in columns 0, 2 and 4.
///
/// Square names are for humans: files a-e are columns 0-4 and ranks 1-12
/// count up from Red's back row, so "a1" is (11, 0) and "e12" is (0, 4).
///
/// Internally everything is indexed by `Position.index` (row * 5 + col) so the
/// move generator and AI can work on flat arrays and 64-bit square masks.

public enum Side: String, Codable, Sendable, CaseIterable {
    /// Bottom half; moves first.
    case red
    case blue

    public var opponent: Side { self == .red ? .blue : .red }
    public var name: String { self == .red ? "Red" : "Blue" }
}

public enum Station: String, Codable, Sendable {
    case post
    /// 行营: pieces here cannot be attacked.
    case camp
    /// 大本营: pieces here can never move again.
    case headquarters
}

public struct Position: Hashable, Codable, Sendable, Comparable, CustomStringConvertible {
    public let row: Int
    public let col: Int

    public init(_ row: Int, _ col: Int) {
        precondition((0..<Board.rows).contains(row) && (0..<Board.cols).contains(col), "off-board position")
        self.row = row
        self.col = col
    }

    public init(index: Int) {
        self.init(index / Board.cols, index % Board.cols)
    }

    /// Parses a square name such as "a1" or "e12".
    public init?(name: String) {
        let text = name.lowercased()
        guard let file = text.first, let col = Board.files.firstIndex(of: file),
              let rank = Int(text.dropFirst()), (1...Board.rows).contains(rank)
        else { return nil }
        self.init(Board.rows - rank, col)
    }

    public var index: Int { row * Board.cols + col }
    public var name: String { "\(Board.files[col])\(Board.rows - row)" }
    public var description: String { name }

    public static func < (a: Position, b: Position) -> Bool { a.index < b.index }
}

public enum Board {
    public static let rows = 12
    public static let cols = 5
    public static let count = rows * cols
    public static let files: [Character] = Array("abcde")
    /// Blue's front row; the frontier is between it and row 6.
    public static let frontierRow = 5
    public static let crossingCols: Set<Int> = [0, 2, 4]
    /// Local row (see `localRow`) of each side's front row.
    public static let frontLocalRow = 5

    public static let allPositions: [Position] = (0..<count).map(Position.init(index:))

    // MARK: Halves and local coordinates

    public static func toGlobal(_ side: Side, localRow: Int, col: Int) -> Position {
        Position(side == .blue ? localRow : rows - 1 - localRow, col)
    }

    /// Distance of `position` from `side`'s back row (0 = back row, 5 = front row).
    public static func localRow(_ side: Side, _ position: Position) -> Int {
        side == .blue ? position.row : rows - 1 - position.row
    }

    public static func half(of position: Position) -> Side {
        position.row <= frontierRow ? .blue : .red
    }

    public static func homePositions(_ side: Side) -> [Position] {
        (0..<rows / 2).flatMap { r in (0..<cols).map { c in toGlobal(side, localRow: r, col: c) } }
    }

    // MARK: Stations

    public static func station(at position: Position) -> Station { stations[position.index] }

    private static let localCamps: Set<[Int]> = [[2, 1], [2, 3], [3, 2], [4, 1], [4, 3]]
    private static let localHeadquarters: Set<[Int]> = [[0, 1], [0, 3]]

    static let stations: [Station] = allPositions.map { p in
        let local = [localRow(half(of: p), p), p.col]
        if localCamps.contains(local) { return .camp }
        if localHeadquarters.contains(local) { return .headquarters }
        return .post
    }

    // MARK: Roads

    /// One-step neighbours by index: orthogonal links plus diagonals touching a camp.
    static let road: [[Int]] = {
        var adj = [Set<Int>](repeating: [], count: count)
        func link(_ a: Position, _ b: Position) {
            adj[a.index].insert(b.index)
            adj[b.index].insert(a.index)
        }
        for p in allPositions {
            if p.col + 1 < cols { link(p, Position(p.row, p.col + 1)) }
            if p.row + 1 < rows, p.row != frontierRow || crossingCols.contains(p.col) {
                link(p, Position(p.row + 1, p.col))
            }
            if stations[p.index] == .camp {
                for dr in [-1, 1] { for dc in [-1, 1] { link(p, Position(p.row + dr, p.col + dc)) } }
            }
        }
        return adj.map { $0.sorted() }
    }()

    // MARK: Railroads

    /// Each railroad is a straight line; non-engineers may only travel along one.
    static let railLines: [[Int]] = {
        var lines: [[Position]] = [1, 5, 6, 10].map { r in (0..<cols).map { Position(r, $0) } }
        lines += [0, 4].map { c in (1..<rows - 1).map { Position($0, c) } }
        lines.append([Position(5, 2), Position(6, 2)])
        return lines.map { $0.map(\.index) }
    }()

    static let rail: [[Int]] = {
        var adj = [Set<Int>](repeating: [], count: count)
        for line in railLines {
            for (a, b) in zip(line, line.dropFirst()) {
                adj[a].insert(b)
                adj[b].insert(a)
            }
        }
        return adj.map { $0.sorted() }
    }()

    static let isRail: [Bool] = rail.map { !$0.isEmpty }

    static let railLinesThrough: [[[Int]]] = (0..<count).map { i in railLines.filter { $0.contains(i) } }

    // MARK: Public topology queries (for drawing and tests)

    public static func isRailroad(_ position: Position) -> Bool { isRail[position.index] }

    public static func roadNeighbors(of position: Position) -> [Position] {
        road[position.index].map(Position.init(index:))
    }

    public static func railNeighbors(of position: Position) -> [Position] {
        rail[position.index].map(Position.init(index:))
    }

    /// Every railroad segment between adjacent stations, each listed once.
    public static let railEdges: [(Position, Position)] = edges(rail)

    /// Every road link that is not also a railroad segment, each listed once.
    public static let roadEdges: [(Position, Position)] = edges(road).filter { a, b in
        !rail[a.index].contains(b.index)
    }

    private static func edges(_ adj: [[Int]]) -> [(Position, Position)] {
        adj.enumerated().flatMap { a, ns in
            ns.filter { $0 > a }.map { (Position(index: a), Position(index: $0)) }
        }
    }

    // MARK: Distances (AI heuristics)

    /// Minimum number of moves for an ordinary piece to travel between two
    /// squares on an empty board (a straight railroad run counts as one move).
    static let moveDistance: [[Int]] = {
        var oneMove = road.map(Set.init)
        for line in railLines {
            for a in line { for b in line where a != b { oneMove[a].insert(b) } }
        }
        return (0..<count).map { start in
            var dist = [Int](repeating: Int.max, count: count)
            dist[start] = 0
            var queue = [start]
            var head = 0
            while head < queue.count {
                let i = queue[head]
                head += 1
                for n in oneMove[i] where dist[n] == Int.max {
                    dist[n] = dist[i] + 1
                    queue.append(n)
                }
            }
            return dist
        }
    }()
}
