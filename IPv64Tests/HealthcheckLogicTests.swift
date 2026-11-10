import Foundation
import Testing
@testable import IPv64_net
import IPv64

struct HealthcheckViewsTests {
    private static let base = 1_800_000_000_000.0
    private static let step = 300_000.0
    private let times = (0..<5).map { base + Double($0) * step }

    @Test(arguments: [(0.37, 1), (0.38, 2), (0.74, 3), (0.0, 0), (1.0, 4), (-1.0, 0), (2.0, 4)])
    func nearestIndexPicksNearMidpoints(fraction: Double, expected: Int) {
        #expect(nearestIndex(times, tMin: Self.base, tMax: times.last!, fraction: fraction) == expected)
    }

    @Test func nearestIndexSingleElement() {
        #expect(nearestIndex([Self.base], tMin: Self.base, tMax: Self.base, fraction: 0.5) == 0)
    }

    @Test(arguments: [("", 0, nil), ("  ", 1, nil), ("90", 0, 90), (" 5 ", 1, 300), ("abc", 0, -1),
                      ("9223372036854775807", 2, -1), ("99999999999", 2, -1), ("-1", 0, -1), ("2", 99, 172_800), ("2", -5, 2),
                      ("2147483647", 0, 2_147_483_647), ("2147483648", 0, -1)] as [(String, Int, Int?)])
    func durationToSecondsHandlesOverflowAndRange(value: String, unit: Int, expected: Int?) {
        #expect(durationToSeconds(value, unitIdx: unit) == expected)
    }

    @Test(arguments: [(nil, "", 1), (0, "", 1), (90, "90", 0), (120, "2", 1), (7200, "2", 2), (172_800, "2", 3)] as [(Int?, String, Int)])
    func secondsToDurationUsesLargestExactUnit(seconds: Int?, value: String, unit: Int) {
        let result = secondsToDuration(seconds)
        #expect(result.0 == value && result.1 == unit)
    }

    @Test func tagsAreTrimmedAndDeduplicated() {
        #expect(hcParseTags(" a, b ,a,, c") == ["a", "b", "c"])
    }
}

struct HealthcheckExecutionTests {
    private let locs = ["de", "us"]

    @Test func executionFieldsPerMode() {
        #expect(executionFields(.online, nodeId: "n1", locations: locs) == ExecutionFields(execution: .online, nodeId: nil, locations: locs))
        #expect(executionFields(.local, nodeId: "n1", locations: locs) == ExecutionFields(execution: .local, nodeId: "n1", locations: nil))
        #expect(executionFields(.both, nodeId: "n1", locations: locs) == ExecutionFields(execution: .both, nodeId: "n1", locations: locs))
    }

    @Test func moveNeededTable() {
        // (nil,nil,locs → ONLINE,"stale",reversed): node id is irrelevant online, location order too
        #expect(!executionMoveNeeded(oldExec: nil, oldNodeId: nil, oldLocations: locs, exec: .online, nodeId: "stale", locations: locs.reversed()))
        #expect(!executionMoveNeeded(oldExec: .local, oldNodeId: "n1", oldLocations: [], exec: .local, nodeId: "n1", locations: locs))
        #expect(executionMoveNeeded(oldExec: .online, oldNodeId: nil, oldLocations: locs, exec: .local, nodeId: "n1", locations: locs))
        #expect(executionMoveNeeded(oldExec: .local, oldNodeId: "n1", oldLocations: [], exec: .local, nodeId: "n2", locations: locs))
        #expect(executionMoveNeeded(oldExec: .both, oldNodeId: "n1", oldLocations: locs, exec: .both, nodeId: "n1", locations: ["de"]))
        #expect(executionMoveNeeded(oldExec: .online, oldNodeId: nil, oldLocations: locs, exec: .online, nodeId: nil, locations: ["de"]))
    }
}

struct HealthcheckFilterTests {
    private func check(_ token: String, name: String, state: String, target: String = "example.org", paused: Bool? = nil,
                       execution: String? = nil) throws -> HC2Check {
        var json = "{\"token\":\"\(token)\",\"name\":\"\(name)\",\"type\":\"http\",\"target\":\"\(target)\",\"state\":{\"state\":\"\(state)\"}"
        if let paused { json += ",\"paused\":\(paused)" }
        if let execution { json += ",\"execution\":\"\(execution)\"" }
        return try decode(HC2Check.self, json + "}")
    }

