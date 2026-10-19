import Testing
@testable import LuzhanqiKit

@Suite struct MovementTests {
    @Test func straightRailRunsAcrossTheFrontier() {
        let state = game(flags.with(["a2": (.red, .colonel)]))
        let reach = names(state.destinations(from: pos("a2")))
        #expect(reach.isSuperset(of: ["a3", "a6", "a7", "a11", "b2", "e2"]))
        #expect(!reach.contains("a12"))  // a11-a12 is a road, not railroad
    }

    @Test func railRunStopsAtFirstPiece() {
        let state = game(flags.with(["a2": (.red, .colonel), "a8": (.blue, .captain), "a4": (.red, .major)]))
        let reach = names(state.destinations(from: pos("a4")))
        #expect(reach.contains("a8"))  // may attack the first enemy
        #expect(!reach.contains("a9"))
        #expect(!reach.contains("a2"))  // own piece
        #expect(!names(state.destinations(from: pos("a2"))).contains("a5"))
    }

    @Test func onlyEngineersTurnCorners() {
        let colonel = game(flags.with(["c2": (.red, .colonel)]))
        let colonelReach = names(colonel.destinations(from: pos("c2")))
        #expect(colonelReach.isSuperset(of: ["a2", "e2"]))
        #expect(!colonelReach.contains("a5"))

        let engineer = game(flags.with(["c2": (.red, .engineer)]))
        let engineerReach = names(engineer.destinations(from: pos("c2")))
        #expect(engineerReach.isSuperset(of: ["a5", "a11", "e11", "c7", "b6"]))
        #expect(!engineerReach.contains("c5"))  // c3-c5 is road
    }

    @Test func engineerAttacksAtEndOfPathOnly() {
        let state = game(flags.with(["c2": (.red, .engineer), "a6": (.blue, .major)]))
        let reach = names(state.destinations(from: pos("c2")))
        #expect(reach.contains("a6"))
        #expect(reach.contains("a7"))  // reachable the other way round via c6-c7
        #expect(reach.contains("a11"))
    }

    @Test func mountainsBlockFilesBAndD() {
        let state = game(flags.with(["b6": (.red, .colonel), "d6": (.red, .colonel)]))
        #expect(!names(state.destinations(from: pos("b6"))).contains("b7"))
        #expect(!names(state.destinations(from: pos("d6"))).contains("d7"))
    }

    @Test func campsProtectAndConnectDiagonally() {
        let state = game(flags.with(["a4": (.red, .colonel), "b5": (.blue, .lieutenant)]))
        #expect(!names(state.destinations(from: pos("a4"))).contains("b5"))
        #expect(names(state.destinations(from: pos("a4"))).contains("b3"))
    }

    @Test func immobilePieces() {
        let state = game(flags.with([
            "d1": (.red, .colonel), "a2": (.red, .landmine), "c11": (.blue, .colonel),
        ]))
        #expect(state.destinations(from: pos("d1")).isEmpty)  // in headquarters
        #expect(state.destinations(from: pos("b1")).isEmpty)  // flag
        #expect(state.destinations(from: pos("a2")).isEmpty)  // landmine
    }

    @Test func applyRejectsIllegalMoves() {
        var state = game(flags.with(["a4": (.red, .colonel), "a10": (.blue, .colonel)]))
        #expect(throws: GameError.notYourPiece(pos("a10"))) { try state.apply(move("a10-a9")) }
        #expect(throws: GameError.illegalMove(move("a4-c4"))) { try state.apply(move("a4-c4")) }
        #expect(throws: Never.self) { try state.apply(move("a4-a5")) }
        #expect(state.sideToMove == .blue)
    }
}
