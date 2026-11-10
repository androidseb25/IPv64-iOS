import SwiftUI

struct SheetScaffold<Content: View>: View {
    @Environment(\.dismiss) private var dismiss

    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let confirmLabel: LocalizedStringKey?
    private let confirmSystemImage: String
    private let confirmEnabled: Bool
    private let destructive: Bool
    private let isBusy: Bool
    private let dismissible: Bool
    private let detents: Set<PresentationDetent>
    private let onConfirm: (() -> Void)?
    private let content: Content

    init(
        _ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, confirmLabel: LocalizedStringKey? = nil,
        confirmSystemImage: String = "checkmark", confirmEnabled: Bool = true, destructive: Bool = false,
        isBusy: Bool = false, dismissible: Bool = true, detents: Set<PresentationDetent> = [.large],
        onConfirm: (() -> Void)? = nil, @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.confirmLabel = confirmLabel
        self.confirmSystemImage = confirmSystemImage
        self.confirmEnabled = confirmEnabled
        self.destructive = destructive
        self.isBusy = isBusy
        self.dismissible = dismissible
        self.detents = detents
        self.onConfirm = onConfirm
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary) }
                    content
                }
                .padding(16)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if dismissible {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", systemImage: "xmark") { dismiss() }.disabled(isBusy)
                    }
                    .appVisibilityPriorityHigh()
                }
                if let onConfirm, let confirmLabel {
                    ToolbarItem(placement: .confirmationAction) {
                        if isBusy {
                            ProgressView()
                        } else {
                            Button(confirmLabel, systemImage: confirmSystemImage, action: onConfirm)
                                .tint(destructive ? Color.ipv64Red : nil)
                                .disabled(!confirmEnabled)
                        }
                    }
                    .appVisibilityPriorityHigh()
                }
            }
        }
        .interactiveDismissDisabled(isBusy || !dismissible)
        .presentationDetents(detents)
    }
}

#Preview {
    Text("Host").sheet(isPresented: .constant(true)) {
        SheetScaffold("Edit", subtitle: "Subtitle", confirmLabel: "Save") {
            FormSection("Field") { Text("Content") }
        }
    }
}
