import Testing
@testable import LuzhanqiKit

@Suite struct BoardTests {
    @Test func stationCounts() {
        let stations = Board.allPositions.map(Board.station(at:))
        #expect(stations.filter { $0 == .camp }.count == 10)
        #expect(stations.filter { $0 == .headquarters }.count == 4)
        #expect(stations.filter { $0 == .post }.count == 46)
        #expect(names(Board.allPositions.filter { Board.station(at: $0) == .headquarters }) == ["b1", "d1", "b12", "d12"])
        #expect(names(Board.allPositions.filter { Board.station(at: $0) == .camp })
            == ["b3", "d3", "c4", "b5", "d5", "b8", "d8", "c9", "b10", "d10"])
    }

    @Test func frontierCrossings() {
        #expect(names(Board.roadNeighbors(of: pos("a6"))).contains("a7"))
        #expect(names(Board.roadNeighbors(of: pos("c6"))).contains("c7"))
        #expect(names(Board.roadNeighbors(of: pos("e6"))).contains("e7"))
        #expect(!names(Board.roadNeighbors(of: pos("b6"))).contains("b7"))
        #expect(!names(Board.roadNeighbors(of: pos("d6"))).contains("d7"))
    }

    @Test func campDiagonals() {
        #expect(names(Board.roadNeighbors(of: pos("b3"))) == ["a2", "b2", "c2", "a3", "c3", "a4", "b4", "c4"])
        #expect(names(Board.roadNeighbors(of: pos("c4"))) == ["b3", "c3", "d3", "b4", "d4", "b5", "c5", "d5"])
        // Diagonals only exist where a camp is involved.
        #expect(!names(Board.roadNeighbors(of: pos("c2"))).contains("b1"))
        #expect(names(Board.roadNeighbors(of: pos("a4"))).contains("b3"))
    }

    @Test func railroads() {
        #expect(!Board.isRailroad(pos("a1")))
        #expect(Board.isRailroad(pos("a2")))
        #expect(Board.isRailroad(pos("c6")) && Board.isRailroad(pos("c7")))
        #expect(!Board.isRailroad(pos("c5")))
        #expect(names(Board.railNeighbors(of: pos("c6"))) == ["b6", "d6", "c7"])
        #expect(names(Board.railNeighbors(of: pos("a6"))) == ["a5", "a7", "b6"])
        #expect(Board.railNeighbors(of: pos("b6")).allSatisfy { $0.name != "b7" })
    }

    @Test func notation() {
        #expect(Position(name: "a1") == Position(11, 0))
        #expect(Position(name: "e12") == Position(0, 4))
        #expect(Position(name: "f1") == nil)
        #expect(Position(name: "a13") == nil)
        #expect(Position(name: "a0") == nil)
        #expect(Board.allPositions.allSatisfy { Position(name: $0.name) == $0 })
        #expect(Move(notation: "a4-a5") == Move(pos("a4"), pos("a5")))
    }
}
