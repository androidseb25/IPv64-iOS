import Foundation
import IPv64

/// Pure logic of the CDN64 list: plan gate, name, traffic text, pending state.
nonisolated enum CdnLogic {
    enum Availability: Equatable {
        case available, notInPlan
        case limitReached(used: Int, limit: Int)
        var canCreate: Bool { self == .available }
    }

    /// `usage.cdnDomains`: no counter or no limit = available, limit <= 0 = not in plan.
    static func availability(used: Double?, limit: Int?) -> Availability {
        guard let limit else { return .available }
        if limit <= 0 { return .notInPlan }
        let usedInt = Int((used ?? 0).rounded(.up))
        return usedInt >= limit ? .limitReached(used: usedInt, limit: limit) : .available
    }

    static func displayName(domain: String?, id: String) -> String {
        domain?.nonBlank ?? "Domain …" + String(id.suffix(4))
    }

    static func megabytes(_ mb: Double) -> String {
        if mb >= 1024 * 1024 { return String(format: "%.1f TB", locale: .current, mb / (1024 * 1024)) }
        if mb >= 1024 { return String(format: "%.2f GB", locale: .current, mb / 1024) }
        return String(format: "%.1f MB", locale: .current, mb)
    }

    static func gigabytes(_ gb: Double) -> String { megabytes(gb * 1024) }

    static func fraction(used: Double?, limit: Int?) -> Double? {
        guard let limit, limit > 0 else { return nil }
        return min(max((used ?? 0) / Double(limit), 0), 1)
    }

    /// Work of the CDN bot is open or something is being switched off: poll until it is done.
    static func isBusy(pending: [CDNPendingTask]?, proxy: CDNProxyState?, portmapper: CDNPortmapperState?) -> Bool {
        !(pending ?? []).isEmpty || proxy == .disabling || portmapper == .disabling
    }
}