    private func nodeCheck(_ token: String, name: String, state: String, owner: String?, paused: Bool? = nil) throws -> Node64.Check {
        var json = "{\"token\":\"\(token)\",\"name\":\"\(name)\",\"target\":\"t\",\"state\":{\"state\":\"\(state)\"}"
        if let owner { json += ",\"owner\":\"\(owner)\"" }
        if let paused { json += ",\"paused\":\(paused)" }
        return try decode(Node64.Check.self, json + "}")
    }

    @Test func accountListFiltersStatusExecutionAndSearch() throws {
        let checks = [
            try check("1", name: "Web", state: "up"),
            try check("2", name: "Mail", state: "down", execution: "local"),
            try check("3", name: "Shop", state: "flapping", target: "shop.example.org", execution: "both"),
            try check("4", name: "Old", state: "up", paused: true),
        ]
        func names(_ s: HcStatusFilter = .all, _ e: HcExecFilter = .all, _ q: String = "") -> [String] {
            healthcheckVisible(checks, status: s, exec: e, query: q).compactMap(\.name)
        }
        #expect(names().count == 4)
        #expect(names(.up) == ["Web"])
        #expect(names(.paused) == ["Old"])
        #expect(names(.degraded) == ["Shop"])
        #expect(names(.down) == ["Mail"])
        #expect(names(.all, .online) == ["Web", "Old"])
        #expect(names(.all, .node) == ["Mail"])
        #expect(names(.all, .both) == ["Shop"])
        #expect(names(.all, .all, "  SHOP ") == ["Shop"])
        #expect(names(.all, .all, "http") .count == 4)   // type label
        #expect(names(.up, .online, "o") == ["Web", "Old"].filter { _ in false } + ["Web"].filter { _ in true })
        #expect(healthcheckStatusCount(checks, .up) == 1)
        #expect(showsExecFilter(checks, current: .all))
        #expect(!showsExecFilter([checks[0]], current: .all))
        #expect(showsExecFilter([checks[0]], current: .online))
    }

    @Test func accountListHidesNodeOwnedChecksSortedByName() throws {
        let checks = [try check("1", name: "b", state: "up"), try check("2", name: "A", state: "up"), try check("3", name: "c", state: "up")]
        #expect(accountChecks(checks, hiddenTokens: ["3"]).compactMap(\.name) == ["A", "b"])
    }

    @Test func nodeListOwnerStatusSearch() throws {
        let checks = [
            try nodeCheck("1", name: "zeta", state: "up", owner: "self"),
            try nodeCheck("2", name: "Alpha", state: "down", owner: nil),
            try nodeCheck("3", name: "online-one", state: "up", owner: "online"),
            try nodeCheck("4", name: "foreign", state: "up", owner: "other"),
            try nodeCheck("5", name: "Pending", state: "pending", owner: "self"),
            try nodeCheck("6", name: "Pausy", state: "up", owner: "self", paused: true),
        ]
        func names(_ s: HcStatusFilter, _ q: String = "") -> [String] { nodeChecksVisible(checks, status: s, query: q).compactMap(\.name) }
        #expect(names(.all) == ["Alpha", "Pausy", "Pending", "zeta"])
        #expect(names(.up) == ["zeta"])
        #expect(names(.down) == ["Alpha"])
        #expect(names(.paused) == ["Pausy"])
        #expect(names(.all, "ZET") == ["zeta"])
        #expect(isNodeOwned(nil) && isNodeOwned(.thisNode))
        #expect(!isNodeOwned(.online) && !isNodeOwned(.other))
    }

    @Test func searchMatchesNameTargetOrTypeLabel() {
        #expect(healthcheckMatchesSearch("", name: nil, target: nil, typeLabel: nil))
        #expect(healthcheckMatchesSearch("ab", name: "Cabin", target: nil, typeLabel: nil))
        #expect(healthcheckMatchesSearch("ab", name: nil, target: "x.ab.y", typeLabel: nil))
        #expect(healthcheckMatchesSearch("ab", name: nil, target: nil, typeLabel: "LAB"))
        #expect(!healthcheckMatchesSearch("zz", name: "a", target: "b", typeLabel: "c"))
    }

    @Test func nodeStatusFilterDiffersFromAccountForPending() {
        #expect(!HcStatusFilter.up.matchesNode(state: "pending", paused: nil))
        #expect(HcStatusFilter.all.matchesNode(state: "pending", paused: nil))
        #expect(HcStatusFilter.degraded.matchesNode(state: "Flapping", paused: nil))
        #expect(HcStatusFilter.paused.matchesNode(state: "up", paused: true))
    }
}
