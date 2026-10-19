import Testing
@testable import LuzhanqiKit

@Suite struct SetupTests {
    @Test(arguments: Side.allCases)
    func randomDeploymentsAreLegal(side: Side) throws {
        for seed in 0..<100 {
            var rng = SeededGenerator(seed: UInt64(seed))
            let deployment = Setup.random(for: side, using: &rng)
            #expect(deployment.count == 25)
            #expect(Setup.errors(in: deployment, for: side).isEmpty)
        }
    }

    @Test func placementRules() {
        #expect(Setup.placementError(.flag, at: pos("b1"), for: .red) == nil)
        #expect(Setup.placementError(.flag, at: pos("a1"), for: .red) == .flagOutsideHeadquarters)
        #expect(Setup.placementError(.landmine, at: pos("c2"), for: .red) == nil)
        #expect(Setup.placementError(.landmine, at: pos("c3"), for: .red) == .landmineOutsideBackRows)
        #expect(Setup.placementError(.landmine, at: pos("c11"), for: .blue) == nil)
        #expect(Setup.placementError(.bomb, at: pos("a5"), for: .red) == nil)
        #expect(Setup.placementError(.bomb, at: pos("a6"), for: .red) == .bombInFrontRow)
        #expect(Setup.placementError(.bomb, at: pos("a7"), for: .blue) == .bombInFrontRow)
        #expect(Setup.placementError(.captain, at: pos("b3"), for: .red) == .campMustStartEmpty)
        #expect(Setup.placementError(.captain, at: pos("a7"), for: .red) == .outsideOwnHalf)
    }

    @Test func wrongCountsAreReported() {
        var rng = SeededGenerator(seed: 1)
        var deployment = Setup.random(for: .red, using: &rng)
        let general = deployment.first { $0.value == .general }!.key
        deployment[general] = .fieldMarshal
        #expect(Setup.errors(in: deployment, for: .red).count == 2)
        #expect(throws: GameError.self) {
            try GameState(red: deployment, blue: Setup.random(for: .blue, using: &rng))
        }
    }

    @Test func swappingValidates() throws {
        var rng = SeededGenerator(seed: 2)
        let deployment = Setup.random(for: .red, using: &rng)
        let flag = deployment.first { $0.value == .flag }!.key
        let frontOfficer = deployment.first { Board.localRow(.red, $0.key) == 5 }!.key
        guard case .failure = Setup.swapping(flag, frontOfficer, in: deployment, for: .red) else {
            Issue.record("flag left the headquarters")
            return
        }
        let otherHQ = [pos("b1"), pos("d1")].first { $0 != flag }!
        let swapped = try Setup.swapping(flag, otherHQ, in: deployment, for: .red).get()
        #expect(swapped[otherHQ] == .flag)
        #expect(Setup.errors(in: swapped, for: .red).isEmpty)
    }
}
