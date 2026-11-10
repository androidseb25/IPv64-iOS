import SwiftUI

struct LoadingView: View {
    private let text: LocalizedStringKey

    init(_ text: LocalizedStringKey = "Loading...") { self.text = text }

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    /// Blocking spinner overlay (Android SpinnerDialog).
    func loadingOverlay(_ isPresented: Bool, text: LocalizedStringKey = "Loading...") -> some View {
        overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    HStack(spacing: 16) {
                        ProgressView()
                        Text(text).font(.body)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 32)
                }
                .transition(.opacity)
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.default, value: isPresented)
    }
}

struct ErrorStateView: View {
    let title: String
    let message: String
    var hint: String?
    var retry: (() -> Void)?

    init(title: String, message: String, hint: String? = nil, retry: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.hint = hint
        self.retry = retry
    }

    var body: some View {
        ContentUnavailableView {
            Label { Text(verbatim: title) } icon: { Image(systemName: "exclamationmark.triangle") }
        } description: {
            Text(verbatim: message)
            if let hint { Text(verbatim: hint).font(.footnote) }
        } actions: {
            if let retry { Button("Retry", systemImage: "arrow.clockwise", action: retry).buttonStyle(.bordered) }
        }
    }
}

struct EmptyStateView: View {
    private let text: Text
    private let actionLabel: LocalizedStringKey?
    private let action: (() -> Void)?

    init(_ text: LocalizedStringKey, actionLabel: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.text = Text(text)
        self.actionLabel = actionLabel
        self.action = action
    }

    init(verbatim: String, actionLabel: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.text = Text(verbatim: verbatim)
        self.actionLabel = actionLabel
        self.action = action
    }

    var body: some View {
        VStack(spacing: 12) {
            text.font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionLabel, let action {
                Button(action: action) { Text(actionLabel) }.buttonStyle(.bordered)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

struct NotAvailableView: View {
    @Environment(\.openURL) private var openURL
    let feature: String
    var reason: String?

    init(feature: String, reason: String? = nil) {
        self.feature = feature
        self.reason = reason
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("\(feature) is not available on your plan").font(.headline).multilineTextAlignment(.center)
            if let reason { Text(verbatim: reason).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            Button("View plans", systemImage: "arrow.up.right") {
                if let url = URL(string: "https://ipv64.net/pricing") { openURL(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ScrollView {
        LoadingView().frame(height: 100)
        ErrorStateView(title: "Failed", message: "Something broke", hint: "Check network") {}
        EmptyStateView("No domains yet.", actionLabel: "Add") {}
        NotAvailableView(feature: "Healthchecks", reason: "Upgrade needed")
    }
    .loadingOverlay(true)
}
