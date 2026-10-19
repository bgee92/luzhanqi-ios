@testable import LuzhanqiKit

func pos(_ name: String) -> Position {
    guard let p = Position(name: name) else { fatalError("bad square \(name)") }
    return p
}

/// Builds a position from square names, e.g. ["a4": (.red, .colonel)].
func game(_ pieces: [String: (Side, Rank)], toMove side: Side = .red, rules: RuleOptions = .standard) -> GameState {
    var placed = [Position: Piece]()
    for (name, (side, rank)) in pieces {
        let p = pos(name)
        placed[p] = Piece(id: p.index, side: side, rank: rank)
    }
    return GameState(pieces: placed, sideToMove: side, rules: rules)
}

func names(_ positions: [Position]) -> Set<String> { Set(positions.map(\.name)) }

func move(_ text: String) -> Move {
    guard let m = Move(notation: text) else { fatalError("bad move \(text)") }
    return m
}

/// Both flags present so the game is not trivially over.
let flags: [String: (Side, Rank)] = ["b1": (.red, .flag), "b12": (.blue, .flag)]

extension Dictionary where Key == String, Value == (Side, Rank) {
    func with(_ other: [String: (Side, Rank)]) -> Self { merging(other) { $1 } }
}
