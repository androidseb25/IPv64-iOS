import SwiftUI
import IPv64

/// Alert for "plan does not allow another CDN domain" (Android `cdnLimitMessage`).
func cdnLimitError(_ availability: ProxyLogic.Availability) -> ErrorText {
    if case .limitReached(_, let limit) = availability {
        return ErrorText(title: String(localized: "Plan limit reached"),
                         message: String(localized: "Your plan allows \(limit) CDN domains. Remove one or upgrade your plan."))
    }
    return ErrorText(title: String(localized: "Plan limit reached"),
                     message: String(localized: "Your plan does not allow more CDN domains."))
}

/// Failure of `cdn.add`: plan/limit errors as "Plan limit reached", others as create errors.
func cdnAddFailure(_ error: any Error) -> ErrorText {
    if let error = error as? IPv64Error, error.isLimitReached || error.isPlanRestricted {
        return ErrorText(title: String(localized: "Plan limit reached"), message: error.planRestrictionText)
    }
    return ErrorText(error, context: .create)
}

extension Me {
    /// Plan availability of the CDN (`usage.cdnDomains`).
    var cdnAvailability: ProxyLogic.Availability {
        ProxyLogic.availability(counterPresent: usage?.cdnDomains != nil, used: usage?.cdnDomains?.used,
                                limit: usage?.cdnDomains?.limit)
    }
}

/// Domain picker (Android `DomainPickerDialog`): searchable list of the account's domains.
struct DomainPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Session.self) private var session

    let exclude: Set<String>
    let onPick: (String) -> Void

    @State private var domains: [String]?
    @State private var error: ErrorText?
    @State private var query = ""

    private var visible: [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return (domains ?? []).filter { !exclude.contains($0) && (q.isEmpty || $0.lowercased().contains(q)) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let domains {
                    List(visible, id: \.self) { name in
                        Button(name) { dismiss(); onPick(name) }.foregroundStyle(.primary)
                    }
                    .overlay {
                        if visible.isEmpty {
                            Text(domains.isEmpty ? "No domains yet." : "No domains available.").foregroundStyle(.secondary)
                        }
                    }
                } else if let error {
                    ErrorStateView(title: error.title, message: error.message) { Task { await load() } }
                } else {
                    LoadingView()
                }
            }
            .searchable(text: $query, prompt: "Search")
            .navigationTitle("Add domain to CDN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", systemImage: "xmark") { dismiss() } }
            }
            .task { await load() }
        }
        .presentationDetents([.large])
    }

    private func load() async {
        error = nil
        do {
            domains = try await ipv64Retrying { try await session.api.domains.list() }
                .compactMap { $0.name?.nonBlank }.sorted { $0.lowercased() < $1.lowercased() }
        } catch where !isCancellation(error) {
            self.error = ErrorText(error)
        } catch {}
    }
}
