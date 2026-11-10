import Foundation
import IPv64

/// Result of an execution change (`checks.move` + test run; Android `Hc2MoveRunner`).
enum MoveOutcome: Equatable {
    case applied
    case failed(String)
    case timedOut
}

/// Starts the move and polls the test run every 2 s for at most 60 s (one network error tolerated).
func runHealthcheckMove(api: IPv64, token: String, fields: ExecutionFields) async throws -> MoveOutcome {
    let run = try await ipv64Retrying {
        try await api.hc2.checks.move(token, execution: fields.execution, nodeID: fields.nodeId, nodes: nil,
                                      locations: fields.locations?.map(HC2Location.init(rawValue:)))
    }
    switch classifyTestrun(run) {
    case .applied: return .applied
    case .failed(let message): return .failed(message)
    case .running: break
    }
    let polled = try await pollUntil(
        interval: .seconds(2), max: .seconds(60),
        fetch: { try await api.hc2.checks.testrun(run.id) },
        done: { classifyTestrun($0) != .running })
    guard let polled else { return .timedOut }
    switch classifyTestrun(polled) {
    case .applied: return .applied
    case .failed(let message): return .failed(message)
    case .running: return .timedOut
    }
}
